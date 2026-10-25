import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tinglang_native/tinglang_native.dart' show SystemSettingsPane, TinglangPlatform;
import 'package:tinglang_ui/tinglang_ui.dart';

import 'core/models.dart';
import 'core/json_helpers.dart';
import 'l10n/app_localizations.dart';
import 'core/providers/provider_repository.dart';
import 'services/speech_model_service.dart';
import 'services/update_service.dart';
import 'services/sync_service.dart';
import 'services/app_controller.dart';
import 'services/cloud/cloud_controller.dart';
import 'services/course_generation.dart';
import 'services/live_controller.dart';
import 'services/panel_coordinator.dart';
import 'services/transcription_controller.dart';
import 'services/voice_memos.dart';
import 'services/playback_hub.dart';
import 'services/recording_service.dart';
import 'ui/account_panel.dart';
import 'ui/brand.dart';
import 'ui/update_banner.dart';
import 'ui/file_picking.dart';
import 'ui/import_dialog.dart';
import 'ui/learn_page.dart';
import 'ui/library_page.dart';
import 'ui/onboarding_dialog.dart';
import 'ui/records_page.dart';
import 'ui/session_page.dart';
import 'ui/settings_page.dart';
import 'ui/share_import.dart';
import 'ui/sync_panel.dart';
import 'ui/voice_memos_dialog.dart';

const appVersion = '0.6.1';

/// `system` → null (follow the OS); otherwise a supported language code.
Locale? uiLocaleFor(String setting) => switch (setting) {
  'en' => const Locale('en'),
  'zh' => const Locale('zh'),
  _ => null,
};

ThemeMode themeModeFor(String setting) => switch (setting) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

class TinglangApp extends StatelessWidget {
  const TinglangApp({
    super.key,
    required this.controller,
    required this.playback,
    required this.recorder,
    required this.live,
    required this.transcription,
    required this.navigation,
    required this.exitNotice,
    this.generation,
    this.providers,
    this.voiceMemos,
    this.cloud,
    this.openUrl,
    this.speechModels,
    this.sync,
    this.updates,
    this.openSystemSettings,
  });
  final AppController controller;
  final PlaybackHub playback;
  final RecordingService recorder;
  final LiveController live;
  final TranscriptionController transcription;
  final ValueNotifier<ShellRequest?> navigation;
  final ValueNotifier<String?> exitNotice;
  final CourseGenerationService? generation;
  final ProviderRepository? providers;
  final VoiceMemoService? voiceMemos;
  final CloudController? cloud;
  final Future<void> Function(Uri url)? openUrl;
  final SpeechModelService? speechModels;

  /// iCloud Drive sync (Settings → SyncPanel).
  final SyncService? sync;

  /// Updates from GitHub Releases (banner and Settings → General).
  final UpdateService? updates;

  /// Opens a Privacy & Security pane (the first-start guide).
  final Future<void> Function(SystemSettingsPane pane)? openSystemSettings;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: TinglangTheme.light(),
      darkTheme: TinglangTheme.dark(),
      themeMode: themeModeFor(controller.setting(AppController.themeKey, 'system')),
      locale: uiLocaleFor(controller.setting(AppController.uiLocaleKey, 'system')),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: TinglangShell(
        app: controller,
        playback: playback,
        recorder: recorder,
        live: live,
        transcription: transcription,
        navigation: navigation,
        exitNotice: exitNotice,
        generation: generation,
        providers: providers,
        voiceMemos: voiceMemos,
        cloud: cloud,
        openUrl: openUrl,
        speechModels: speechModels,
        sync: sync,
        updates: updates,
        openSystemSettings: openSystemSettings,
      ),
    ),
  );
}

/// Sidebar sections: history (captions, imports, review, speaking), the
/// library (courses, discover, shared) and settings.
enum Section { records, library, settings }

class TinglangShell extends StatefulWidget {
  const TinglangShell({
    super.key,
    required this.app,
    required this.playback,
    required this.recorder,
    required this.live,
    required this.transcription,
    required this.navigation,
    required this.exitNotice,
    this.generation,
    this.providers,
    this.voiceMemos,
    this.cloud,
    this.openUrl,
    this.speechModels,
    this.sync,
    this.updates,
    this.openSystemSettings,
  });
  final AppController app;
  final PlaybackHub playback;
  final RecordingService recorder;
  final LiveController live;
  final TranscriptionController transcription;

