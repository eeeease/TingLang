import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'client.dart';
import 'errors.dart';
import 'http.dart';
import 'models.dart';
import 'server_url.dart';

String _base64Url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

/// RFC 7636 proof key (S256).
class Pkce {
  Pkce(this.verifier) : challenge = _base64Url(sha256.convert(ascii.encode(verifier)).bytes);

  /// 32 random bytes → a 43-character verifier.
  factory Pkce.generate([Random? random]) {
    final rng = random ?? Random.secure();
    return Pkce(_base64Url(List<int>.generate(32, (_) => rng.nextInt(256))));
  }

  final String verifier, challenge;
}

/// A random `state` value for one sign-in.
String newState([Random? random]) {
  final rng = random ?? Random.secure();
  return _base64Url(List<int>.generate(16, (_) => rng.nextInt(256)));
}

/// Opens the sign-in page and returns the callback URL it ends on. On macOS
/// this is a system authentication session (ASWebAuthenticationSession).
abstract interface class AuthorizationAgent {
  /// Throws [AuthFailure] with [AuthFailureReason.canceled] when the user
  /// closes the window.
  Future<Uri> authorize(Uri url, {required String callbackScheme});
}

/// Where the refresh token lives (the Keychain in the app).
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String refreshToken);
  Future<void> delete();
}

class TokenSet {
  const TokenSet({required this.accessToken, required this.expiresAt, this.refreshToken});
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
}

/// The authorization request (authorization code with PKCE, public client).
Uri authorizationUrl(AuthConfig auth, Pkce pkce, String state) =>
    auth.authorizationEndpoint.replace(
      queryParameters: {
        ...auth.authorizationEndpoint.queryParameters,
        'response_type': 'code',
        'client_id': auth.clientId,
        'redirect_uri': auth.redirectUri.toString(),
        'code_challenge': pkce.challenge,
        'code_challenge_method': 'S256',
        'state': state,
        if (auth.scopes.isNotEmpty) 'scope': auth.scopes.join(' '),
      },
    );

/// The authorization code from [callback], after checking that it belongs to
/// this sign-in.
String codeFromCallback(Uri callback, {required AuthConfig auth, required String state}) {
  final expected = auth.redirectUri;
  if (callback.scheme != expected.scheme ||
      callback.host != expected.host ||
      callback.path != expected.path) {
    throw const AuthFailure('Unexpected sign-in callback', reason: AuthFailureReason.mismatch);
  }
  final query = callback.queryParameters;
  if (query['state'] != state) {
    throw const AuthFailure('Sign-in state does not match', reason: AuthFailureReason.mismatch);
  }
  final error = query['error'];
  if (error != null) {
    throw AuthFailure(
      'Sign-in was not completed ($error)',
      reason: error == 'access_denied' ? AuthFailureReason.canceled : AuthFailureReason.other,
    );
  }
  final code = query['code'];
  if (code == null || code.isEmpty) {
    throw const AuthFailure('The callback carried no code', reason: AuthFailureReason.mismatch);
  }
  return code;
}

/// The token and revocation endpoints from [AuthConfig].
class OAuthClient {
  OAuthClient(
    this.auth, {
    HttpClient? http,
    String? userAgent,
    DateTime Function()? now,
    Duration timeout = const Duration(seconds: 30),
  }) : _transport = HttpTransport(http: http, userAgent: userAgent, timeout: timeout),
       _now = now ?? DateTime.now {
    ServerUrl.checkSecure(auth.tokenEndpoint);
    ServerUrl.checkSecure(auth.authorizationEndpoint);
    if (auth.revocationEndpoint != null) ServerUrl.checkSecure(auth.revocationEndpoint!);
  }

  final AuthConfig auth;
  final HttpTransport _transport;
  final DateTime Function() _now;

  Future<TokenSet> exchangeCode(String code, Pkce pkce) => _token({
    'grant_type': 'authorization_code',
    'code': code,
    'redirect_uri': auth.redirectUri.toString(),
    'client_id': auth.clientId,
    'code_verifier': pkce.verifier,
  });

  Future<TokenSet> refresh(String refreshToken) => _token({
    'grant_type': 'refresh_token',
    'refresh_token': refreshToken,
    'client_id': auth.clientId,
  });

  /// Whether a refused token request means the grant itself is unusable.
  /// RFC 6749 servers say `invalid_grant`; some (Supabase's OAuth server)
  /// answer a revoked, expired or reused refresh token with their own code
  /// (`refresh_token_not_found`, …) and HTTP 400. A refresh refused with 400
  /// or 401 can never succeed later, so it counts as a dead grant too.
  static bool _grantGone(Map<String, String> form, int status, Object? error) =>
      error == 'invalid_grant' ||
      (form['grant_type'] == 'refresh_token' && (status == 400 || status == 401));

