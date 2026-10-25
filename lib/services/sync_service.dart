import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

import '../core/library_store.dart';
import '../core/live_repository.dart';
import 'app_controller.dart';
import 'sync_engine.dart';

export 'sync_engine.dart' show SyncProblem, SyncProblemKind, SyncReport;

/// Where sync stands, for Settings.
enum SyncStatus {
  /// Turned off (the default). Nothing is read from or written to iCloud.
  off,

  /// Turned on, but iCloud Drive is off or not set up on this Mac. Nothing
  /// is written until it is back.
  unavailable,

  /// Waiting for the next change.
  idle,

  /// A pass is running.
  syncing,

  /// The last pass could not work with the folder at all (see [error]).
  failed,
}

/// Opt-in sync of the library and learning progress between Macs through
/// the user's iCloud Drive folder (`~/Library/Mobile Documents/
/// com~apple~CloudDocs/Tinglang`). macOS uploads and downloads the folder;
/// Tinglang only reads and writes files there and makes no network request.
///
/// A pass ([SyncEngine.run]) runs when sync is turned on, at launch, a few
/// seconds after a change in the library, when files in the folder change,
/// and every few minutes while the app is in front.
class SyncService extends ChangeNotifier {
  SyncService({
    required this.app,
    required this.repository,
    this.drive,
    Directory? iCloudDrive,
    this.appVersion = '',
    String? deviceName,
    this.debounce = const Duration(seconds: 3),
    this.interval = const Duration(minutes: 2),
    this.watchFolder = true,
    this.followLifecycle = true,
    DateTime Function()? clock,
  }) : iCloudDrive = iCloudDrive ?? defaultICloudDrive(),
       deviceName = deviceName ?? _hostName(),
       clock = clock ?? DateTime.now;

  final AppController app;
  final LiveRepository repository;
  final CloudDriveSupport? drive;

  /// The iCloud Drive folder macOS syncs. Sync never creates it.
  final Directory iCloudDrive;
  final String appVersion;
  final String deviceName;
  final Duration debounce, interval;
  final bool watchFolder, followLifecycle;
  final DateTime Function() clock;

  /// `app_meta` setting: `true` once the user turns sync on.
  static const enabledKey = 'sync_icloud';
  static const folderName = 'Tinglang';
  static const _deviceKey = 'sync.device';
  static const _machineKey = 'sync.machine';
  static const _lastKey = 'sync.last';

  static Directory defaultICloudDrive() => Directory(
    p.join(
      Platform.environment['HOME'] ?? '',
      'Library',
      'Mobile Documents',
      'com~apple~CloudDocs',
    ),
  );

  static String _hostName() {
    final host = Platform.localHostname;
    return host.endsWith('.local') ? host.substring(0, host.length - 6) : host;
  }

  /// The folder sync writes, inside iCloud Drive.
  Directory get folder => Directory(p.join(iCloudDrive.path, folderName));

  bool get enabled => app.setting(enabledKey, 'false') == 'true';

  /// Whether iCloud Drive is there; null until checked.
  bool? get iCloudDriveAvailable => _available;
  bool? _available;

  SyncStatus get status {
    if (!enabled) return SyncStatus.off;
    if (_available == false) return SyncStatus.unavailable;
    if (_running != null) return SyncStatus.syncing;
    if (error != null) return SyncStatus.failed;
    return SyncStatus.idle;
  }

  /// The last pass's outcome (counts, waiting, problems) in this run.
  SyncReport? get report => _report;
  SyncReport? _report;

  /// When a pass last finished, also from earlier runs.
  DateTime? get lastSync => _lastSync;
  DateTime? _lastSync;

  /// Why the last pass could not run at all.
  Object? error;

  SyncEngine? _engine;
  Future<void>? _running;
  bool _again = false;
  bool _started = false;
  bool _active = true;
  Timer? _soon, _periodic;
  StreamSubscription<Object?>? _tables, _watch;
  AppLifecycleListener? _lifecycle;
  int? _seen;