  /// Requests from the floating panel (open history, a session, settings).
  final ValueNotifier<ShellRequest?> navigation;

  /// Why a quit was refused; shown as a message.
  final ValueNotifier<String?> exitNotice;
  final CourseGenerationService? generation;
  final ProviderRepository? providers;

  /// Apple Voice Memos, where the platform has them.
  final VoiceMemoService? voiceMemos;

  /// The optional TingLang account (sidebar → Account).
  final CloudController? cloud;
  final Future<void> Function(Uri url)? openUrl;
  final SpeechModelService? speechModels;

  /// iCloud Drive sync, for Settings (`SyncPanel(sync: …)`).
  final SyncService? sync;

  /// Updates from GitHub Releases.
  final UpdateService? updates;

  /// Opens a Privacy & Security pane (the first-start guide).
  final Future<void> Function(SystemSettingsPane pane)? openSystemSettings;
  @override
  State<TinglangShell> createState() => _TinglangShellState();
}

class _TinglangShellState extends State<TinglangShell> {
  Section _section = Section.records;
  RecordsTab _recordsTab = RecordsTab.captions;
  LibraryTab _libraryTab = LibraryTab.mine;
  SettingsTab _settingsTab = SettingsTab.general;
  int _navigationToken = 0;
  String? _courseId, _clipId;
  late final Listenable _changes;
  bool get locked => widget.recorder.navigationLocked || widget.app.pendingAttempt != null;

  /// Opt-in automation for local verification only (never set in normal
  /// launches): import a file and/or open the newest session.
  Future<void> _verificationHooks() async {
    final env = Platform.environment;
    final open = env['TINGLANG_OPEN_COURSE'];
    if (open != null && mounted) {
      final parts = open.split('#');
      final course = widget.app.state.courses.where((c) => c.id == parts.first).firstOrNull;
      if (course != null) _open(course, parts.length > 1 ? parts[1] : null);
      return;
    }
    String? sessionId;
    final path = env['TINGLANG_AUTOIMPORT'];
    if (path != null) {
      final job = await transcribeMedia(widget.app, widget.transcription, File(path));
      while (job.status == ImportStatus.copying || job.status == ImportStatus.transcribing) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      sessionId = job.sessionId;
    } else if (env['TINGLANG_OPEN_LATEST_SESSION'] == '1') {
      final sessions = await widget.live.repository.recentSessions(limit: 1);
      sessionId = sessions.isEmpty ? null : sessions.first.id;
    }
    if (sessionId == null || !mounted) return;
    _navigate(Section.records);
    final course = await Navigator.of(context).push(
      MaterialPageRoute<Course?>(
        builder: (_) => SessionPage(
          sessionId: sessionId!,
          repository: widget.live.repository,
          store: widget.app.store,
          playback: widget.playback,
          generation: widget.generation,
        ),
      ),
    );
    if (course != null) _open(course, null);
  }

  /// Acts on the latest panel request; the window may have been hidden when
  /// it arrived, so it is also checked after the first frame.
  void _onNavigation() {
    final request = widget.navigation.value;
    if (request == null || !mounted) return;
    widget.navigation.value = null;
    switch (request) {
      case OpenHistory():
        _navigate(Section.records, records: RecordsTab.captions);
      case OpenSettings(:final speech):
        _navigate(Section.settings, settings: speech ? SettingsTab.speech : null);
      case OpenVoiceMemos():
        unawaited(_openVoiceMemos());
      case OpenSession(:final sessionId, :final makeCourse):
        unawaited(_openSession(sessionId, makeCourse: makeCourse));
      case ImportPackages(:final paths):
        unawaited(_importPackages(paths));
    }
  }

  /// `.tinglang` files opened from Finder or the Dock (or dropped), one
  /// after another through the usual import flow and its confirmation.
  Future<void> _importPackages(List<String> paths) async {
    for (final path in paths) {
      if (!mounted) return;
      await importSharedPath(
        context,
        path,
        app: widget.app,
        repository: widget.live.repository,
        onSession: (_) => _navigate(Section.records, records: RecordsTab.captions),
        onCourse: (course) => _open(course, null),
      );
    }
  }

  /// History, with the Voice Memos list on top; imports show their
  /// progress under History.
  Future<void> _openVoiceMemos() async {
    final memos = widget.voiceMemos;
    if (memos == null || locked) return;
    _navigate(Section.records, records: RecordsTab.captions);
    await showVoiceMemos(context, memos);
  }

