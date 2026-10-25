import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import '../core/db/database.dart';
import '../core/dictation.dart';
import '../core/library_store.dart';
import '../l10n/app_localizations.dart';
import '../core/live_repository.dart';
import '../core/transcript_export.dart';
import '../services/course_generation.dart';
import '../services/media_session.dart';
import '../services/playback_hub.dart';
import 'brand.dart';
import 'share_import.dart';
import 'make_course_sheet.dart';

/// A saved session: player with A–B loop and speed, the bilingual transcript
/// (tap to seek), and sentence-by-sentence dictation.
class SessionPage extends StatefulWidget {
  const SessionPage({
    super.key,
    required this.sessionId,
    required this.repository,
    required this.store,
    required this.playback,
    this.generation,
    this.openMakeCourse = false,
  });
  final String sessionId;
  final LiveRepository repository;
  final LibraryStore store;
  final PlaybackHub playback;

  /// "Make course"; the page pops with the generated course to open it.
  final CourseGenerationService? generation;

  /// Opens "Make course" as soon as the transcript has loaded (from the
  /// floating panel's button).
  final bool openMakeCourse;

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  SessionRow? _session;
  MediaRow? _media;
  String? _mediaPath;
  List<SavedLine> _lines = const [];
  bool _loading = true;
  String? _loadError;
  ({int startMs, int endMs})? _loop;
  int? _pendingA;

