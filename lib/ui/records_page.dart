import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import '../core/db/database.dart';
import '../core/live_repository.dart';
import '../core/models.dart';
import '../core/transcript_export.dart';
import '../services/app_controller.dart';
import '../services/live_controller.dart';
import '../services/playback_hub.dart';
import '../services/recording_service.dart';
import '../services/transcription_controller.dart';
import '../services/voice_memos.dart';
import 'brand.dart';
import 'errors.dart';
import 'file_picking.dart';
import 'review_page.dart';
import 'share_import.dart';
import 'speak_page.dart';

enum RecordsTab { captions, review, speak }

typedef _Listing = ({List<SessionRow> sessions, Map<String, String> previews});

/// Everything you captured or imported, with review and speaking practice
/// alongside: the main window's home.
class RecordsPage extends StatelessWidget {
  const RecordsPage({
    super.key,
    required this.app,
    required this.live,
    required this.transcription,
    required this.playback,
    required this.recorder,
    required this.tab,
    required this.onTab,
    required this.onOpenSession,
    required this.onImportAudio,
    required this.onOpenClip,
    this.voiceMemos,
    this.onVoiceMemos,
  });
  final AppController app;
  final LiveController live;
  final TranscriptionController transcription;
  final PlaybackHub playback;
  final RecordingService recorder;
  final RecordsTab tab;
  final ValueChanged<RecordsTab> onTab;
  final Future<void> Function(String sessionId) onOpenSession;
  final Future<void> Function() onImportAudio;
  final void Function(Course course, String? clipId) onOpenClip;

  /// Apple Voice Memos, where the platform has them.
  final VoiceMemoService? voiceMemos;
  final Future<void> Function()? onVoiceMemos;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SlPageHeader(
          title: l.navRecords,
          tabs: SlTabs<RecordsTab>(
            tabs: [
              (value: RecordsTab.captions, label: l.tabCaptions, count: null),
              (value: RecordsTab.review, label: l.tabReview, count: app.due.length),
              (value: RecordsTab.speak, label: l.tabSpeak, count: null),
            ],
            selected: tab,
            onChanged: onTab,
          ),
          actions: [
            if (tab == RecordsTab.captions && (voiceMemos?.available ?? false))
              OutlinedButton.icon(
                key: const ValueKey('voice-memos'),
                onPressed: onVoiceMemos,
                icon: const Icon(Icons.keyboard_voice_outlined, size: 18),
                label: Text(l.voiceMemos),
              ),
            if (tab == RecordsTab.captions)
              OutlinedButton.icon(
                onPressed: onImportAudio,
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: Text(l.importAudio),
              ),
          ],
        ),
        Expanded(
          child: switch (tab) {
            RecordsTab.captions => SessionsView(
              app: app,
              live: live,
              transcription: transcription,
              onOpen: onOpenSession,
              onImportAudio: onImportAudio,
              voiceMemos: voiceMemos,
              onVoiceMemos: onVoiceMemos,
            ),
            RecordsTab.review => ReviewPage(app: app, onOpen: onOpenClip),
            RecordsTab.speak => SpeakPage(app: app, recorder: recorder, playback: playback),
          },
        ),
      ],
    );
  }
}

/// Captions and imports, newest first and grouped by day, with full-text
/// search over every saved line.
class SessionsView extends StatefulWidget {
  const SessionsView({
    super.key,
    required this.app,
    required this.live,
    required this.transcription,
    required this.onOpen,
    required this.onImportAudio,
    this.voiceMemos,
    this.onVoiceMemos,
  });
  final AppController app;
  final LiveController live;
  final TranscriptionController transcription;
  final Future<void> Function(String sessionId) onOpen;
  final Future<void> Function() onImportAudio;
  final VoiceMemoService? voiceMemos;
  final Future<void> Function()? onVoiceMemos;

  @override
  State<SessionsView> createState() => _SessionsViewState();
}