  Future<void> _openSession(String sessionId, {bool makeCourse = false}) async {
    if (locked) return;
    await widget.playback.pauseAll();
    if (!mounted) return;
    setState(() {
      _section = Section.records;
      _recordsTab = RecordsTab.captions;
    });
    final course = await Navigator.of(context).push(
      MaterialPageRoute<Course?>(
        builder: (_) => SessionPage(
          sessionId: sessionId,
          repository: widget.live.repository,
          store: widget.app.store,
          playback: widget.playback,
          generation: widget.generation,
          openMakeCourse: makeCourse,
        ),
      ),
    );
    if (course != null) _open(course, null);
  }

  void _onExitNotice() {
    final message = widget.exitNotice.value;
    if (message == null || !mounted) return;
    widget.exitNotice.value = null;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificationHooks());
    _changes = Listenable.merge([widget.app, widget.recorder, ?widget.voiceMemos]);
    widget.navigation.addListener(_onNavigation);
    widget.exitNotice.addListener(_onExitNotice);
    // Requests that arrived while the window was still hidden.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onNavigation();
      _onExitNotice();
      // A new library: the guide opens once (main.dart shows the window).
      if (widget.app.setting(AppController.onboardingKey, '') == AppController.onboardingPending) {
        unawaited(_showOnboarding());
      }
    });
  }

  bool _onboarding = false;

  /// The first-start guide; finished with the cloud chosen, it leads on to
  /// Settings → Speech recognition for the key.
  Future<void> _showOnboarding() async {
    if (_onboarding || !mounted) return;
    _onboarding = true;
    try {
      final outcome = await showOnboarding(
        context,
        app: widget.app,
        models: widget.speechModels,
        access: PermissionAccess(
          probe: TinglangPlatform.isInstalled ? TinglangPlatform.instance.probe : null,
          requestMicrophone: widget.recorder.requestPermission,
          openSettings: widget.openSystemSettings,
        ),
      );
      if (outcome == OnboardingOutcome.setUpCloud) {
        _navigate(Section.settings, settings: SettingsTab.speech);
      }
    } finally {
      _onboarding = false;
    }
  }

  void _navigate(
    Section section, {
    RecordsTab? records,
    LibraryTab? library,
    SettingsTab? settings,
  }) {
    if (locked) return;
    final token = ++_navigationToken;
    unawaited(
      reportAction(context, () async {
        await widget.playback.pauseAll();
        if (!mounted || locked || token != _navigationToken) return;
        setState(() {
          _section = section;
          if (records != null) _recordsTab = records;
          if (library != null) _libraryTab = library;
          if (settings != null) _settingsTab = settings;
          _courseId = null;
          _clipId = null;
        });
      }),
    );
  }

  /// Course JSON and subtitles become courses; a media file on its own is
  /// transcribed, and its progress shows under History.
  Future<void> _showImport() => showImportDialog(
    context,
    widget.app,
    onTranscribe: (media) async {
      await transcribeMedia(widget.app, widget.transcription, media);
      _navigate(Section.records, records: RecordsTab.captions);
    },
  );

  Future<void> _importAudio() => reportAction(context, () async {
    final path = await pickFile(TranscriptionController.extensions);
    if (path == null || !mounted) return;
    await transcribeMedia(widget.app, widget.transcription, File(path));
    _navigate(Section.records, records: RecordsTab.captions);
  });

  Future<void> _importShared() => importSharedFile(
    context,
    app: widget.app,
    repository: widget.live.repository,
    onSession: (_) => _navigate(Section.records, records: RecordsTab.captions),
    onCourse: (course) => _open(course, null),
  );

  void _open(Course course, String? requestedClip) {
    if (locked) return;
    final id = course.clips.any((c) => c.id == requestedClip)
        ? requestedClip
        : course.clips.first.id;
    final clip = course.clips.firstWhere((c) => c.id == id);
    final token = ++_navigationToken;
    unawaited(
      reportAction(context, () async {
        await widget.playback.pauseAll();
        if (!mounted || locked || token != _navigationToken) return;
        setState(() {
          _section = Section.library;
          _courseId = course.id;
          _clipId = clip.id;
        });
        await widget.app.visit(course, clip);
      }),
    );
  }

  @override
  void dispose() {
    widget.navigation.removeListener(_onNavigation);
    widget.exitNotice.removeListener(_onExitNotice);
    widget.recorder.dispose();
    widget.playback.dispose();
    widget.app.dispose();
    super.dispose();
  }

  Widget _content() {
    Course? selected;
    for (final course in widget.app.state.courses) {
      if (course.id == _courseId) selected = course;
    }
    final course = selected;
    if (_section == Section.library && course != null && _clipId != null) {
      return LearnPage(
        key: ValueKey(entityKey(course.id, _clipId!)),
        app: widget.app,
        course: course,
        clipId: _clipId!,
        playback: widget.playback,
        recorder: widget.recorder,
        onClip: (id) => _open(course, id),
        onBack: () => _navigate(Section.library),
      );
    }
    return switch (_section) {
      Section.records => RecordsPage(
        app: widget.app,
        live: widget.live,
        transcription: widget.transcription,
        playback: widget.playback,
        recorder: widget.recorder,
        tab: _recordsTab,
        onTab: (tab) => setState(() => _recordsTab = tab),
        onOpenSession: _openSession,
        onImportAudio: _importAudio,
        onOpenClip: _open,
        voiceMemos: widget.voiceMemos,
        onVoiceMemos: _openVoiceMemos,
      ),
      Section.library => LibraryPage(
        app: widget.app,
        onOpen: _open,
        onImport: _showImport,
        onImportShared: _importShared,
        tab: _libraryTab,
        onTab: (tab) => setState(() => _libraryTab = tab),
      ),
      Section.settings => SettingsPage(
        app: widget.app,
        tab: _settingsTab,
        onTab: (tab) => setState(() => _settingsTab = tab),
        providers: widget.providers,
        onResetPanel: widget.live.resetOverlay,
        openUrl: widget.openUrl,
        speechModels: widget.speechModels,
        sync: widget.sync == null ? null : SyncPanel(sync: widget.sync!),
        updates: widget.updates == null
            ? null
            : UpdateSettingsTile(updates: widget.updates!, openUrl: widget.openUrl),
        onShowOnboarding: () => unawaited(_showOnboarding()),
      ),
    };
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _changes,
    builder: (context, _) {
      final c = context.sl;
      final l = context.l10n;
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              section: _section,
              locked: locked,
              dueCount: widget.app.due.length,
              live: widget.live,
              onSelect: (section) => _navigate(section),
              onSpeechSetup: () => _navigate(Section.settings, settings: SettingsTab.speech),
              cloud: widget.cloud,
              openUrl: widget.openUrl,
              updates: widget.updates,
            ),
            Expanded(
              child: Column(
                children: [
                  if (widget.updates != null)
                    UpdateBanner(
                      updates: widget.updates!,
                      openUrl: widget.openUrl,
                      padding: EdgeInsets.fromLTRB(
                        SlSpace.page,
                        locked ? 10 : 34,
                        SlSpace.page,
                        10,
                      ),
                    ),
                  if (locked)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(SlSpace.page, 34, SlSpace.page, 10),
                      color: c.warning.withValues(alpha: .1),
                      child: Text(
                        widget.app.pendingAttempt != null ? l.lockPendingAttempt : l.lockRecording,
                        style: SlType.caption.copyWith(color: c.warning),
                      ),
                    ),
                  if (widget.app.persistenceError != null)
                    MaterialBanner(
                      content: Text(l.persistenceFailed(widget.app.persistenceError!)),
                      actions: [
                        if (widget.app.pendingAttempt != null)
                          TextButton(
                            onPressed: () => reportAction(context, widget.app.retryPending),
                            child: Text(l.retrySave),
                          )
                        else
                          TextButton(
                            onPressed: () => _navigate(Section.settings),
                            child: Text(l.showDataLocation),
                          ),
                      ],
                    ),
                  Expanded(child: _content()),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The left rail: the mark and name under the window buttons, a button that
/// starts live captions (the panel shows them), two sections and settings.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.section,
    required this.locked,
    required this.dueCount,
    required this.live,
    required this.onSelect,
    required this.onSpeechSetup,
    this.cloud,
    this.openUrl,
    this.updates,
  });
  final Section section;
  final bool locked;
  final int dueCount;
  final LiveController live;
  final ValueChanged<Section> onSelect;

  /// Shows Settings → Speech recognition (start found nothing set up).
  final VoidCallback onSpeechSetup;

  /// The TingLang account (null in tests without one).
  final CloudController? cloud;
  final Future<void> Function(Uri url)? openUrl;

  /// A newer version puts a green arrow on the mark's corner.
  final UpdateService? updates;

  @override
  Widget build(BuildContext context) {
    final c = context.sl;
    final l = context.l10n;
    return Container(
      width: 224,
      decoration: BoxDecoration(
        color: c.sidebar,
        border: Border(right: BorderSide(color: c.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The transparent title bar (traffic lights, dragging) sits here.
          const SizedBox(height: 46),
          // The mark and the name on one line, the version under the name.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              key: const ValueKey('sidebar-brand'),
              children: [
                // The mark and the gap after it. A newer version puts a green
                // arrow on the mark's corner, inside this box: a widget that
                // sticks out of its parent takes no clicks there.
                SizedBox(
                  width: 36 + SlSpace.sm + 2,
                  height: 36,
                  child: Stack(
                    children: [
                      const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 36)),
                      if (updates != null)
                        Positioned(
                          top: 0,
                          left: 27,
                          child: UpdateBadge(updates: updates!, openUrl: openUrl),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.appTitle,
                        overflow: TextOverflow.ellipsis,
                        style: SlType.title.copyWith(
                          color: c.text,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.2,
                          height: 1.15,
                        ),
                      ),
                      Text(
                        'v$appVersion',
                        key: const ValueKey('sidebar-version'),
                        style: SlType.micro.copyWith(
                          color: c.muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SlSpace.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _LiveButton(live: live, onSpeechSetup: onSpeechSetup),
          ),
          const SizedBox(height: SlSpace.lg),
          _NavItem(
            key: const ValueKey('nav-records'),
            icon: Icons.subtitles_outlined,
            label: l.navRecords,
            count: dueCount,
            selected: section == Section.records,
            enabled: !locked,
            onTap: () => onSelect(Section.records),
          ),
          _NavItem(
            key: const ValueKey('nav-library'),
            icon: Icons.collections_bookmark_outlined,
            label: l.navLibrary,
            selected: section == Section.library,
            enabled: !locked,
            onTap: () => onSelect(Section.library),
          ),
          const Spacer(),
          if (cloud != null) AccountEntry(cloud: cloud!, openUrl: openUrl),
          _NavItem(
            key: const ValueKey('nav-settings'),
            icon: Icons.tune_rounded,
            label: l.navSettings,
            selected: section == Section.settings,
            enabled: !locked,
            onTap: () => onSelect(Section.settings),
          ),
          const SizedBox(height: SlSpace.md),
        ],
      ),
    );
  }
}

class _LiveButton extends StatelessWidget {
  const _LiveButton({required this.live, required this.onSpeechSetup});
  final LiveController live;
  final VoidCallback onSpeechSetup;

  /// Starts captions from the main window; a setup that is made in Settings
  /// (first choice, cloud key) opens it here, the panel says it too.
  Future<void> _toggle() async {
    await live.toggle();
    if (isSpeechSettingsNeed(live.setupNeed)) onSpeechSetup();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListenableBuilder(
      listenable: live,
      builder: (context, _) {
        final busy = live.status == LiveStatus.starting || live.status == LiveStatus.stopping;
        final available = live.unavailableReason == null;
        final button = live.isActive
            ? OutlinedButton.icon(
                onPressed: busy ? null : live.toggle,
                icon: Icon(Icons.stop_rounded, size: 18, color: context.sl.accentInk),
                label: Text(l.liveStop),
              )
            : FilledButton.icon(
                onPressed: busy || !available ? null : _toggle,
                icon: const Icon(Icons.mic_rounded, size: 18),
                label: Text(l.panelStart, overflow: TextOverflow.ellipsis),
              );
        return Tooltip(
          message: available ? '⌘⇧T' : l.panelUnavailable,
          child: SizedBox(width: double.infinity, child: button),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.count = 0,
  });
  final IconData icon;
  final String label;
  final bool selected, enabled;
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.sl;
    final tone = selected ? c.accentInk : c.inkSoft;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: selected ? c.accentSoft : Colors.transparent,
        borderRadius: SlRadius.all(10),
        child: InkWell(
          borderRadius: SlRadius.all(10),
          onTap: enabled ? onTap : null,
          child: Semantics(
            selected: selected,
            button: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: tone),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: SlType.body.copyWith(
                        color: selected ? c.accentInk : c.text,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (count > 0)
                    Text(
                      '$count',
                      style: SlType.caption.copyWith(
                        color: tone,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
