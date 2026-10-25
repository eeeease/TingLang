import 'dart:io';

import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';
import 'package:tinglang_api/tinglang_api.dart';
import 'package:tinglang_api/tinglang_api.dart' as api show signIn;

/// Accounts on a Tinglang server (docs/CLOUD.md §5–6). Every call is a
/// network call the user asked for; nothing here runs on its own.
abstract interface class AccountService {
  ServerUrl get server;

  /// `GET /v1/meta`; needs no sign-in.
  Future<ApiMeta> fetchMeta();

  /// Opens the server's sign-in page in the system browser session and
  /// stores the refresh token. [meta] must offer accounts.
  Future<void> signIn(ApiMeta meta);

  /// Whether a refresh token is stored for this server (no network).
  Future<bool> hasSession();
  Future<Account> fetchAccount(ApiMeta meta);
  Future<Entitlements> fetchEntitlements(ApiMeta meta);

  /// Revokes the session when the server can be reached and always forgets
  /// it locally.
  Future<void> signOut(ApiMeta? meta);
}

/// Cloud jobs (docs/CLOUD.md §7). Results keep the app's own formats.
abstract interface class CloudJobService {
  Future<JobEstimate> estimate(ApiMeta meta, JobEstimateRequest request);
  Future<Job> create(ApiMeta meta, JobCreateRequest request, {required String idempotencyKey});
  Future<void> upload(ApiMeta meta, UploadTarget target, File file);
  Future<Job> start(ApiMeta meta, String id);
  Future<(Job, Duration?)> poll(ApiMeta meta, String id);
  Future<JobResult> result(ApiMeta meta, String id);
  Future<Job> cancel(ApiMeta meta, String id);
}

/// Thrown when this system cannot do something cloud sign-in needs.
final class CloudUnsupported implements Exception {
  const CloudUnsupported(this.reason);
  final CloudUnsupportedReason reason;
  @override
  String toString() => 'Cloud sign-in unavailable: ${reason.name}';
}

enum CloudUnsupportedReason { noBrowserSession, noSecureStorage, noAccounts }

/// The refresh token lives in the platform's secret store (Keychain), one
/// entry per server.
final class SecretTokenStore implements TokenStore {
  SecretTokenStore(this.secrets, ServerUrl server) : key = 'account:${server.origin}';
  final SecretStore secrets;
  final String key;
  @override
  Future<String?> read() => secrets.read(key);
  @override
  Future<void> write(String refreshToken) => secrets.write(key, refreshToken);
  @override
  Future<void> delete() => secrets.delete(key);
}

/// The system browser session as the sign-in agent.
final class BrowserAgent implements AuthorizationAgent {
  BrowserAgent(this.browser);
  final WebAuthenticator browser;
  @override
  Future<Uri> authorize(Uri url, {required String callbackScheme}) async {
    try {
      return await browser.authenticate(url, callbackScheme: callbackScheme);
    } on WebAuthCanceled {
      throw const AuthFailure('Sign-in canceled', reason: AuthFailureReason.canceled);
    }
  }
}

/// [AccountService] and [CloudJobService] for one server, over
/// `package:tinglang_api`. Constructing it sends nothing.
final class CloudClient implements AccountService, CloudJobService {
  CloudClient(
    this.server, {
    required this.secrets,
    required this.browser,
    this.http,
    this.userAgent,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  @override
  final ServerUrl server;
  final SecretStore? secrets;
  final WebAuthenticator? browser;

  /// Injected in tests; otherwise each client makes its own.
  final HttpClient? http;
  final String? userAgent;
  final DateTime Function() _now;
  AuthSession? _session;
  TinglangApi? _api;

  TokenStore get _store {
    final store = secrets;
    if (store == null) throw const CloudUnsupported(CloudUnsupportedReason.noSecureStorage);
    return SecretTokenStore(store, server);
  }

  AuthSession _sessionFor(ApiMeta meta) {
    final auth = meta.auth;
    if (auth == null) throw const CloudUnsupported(CloudUnsupportedReason.noAccounts);
    final existing = _session;
    if (existing != null && existing.client.auth.tokenEndpoint == auth.tokenEndpoint) {
      return existing;
    }
    return _session = AuthSession(
      OAuthClient(auth, http: http, userAgent: userAgent, now: _now),
      _store,
      now: _now,
    );
  }

  TinglangApi _client(ApiMeta? meta) => _api ??= TinglangApi(
    server,
    tokens: meta == null ? null : _sessionFor(meta),
    http: http,
    userAgent: userAgent,
  );

  @override
  Future<ApiMeta> fetchMeta() => TinglangApi(server, http: http, userAgent: userAgent).getMeta();

  @override
  Future<void> signIn(ApiMeta meta) async {
    final agent = browser;
    if (agent == null) throw const CloudUnsupported(CloudUnsupportedReason.noBrowserSession);
    final session = _sessionFor(meta);
    await session.adopt(await api.signIn(session.client, BrowserAgent(agent)));
    _api = null;
  }

  @override
  Future<bool> hasSession() async {
    final store = secrets;
    return store != null && await SecretTokenStore(store, server).read() != null;
  }

  @override
  Future<Account> fetchAccount(ApiMeta meta) => _client(meta).getAccount();
  @override
  Future<Entitlements> fetchEntitlements(ApiMeta meta) => _client(meta).getEntitlements();

  @override
  Future<void> signOut(ApiMeta? meta) async {
    _api = null;
    if (meta?.auth != null && secrets != null) {
      await _sessionFor(meta!).signOut();
    } else if (secrets != null) {
      await _store.delete();
    }
    _session = null;
  }

  @override
  Future<JobEstimate> estimate(ApiMeta meta, JobEstimateRequest request) =>
      _client(meta).estimateJob(request);
  @override
  Future<Job> create(ApiMeta meta, JobCreateRequest request, {required String idempotencyKey}) =>
      _client(meta).createJob(request, idempotencyKey: idempotencyKey);
  @override
  Future<void> upload(ApiMeta meta, UploadTarget target, File file) async =>
      _client(meta).upload(target, file.openRead(), await file.length());
  @override
  Future<Job> start(ApiMeta meta, String id) => _client(meta).startJob(id);
  @override
  Future<(Job, Duration?)> poll(ApiMeta meta, String id) => _client(meta).getJob(id);
  @override
  Future<JobResult> result(ApiMeta meta, String id) => _client(meta).getJobResult(id);
  @override
  Future<Job> cancel(ApiMeta meta, String id) => _client(meta).cancelJob(id);
}
