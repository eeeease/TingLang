import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang_ui/tinglang_ui.dart';

import '../core/course_codec.dart' hide normalizeAnswer;
import '../core/dictation.dart';
import '../core/models.dart';
import '../services/app_controller.dart';
import '../services/playback_hub.dart';
import '../services/recording_service.dart';
import 'brand.dart';
import 'file_picking.dart';
import 'practice_panel.dart';
import 'quiz_view.dart';
import 'share_import.dart';
import 'youtube_player.dart';

class LearnPage extends StatefulWidget {
  const LearnPage({
    super.key,
    required this.app,
    required this.course,
    required this.clipId,
    required this.playback,
    required this.recorder,
    required this.onClip,
    required this.onBack,
  });
  final AppController app;
  final Course course;
  final String clipId;
  final PlaybackHub playback;
  final RecordingService recorder;
  final void Function(String) onClip;
  final VoidCallback onBack;
  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  int _tab = 0;
  bool _showTranscript = false, _showAnswers = false, _checked = false;
  final Map<String, String> _answers = {};
  YouTubeClipController? _youtube;
  CourseClip get clip => widget.course.clips.firstWhere(
    (c) => c.id == widget.clipId,
    orElse: () => widget.course.clips.first,
  );
  bool get locked => widget.recorder.navigationLocked || widget.app.pendingAttempt != null;

  @override
  void initState() {
    super.initState();
    final done = widget.app.done(widget.course, clip);
    final next = learningSteps.indexWhere((step) => !done.contains(step));
    _tab = next < 0 ? 0 : next;
    final videoId = widget.course.youtubeId;
    if (widget.course.mediaPath == null && videoId != null) {
      _youtube = YouTubeClipController(videoId: videoId, startMs: clip.startMs, endMs: clip.endMs);
    }
    _openMedia();
  }

  @override
  void dispose() {
    _youtube?.dispose();
    super.dispose();
  }

