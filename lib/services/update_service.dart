import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show AppExitResponse, AppExitType;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show ServicesBinding;
import 'package:path/path.dart' as p;

import 'app_controller.dart';
import 'update_install.dart';

export 'update_install.dart' show UpdateFailure, UpdateProblem;

/// The GitHub repository whose releases are TingLang's.
const updateRepository = 'eeeease/TingLang';

/// A release version `X.Y.Z` (an optional leading `v`), compared number by
/// number: 0.10.0 is newer than 0.9.0.
@immutable
final class ReleaseVersion implements Comparable<ReleaseVersion> {
  const ReleaseVersion(this.major, this.minor, this.patch);

  /// Null for anything but `X.Y.Z` / `vX.Y.Z` (prerelease suffixes too).
  static ReleaseVersion? tryParse(String text) {
    final match = RegExp(r'^v?(\d{1,9})\.(\d{1,9})\.(\d{1,9})$').firstMatch(text.trim());
    if (match == null) return null;
    return ReleaseVersion(int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!));
  }

  final int major, minor, patch;

  @override
  int compareTo(ReleaseVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >(ReleaseVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is ReleaseVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// One file attached to a release.
@immutable
final class UpdateAsset {
  const UpdateAsset({required this.name, required this.url, required this.size});
  final String name;

  /// `browser_download_url`; every redirect hop is checked again.
  final Uri url;

  /// Bytes, as GitHub lists them.
  final int size;

  Map<String, Object?> toJson() => {'name': name, 'url': '$url', 'size': size};
}

/// Which addresses the updater may contact.
@immutable
final class UpdateEndpoints {
  const UpdateEndpoints({required this.latestRelease, this.allowLoopback = false});

  /// The GitHub REST API's latest published release of [updateRepository]
  /// (drafts and prereleases are never "latest").
  static final gitHub = UpdateEndpoints(
    latestRelease: Uri.https('api.github.com', '/repos/$updateRepository/releases/latest'),
  );

  final Uri latestRelease;

  /// Tests only: plain http to 127.0.0.1 is allowed for the API and the
  /// downloads, so a loopback server can stand in for GitHub.
  final bool allowLoopback;

  /// The release API: https on api.github.com only.
  bool allowsApi(Uri uri) =>
      _loopback(uri) || (_https(uri) && uri.host.toLowerCase() == 'api.github.com');

  /// Release files and every redirect on the way to them.
  bool allowsDownload(Uri uri) => _loopback(uri) || isGitHubDownload(uri);

  /// https on github.com or a *.githubusercontent.com host (where GitHub
  /// redirects release files), default port, no user name.
  static bool isGitHubDownload(Uri uri) {
    if (!_https(uri)) return false;
    final host = uri.host.toLowerCase();
    return host == 'github.com' || host.endsWith('.githubusercontent.com');
  }

  static bool _https(Uri uri) =>
      uri.isScheme('https') &&
      uri.userInfo.isEmpty &&
      uri.host.isNotEmpty &&
      (!uri.hasPort || uri.port == 443);

  bool _loopback(Uri uri) =>
      allowLoopback && uri.isScheme('http') && uri.host == '127.0.0.1' && uri.userInfo.isEmpty;
}

/// A published release this app could update to.
@immutable
final class UpdateRelease {
  const UpdateRelease({required this.version, required this.archive, required this.checksum});

  final ReleaseVersion version;

  /// `Tinglang-X.Y.Z-macOS.zip` (made with `ditto -c -k --keepParent`).
  final UpdateAsset archive;

  /// `Tinglang-X.Y.Z-macOS.zip.sha256` (`shasum -a 256` output).
  final UpdateAsset checksum;

  String get tag => 'v$version';

  /// The release on GitHub (notes, the files); built here, not taken from
  /// the API answer.
  Uri get page => releasePage(version);

  static Uri releasePage(ReleaseVersion? version) => Uri.https(
    'github.com',
    version == null
        ? '/$updateRepository/releases/latest'
        : '/$updateRepository/releases/tag/v$version',
  );

  static String archiveName(ReleaseVersion version) => 'Tinglang-$version-macOS.zip';

  /// The largest archive accepted (sanity check on the listed size).
  static const maxArchiveBytes = 2 * 1024 * 1024 * 1024;

  /// Reads a GitHub release object. Null for drafts, prereleases, tags that
  /// are not `vX.Y.Z`, and releases without both files at allowed addresses.
  static UpdateRelease? fromGitHub(Object? json, UpdateEndpoints endpoints) {
    if (json is! Map) return null;
    if (json['draft'] != false || json['prerelease'] != false) return null;
    final tag = json['tag_name'];
    if (tag is! String || !tag.startsWith('v')) return null;
    final version = ReleaseVersion.tryParse(tag);
    final assets = json['assets'];
    if (version == null || assets is! List) return null;
    final name = archiveName(version);
    final archive = _asset(assets, name, endpoints, max: maxArchiveBytes);
    final checksum = _asset(assets, '$name.sha256', endpoints, max: 4096);
    if (archive == null || checksum == null) return null;
    return UpdateRelease(version: version, archive: archive, checksum: checksum);
  }

  static UpdateAsset? _asset(
    List<Object?> assets,
    String name,
    UpdateEndpoints endpoints, {
    required int max,
  }) {
    for (final asset in assets) {
      if (asset is! Map || asset['name'] != name) continue;
      final state = asset['state'];
      if (state != null && state != 'uploaded') return null;
      final size = asset['size'];
      final url = asset['browser_download_url'];
      final uri = url is String ? Uri.tryParse(url) : null;
      if (size is! int || size <= 0 || size > max || uri == null) return null;
      if (!endpoints.allowsDownload(uri)) return null;
      return UpdateAsset(name: name, url: uri, size: size);
    }
    return null;
  }

  /// For the settings cache ([UpdateService.releaseKey]).
  Map<String, Object?> toJson() => {
    'version': '$version',
    'archive': archive.toJson(),
    'checksum': checksum.toJson(),
  };

  /// Reads [toJson] back with the same checks as [fromGitHub].
  static UpdateRelease? fromJson(Object? json, UpdateEndpoints endpoints) {
    if (json is! Map) return null;
    final version = ReleaseVersion.tryParse('${json['version']}');
    if (version == null) return null;
    UpdateAsset? asset(Object? raw, String name, int max) {
      if (raw is! Map || raw['name'] != name) return null;
      return _asset(
        [
          {'name': name, 'size': raw['size'], 'browser_download_url': raw['url']},
        ],
        name,
        endpoints,
        max: max,
      );
    }

    final name = archiveName(version);
    final archive = asset(json['archive'], name, maxArchiveBytes);
    final checksum = asset(json['checksum'], '$name.sha256', 4096);
    if (archive == null || checksum == null) return null;
    return UpdateRelease(version: version, archive: archive, checksum: checksum);
  }
}

/// The SHA-256 in a `shasum -a 256` line (`<hex>  <file>`), lower case;
/// null when the text is not one, or names another file than [fileName].
String? parseChecksumFile(String text, String fileName) {
  final line = text.trim().split('\n').first.trim();
  final parts = line.split(RegExp(r'\s+'));
  final hash = parts.first.toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) return null;
  if (parts.length > 1) {
    // `shasum -b` marks binary mode with a leading `*`.
    final named = parts.sublist(1).join(' ');
    if ((named.startsWith('*') ? named.substring(1) : named) != fileName) return null;
  }
  return hash;
}

/// What the last check in this run found.
enum UpdateCheckResult {
  /// GitHub answered; this is the newest version.
  upToDate,

  /// GitHub answered with a newer version ([UpdateService.available]).
  available,

  /// No answer that could be used (offline, the repository is private, a
  /// rate limit, an odd answer). Treated as "no update", silently.
  unknown,
}

/// Where an update the user asked for stands.
enum UpdateStage { idle, downloading, installing, restarting, failed }

/// Starts [executable] detached from this process (it keeps running after
/// the app quits) and returns a function that stops it again.
typedef DetachedStarter = Future<void Function()> Function(
  String executable,
  List<String> arguments,
);

/// Checks GitHub Releases for a newer TingLang and, when the user agrees,
/// downloads it, verifies it, replaces the installed app and restarts.
///
/// Nothing is sent while the app starts: [start] schedules the first
/// automatic check [startDelay] after launch and then at most once per
/// [checkInterval], only while [autoCheck] is on. [checkNow] always checks.
/// A check that gets no usable answer (offline, a private repository, a rate
/// limit, unexpected JSON) means "no update" and shows nothing.
class UpdateService extends ChangeNotifier {
  UpdateService({
    required this.app,
    required this.appVersion,
    this.busy,
    Future<AppExitResponse> Function()? quit,
    UpdateEndpoints? endpoints,
    HttpClient Function()? httpClient,
    this.executable,
    Future<Directory> Function()? workFolder,
    DetachedStarter? startDetached,
    DateTime Function()? clock,
    Timer Function(Duration delay, void Function() callback)? timer,
    this.startDelay = const Duration(minutes: 1),
    this.checkInterval = const Duration(hours: 24),
    this.connectionTimeout = const Duration(seconds: 20),
    this.idleTimeout = const Duration(seconds: 60),
    this.quitTimeout = const Duration(minutes: 2),
    this.opener = '/usr/bin/open',
    this.logFile,
  }) : endpoints = endpoints ?? UpdateEndpoints.gitHub,
       _quit = quit ?? _exitApplication,
       _httpClient = httpClient ?? HttpClient.new,
       _workFolder = workFolder ?? (() => Directory.systemTemp.createTemp('tinglang-update-')),
       _startDetached = startDetached ?? _startDetachedProcess,
       _clock = clock ?? DateTime.now,
       _timer = timer ?? Timer.new {
    _known = _cachedRelease();
  }

  final AppController app;

  /// This build's version (`appVersion`); sent in the User-Agent.
  final String appVersion;

  /// True while the app may not quit (a recording runs or is not saved);
  /// the same guard as the exit handler (`exitBlockedByRecording`).
  final bool Function()? busy;
  final UpdateEndpoints endpoints;
  final Duration startDelay, checkInterval, connectionTimeout, idleTimeout;

  /// How long the install script waits for the app to quit before it gives
  /// up and changes nothing.
  final Duration quitTimeout;

  /// Opens the new app once it is in place.
  final String opener;

  /// The running app's executable; `Platform.resolvedExecutable` when null.
  final String? executable;

  /// Where the install script writes what it did; a file in the system's
  /// temporary folder when null.
  final String? logFile;

  final Future<AppExitResponse> Function() _quit;
  final HttpClient Function() _httpClient;
  final Future<Directory> Function() _workFolder;
  final DetachedStarter _startDetached;
  final DateTime Function() _clock;
  final Timer Function(Duration, void Function()) _timer;

  /// `app_meta` setting: `false` turns automatic checks off (on by default).
  static const autoCheckKey = 'update_auto_check';

  /// When the last check ran (ISO 8601, UTC), answered or not.
  static const lastCheckKey = 'update_last_check';

  /// The newer release the last answered check found (JSON), so the banner
  /// can show it after a restart without asking again; empty when none.
  static const releaseKey = 'update_release';
  static const _maxRedirects = 5;

  static Future<AppExitResponse> _exitApplication() =>
      ServicesBinding.instance.exitApplication(AppExitType.cancelable);

  static Future<void Function()> _startDetachedProcess(
    String executable,
    List<String> arguments,
  ) async {
    final process = await Process.start(executable, arguments, mode: ProcessStartMode.detached);
    return () => Process.killPid(process.pid);
  }

  ReleaseVersion? get currentVersion => ReleaseVersion.tryParse(appVersion);

  bool get autoCheck => app.setting(autoCheckKey, 'true') != 'false';

  Future<void> setAutoCheck(bool value) async {
    await app.setSetting(autoCheckKey, '$value');
    _onSettings();
  }

  DateTime? get lastCheck => DateTime.tryParse(app.setting(lastCheckKey, ''));

  /// A release newer than this build, if a check (now or earlier) found one.
  UpdateRelease? get available {
    final known = _known, current = currentVersion;
    return known != null && current != null && known.version > current ? known : null;
  }

  UpdateRelease? _known;

  /// What the last check in this run found; null before the first one.
  UpdateCheckResult? get lastResult => _result;
  UpdateCheckResult? _result;

  bool get checking => _checking != null;
  Future<void>? _checking;

  UpdateStage get stage => _stage;
  UpdateStage _stage = UpdateStage.idle;

  /// Why the last update attempt failed ([UpdateStage.failed]).
  UpdateFailure? get failure => _failure;
  UpdateFailure? _failure;

  /// Download progress, 0–1.
  double get progress => _progress;
  double _progress = 0;

  /// Whether the main window shows the banner: an update is there and the
  /// user has not put it off in this run, or an update is under way.
  bool get showBanner =>
      stage != UpdateStage.idle || (available != null && available!.version != _dismissed);
  ReleaseVersion? _dismissed;

  bool _started = false, _disposed = false, _cancelled = false, _lastAuto = true;
  DateTime? _startedAt;

  /// When a check last started in this run, in case saving [lastCheckKey]
  /// failed: the schedule never asks again sooner than [checkInterval].
  DateTime? _lastAttempt;
  Timer? _scheduled;
  HttpClient? _client;
  Process? _process;

  String get userAgent => 'Tinglang/$appVersion (macos)';

  UpdateRelease? _cachedRelease() {
    final raw = app.setting(releaseKey, '');
    if (raw.isEmpty) return null;
    try {
      return UpdateRelease.fromJson(jsonDecode(raw), endpoints);
    } on FormatException {
      return null;
    }
  }

  /// Schedules the automatic checks: never sooner than [startDelay] after
  /// this call, then once per [checkInterval]. Sends nothing by itself.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _startedAt = _clock();
    _lastAuto = autoCheck;
    app.addListener(_onSettings);
    _schedule();
  }

  void _onSettings() {
    final on = autoCheck;
    if (on == _lastAuto) return;
    _lastAuto = on;
    _schedule();
  }

  /// Sets the timer for the next automatic check, at least [minimum] away.
  void _schedule({Duration minimum = Duration.zero}) {
    _scheduled?.cancel();
    _scheduled = null;
    final startedAt = _startedAt;
    if (!_started || _disposed || startedAt == null || !autoCheck) return;
    final now = _clock();
    final earliest = startedAt.add(startDelay);
    final saved = lastCheck, attempted = _lastAttempt;
    final last = saved == null || (attempted != null && attempted.isAfter(saved))
        ? attempted
        : saved;
    var due = last == null || last.isAfter(now) ? earliest : last.add(checkInterval);
    if (due.isBefore(earliest)) due = earliest;
    final wait = due.difference(now);
    _scheduled = _timer(wait < minimum ? minimum : wait, () {
      _scheduled = null;
      if (_disposed || !autoCheck) return;
      if (stage == UpdateStage.idle || stage == UpdateStage.failed) {
        unawaited(checkNow());
      } else {
        // An update is under way; ask again a while later.
        _schedule(minimum: startDelay);
      }
    });
  }

  /// Asks GitHub for the latest release now (also with automatic checks
  /// off). Never throws; no answer means no update.
  Future<void> checkNow() {
    final running = _checking;
    if (running != null) return running;
    if (_disposed || stage == UpdateStage.downloading || stage == UpdateStage.installing) {
      return Future.value();
    }
    final run = _checking = _check();
    _notify();
    return run;
  }

  Future<void> _check() async {
    _lastAttempt = _clock();
    try {
      final release = await fetchLatest();
      if (_disposed) return;
      final current = currentVersion;
      final newer = release != null && current != null && release.version > current;
      _result = release == null
          ? UpdateCheckResult.unknown
          : newer
          ? UpdateCheckResult.available
          : UpdateCheckResult.upToDate;
      // An unanswered check keeps what an earlier one found.
      if (release != null) _known = newer ? release : null;
      await app.setSettings({
        lastCheckKey: _clock().toUtc().toIso8601String(),
        if (release != null) releaseKey: newer ? jsonEncode(release.toJson()) : '',
      });
    } on Object {
      // The setting could not be saved; AppController reports that itself.
    } finally {
      _checking = null;
      _notify();
      _schedule();
    }
  }

  /// One request for the latest release; null for every kind of failure.
  @visibleForTesting
  Future<UpdateRelease?> fetchLatest() async {
    if (!endpoints.allowsApi(endpoints.latestRelease)) return null;
    HttpClient? client;
    try {
      client = _httpClient()
        ..connectionTimeout = connectionTimeout
        ..userAgent = userAgent;
      var uri = endpoints.latestRelease;
      for (var hop = 0; hop <= _maxRedirects; hop++) {
        if (!endpoints.allowsApi(uri)) return null;
        final request = await client.getUrl(uri).timeout(connectionTimeout);
        request
          ..followRedirects = false
          ..headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
          ..headers.set('X-GitHub-Api-Version', '2022-11-28');
        final response = await request.close().timeout(idleTimeout);
        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>();
          if (location == null) return null;
          uri = uri.resolve(location);
          continue;
        }
        if (response.statusCode != HttpStatus.ok) {
          await response.drain<void>();
          return null;
        }
        final body = await _readAll(response, 2 * 1024 * 1024);
        if (body == null) return null;
        return UpdateRelease.fromGitHub(jsonDecode(utf8.decode(body)), endpoints);
      }
      return null;
    } on Object {
      // Offline, private repository (404), rate limit (403/429), bad JSON.
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  /// The body, or null when it is longer than [max] bytes.
  Future<List<int>?> _readAll(HttpClientResponse response, int max) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(idleTimeout)) {
      if (bytes.length + chunk.length > max) return null;
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  /// Hides the banner for [available] until the next start (or a newer
  /// version).
  void dismiss() {
    if (_stage == UpdateStage.failed) {
      _stage = UpdateStage.idle;
      _failure = null;
    }
    _dismissed = available?.version;
    _notify();
  }

  /// Stops a download; nothing is kept.
  void cancel() {
    if (_stage != UpdateStage.downloading && _stage != UpdateStage.installing) return;
    _cancelled = true;
    _client?.close(force: true);
    _process?.kill();
  }

  /// Downloads [available], verifies it, puts it next to the installed app,
  /// starts the script that swaps them and asks the app to quit (through the
  /// usual exit handler, which refuses while a recording runs).
  Future<void> install() async {
    final release = available;
    if (release == null || _disposed) return;
    if (_stage == UpdateStage.downloading ||
        _stage == UpdateStage.installing ||
        _stage == UpdateStage.restarting) {
      return;
    }
    await _checking;
    _cancelled = false;
    _failure = null;
    _dismissed = null;
    _progress = 0;
    _setStage(UpdateStage.downloading);
    Directory? work;
    String? staged;
    void Function()? stopScript;
    try {
      if (busy?.call() ?? false) throw const UpdateFailure(UpdateProblem.busy);
      final location = await locateInstall(executable ?? Platform.resolvedExecutable);
      work = await _workFolder();
      final client = _client = _httpClient()
        ..connectionTimeout = connectionTimeout
        ..userAgent = userAgent
        ..autoUncompress = false;
      final expected = await _fetchChecksum(client, release);
      final archive = await _fetchArchive(client, release, work, expected);
      client.close(force: true);
      _client = null;
      _checkCancelled();
      _setStage(UpdateStage.installing);
      final bundle = await _unpack(archive, work, release.version);
      _checkCancelled();
      if (busy?.call() ?? false) throw const UpdateFailure(UpdateProblem.busy);
      final stamp = '$pid-${_clock().millisecondsSinceEpoch}';
      staged = p.join(location.folder, '.tinglang-update-$stamp');
      final moved = await Process.run('/bin/mv', [bundle, staged]);
      if (moved.exitCode != 0) {
        staged = null;
        throw UpdateFailure(UpdateProblem.install, location.folder);
      }
      _checkCancelled();
      stopScript = await _startDetached('/bin/sh', [
        '-c',
        updateInstallScript(),
        'tinglang-update',
        ...updateScriptArguments(
          appPid: pid,
          target: location.bundle,
          staged: staged,
          backup: p.join(location.folder, '.tinglang-old-$stamp'),
          work: work.path,
          quitTimeout: quitTimeout,
          opener: opener,
          log: logFile ?? p.join(Directory.systemTemp.path, 'tinglang-update.log'),
        ),
      ]);
      _checkCancelled();
      _setStage(UpdateStage.restarting);
      final response = await _quit();
      // Still running: the exit handler said no (and told the user why).
      if (response == AppExitResponse.cancel) {
        throw const UpdateFailure(UpdateProblem.quitRefused);
      }
    } on Object catch (error) {
      // The script must not swap the app later, when the user quits.
      stopScript?.call();
      if (staged != null) await _delete(Directory(staged));
      if (work != null) await _delete(work);
      if (_disposed) return;
      if (_cancelled) {
        _cancelled = false;
        _setStage(UpdateStage.idle);
      } else {
        _failure = switch (error) {
          UpdateFailure() => error,
          FileSystemException() => const UpdateFailure(UpdateProblem.disk),
          ProcessException() => const UpdateFailure(UpdateProblem.install),
          _ => const UpdateFailure(UpdateProblem.network),
        };
        _setStage(UpdateStage.failed);
      }
    } finally {
      _client?.close(force: true);
      _client = null;
      _process = null;
    }
  }

  void _checkCancelled() {
    if (_cancelled) throw const UpdateFailure(UpdateProblem.network);
  }

  static Future<void> _delete(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException {
      // Left for the system's temporary-file cleanup.
    }
  }

  /// GET with redirects followed by hand, each hop checked.
  Future<HttpClientResponse> _open(HttpClient client, Uri uri) async {
    for (var hop = 0; hop <= _maxRedirects; hop++) {
      if (!endpoints.allowsDownload(uri)) throw const UpdateFailure(UpdateProblem.network);
      _checkCancelled();
      final request = await client.getUrl(uri).timeout(connectionTimeout);
      request
        ..followRedirects = false
        ..headers.set(HttpHeaders.acceptHeader, 'application/octet-stream')
        ..headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      final response = await request.close().timeout(idleTimeout);
      if (!response.isRedirect) {
        if (response.statusCode == HttpStatus.ok) return response;
        await response.drain<void>().catchError((Object _) {});
        throw const UpdateFailure(UpdateProblem.network);
      }
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>().catchError((Object _) {});
      if (location == null) break;
      uri = uri.resolve(location);
    }
    throw const UpdateFailure(UpdateProblem.network);
  }

  Future<String> _fetchChecksum(HttpClient client, UpdateRelease release) async {
    final response = await _open(client, release.checksum.url);
    final body = await _readAll(response, 4096);
    final hash = body == null
        ? null
        : parseChecksumFile(utf8.decode(body, allowMalformed: true), release.archive.name);
    if (hash == null) throw const UpdateFailure(UpdateProblem.checksum);
    return hash;
  }

  /// Streams the archive to [work], hashing it on the way; a wrong size or
  /// hash deletes the file.
  Future<File> _fetchArchive(
    HttpClient client,
    UpdateRelease release,
    Directory work,
    String expected,
  ) async {
    final total = release.archive.size;
    final file = File(p.join(work.path, release.archive.name));
    final response = await _open(client, release.archive.url);
    if (response.contentLength >= 0 && response.contentLength != total) {
      await response.drain<void>().catchError((Object _) {});
      throw const UpdateFailure(UpdateProblem.checksum);
    }
    final digest = _DigestSink();
    final hash = sha256.startChunkedConversion(digest);
    var received = 0;
    var oversize = false;
    final sink = await file.open(mode: FileMode.write);
    try {
      await for (final chunk in response.timeout(idleTimeout)) {
        _checkCancelled();
        if (received + chunk.length > total) {
          oversize = true;
          break;
        }
        hash.add(chunk);
        await sink.writeFrom(chunk);
        received += chunk.length;
        _setProgress(received / total);
      }
    } finally {
      await sink.close();
    }
    _checkCancelled();
    if (!oversize && received < total) {
      await _deleteFile(file);
      throw const UpdateFailure(UpdateProblem.network);
    }
    hash.close();
    if (oversize || digest.value.toString() != expected) {
      await _deleteFile(file);
      throw const UpdateFailure(UpdateProblem.checksum);
    }
    return file;
  }

  static Future<void> _deleteFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // The whole folder goes next.
    }
  }

  /// `ditto -x -k` into a new folder; the one app inside must be TingLang
  /// [version].
  Future<String> _unpack(File archive, Directory work, ReleaseVersion version) async {
    final out = Directory(p.join(work.path, 'unpacked'));
    await out.create();
    final process = _process = await Process.start('/usr/bin/ditto', [
      '-x',
      '-k',
      archive.path,
      out.path,
    ]);
    final errors = process.stderr.transform(const Utf8Decoder(allowMalformed: true)).join();
    await process.stdout.drain<void>();
    final code = await process.exitCode;
    final message = await errors;
    _process = null;
    _checkCancelled();
    if (code != 0) {
      throw UpdateFailure(
        message.contains('No space left') ? UpdateProblem.disk : UpdateProblem.badPackage,
      );
    }
    await _deleteFile(archive);
    final apps = [
      await for (final entry in out.list(followLinks: false))
        if (entry is Directory && p.extension(entry.path) == '.app') entry.path,
    ];
    if (apps.length != 1) throw const UpdateFailure(UpdateProblem.badPackage);
    await checkUpdateBundle(apps.single, version: '$version');
    return apps.single;
  }

  void _setProgress(double value) {
    // At most one notification per percent.
    if ((value * 100).floor() == (_progress * 100).floor() && value < 1) {
      _progress = value;
      return;
    }
    _progress = value;
    _notify();
  }

  void _setStage(UpdateStage stage) {
    _stage = stage;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _scheduled?.cancel();
    _scheduled = null;
    app.removeListener(_onSettings);
    _cancelled = true;
    _client?.close(force: true);
    _process?.kill();
    super.dispose();
  }
}

final class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
