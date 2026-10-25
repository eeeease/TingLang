import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tinglang_api/tinglang_api.dart';

import '../app_controller.dart';
import 'cloud_services.dart';

/// The optional TingLang account (sidebar → Account, docs/CLOUD.md).
///
/// It only reads what earlier sessions cached in settings; it talks to the
/// server when the user signs in, refreshes or signs out, and never at
/// startup. Tokens live in the secret store, never in settings.
class CloudController extends ChangeNotifier {
  CloudController({
    required this.app,
    required this.connect,
    required this.clientVersion,
    this.officialServer,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// The official API. A build can point elsewhere for development with
  /// `--dart-define=TINGLANG_SERVER=https://…` (http only on this Mac).
  static const official = String.fromEnvironment(
    'TINGLANG_SERVER',
    defaultValue: 'https://api.tinglang.app',
  );

  /// The official website (pricing before signing in; the server's
  /// `/v1/meta` gives the exact pages once signed in).
  static final website = Uri.parse('https://tinglang.app');

  /// Where builds up to 0.5 kept a server address typed in Settings.
  static const legacyServerKey = 'cloud_server_url';
  static const signedInKey = 'cloud_signed_in';
  static const metaKey = 'cloud_meta';
  static const accountKey = 'cloud_account';
  static const entitlementsKey = 'cloud_entitlements';

  /// Services shown on the Account page when the server offers them.
  static const services = ['jobs.transcribe', 'jobs.translate', 'llm_gateway'];

  final AppController app;

  /// Builds the services for a server; creating them sends nothing.
  final AccountService Function(ServerUrl server) connect;
  final String clientVersion;

  /// The server to use, normally [official]; tests pass their own.
  final String? officialServer;
  final DateTime Function() _now;

  AccountService? _service;
  bool _busy = false;
  Object? _error;
  bool _offline = false;

  bool get busy => _busy;

  /// The last action's failure, for the page to describe.
  Object? get error => _error;

  /// The last refresh could not reach the server; cached values are shown.
  bool get offline => _offline;

  /// The server in use.
  ServerUrl? get server {
    final text = officialServer;
    if (text == null || text.isEmpty) return null;
    try {
      return ServerUrl.parse(text);
    } on ServerUrlException {
      return null;
    }
  }

  bool get signedIn => app.setting(signedInKey, 'false') == 'true';
  ApiMeta? get meta => _cached(metaKey, ApiMeta.fromJson);
  Account? get account => signedIn ? _cached(accountKey, Account.fromJson) : null;
  Entitlements? get entitlements =>
      signedIn ? _cached(entitlementsKey, Entitlements.fromJson) : null;

  /// What the server offers, as last seen. Off while signed out.
  CloudFeatures get features =>
      signedIn ? (meta?.features ?? CloudFeatures.none) : CloudFeatures.none;
  bool offers(String feature) => features.isOn(feature);

  /// While offline, the cached plan is shown as is until its grace period
  /// ends (docs/CLOUD.md §6).
  bool get planConfirmed {
    final e = entitlements;
    return e != null && (!_offline || e.usableOffline(_now()));
  }

  T? _cached<T>(String key, T Function(Object? json) read) {
    final text = app.setting(key, '');
    if (text.isEmpty) return null;
    try {
      return read(jsonDecode(text));
    } on Object {
      return null;
    }
  }

  AccountService _connectTo(ServerUrl server) {
    final current = _service;
    if (current != null && current.server == server) return current;
    return _service = connect(server);
  }

  Future<void> _run(Future<void> Function(ServerUrl server) action) async {
    final target = server;
    if (target == null || _busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action(target);
    } on Object catch (e) {
      _error = e;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Opens the server's sign-in page in the browser, then loads the account.
  Future<void> signIn() => _run((target) async {
    final service = _connectTo(target);
    final meta = await service.fetchMeta();
    if (meta.requiresNewerClient('macos', clientVersion)) {
      throw ApiProblemException(const ApiProblem(status: 426, code: 'client_too_old'));
    }
    if (!meta.features.accounts || meta.auth == null) {
      throw const CloudUnsupported(CloudUnsupportedReason.noAccounts);
    }
    await service.signIn(meta);
    final account = await service.fetchAccount(meta);
    final entitlements = meta.features.entitlements ? await service.fetchEntitlements(meta) : null;
    _offline = false;
    await app.setSettings({
      signedInKey: 'true',
      metaKey: jsonEncode(meta.toJson()),
      accountKey: jsonEncode(account.toJson()),
      entitlementsKey: entitlements == null ? '' : jsonEncode(entitlements.toJson()),
    });
  });

  /// Reloads the server's offer, the account and the plan.
  Future<void> refresh() => _run((target) async {
    if (!signedIn) return;
    final service = _connectTo(target);
    try {
      final meta = await service.fetchMeta();
      final account = await service.fetchAccount(meta);
      final entitlements = meta.features.entitlements
          ? await service.fetchEntitlements(meta)
          : null;
      _offline = false;
      await app.setSettings({
        metaKey: jsonEncode(meta.toJson()),
        accountKey: jsonEncode(account.toJson()),
        entitlementsKey: entitlements == null ? '' : jsonEncode(entitlements.toJson()),
      });
    } on ApiUnreachable {
      _offline = true;
      rethrow;
    } on AuthFailure catch (e) {
      // The session is gone (revoked elsewhere, expired): sign out here too.
      if (e.reason == AuthFailureReason.invalidGrant || e.reason == AuthFailureReason.signedOut) {
        await _forget();
      }
      rethrow;
    } on ApiProblemException catch (e) {
      if (e.code == ProblemCode.unauthorized) await _forget();
      rethrow;
    }
  });

  /// Revokes the session when the server answers; always signs out here.
  Future<void> signOut() => _run((target) async {
    try {
      await _connectTo(target).signOut(meta);
    } finally {
      await _forget();
    }
  });

  Future<void> _forget() async {
    _offline = false;
    await app.setSettings({signedInKey: 'false', accountKey: '', entitlementsKey: ''});
  }

  /// Builds up to 0.5 could sign in to a server typed in Settings; that
  /// session belongs to another server, so it is forgotten (locally only;
  /// nothing is sent).
  Future<void> forgetLegacyServer() async {
    if (app.setting(legacyServerKey, '').isEmpty) return;
    await app.setSettings({
      legacyServerKey: '',
      signedInKey: 'false',
      metaKey: '',
      accountKey: '',
      entitlementsKey: '',
    });
  }

  /// Plan ids the app names; anything else is shown as sent.
  static bool isFree(Entitlements? plan) =>
      plan == null || plan.plan == 'free' || plan.knownStatus == EntitlementStatus.none;
}