  Widget _youtubePlayer(YouTubeClipController yt) {
    final l = context.l10n;
    final c = context.sl;
    return SlPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: YouTubeClipPlayer(controller: yt),
          ),
          ListenableBuilder(
            listenable: yt,
            builder: (context, _) {
              final end = clip.endMs ?? clip.startMs + 1;
              final pos = yt.positionMs.clamp(clip.startMs, end);
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (yt.errorCode != null)
                      Row(
                        children: [
                          Expanded(child: SlNotice(l.youtubeBlocked(yt.errorCode!), error: true)),
                          TextButton(
                            onPressed: () => Process.run('open', [
                              'https://www.youtube.com/watch?v=${yt.videoId}&t=${clip.startMs ~/ 1000}s',
                            ]),
                            child: Text(l.openOnYouTube),
                          ),
                        ],
                      ),
                    Slider(
                      min: clip.startMs.toDouble(),
                      max: end.toDouble(),
                      value: pos.toDouble(),
                      onChanged: yt.ready ? (v) => yt.seek(v.round()) : null,
                    ),
                    Row(
                      children: [
                        Text(
                          '${timeLabel(yt.positionMs)} · ${l.clipRange(timeLabel(clip.startMs), clip.endMs == null ? l.clipEnd : timeLabel(clip.endMs!))}',
                          style: SlType.micro.copyWith(color: c.muted),
                        ),
                        const Spacer(),
                        Text('YouTube', style: SlType.micro.copyWith(color: c.muted)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: yt.ready ? yt.toggle : null,
                          icon: Icon(yt.playing ? Icons.pause : Icons.play_arrow),
                          label: Text(yt.playing ? l.pause : l.playClip),
                        ),
                        IconButton(
                          tooltip: l.backToClipStart,
                          onPressed: yt.ready ? () => yt.seek(clip.startMs) : null,
                          icon: const Icon(Icons.replay_rounded),
                        ),
                        FilterChip(
                          label: Text(l.abLoop),
                          selected: yt.loop,
                          onSelected: yt.setLoop,
                        ),
                        DropdownButton<double>(
                          value: yt.rate,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final rate in [.75, 1.0, 1.25, 1.5])
                              DropdownMenuItem(value: rate, child: Text('${rate}x')),
                          ],
                          onChanged: (v) {
                            if (v != null) yt.setRate(v);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(covariant LearnPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.course.mediaPath != widget.course.mediaPath) _openMedia();
  }

  void _openMedia() {
    final relative = widget.course.mediaPath;
    if (relative != null) {
      unawaited(
        widget.playback.lesson.open(widget.app.store.resolve(relative), clip.startMs, clip.endMs),
      );
    }
  }

  Future<void> _attach() => reportAction(context, () async {
    final path = await pickFile(mediaExtensions);
    if (path != null) await widget.app.attachMedia(widget.course, File(path));
  });

  Widget _player() {
    final l = context.l10n;
    final c = context.sl;
    final youtube = _youtube;
    if (youtube != null) return _youtubePlayer(youtube);
    if (widget.course.mediaPath == null) {
      return SlPanel(
        child: Column(
          children: [
            Icon(Icons.video_file_outlined, color: c.accentInk, size: 50),
            const SizedBox(height: 18),
            Text(l.attachMediaPrompt),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: locked ? null : _attach,
              icon: const Icon(Icons.attach_file),
              label: Text(l.attachMedia),
            ),
          ],
        ),
      );
    }
    final session = widget.playback.lesson;
    final ext = p.extension(widget.course.mediaPath ?? '').toLowerCase();
    final video = {'.mp4', '.mov', '.m4v', '.mkv', '.webm'}.contains(ext);
    return SlPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: video
                ? Video(controller: session.video, controls: null)
                : Container(
                    color: c.raised,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.graphic_eq, size: 65, color: c.accentInk),
                        const SizedBox(height: 16),
                        Text(
                          clip.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
          ),
          AnimatedBuilder(
            animation: session,
            builder: (context, _) {
              final end = session.effectiveEnd;
              final valid = end > clip.startMs;
              final value = valid ? session.positionMs.clamp(clip.startMs, end).toDouble() : 0.0;
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (session.loading) const LinearProgressIndicator(),
                    if (session.error != null)
                      SlNotice(
                        session.boundsMismatch ? l.mediaBoundsMismatch : session.error!,
                        error: true,
                      ),
                    Slider(
                      min: valid ? clip.startMs.toDouble() : 0,
                      max: valid ? end.toDouble() : 1,
                      value: value,
                      onChanged: !valid || locked ? null : (value) => session.seek(value.round()),
                    ),
                    Row(
                      children: [
                        Text(
                          '${timeLabel(session.positionMs)} / ${timeLabel(end)}',
                          style: SlType.micro.copyWith(color: c.muted),
                        ),
                        const Spacer(),
                        Text(
                          l.clipRange(
                            timeLabel(clip.startMs),
                            clip.endMs == null ? l.clipEnd : timeLabel(clip.endMs!),
                          ),
                          style: SlType.micro.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: locked || !session.ready
                              ? null
                              : () => reportAction(context, widget.playback.toggleLesson),
                          icon: Icon(session.playing ? Icons.pause : Icons.play_arrow),
                          label: Text(session.playing ? l.pause : l.playClip),
                        ),
                        IconButton(
                          tooltip: l.backToClipStart,
                          onPressed: locked ? null : () => session.seek(clip.startMs),
                          icon: const Icon(Icons.replay_rounded),
                        ),
                        FilterChip(
                          label: Text(l.abLoop),
                          selected: session.loop,
                          onSelected: locked ? null : session.setLoop,
                        ),
                        DropdownButton<double>(
                          value: session.rate,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final rate in [.75, 1.0, 1.25, 1.5])
                              DropdownMenuItem(value: rate, child: Text('${rate}x')),
                          ],
                          onChanged: locked
                              ? null
                              : (value) {
                                  if (value != null) session.setRate(value);
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _transcript() {
    final l = context.l10n;
    final c = context.sl;
    return SlPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(l.transcript),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _showTranscript = !_showTranscript),
                icon: Icon(
                  _showTranscript ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 16,
                ),
                label: Text(_showTranscript ? l.hideTranscript : l.showTranscript),
              ),
            ],
          ),
          if (_showTranscript) ...[
            if (clip.transcript.isEmpty) Text(l.noSubtitles, style: TextStyle(color: c.muted)),
            if (clip.sentences.isEmpty)
              SelectableText(clip.transcript, style: const TextStyle(fontSize: 16, height: 1.7))
            else
              AnimatedBuilder(
                animation: widget.playback.lesson,
                builder: (context, _) => Column(
                  children: [
                    for (final cue in clip.sentences)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onTap: locked || widget.course.mediaPath == null
                            ? null
                            : () => widget.playback.lesson.seek(cue.startTime.inMilliseconds),
                        leading: Text(
                          timeLabel(cue.startTime.inMilliseconds),
                          style: SlType.micro.copyWith(color: c.muted),
                        ),
                        title: Text(
                          cue.text,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                cue.contains(
                                  Duration(milliseconds: widget.playback.lesson.positionMs),
                                )
                                ? c.accentInk
                                : c.text,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ] else
            Text(l.listenFirst, style: TextStyle(color: c.muted)),
        ],
      ),
    );
  }

  Widget _learningItems(String kind) {
    final l = context.l10n;
    final c = context.sl;
    final items = clip.items.where((item) => item.kind == kind).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          kind == 'words'
              ? l.wordsTitle
              : kind == 'phrases'
              ? l.phrasesTitle
              : l.sentencesTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (items.isEmpty) SlNotice(l.noItems),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SlPanel(
              color: c.canvas,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SelectableText(
                          item.text,
                          style: TextStyle(
                            fontSize: 20,
                            color: c.accentInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l.saveToReview,
                        onPressed: () => reportAction(
                          context,
                          () => widget.app.saveExpression(
                            widget.course,
                            clip,
                            item.text,
                            item.meaning,
                          ),
                          success: l.savedToReview,
                        ),
                        icon: Icon(
                          widget.app.isSaved(widget.course, clip, item.text)
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  if (item.cefr.isNotEmpty || item.subtype.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        children: [
                          if (item.cefr.isNotEmpty) SlBadge(item.cefr),
                          if (item.subtype.isNotEmpty) SlBadge(item.subtype.replaceAll('_', ' ')),
                        ],
                      ),
                    ),
                  if (item.meaning.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Text(item.meaning)),
                  if (item.whyUseful.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(item.whyUseful, style: TextStyle(color: c.muted, fontSize: 13)),
                    ),
                  if (item.patterns.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        item.patterns.join('  ·  '),
                        style: TextStyle(color: c.accentInk, fontSize: 13),
                      ),
                    ),
                  if (item.explanation.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(item.explanation, style: TextStyle(color: c.muted)),
                    ),
                  if (item.original.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        l.inThisScene(item.original),
                        style: TextStyle(color: c.muted, fontSize: 13),
                      ),
                    ),
                  if (item.example.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        l.makeItYours(item.example),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  if (item.frame.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(l.frameLabel(item.frame), style: TextStyle(color: c.accentInk)),
                    ),
                  if (item.memory.isNotEmpty || item.memoryNote.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: SlNotice(
                        [item.memory, item.memoryNote].where((t) => t.isNotEmpty).join('\n'),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Blank colours by type: word, phrase, sentence (as in the English V3 course player).
  Color _blankColor(String type) => switch (type) {
    'phrase' => const Color(0xFF5B8DEF),
    'sentence' => const Color(0xFFA06CD5),
    _ => const Color(0xFFE0675B),
  };

  DictationResult _gradeBlank(ListeningBlank blank) =>
      gradeDictation(_answers[blank.id] ?? '', blank.answer).result;

  Future<void> _checkBlind() async {
    setState(() => _checked = true);
    final allCorrect = clip.blanks.every((b) => _gradeBlank(b) == DictationResult.correct);
    if (allCorrect && clip.blanks.isNotEmpty) {
      await widget.app.setDone(widget.course, clip, 'blind', true);
    }
  }

  Future<void> _addMissedBlanks() async {
    for (final blank in clip.blanks.where((b) => _gradeBlank(b) != DictationResult.correct)) {
      final item = clip.items.where((i) => i.id == blank.itemId).firstOrNull;
      await widget.app.saveExpression(
        widget.course,
        clip,
        item?.text ?? blank.answer,
        item?.meaning ?? '',
      );
    }
  }

  Widget _blind() {
    final l = context.l10n;
    final c = context.sl;
    final pieces = clip.blindTemplate.split(RegExp(r'(\{\{[^}]+\}\})'));
    final tokens = RegExp(r'\{\{([^}]+)\}\}').allMatches(clip.blindTemplate).toList();
    final byId = {for (final b in clip.blanks) b.id: b};
    final correct = _checked
        ? clip.blanks.where((b) => _gradeBlank(b) == DictationResult.correct).length
        : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.blindTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(l.blindInlineHint, style: SlType.caption.copyWith(color: c.muted)),
        const SizedBox(height: 12),
        if (clip.blanks.isEmpty)
          SlNotice(l.noBlanks)
        else ...[
          Text.rich(
            TextSpan(
              children: [
                for (var i = 0; i < pieces.length; i++) ...[
                  TextSpan(text: pieces[i]),
                  if (i < tokens.length && byId[tokens[i].group(1)] != null)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: _BlankField(
                        key: ValueKey(tokens[i].group(1)),
                        blank: byId[tokens[i].group(1)]!,
                        color: _blankColor(byId[tokens[i].group(1)]!.type),
                        initial: _answers[tokens[i].group(1)] ?? '',
                        result: _checked ? _gradeBlank(byId[tokens[i].group(1)]!) : null,
                        reveal: _showAnswers,
                        onChanged: (text) => setState(() {
                          _answers[tokens[i].group(1)!] = text;
                          _checked = false;
                        }),
                      ),
                    ),
                ],
              ],
            ),
            style: const TextStyle(fontSize: 16, height: 2.2),
          ),
          const SizedBox(height: 18),
          if (_checked)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                correct == clip.blanks.length
                    ? l.blindAllCorrect
                    : l.blindScore(correct, clip.blanks.length),
                style: TextStyle(color: correct == clip.blanks.length ? c.accentInk : c.text),
              ),
            ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(onPressed: _checkBlind, child: Text(l.checkAnswers)),
              TextButton(
                onPressed: () => setState(() => _showAnswers = !_showAnswers),
                child: Text(_showAnswers ? l.hideAnswers : l.showAnswers),
              ),
              if (_checked && correct < clip.blanks.length)
                OutlinedButton(
                  onPressed: () =>
                      reportAction(context, _addMissedBlanks, success: l.addedToReview),
                  child: Text(l.blindAddMissed),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _practice(bool shadow) {
    final l = context.l10n;
    final c = context.sl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(shadow ? l.shadowTitle : l.retellTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (shadow) ...[
          if (clip.transcript.isEmpty)
            Text(l.shadowFallback)
          else
            SelectableText.rich(
              TextSpan(children: _highlightPassages(clip.transcript, clip.shadowing, c)),
              style: const TextStyle(fontSize: 16, height: 1.8),
            ),
          if (clip.shadowPassages.any((p) => p.reason.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Text(l.focusOn, style: SlType.label.copyWith(color: c.text)),
            for (final passage in clip.shadowPassages.where((p) => p.reason.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l.shadowReason(passage.reason),
                  style: TextStyle(color: c.muted, fontSize: 13),
                ),
              ),
          ],
        ] else ...[
          Text(clip.retellPrompt, style: const TextStyle(fontSize: 17, height: 1.6)),
          if (clip.outline.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(l.needHint),
              children: [
                for (final point in clip.outline)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.subdirectory_arrow_right, size: 16),
                    title: Text(point),
                  ),
              ],
            ),
          if (clip.targetItemIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(l.retellTryToUse, style: SlType.label.copyWith(color: c.accentInk)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in clip.targetItemIds)
                  for (final item in clip.items.where((i) => i.id == id)) SlBadge(item.text),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SlNotice(clip.followUp),
        ],
        const SizedBox(height: 20),
        PracticePanel(
          key: ValueKey('${clip.id}-${shadow ? "shadowing" : "retelling"}'),
          app: widget.app,
          recorder: widget.recorder,
          playback: widget.playback,
          kind: shadow ? 'shadowing' : 'retelling',
          courseId: widget.course.id,
          clipId: clip.id,
        ),
      ],
    );
  }

  Widget _workbench() {
    final l = context.l10n;
    final done = widget.app.done(widget.course, clip);
    final labels = [
      l.stepWords,
      l.stepPhrases,
      l.stepSentences,
      l.stepBlind,
      l.stepShadow,
      l.stepRetell,
      l.stepQuiz,
    ];
    return SlPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              for (var i = 0; i < learningSteps.length; i++)
                ChoiceChip(
                  showCheckmark: false,
                  label: Text(labels[i]),
                  avatar: done.contains(learningSteps[i])
                      ? const Icon(Icons.check, size: 14)
                      : null,
                  selected: _tab == i,
                  onSelected: locked ? null : (_) => setState(() => _tab = i),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (_tab <= 2)
            _learningItems(learningSteps[_tab])
          else if (_tab == 3)
            _blind()
          else if (_tab == 6)
            QuizView(app: widget.app, course: widget.course, clip: clip)
          else
            _practice(_tab == 4),
          const SizedBox(height: 24),
          const Divider(),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.stepDone),
            value: done.contains(learningSteps[_tab]),
            onChanged: locked
                ? null
                : (value) => reportAction(
                    context,
                    () => widget.app.setDone(
                      widget.course,
                      clip,
                      learningSteps[_tab],
                      value ?? false,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListView(
      // The top 28 pt belong to the transparent title bar (window dragging).
      padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: locked ? null : widget.onBack,
              tooltip: l.backToLibrary,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.course.title, style: Theme.of(context).textTheme.titleLarge),
            ),
            TextButton(onPressed: locked ? null : _attach, child: Text(l.changeMedia)),
            IconButton(
              tooltip: l.exportShared,
              onPressed: locked
                  ? null
                  : () =>
                        exportCourseShare(context, course: widget.course, store: widget.app.store),
              icon: const Icon(Icons.ios_share_outlined, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(widget.course.sourceLabel, style: SlType.micro.copyWith(color: context.sl.muted)),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < widget.course.clips.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    showCheckmark: false,
                    label: Text('${i + 1}. ${widget.course.clips[i].title}'),
                    selected: widget.course.clips[i].id == clip.id,
                    onSelected: locked ? null : (_) => widget.onClip(widget.course.clips[i].id),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, c) {
            final left = Column(children: [_player(), const SizedBox(height: 18), _transcript()]);
            if (c.maxWidth < 900) {
              return Column(children: [left, const SizedBox(height: 22), _workbench()]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: left),
                const SizedBox(width: 22),
                Expanded(flex: 5, child: _workbench()),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Source text with the shadowing passages emphasised and the rest dimmed.
List<TextSpan> _highlightPassages(String text, List<String> passages, TinglangColors c) {
  final lower = text.toLowerCase();
  final ranges = <(int, int)>[];
  for (final passage in passages) {
    final at = lower.indexOf(passage.toLowerCase().trim());
    if (at >= 0) ranges.add((at, at + passage.trim().length));
  }
  ranges.sort((a, b) => a.$1.compareTo(b.$1));
  final spans = <TextSpan>[];
  var cursor = 0;
  for (final (start, end) in ranges) {
    if (start < cursor) continue;
    spans.add(
      TextSpan(
        text: text.substring(cursor, start),
        style: TextStyle(color: c.muted),
      ),
    );
    spans.add(
      TextSpan(
        text: text.substring(start, end),
        style: TextStyle(color: c.accentInk, fontWeight: FontWeight.w700),
      ),
    );
    cursor = end;
  }
  spans.add(
    TextSpan(
      text: text.substring(cursor),
      style: TextStyle(color: ranges.isEmpty ? c.text : c.muted),
    ),
  );
  return spans;
}

/// An inline blank: an underlined field in the blank's colour, then the
/// answer marked correct / close / incorrect after checking.
class _BlankField extends StatelessWidget {
  const _BlankField({
    super.key,
    required this.blank,
    required this.color,
    required this.initial,
    required this.result,
    required this.reveal,
    required this.onChanged,
  });
  final ListeningBlank blank;
  final Color color;
  final String initial;
  final DictationResult? result;
  final bool reveal;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.sl;
    final width = (blank.answer.length * 9.0 + 24).clamp(
      60.0,
      blank.type == 'sentence' ? 520.0 : 260.0,
    );
    final mark = switch (result) {
      DictationResult.correct => c.accentInk,
      DictationResult.close => const Color(0xFFE0A030),
      DictationResult.incorrect => c.warning,
      null => color,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: width,
            child: TextFormField(
              initialValue: initial,
              onChanged: onChanged,
              style: TextStyle(color: mark, fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: color, width: 2)),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: color, width: 2.5),
                ),
                filled: false,
              ),
            ),
          ),
          if (reveal || (result != null && result != DictationResult.correct))
            Text(blank.answer, style: TextStyle(color: c.accentInk, fontSize: 12)),
        ],
      ),
    );
  }
}
