import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse, AppExitType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tinglang_native/tinglang_native.dart';

import 'app_controller.dart';
import 'transcription_controller.dart';
import 'update_install.dart' show bundleOfExecutable;

/// The Voice Memos library as the app sees it: recordings, which were
/// already imported, and why it cannot be read.
///
/// Nothing is read until the user opens the import list once; after a
/// successful listing, launches and returning to the app check for today's
/// new recordings (protected folders are never touched unasked).
class VoiceMemoService extends ChangeNotifier {
  VoiceMemoService({
    required this.app,
    required this.transcription,
    TinglangPlatform? platform,
    this.shell,
    DateTime Function()? now,
    Future<void> Function(List<String> arguments)? open,
    Future<void> Function()? relaunch,
  }) : _platform = platform ?? (TinglangPlatform.isInstalled ? TinglangPlatform.instance : null),
       _now = now ?? DateTime.now,
       _open = open ?? _openWithSystem,
       _relaunch = relaunch ?? _relaunchApp;

  /// Set once listing worked; enables the automatic checks.
  static const enabledKey = 'voice_memos_enabled';
  static const refPrefix = 'voicememo:';
  static String refFor(VoiceMemo memo) => '$refPrefix${memo.id}';

  final AppController app;
  final TranscriptionController transcription;
  final DesktopShell? shell;
  final TinglangPlatform? _platform;
  final DateTime Function() _now;
  final Future<void> Function(List<String> arguments) _open;
  final Future<void> Function() _relaunch;
  VoiceMemoLibrary? _library;

  /// How often "Check again" found the folder still closed in this run:
  /// the dialog then says that macOS applies the switch after a restart.
  int refusedChecks = 0;
  bool _resolved = false;
  DateTime? _checked;

  List<VoiceMemo> memos = const [];
  Set<String> imported = const {};
  VoiceMemoProblem? problem;
  bool loading = false;

  /// False where no backend exists (Windows, tests without one).
  bool available = false;

  bool isImported(VoiceMemo memo) => imported.contains(refFor(memo));

  /// Recorded today (local time) and not imported yet.
  List<VoiceMemo> get fresh {
    final now = _now();
    return [
      for (final memo in memos)
        if (!isImported(memo) && _sameDay(memo.recordedAt.toLocal(), now)) memo,
    ];
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<VoiceMemoLibrary?> _backend() async {
    if (_resolved) return _library;
    _resolved = true;
    final platform = _platform;
    if (platform != null) {
      final choice = platform.voiceMemos.pick(await platform.probe());
      if (choice.hasSelection) _library = choice.create();
    }
    available = _library != null;
    notifyListeners();
    return _library;
  }

  /// Finds out whether this platform has Voice Memos at all.
  Future<void> init() async => _backend();

  /// Lists the library and marks what was already imported.
  Future<void> refresh() async {
    final library = await _backend();
    if (library == null || loading) return;
    loading = true;
    notifyListeners();
    try {
      final listed = await library.list();
      imported = await transcription.repository.importedSources(refPrefix);
      memos = listed;
      problem = null;
    } on VoiceMemoFailure catch (e) {
      memos = const [];
      problem = e.problem;
    } finally {
      loading = false;
      notifyListeners();
    }
    // Remembered after the list is shown, so a slow save never holds it up.
    if (problem == null && app.setting(enabledKey, 'false') != 'true') {
      await app.setSetting(enabledKey, 'true');
    }
  }

  /// At launch and when the app comes back (at most once a minute): only
  /// once the user has used the import list successfully.
  Future<void> checkInBackground() async {
    if (app.setting(enabledKey, 'false') != 'true') return;
    final now = _now(), last = _checked;
    if (last != null && now.difference(last) < const Duration(minutes: 1)) return;
    _checked = now;
    await refresh();
  }

  /// Copies and transcribes [selected]; progress shows under History.
  /// [titleFor] names recordings that have no title of their own.
  Future<void> import(Iterable<VoiceMemo> selected, String Function(VoiceMemo) titleFor) async {
    for (final memo in selected) {
      await transcribeMedia(
        app,
        transcription,
        File(memo.path),
        origin: 'voice_memo',
        sourceRef: refFor(memo),
        title: memo.title.isEmpty ? titleFor(memo) : memo.title,
        recordedAt: memo.recordedAt,
      );
      imported = {...imported, refFor(memo)};
    }
    notifyListeners();
  }

  Future<void> openPrivacySettings() async =>
      shell?.openSystemSettings(SystemSettingsPane.fullDiskAccess);

  /// "Check again": reads the library and counts a refusal, so the user sees
  /// that the check ran.
  Future<void> checkAgain() async {
    await refresh();
    if (problem == VoiceMemoProblem.needsFullDiskAccess) {
      refusedChecks++;
      notifyListeners();
    }
  }

  /// Selects TingLang in Finder, to drag it into the Full Disk Access list
  /// (macOS lists an app there only once it is added with "+" or a drop).
  Future<void> revealApp() async {
    final bundle = bundleOfExecutable(Platform.resolvedExecutable);
    if (bundle != null) await _open(['-R', bundle]);
  }

  /// Quits through the usual exit handler and opens TingLang again: macOS
  /// applies Full Disk Access to a running app only after a restart.
  Future<void> relaunch() => _relaunch();

  static Future<void> _openWithSystem(List<String> arguments) async {
    await Process.run('/usr/bin/open', arguments);
  }

  static Future<void> _relaunchApp() async {
    final bundle = bundleOfExecutable(Platform.resolvedExecutable);
    if (bundle == null) return;
    // Waits for this process to end, then opens the app again.
    final waiter = await Process.start('/bin/sh', [
      '-c',
      'while kill -0 "\$1" 2>/dev/null; do sleep 0.2; done; /usr/bin/open "\$2"',
      'tinglang-relaunch',
      '$pid',
      bundle,
    ], mode: ProcessStartMode.detached);
    final response = await ServicesBinding.instance.exitApplication(AppExitType.cancelable);
    // The exit handler said no (a recording runs): do not reopen later.
    if (response == AppExitResponse.cancel) Process.killPid(waiter.pid);
  }
}