  MediaSession get player => widget.playback.lesson;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(widget.playback.pauseAll());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final session = await widget.repository.session(widget.sessionId);
      final lines = await widget.repository.lines(widget.sessionId);
      MediaRow? media;
      String? path;
      if (session?.mediaId != null && session!.timeBase == 'media') {
        media = await widget.repository.media(session.mediaId!);
        if (media?.relPath != null) path = widget.store.resolve(media!.relPath!);
      }
      if (path != null) {
        player.setLoop(false);
        await player.open(path, 0, null);
      }
      if (!mounted) return;
      setState(() {
        _session = session;
        _lines = lines;
        _media = media;
        _mediaPath = path;
        _loading = false;
      });
      if (widget.openMakeCourse && widget.generation != null && lines.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_makeCourse());
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    }
  }

  Future<void> _setLoop(({int startMs, int endMs})? loop) async {
    final path = _mediaPath;
    if (path == null) return;
    setState(() {
      _loop = loop;
      _pendingA = null;
    });
    player.setLoop(loop != null);
    await player.open(path, loop?.startMs ?? 0, loop?.endMs);
  }

  Future<void> _seekTo(int ms) async {
    if (_mediaPath == null) return;
    if (_loop != null && (ms < _loop!.startMs || ms > _loop!.endMs)) await _setLoop(null);
    await player.seek(ms);
    if (!player.playing) await widget.playback.toggleLesson();
  }

  Future<void> _makeCourse() async {
    await widget.playback.pauseAll();
    if (!mounted) return;
    final course = await showMakeCourseSheet(
      context,
      generation: widget.generation!,
      sessionId: widget.sessionId,
    );
    if (course != null && mounted) Navigator.of(context).pop(course);
  }

  int _tab = 0;

  String _title(AppLocalizations l) => _session == null
      ? ''
      : (_session!.title.isNotEmpty
            ? _session!.title
            : l.liveSessionTitle(
                DateFormat.yMMMd(l.localeName).add_Hm().format(_session!.startedAt.toLocal()),
              ));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    final title = _title(l);
    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          // A reading column; wide windows get margins, not longer lines.
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Below the transparent title bar (which handles clicks for
              // dragging): back, title and actions.
              Padding(
                padding: const EdgeInsets.fromLTRB(SlSpace.lg, 34, SlSpace.lg, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: SlSpace.xs),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SlType.title.copyWith(color: c.text),
                      ),
                    ),
                    // Lines, translations and the audio or video in one
                    // file (also a recording whose transcript is empty).
                    if (_session != null && (_lines.isNotEmpty || _media != null))
                      IconButton(
                        key: const ValueKey('session-export-share'),
                        tooltip: l.exportShared,
                        onPressed: () => exportSessionShare(
                          context,
                          repository: widget.repository,
                          store: widget.store,
                          sessionId: widget.sessionId,
                          title: title,
                        ),
                        icon: const Icon(Icons.ios_share_rounded, size: 20),
                      ),
                    if (widget.generation != null && _lines.isNotEmpty) ...[
                      const SizedBox(width: SlSpace.xs),
                      FilledButton.icon(
                        key: const ValueKey('make-course'),
                        onPressed: _makeCourse,
                        icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                        label: Text(l.makeCourse),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SlSpace.page,
                  SlSpace.md,
                  SlSpace.page,
                  SlSpace.sm,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SlTabs<int>(
                    tabs: [
                      (value: 0, label: l.sessionTranscript, count: null),
                      (value: 1, label: l.sessionDictation, count: null),
                    ],
                    selected: _tab,
                    onChanged: (tab) => setState(() => _tab = tab),
                  ),
                ),
              ),
              Expanded(
                child: _loadError != null
                    ? Padding(
                        padding: const EdgeInsets.all(SlSpace.page),
                        child: SlNotice(_loadError!, error: true),
                      )
                    : _loading
                    ? const Center(child: CircularProgressIndicator.adaptive())
                    : IndexedStack(
                        index: _tab,
                        children: [
                          _transcriptTab(context),
                          _DictationView(
                            sessionId: widget.sessionId,
                            lines: _lines,
                            repository: widget.repository,
                            player: _mediaPath == null ? null : player,
                            onLoop: _setLoop,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _transcriptTab(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_mediaPath == null)
          Padding(padding: const EdgeInsets.all(SlSpace.lg), child: SlNotice(l.sessionNoMedia))
        else
          _PlayerBar(
            player: player,
            playback: widget.playback,
            isVideo: _media?.kind == 'video',
            loop: _loop,
            pendingA: _pendingA,
            onSetA: () => setState(() => _pendingA = player.positionMs),
            onSetB: () {
              final a = _pendingA;
              if (a != null && player.positionMs > a + 200) {
                _setLoop((startMs: a, endMs: player.positionMs));
              }
            },
            onClearLoop: () => _setLoop(null),
          ),
        Expanded(
          child: ListenableBuilder(
            listenable: player,
            builder: (context, _) {
              final position = player.positionMs;
              return ListView.builder(
                padding: const EdgeInsets.all(SlSpace.lg),
                itemCount: _lines.length,
                itemBuilder: (context, i) {
                  final line = _lines[i];
                  final active =
                      _mediaPath != null && position >= line.startMs && position < line.endMs;
                  return _TranscriptRow(
                    line: line,
                    active: active,
                    canPlay: _mediaPath != null,
                    onTap: () => _seekTo(line.startMs),
                    onLoop: () => _setLoop(sentenceSpan(line.startMs, line.endMs)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({
    required this.player,
    required this.playback,
    required this.isVideo,
    required this.loop,
    required this.pendingA,
    required this.onSetA,
    required this.onSetB,
    required this.onClearLoop,
  });
  final MediaSession player;
  final PlaybackHub playback;
  final bool isVideo;
  final ({int startMs, int endMs})? loop;
  final int? pendingA;
  final VoidCallback onSetA, onSetB, onClearLoop;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final duration = player.durationMs <= 0 ? 1 : player.durationMs;
        final position = player.positionMs.clamp(0, duration);
        return SlPanel(
          padding: const EdgeInsets.all(SlSpace.md),
          child: Column(
            children: [
              if (isVideo)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Video(controller: player.video, controls: null),
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    tooltip: l.playerBack5,
                    onPressed: () => player.seek(player.positionMs - 5000),
                    icon: const Icon(Icons.replay_5),
                  ),
                  IconButton.filled(
                    onPressed: playback.toggleLesson,
                    icon: Icon(player.playing ? Icons.pause : Icons.play_arrow),
                  ),
                  IconButton(
                    tooltip: l.playerForward5,
                    onPressed: () => player.seek(player.positionMs + 5000),
                    icon: const Icon(Icons.forward_5),
                  ),
                  Expanded(
                    child: Slider(
                      value: position.toDouble(),
                      max: duration.toDouble(),
                      onChanged: (v) => player.seek(v.round()),
                    ),
                  ),
                  Text(
                    '${timestamp(position, '.').substring(0, 8)} / ${timestamp(duration, '.').substring(0, 8)}',
                    style: SlType.caption.copyWith(
                      color: c.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: SlSpace.md),
                  PopupMenuButton<double>(
                    tooltip: l.playerSpeed,
                    initialValue: player.rate,
                    onSelected: player.setRate,
                    itemBuilder: (context) => [
                      for (final r in const [0.6, 0.75, 0.9, 1.0, 1.25, 1.5])
                        PopupMenuItem(value: r, child: Text('$r×')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('${player.rate}×', style: SlType.body),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('player-mute'),
                    tooltip: player.volume == 0 ? l.playerUnmute : l.playerMute,
                    onPressed: player.toggleMute,
                    icon: Icon(
                      player.volume == 0
                          ? Icons.volume_off_rounded
                          : player.volume < 50
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded,
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: Semantics(
                      label: l.playerVolume,
                      child: Slider(
                        key: const ValueKey('player-volume'),
                        value: player.volume,
                        max: 100,
                        onChanged: player.setVolume,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: onSetA,
                    child: Text(
                      pendingA == null
                          ? l.playerSetA
                          : 'A ${timestamp(pendingA!, '.').substring(3, 8)}',
                    ),
                  ),
                  const SizedBox(width: SlSpace.sm),
                  OutlinedButton(
                    onPressed: pendingA == null ? null : onSetB,
                    child: Text(l.playerSetB),
                  ),
                  const SizedBox(width: SlSpace.sm),
                  if (loop != null) ...[
                    SlBadge(
                      'A–B ${timestamp(loop!.startMs, '.').substring(3, 10)} → ${timestamp(loop!.endMs, '.').substring(3, 10)}',
                      icon: Icons.repeat,
                    ),
                    TextButton(onPressed: onClearLoop, child: Text(l.playerClearLoop)),
                  ],
                ],
              ),
              if (player.error != null) SlNotice(player.error!, error: true),
            ],
          ),
        );
      },
    );
  }
}

class _TranscriptRow extends StatelessWidget {
  const _TranscriptRow({
    required this.line,
    required this.active,
    required this.canPlay,
    required this.onTap,
    required this.onLoop,
  });
  final SavedLine line;
  final bool active, canPlay;
  final VoidCallback onTap, onLoop;

  @override
  Widget build(BuildContext context) {
    final c = context.sl;
    return Material(
      color: active ? c.accentInk.withValues(alpha: .12) : Colors.transparent,
      borderRadius: BorderRadius.circular(SlRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(SlRadius.sm),
        onTap: canPlay ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SlSpace.sm, vertical: SlSpace.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  timestamp(line.startMs, '.').substring(0, 8),
                  style: SlType.caption.copyWith(
                    color: c.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.text, style: SlType.body.copyWith(color: c.text)),
                    if (line.translation != null)
                      Text(line.translation!, style: SlType.body.copyWith(color: c.inkSoft)),
                  ],
                ),
              ),
              if (canPlay)
                IconButton(
                  tooltip: context.l10n.playerLoopSentence,
                  visualDensity: VisualDensity.compact,
                  onPressed: onLoop,
                  icon: const Icon(Icons.repeat_one, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sentence-by-sentence dictation: replay the span, type, check, compare.
class _DictationView extends StatefulWidget {
  const _DictationView({
    required this.sessionId,
    required this.lines,
    required this.repository,
    required this.player,
    required this.onLoop,
  });
  final String sessionId;
  final List<SavedLine> lines;
  final LiveRepository repository;
  final MediaSession? player;
  final Future<void> Function(({int startMs, int endMs})? loop) onLoop;

  @override
  State<_DictationView> createState() => _DictationViewState();
}

class _DictationViewState extends State<_DictationView> with AutomaticKeepAliveClientMixin {
  late final List<DictationItem> _items = dictationItems(
    widget.lines.map(
      (l) => (
        segmentId: l.segmentId,
        text: l.text,
        startMs: l.startMs,
        endMs: l.endMs,
        wordsJson: l.wordsJson,
        translation: l.translation,
      ),
    ),
  );
  final _answer = TextEditingController();
  final _focus = FocusNode();
  int _index = 0;
  DictationGrade? _grade;
  bool _revealed = false;
  Map<String, String> _results = const {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.repository.dictationResults(widget.sessionId).then((r) {
        if (!mounted) return;
        setState(() {
          _results = r;
          final next = _items.indexWhere((l) => r[l.id] != 'correct');
          if (next > 0) _index = next;
        });
      }),
    );
  }

  @override
  void dispose() {
    _answer.dispose();
    _focus.dispose();
    super.dispose();
  }

  DictationItem get _line => _items[_index];

  Future<void> _play() async {
    final player = widget.player;
    if (player == null) return;
    await widget.onLoop(sentenceSpan(_line.startMs, _line.endMs));
    if (!player.playing) await player.toggle();
    _focus.requestFocus();
  }

  Future<void> _check() async {
    final answer = _answer.text;
    if (answer.trim().isEmpty) return;
    final grade = gradeDictation(answer, _line.text);
    setState(() {
      _grade = grade;
      _results = {..._results, _line.id: grade.result.name};
    });
    await widget.player?.pause();
    try {
      await widget.repository.addDictationAttempt(
        id: newId(),
        sessionId: widget.sessionId,
        segmentId: _line.id,
        answer: answer,
        result: grade.result.name,
        similarity: grade.similarity,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.liveSaveFailed('$e'))));
      }
    }
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, _items.length - 1);
    setState(() {
      _index = next;
      _grade = null;
      _revealed = false;
      _answer.clear();
    });
    unawaited(_play());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = context.l10n;
    final c = context.sl;
    if (widget.player == null) {
      return Padding(
        padding: const EdgeInsets.all(SlSpace.page),
        child: SlNotice(l.sessionNoMedia),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(l.dictationEmpty, style: SlType.body.copyWith(color: c.muted)),
      );
    }
    final done = _items.where((i) => _results[i.id] == 'correct').length;
    final grade = _grade;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _check,
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): _play,
      },
      child: ListView(
        padding: const EdgeInsets.all(SlSpace.page),
        children: [
          Row(
            children: [
              Text(
                l.dictationProgress(done, _items.length),
                style: SlType.caption.copyWith(color: c.muted),
              ),
              const Spacer(),
              Text(
                '${_index + 1} / ${_items.length}',
                style: SlType.caption.copyWith(color: c.muted),
              ),
            ],
          ),
          const SizedBox(height: SlSpace.sm),
          LinearProgressIndicator(value: _items.isEmpty ? 0 : done / _items.length),
          const SizedBox(height: SlSpace.xl),
          Text(l.dictationPrompt, style: SlType.title),
          const SizedBox(height: SlSpace.md),
          Wrap(
            spacing: SlSpace.sm,
            children: [
              FilledButton.icon(
                onPressed: _play,
                icon: const Icon(Icons.replay),
                label: Text(l.dictationPlay),
              ),
              OutlinedButton(
                onPressed: () async {
                  await widget.player!.setRate(widget.player!.rate == 0.75 ? 1 : 0.75);
                  setState(() {});
                },
                child: Text(widget.player!.rate == 0.75 ? '1×' : '0.75×'),
              ),
            ],
          ),
          const SizedBox(height: SlSpace.lg),
          TextField(
            controller: _answer,
            focusNode: _focus,
            minLines: 2,
            maxLines: 4,
            autofocus: true,
            decoration: InputDecoration(hintText: l.dictationHint),
            onSubmitted: (_) => _check(),
          ),
          const SizedBox(height: SlSpace.md),
          Row(
            children: [
              OutlinedButton(
                onPressed: _index == 0 ? null : () => _go(-1),
                child: Text(l.dictationPrevious),
              ),
              const SizedBox(width: SlSpace.sm),
              FilledButton(onPressed: _check, child: Text(l.dictationCheck)),
              const SizedBox(width: SlSpace.sm),
              TextButton(
                onPressed: () => setState(() => _revealed = true),
                child: Text(l.dictationReveal),
              ),
              const Spacer(),
              FilledButton.tonal(
                onPressed: _index >= _items.length - 1 ? null : () => _go(1),
                child: Text(l.dictationNext),
              ),
            ],
          ),
          if (grade != null) ...[
            const SizedBox(height: SlSpace.lg),
            SlBadge(switch (grade.result) {
              DictationResult.correct => l.dictationCorrect,
              DictationResult.close => l.dictationClose,
              DictationResult.incorrect => l.dictationIncorrect,
            }, warning: grade.result == DictationResult.incorrect),
            const SizedBox(height: SlSpace.md),
            _DiffView(grade: grade),
          ],
          if (grade != null || _revealed) ...[
            const SizedBox(height: SlSpace.lg),
            SelectableText(_line.text, style: SlType.body.copyWith(color: c.text)),
            if (_line.context != null)
              SelectableText(_line.context!, style: SlType.body.copyWith(color: c.accentInk)),
          ],
        ],
      ),
    );
  }
}

class _DiffView extends StatelessWidget {
  const _DiffView({required this.grade});
  final DictationGrade grade;
  @override
  Widget build(BuildContext context) {
    final c = context.sl;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final w in grade.words)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: switch (w.mark) {
                WordMark.matched => c.accentInk.withValues(alpha: .14),
                WordMark.missed => c.warning.withValues(alpha: .18),
                WordMark.extra => Colors.transparent,
              },
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              w.text,
              style: SlType.body.copyWith(
                color: w.mark == WordMark.extra ? c.muted : c.text,
                decoration: w.mark == WordMark.extra ? TextDecoration.lineThrough : null,
                fontWeight: w.mark == WordMark.missed ? FontWeight.w700 : null,
              ),
            ),
          ),
      ],
    );
  }
}