  /// RFC 7009. Does nothing when the server has no revocation endpoint.
  Future<void> revoke(String token, {String hint = 'refresh_token'}) async {
    final endpoint = auth.revocationEndpoint;
    if (endpoint == null) return;
    final reply = await _transport.send(
      'POST',
      endpoint,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: utf8.encode(
        Uri(queryParameters: {'token': token, 'token_type_hint': hint, 'client_id': auth.clientId})
            .query,
      ),
    );
    if (!reply.ok) throw reply.problem();
  }

  Future<TokenSet> _token(Map<String, String> form) async {
    final reply = await _transport.send(
      'POST',
      auth.tokenEndpoint,
      headers: {'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json'},
      body: utf8.encode(Uri(queryParameters: form).query),
    );
    final body = reply.json();
    if (!reply.ok) {
      // RFC 6749 §5.2: {"error": "invalid_grant", ...}; Supabase also sends
      // {"error_code": "...", "msg": "..."}.
      final fields = body is Map<String, Object?> ? body : const <String, Object?>{};
      final error = fields['error'] ?? fields['error_code'];
      throw AuthFailure(
        'The sign-in server refused the request (${error ?? reply.status})',
        reason: _grantGone(form, reply.status, error)
            ? AuthFailureReason.invalidGrant
            : AuthFailureReason.other,
      );
    }
    if (body is! Map<String, Object?>) throw const ApiBadResponse('token: expected an object');
    final access = body['access_token'];
    final type = body['token_type'];
    final expiresIn = body['expires_in'];
    final refresh = body['refresh_token'];
    if (access is! String || access.isEmpty) {
      throw const ApiBadResponse('token: no access_token');
    }
    if (type is String && type.toLowerCase() != 'bearer') {
      throw const ApiBadResponse('token: not a bearer token');
    }
    return TokenSet(
      accessToken: access,
      refreshToken: refresh is String && refresh.isNotEmpty ? refresh : null,
      expiresAt: _now().add(Duration(seconds: expiresIn is num ? expiresIn.toInt() : 3600)),
    );
  }

  void close() => _transport.close();
}

/// Signs in with [agent] and returns the tokens (not yet stored).
Future<TokenSet> signIn(OAuthClient client, AuthorizationAgent agent, {Random? random}) async {
  final pkce = Pkce.generate(random);
  final state = newState(random);
  final callback = await agent.authorize(
    authorizationUrl(client.auth, pkce, state),
    callbackScheme: client.auth.redirectUri.scheme,
  );
  return client.exchangeCode(codeFromCallback(callback, auth: client.auth, state: state), pkce);
}

/// Keeps an access token fresh from the stored refresh token. Refresh tokens
/// rotate, so every new one replaces the stored one.
class AuthSession implements TokenSource {
  AuthSession(this.client, this.store, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final OAuthClient client;
  final TokenStore store;
  final DateTime Function() _now;
  TokenSet? _current;
  Future<TokenSet>? _refreshing;

  /// Stores a fresh sign-in.
  Future<void> adopt(TokenSet tokens) async {
    final refresh = tokens.refreshToken;
    if (refresh == null) {
      throw const AuthFailure('The server issued no refresh token');
    }
    await store.write(refresh);
    _current = tokens;
  }

  @override
  Future<String> accessToken({bool force = false}) async {
    final current = _current;
    if (!force &&
        current != null &&
        current.expiresAt.isAfter(_now().add(const Duration(seconds: 60)))) {
      return current.accessToken;
    }
    return (await (_refreshing ??= _refresh().whenComplete(() => _refreshing = null))).accessToken;
  }

  Future<TokenSet> _refresh() async {
    final stored = await store.read();
    if (stored == null) {
      throw const AuthFailure('Not signed in', reason: AuthFailureReason.signedOut);
    }
    try {
      final tokens = await client.refresh(stored);
      if (tokens.refreshToken != null) await store.write(tokens.refreshToken!);
      return _current = tokens;
    } on AuthFailure catch (e) {
      if (e.reason == AuthFailureReason.invalidGrant) {
        // The grant is gone (revoked elsewhere or expired): forget it.
        _current = null;
        await store.delete();
      }
      rethrow;
    }
  }

  /// Revokes the refresh token when possible and always forgets the tokens.
  Future<void> signOut() async {
    final stored = await store.read();
    _current = null;
    try {
      if (stored != null) await client.revoke(stored);
    } on ApiFailure {
      // Offline or refused: the local sign-out still happens.
    } finally {
      await store.delete();
    }
  }
}
