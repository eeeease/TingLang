import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import '../core/course_codec.dart';
import '../core/library_store.dart';
import '../core/models.dart';
import '../services/app_controller.dart';
import '../services/playback_hub.dart';
import '../services/recording_service.dart';
import 'brand.dart';

class PracticePanel extends StatefulWidget {
  const PracticePanel({
    super.key,
    required this.app,
    required this.recorder,
    required this.playback,
    required this.kind,
    this.courseId,
    this.clipId,
    this.showAllHistory = false,
  });
  final AppController app;
  final RecordingService recorder;
  final PlaybackHub playback;
  final String kind;
  final String? courseId, clipId;
  final bool showAllHistory;
  @override
  State<PracticePanel> createState() => _PracticePanelState();
}

class _PracticePanelState extends State<PracticePanel> {
  late final TextEditingController _note;
  bool _saving = false, _draftSaved = true;
  int _draftToken = 0;
  String get _key => widget.app.draftKey(widget.courseId, widget.clipId, widget.kind);
  @override
  void initState() {
    super.initState();
    _note = TextEditingController(
      text: widget.app.draft(widget.courseId, widget.clipId, widget.kind),
    );
  }

  void _noteChanged(String text) {
    final token = ++_draftToken;
    setState(() => _draftSaved = false);
    unawaited(() async {
      try {
        await widget.app.saveDraft(widget.courseId, widget.clipId, widget.kind, text);
        if (mounted && token == _draftToken) setState(() => _draftSaved = true);
      } catch (_) {
        /* AppController exposes the persistence error in the shell. */
      }
    }());
  }

  @override
  void dispose() {
    final text = _note.text;
    if (!_draftSaved) {
      unawaited(
        widget.app
            .saveDraft(widget.courseId, widget.clipId, widget.kind, text)
            .catchError((Object _) {}),
      );
    }
    _note.dispose();
    super.dispose();
  }

  Future<void> _start() => reportAction(context, () async {
    await widget.recorder.start(_key, beforeStart: widget.playback.pauseAll);
  });
  Future<void> _save({required bool stopRecording}) async {
    final l = context.l10n;
    setState(() => _saving = true);
    await reportAction(context, () async {
      final result = stopRecording ? await widget.recorder.stop() : null;
      if (result == null && _note.text.trim().isEmpty) {
        throw StateError(l.practiceEmpty);
      }
      await widget.app.saveAttempt(
        PracticeAttempt(
          id: newId(),
          createdAt: DateTime.now().toUtc(),
          kind: widget.kind,
          note: _note.text,
          durationMs: result?.durationMs ?? 0,
          courseId: widget.courseId,
          clipId: widget.clipId,
          recordingPath: result?.path,
        ),
      );
    }, success: l.practiceSaved);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.recorder,
    builder: (context, _) {
      final l = context.l10n;
      final c = context.sl;
      final ownRecording = widget.recorder.recording && widget.recorder.activeKey == _key;
      final busy = _saving || widget.recorder.busy || widget.app.pendingAttempt != null;
      final attempts = widget.app.state.attempts
          .where(
            (a) =>
                widget.showAllHistory ||
                (a.courseId == widget.courseId &&
                    a.clipId == widget.clipId &&
                    a.kind == widget.kind),
          )
          .toList()
          .reversed
          .take(12)
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _note,
            onChanged: _noteChanged,
            minLines: 4,
            maxLines: 10,
            decoration: InputDecoration(hintText: l.practiceHint),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _draftSaved ? l.draftSaved : l.draftSaving,
              style: SlType.micro.copyWith(color: c.muted),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : ownRecording
                    ? () => _save(stopRecording: true)
                    : widget.recorder.navigationLocked
                    ? null
                    : _start,
                icon: Icon(ownRecording ? Icons.stop_rounded : Icons.mic_none),
                label: Text(
                  ownRecording
                      ? l.stopAndSave(timeLabel(widget.recorder.elapsedMs))
                      : l.recordYourself,
                ),
              ),
              OutlinedButton.icon(
                onPressed: busy || widget.recorder.recording
                    ? null
                    : () => _save(stopRecording: false),
                icon: const Icon(Icons.edit_note),
                label: Text(l.saveTextOnly),
              ),
              if (ownRecording)
                Text(l.recordingBadge, style: SlType.micro.copyWith(color: c.warning)),
            ],
          ),
          const SizedBox(height: 16),
          Text(l.practiceNotice, style: SlType.caption.copyWith(color: c.muted)),
          if (attempts.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              widget.showAllHistory ? l.recentPractice : l.clipPractice,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            for (final attempt in attempts)
              AttemptTile(
                attempt: attempt,
                app: widget.app,
                playback: widget.playback,
                disabled: widget.recorder.navigationLocked,
              ),
          ],
        ],
      );
    },
  );
}

class AttemptTile extends StatelessWidget {
  const AttemptTile({
    super.key,
    required this.attempt,
    required this.app,
    required this.playback,
    this.disabled = false,
  });
  final PracticeAttempt attempt;
  final AppController app;
  final PlaybackHub playback;
  final bool disabled;
  @override
  Widget build(BuildContext context) {
    final c = context.sl;
    final l = context.l10n;
    final relative = attempt.recordingPath;
    final date = attempt.createdAt.toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SlPanel(
        padding: const EdgeInsets.all(12),
        color: c.canvas,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${DateFormat.yMMMd(l.localeName).add_Hm().format(date)} · '
                    '${switch (attempt.kind) {
                      'shadowing' => l.stepShadow,
                      'retelling' => l.stepRetell,
                      _ => l.tabSpeak,
                    }}',
                    style: SlType.micro.copyWith(color: c.muted),
                  ),
                ),
                if (relative != null)
                  AnimatedBuilder(
                    animation: playback.voice,
                    builder: (context, _) {
                      final selected = playback.voicePath == app.store.resolve(relative);
                      return IconButton(
                        tooltip: context.l10n.playRecording,
                        onPressed: disabled
                            ? null
                            : () => reportAction(
                                context,
                                () => playback.playVoice(app.store.resolve(relative)),
                              ),
                        icon: Icon(
                          selected && playback.voice.playing
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                          color: c.accentInk,
                        ),
                      );
                    },
                  ),
                if (relative != null)
                  Text(timeLabel(attempt.durationMs), style: SlType.micro.copyWith(color: c.muted)),
              ],
            ),
            if (attempt.note.isNotEmpty)
              SelectableText(attempt.note, style: const TextStyle(fontSize: 13)),
            if (relative != null)
              AnimatedBuilder(
                animation: playback.voice,
                builder: (context, _) {
                  if (playback.voicePath != app.store.resolve(relative) ||
                      playback.voice.error == null) {
                    return const SizedBox.shrink();
                  }
                  return SlNotice(playback.voice.error!, error: true);
                },
              ),
          ],
        ),
      ),
    );
  }
}
