import 'dart:async';

import 'package:test/test.dart';
import 'package:tinglang_api/tinglang_api.dart';

import 'support.dart';

class _MemoryStore implements TokenStore {
  _MemoryStore([this.value]);
  String? value;
  final writes = <String>[];
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String refreshToken) async {
    writes.add(refreshToken);
    value = refreshToken;
  }

  @override
  Future<void> delete() async => value = null;
}

class _Agent implements AuthorizationAgent {
  _Agent(this.answer);
  final Uri Function(Uri url) answer;
  Uri? opened;
  String? scheme;
  @override
  Future<Uri> authorize(Uri url, {required String callbackScheme}) async {
    opened = url;
    scheme = callbackScheme;
    return answer(url);
  }
}

AuthConfig _auth(String origin, {bool revocation = true}) => AuthConfig(
  issuer: Uri.parse('$origin/auth/v1'),
  authorizationEndpoint: Uri.parse('$origin/auth/v1/oauth/authorize?prompt=consent'),
  tokenEndpoint: Uri.parse('$origin/auth/v1/oauth/token'),
  revocationEndpoint: revocation ? Uri.parse('$origin/v1/auth/revoke') : null,
  clientId: '9a0e6c1e-4c4f-4d43-9a43-3c7f2f1d8b10',
  scopes: const ['openid', 'email'],
  redirectUri: Uri.parse('tinglang://oauth/callback'),
);