class _SessionsViewState extends State<SessionsView> {
  LiveRepository get repository => widget.live.repository;
  late Future<_Listing> _sessions = _load();
  Future<List<SegmentRow>>? _search;
  Timer? _debounce;
  LiveStatus _lastStatus = LiveStatus.idle;
  final _seenJobs = <ImportJob>{};

  @override
  void initState() {
    super.initState();
    widget.live.addListener(_onLive);
    widget.transcription.addListener(_onJobs);
    _watchJobs();
  }

  @override
  void dispose() {
    widget.live.removeListener(_onLive);
    widget.transcription.removeListener(_onJobs);
    for (final job in _seenJobs) {
      job.removeListener(_onJob);
    }
    _debounce?.cancel();
    super.dispose();
  }

  Future<_Listing> _load() async {
    final sessions = await repository.recentSessions(limit: 200);
    final previews = await repository.firstLines([for (final s in sessions) s.id]);
    return (sessions: sessions, previews: previews);
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _sessions = _load();
    });
  }

  /// A capture that just ended appears in the list.
  void _onLive() {
    final status = widget.live.status;
    if (status != _lastStatus && status == LiveStatus.idle) _reload();
    if (status != _lastStatus && mounted) setState(() {});
    _lastStatus = status;
  }

  void _watchJobs() {
    for (final job in widget.transcription.jobs) {
      if (_seenJobs.add(job)) job.addListener(_onJob);
    }
  }

  void _onJobs() {
    _watchJobs();
    _reload();
  }

  void _onJob() => _reload();

  String _title(BuildContext context, SessionRow s) => s.title.isNotEmpty
      ? s.title
      : context.l10n.liveSessionTitle(
          DateFormat.MMMd(context.l10n.localeName).add_Hm().format(s.startedAt.toLocal()),
        );

  Future<void> _export(BuildContext context, SessionRow session) async {
    final l = context.l10n;
    final choice = await showDialog<(TranscriptFormat, TranscriptLanguage)>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.liveExport),
        children: [
          for (final format in TranscriptFormat.values)
            for (final language in TranscriptLanguage.values)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, (format, language)),
                child: Text(
                  '${format.name.toUpperCase()} · ${switch (language) {
                    TranscriptLanguage.bilingual => l.liveExportBilingual,
                    TranscriptLanguage.source => l.liveExportSource,
                    TranscriptLanguage.translation => l.liveExportTranslation,
                  }}',
                ),
              ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    final title = _title(context, session);
    await reportAction(context, () async {
      final lines = await repository.lines(session.id);
      final text = renderTranscript(
        lines,
        title: title,
        format: choice.$1,
        language: choice.$2,
        timesNote: l.liveTimesNote,
      );
      final path = await pickSaveLocation(
        dialogTitle: l.liveExport,
        fileName: '${title.replaceAll(RegExp(r'[/:\\]'), '-')}.${choice.$1.name}',
      );
      if (path != null) await File(path).writeAsString(text);
    });
  }

  Future<void> _delete(BuildContext context, SessionRow session) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.liveDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.sl.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.liveDelete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await reportAction(context, () => repository.deleteSession(session.id));
    _reload();
  }

  Future<void> _open(String id) async {
    await widget.onOpen(id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    final jobs = [
      for (final job in widget.transcription.jobs.take(5))
        if (job.status != ImportStatus.done) job,
    ];
    final fresh = widget.voiceMemos?.fresh.length ?? 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(SlSpace.page, 0, SlSpace.page, SlSpace.page),
      children: [
        if (widget.live.isActive) ...[
          _LiveBanner(live: widget.live),
          const SizedBox(height: SlSpace.lg),
        ],
        if (fresh > 0 && widget.onVoiceMemos != null) ...[
          _VoiceMemosBanner(count: fresh, onImport: widget.onVoiceMemos!),
          const SizedBox(height: SlSpace.lg),
        ],
        for (final job in jobs) ...[_ImportJobTile(job: job), const SizedBox(height: SlSpace.sm)],
        if (jobs.isNotEmpty) const SizedBox(height: SlSpace.sm),
        TextField(
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search, size: 18, color: c.muted),
            hintText: l.liveSearchHint,
          ),
          onChanged: (q) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 250), () {
              setState(() {
                _search = q.trim().isEmpty ? null : repository.db.searchSegments(q);
              });
            });
          },
        ),
        const SizedBox(height: SlSpace.lg),
        if (_search == null) _list(context) else _results(context),
      ],
    );
  }

  Widget _list(BuildContext context) {
    final l = context.l10n;
    return FutureBuilder<_Listing>(
      future: _sessions,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const SizedBox.shrink();
        final sessions = snapshot.data?.sessions ?? const <SessionRow>[];
        final previews = snapshot.data?.previews ?? const <String, String>{};
        if (sessions.isEmpty) {
          return SlEmptyState(
            icon: Icons.subtitles_outlined,
            art: const BrandMark(size: 56),
            title: l.recordsEmptyTitle,
            body: l.recordsEmptyBody,
            action: FilledButton.icon(
              onPressed: widget.onImportAudio,
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: Text(l.importAudio),
            ),
          );
        }
        final groups = <String, List<SessionRow>>{};
        for (final session in sessions) {
          groups.putIfAbsent(_day(context, session.startedAt), () => []).add(session);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, SlSpace.sm, 0, SlSpace.sm),
                child: Text(entry.key, style: SlType.label.copyWith(color: context.sl.muted)),
              ),
              SlPanel(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final (index, session) in entry.value.indexed) ...[
                      if (index > 0) Divider(indent: 60, color: context.sl.line),
                      _SessionRowTile(
                        session: session,
                        // Untitled captures read best by what was said.
                        title: session.title.isEmpty
                            ? previews[session.id] ?? _title(context, session)
                            : session.title,
                        onTap: () => _open(session.id),
                        onExport: () => _export(context, session),
                        onShare: () => exportSessionShare(
                          context,
                          repository: repository,
                          store: widget.app.store,
                          sessionId: session.id,
                          title: session.title.isEmpty
                              ? previews[session.id] ?? _title(context, session)
                              : session.title,
                        ),
                        onDelete: () => _delete(context, session),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: SlSpace.md),
            ],
          ],
        );
      },
    );
  }

  String _day(BuildContext context, DateTime startedAt) {
    final l = context.l10n;
    final local = startedAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final days = today.difference(day).inDays;
    if (days == 0) return l.dayToday;
    if (days == 1) return l.dayYesterday;
    return DateFormat.MMMEd(l.localeName).format(local);
  }

  Widget _results(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    return FutureBuilder<List<SegmentRow>>(
      future: _search,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const SizedBox.shrink();
        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(SlSpace.lg),
            child: Text(l.liveNoMatches, style: SlType.body.copyWith(color: c.muted)),
          );
        }
        return SlPanel(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final row in rows)
                ListTile(
                  title: Text(row.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    DateFormat.yMMMd(l.localeName).add_Hm().format(row.createdAt.toLocal()),
                    style: SlType.caption.copyWith(color: c.muted),
                  ),
                  onTap: () => _open(row.sessionId),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SessionRowTile extends StatelessWidget {
  const _SessionRowTile({
    required this.session,
    required this.title,
    required this.onTap,
    required this.onExport,
    required this.onShare,
    required this.onDelete,
  });
  final SessionRow session;
  final String title;

  /// [onExport] saves the transcript as text; [onShare] saves a `.tinglang`
  /// file with the lines, translations and audio or video.
  final VoidCallback onTap, onExport, onShare, onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    final (icon, source) = switch (session.origin) {
      'live_mic' => (Icons.mic_none_rounded, l.liveSourceMic),
      'live_system' => (Icons.graphic_eq_rounded, l.liveSourceSystem),
      'shared' => (Icons.move_to_inbox_outlined, l.originShared),
      'voice_memo' => (Icons.keyboard_voice_outlined, l.originVoiceMemo),
      _ => (Icons.audio_file_outlined, l.originFile),
    };
    final time = DateFormat.Hm(l.localeName).format(session.startedAt.toLocal());
    final length = session.endedAt?.difference(session.startedAt);
    final details = [
      time,
      source,
      if (length != null && session.origin.startsWith('live_')) _clock(length),
      if (session.status == 'interrupted') l.liveSessionInterrupted,
      if (session.status == 'failed') l.sessionFailed,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: c.raised, borderRadius: SlRadius.all(10)),
              child: Icon(icon, size: 18, color: c.inkSoft),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SlType.body.copyWith(fontWeight: FontWeight.w600, color: c.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SlType.caption.copyWith(
                      color: session.status == 'completed' ? c.muted : c.warning,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: l.panelMore,
              icon: Icon(Icons.more_horiz, color: c.muted),
              onSelected: (value) => switch (value) {
                'export' => onExport(),
                'share' => onShare(),
                _ => onDelete(),
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'export', child: Text(l.liveExport)),
                PopupMenuItem(
                  key: const ValueKey('session-share'),
                  value: 'share',
                  child: Text(l.exportShared),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l.liveDelete, style: TextStyle(color: c.danger)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _clock(Duration d) {
    final m = d.inMinutes, s = d.inSeconds % 60;
    return d.inHours > 0
        ? '${d.inHours}:${(m % 60).toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// Today's Voice Memos that are not imported yet.
class _VoiceMemosBanner extends StatelessWidget {
  const _VoiceMemosBanner({required this.count, required this.onImport});
  final int count;
  final Future<void> Function() onImport;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    return SlPanel(
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
      child: Row(
        children: [
          Icon(Icons.keyboard_voice_outlined, size: 18, color: c.accentInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.voiceMemosNewToday('$count'),
              style: SlType.label.copyWith(color: c.text),
            ),
          ),
          TextButton(onPressed: onImport, child: Text(l.voiceMemosImportShort)),
        ],
      ),
    );
  }
}

/// Shown while live captions run; the captions themselves are on the panel.
class _LiveBanner extends StatelessWidget {
  const _LiveBanner({required this.live});
  final LiveController live;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    return SlPanel(
      color: c.accentSoft,
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l.liveRunning, style: SlType.label.copyWith(color: c.accentInk)),
          ),
          TextButton.icon(
            onPressed: live.status == LiveStatus.running ? live.stop : null,
            icon: const Icon(Icons.stop_rounded, size: 18),
            label: Text(l.liveStop),
          ),
        ],
      ),
    );
  }
}