  /// Starts the triggers and, when sync is on, a first pass. Reads nothing
  /// from iCloud Drive while sync is off.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final last = await repository.db.meta(_lastKey);
    _lastSync = last == null ? null : DateTime.tryParse(last);
    _seen = _fingerprint(app.state);
    app.addListener(_onLibrary);
    _tables = repository.db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            repository.db.sessions,
            repository.db.segments,
            repository.db.translations,
            repository.db.dictationAttempts,
          ]),
        )
        .listen((_) => _changed());
    if (followLifecycle) {
      _lifecycle = AppLifecycleListener(
        onResume: () => setActive(true),
        onHide: () => setActive(false),
      );
    }
    await _follow();
  }

  /// Turns sync on or off (saved in the library's settings). Turning it off
  /// stops writing; what is already in iCloud Drive stays there.
  Future<void> setEnabled(bool on) async {
    if (on == enabled) return;
    await app.setSetting(enabledKey, '$on');
    if (!on) error = null;
    await _follow();
  }

  /// Checks whether iCloud Drive is there (for Settings while sync is off).
  Future<bool> refreshAvailability() async {
    final available = await iCloudDrive.exists();
    if (available != _available) {
      _available = available;
      notifyListeners();
    }
    return available;
  }

  /// Runs a pass now (or right after the one that is running).
  Future<void> syncNow() async {
    _soon?.cancel();
    if (!enabled) return;
    if (_running != null) {
      _again = true;
      return _running;
    }
    final run = _pass();
    _running = run;
    notifyListeners();
    try {
      await run;
    } finally {
      _running = null;
      notifyListeners();
    }
    if (_again && enabled) {
      _again = false;
      _schedule(debounce);
    }
  }

  /// While the app is in front a pass also runs every [interval].
  void setActive(bool active) {
    if (active == _active) return;
    _active = active;
    _periodic?.cancel();
    _periodic = null;
    if (active && enabled) {
      _schedule(Duration.zero);
      _startTimer();
    }
  }

  Future<void> _follow() async {
    _soon?.cancel();
    _periodic?.cancel();
    _periodic = null;
    await _watch?.cancel();
    _watch = null;
    if (!enabled) {
      notifyListeners();
      return;
    }
    await refreshAvailability();
    _startTimer();
    await syncNow();
  }

  void _startTimer() {
    if (_active && interval > Duration.zero) {
      _periodic ??= Timer.periodic(interval, (_) => _schedule(Duration.zero));
    }
  }

  void _onLibrary() {
    // Every change notifies, settings too (the panel saves its place on
    // every move); only synced content starts a pass.
    final seen = _fingerprint(app.state);
    if (seen == _seen) return;
    _seen = seen;
    _changed();
  }

  /// Cheap: courses, attempts and cards are immutable objects that keep
  /// their identity until they change.
  static int _fingerprint(LibraryState state) => Object.hash(
    Object.hashAll(state.courses),
    Object.hashAll(state.attempts),
    Object.hashAll(state.reviews),
    Object.hashAllUnordered([for (final e in state.drafts.entries) Object.hash(e.key, e.value)]),
    Object.hashAllUnordered([
      for (final e in state.completed.entries) Object.hash(e.key, Object.hashAllUnordered(e.value)),
    ]),
  );

  void _changed() {
    if (enabled) _schedule(debounce);
  }

  void _schedule(Duration delay) {
    if (!enabled) return;
    _soon?.cancel();
    _soon = Timer(delay, () => unawaited(syncNow()));
  }

  Future<void> _pass() async {
    try {
      if (!await refreshAvailability()) return;
      final engine = _engine ??= SyncEngine(
        folder: folder,
        app: app,
        repository: repository,
        deviceId: await _deviceId(),
        deviceName: deviceName,
        drive: drive,
        appVersion: appVersion,
        clock: clock,
      );
      _report = await engine.run();
      error = null;
      _lastSync = clock().toUtc();
      await repository.db.setMeta(_lastKey, _lastSync!.toIso8601String());
      _seen = _fingerprint(app.state);
      if (watchFolder) await _watchFolder();
    } on Object catch (e) {
      error = e;
    }
  }

  /// FSEvents on the folder: files macOS downloaded or another Mac changed.
  Future<void> _watchFolder() async {
    if (_watch != null || !await folder.exists()) return;
    try {
      _watch = folder
          .watch(recursive: true)
          .listen(
            (_) => _schedule(debounce),
            onError: (Object _) {
              unawaited(_watch?.cancel());
              _watch = null;
            },
          );
    } on FileSystemException {
      // The periodic check still runs.
    }
  }

  /// A random id for this Mac's folder, kept in the library. A library
  /// copied to another Mac (seen by a different machine id) gets a new one,
  /// so two Macs never write the same folder.
  Future<String> _deviceId() async {
    final db = repository.db;
    String? machine;
    try {
      final id = await drive?.machineId();
      machine = id == null ? null : sha256.convert(id.codeUnits).toString();
    } on Object {
      machine = null;
    }
    final stored = await db.meta(_deviceKey);
    final storedMachine = await db.meta(_machineKey);
    if (stored != null && (machine == null || storedMachine == null || storedMachine == machine)) {
      if (storedMachine == null && machine != null) await db.setMeta(_machineKey, machine);
      return stored;
    }
    final fresh = newId();
    await db.setMeta(_deviceKey, fresh);
    await db.setMeta(_machineKey, machine);
    return fresh;
  }

  @override
  void dispose() {
    _soon?.cancel();
    _periodic?.cancel();
    unawaited(_tables?.cancel());
    unawaited(_watch?.cancel());
    _lifecycle?.dispose();
    app.removeListener(_onLibrary);
    super.dispose();
  }
}