void main() {
  test('PKCE matches RFC 7636 appendix B', () {
    final pkce = Pkce('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk');
    expect(pkce.challenge, 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
    final generated = Pkce.generate();
    expect(generated.verifier, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    expect(Pkce.generate().verifier, isNot(generated.verifier));
  });

  test('the authorization request carries PKCE, state and the registered callback', () {
    final url = authorizationUrl(_auth('https://id.example.com'), Pkce('v' * 43), 'st');
    expect(url.path, '/auth/v1/oauth/authorize');
    expect(url.queryParameters, {
      'prompt': 'consent',
      'response_type': 'code',
      'client_id': '9a0e6c1e-4c4f-4d43-9a43-3c7f2f1d8b10',
      'redirect_uri': 'tinglang://oauth/callback',
      'code_challenge': Pkce('v' * 43).challenge,
      'code_challenge_method': 'S256',
      'state': 'st',
      'scope': 'openid email',
    });
  });

  group('the callback', () {
    final auth = _auth('https://id.example.com');
    String code(String callback) => codeFromCallback(Uri.parse(callback), auth: auth, state: 's1');
    Matcher fails(AuthFailureReason reason) =>
        throwsA(isA<AuthFailure>().having((e) => e.reason, 'reason', reason));

    test('yields the code when it belongs to this sign-in', () {
      expect(code('tinglang://oauth/callback?code=abc&state=s1'), 'abc');
    });
    test('is refused when the state or the address differs', () {
      expect(
        () => code('tinglang://oauth/callback?code=abc&state=other'),
        fails(AuthFailureReason.mismatch),
      );
      expect(
        () => code('evil://oauth/callback?code=abc&state=s1'),
        fails(AuthFailureReason.mismatch),
      );
      expect(
        () => code('tinglang://oauth/elsewhere?code=abc&state=s1'),
        fails(AuthFailureReason.mismatch),
      );
      expect(() => code('tinglang://oauth/callback?state=s1'), fails(AuthFailureReason.mismatch));
    });
    test('reports a declined consent as canceled', () {
      expect(
        () => code('tinglang://oauth/callback?error=access_denied&state=s1'),
        fails(AuthFailureReason.canceled),
      );
    });
  });

  group('against a token endpoint', () {
    late LocalServer server;
    final now = DateTime.utc(2026, 10, 23, 8);
    setUp(() async => server = await LocalServer.start());
    tearDown(() => server.close());

    OAuthClient client({bool revocation = true}) =>
        OAuthClient(_auth(server.origin, revocation: revocation), now: () => now);

    Reply tokens(String access, String refresh) => Reply.json({
      'access_token': access,
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': refresh,
    });

    test('sign-in opens the page, checks the callback and exchanges the code', () async {
      server.handler = (_) => tokens('a1', 'r1');
      final agent = _Agent((url) {
        final state = url.queryParameters['state']!;
        return Uri.parse('tinglang://oauth/callback?code=c1&state=$state');
      });
      final result = await signIn(client(), agent);
      expect(agent.scheme, 'tinglang');
      expect(result.accessToken, 'a1');
      expect(result.refreshToken, 'r1');
      expect(result.expiresAt, now.add(const Duration(hours: 1)));
      final form = Uri.splitQueryString(server.requests.single.body);
      final challenge = agent.opened!.queryParameters['code_challenge'];
      expect(form['grant_type'], 'authorization_code');
      expect(form['code'], 'c1');
      expect(form['redirect_uri'], 'tinglang://oauth/callback');
      expect(Pkce(form['code_verifier']!).challenge, challenge);
      expect(
        server.requests.single.header('content-type'),
        startsWith('application/x-www-form-urlencoded'),
      );
    });

    test('a refused grant is reported as such', () async {
      server.handler = (_) => Reply.json({'error': 'invalid_grant'}, status: 400);
      await expectLater(
        client().refresh('r0'),
        throwsA(
          isA<AuthFailure>().having((e) => e.reason, 'reason', AuthFailureReason.invalidGrant),
        ),
      );
    });

    test('the session refreshes once, stores the rotated token and reuses it', () async {
      var issued = 0;
      server.handler = (_) {
        issued++;
        return tokens('a$issued', 'r$issued');
      };
      final store = _MemoryStore('r0');
      final session = AuthSession(client(), store, now: () => now);
      final results = await Future.wait([session.accessToken(), session.accessToken()]);
      expect(results, ['a1', 'a1']);
      expect(issued, 1, reason: 'concurrent callers share one refresh');
      expect(Uri.splitQueryString(server.requests.single.body)['refresh_token'], 'r0');
      expect(store.value, 'r1');
      expect(await session.accessToken(), 'a1');
      expect(await session.accessToken(force: true), 'a2');
      expect(store.writes, ['r1', 'r2']);
    });

    test("Supabase's own refusal of a refresh token is a dead grant too", () async {
      // What the live server answers for a revoked or unknown refresh token.
      server.handler = (_) => Reply.json({
        'code': 400,
        'error_code': 'refresh_token_not_found',
        'msg': 'Invalid Refresh Token: Refresh Token Not Found',
      }, status: 400);
      await expectLater(
        client().refresh('r0'),
        throwsA(
          isA<AuthFailure>()
              .having((e) => e.reason, 'reason', AuthFailureReason.invalidGrant)
              .having((e) => e.message, 'message', contains('refresh_token_not_found')),
        ),
      );
      final store = _MemoryStore('r0');
      await expectLater(AuthSession(client(), store).accessToken(), throwsA(isA<AuthFailure>()));
      expect(store.value, isNull, reason: 'the dead token is forgotten');
    });

    test(
      'a refused code exchange is not mistaken for a dead grant; a server error keeps it',
      () async {
        server.handler = (_) => Reply.json({'error_code': 'bad_code_verifier'}, status: 400);
        await expectLater(
          client().exchangeCode('c1', Pkce('v' * 43)),
          throwsA(isA<AuthFailure>().having((e) => e.reason, 'reason', AuthFailureReason.other)),
        );
        server.handler = (_) => Reply.json({'error_code': 'unexpected_failure'}, status: 500);
        final store = _MemoryStore('r0');
        await expectLater(AuthSession(client(), store).accessToken(), throwsA(isA<AuthFailure>()));
        expect(store.value, 'r0', reason: 'a server failure may pass; keep the token');
      },
    );

    test('a dead grant is forgotten', () async {
      server.handler = (_) => Reply.json({'error': 'invalid_grant'}, status: 400);
      final store = _MemoryStore('r0');
      await expectLater(AuthSession(client(), store).accessToken(), throwsA(isA<AuthFailure>()));
      expect(store.value, isNull);
    });

    test('signing out revokes with the contract form and forgets the token', () async {
      server.handler = (_) => const Reply(200);
      final store = _MemoryStore('v1.refresh-token-example');
      await AuthSession(client(), store).signOut();
      final seen = server.requests.single;
      expect(seen.uri.path, '/v1/auth/revoke');
      expect(Uri.splitQueryString(seen.body), example('revokeToken/request.json'));
      expect(store.value, isNull);
    });

    test('signing out offline still forgets the token', () async {
      final port = await deadPort();
      final offline = AuthConfig(
        issuer: Uri.parse('http://127.0.0.1:$port'),
        authorizationEndpoint: Uri.parse('http://127.0.0.1:$port/authorize'),
        tokenEndpoint: Uri.parse('http://127.0.0.1:$port/token'),
        revocationEndpoint: Uri.parse('http://127.0.0.1:$port/revoke'),
        clientId: 'c',
        redirectUri: Uri.parse('tinglang://oauth/callback'),
      );
      final store = _MemoryStore('r0');
      await AuthSession(OAuthClient(offline), store).signOut();
      expect(store.value, isNull);
    });

    test('without a revocation endpoint sign-out is local only', () async {
      final store = _MemoryStore('r0');
      await AuthSession(client(revocation: false), store).signOut();
      expect(server.requests, isEmpty);
      expect(store.value, isNull);
    });
  });

  test('insecure identity endpoints are refused', () {
    final insecure = AuthConfig(
      issuer: Uri.parse('http://id.example.com'),
      authorizationEndpoint: Uri.parse('http://id.example.com/authorize'),
      tokenEndpoint: Uri.parse('http://id.example.com/token'),
      clientId: 'c',
      redirectUri: Uri.parse('tinglang://oauth/callback'),
    );
    expect(() => OAuthClient(insecure), throwsA(isA<ServerUrlException>()));
  });
}