class _ImportJobTile extends StatelessWidget {
  const _ImportJobTile({required this.job});
  final ImportJob job;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    return ListenableBuilder(
      listenable: job,
      builder: (context, _) {
        final running =
            job.status == ImportStatus.copying || job.status == ImportStatus.transcribing;
        return SlPanel(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.audio_file_outlined, size: 18, color: c.inkSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      job.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SlType.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (job.status == ImportStatus.transcribing)
                    TextButton(onPressed: job.cancel, child: Text(l.importCancel)),
                ],
              ),
              if (running) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: job.status == ImportStatus.copying ? null : job.progress,
                  borderRadius: SlRadius.all(4),
                ),
                const SizedBox(height: 6),
                Text(
                  job.status == ImportStatus.copying
                      ? l.importCopying
                      : l.importTranscribing((job.progress * 100).toStringAsFixed(0)),
                  style: SlType.caption.copyWith(color: c.muted),
                ),
              ],
              if (job.status == ImportStatus.failed || job.status == ImportStatus.cancelled) ...[
                const SizedBox(height: 8),
                SlNotice(
                  job.status == ImportStatus.cancelled
                      ? l.importCancelled
                      : describeError(l, job.failure ?? job.error ?? ''),
                  error: job.status == ImportStatus.failed,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
