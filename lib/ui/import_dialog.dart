import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang_ui/tinglang_ui.dart';

import '../core/course_codec.dart';
import '../core/models.dart';
import '../services/app_controller.dart';
import 'brand.dart';
import 'errors.dart';
import 'file_picking.dart';

/// [onTranscribe] receives a media file chosen without a course or
/// subtitles; it is transcribed into a session instead of an empty course.
Future<void> showImportDialog(
  BuildContext context,
  AppController app, {
  required Future<void> Function(File media) onTranscribe,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => ImportDialog(app: app, onTranscribe: onTranscribe),
);

class ImportDialog extends StatefulWidget {
  const ImportDialog({super.key, required this.app, required this.onTranscribe});
  final AppController app;
  final Future<void> Function(File media) onTranscribe;
  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  Area _area = Area.life;
  String? _media, _subtitles, _error;
  bool _busy = false;
  final _title = TextEditingController();
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pick(String kind) async {
    try {
      final file = await pickFile(kind == 'media' ? mediaExtensions : ['srt', 'vtt']);
      if (!mounted || file == null) return;
      setState(() {
        if (kind == 'media') {
          _media = file;
          if (_title.text.isEmpty) _title.text = p.basenameWithoutExtension(file);
        } else {
          _subtitles = file;
        }
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = describeError(context.l10n, error));
    }
  }

  bool get _transcribes => _media != null && _subtitles == null;

  Future<void> _import() async {
    final l = context.l10n;
    if (_media == null) {
      setState(() => _error = l.importNeedMedia);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final media = _media;
      if (_transcribes && media != null) {
        await widget.onTranscribe(File(media));
        if (mounted) Navigator.pop(context);
        return;
      }
      const codec = CourseCodec();
      final relative = await widget.app.store.importMedia(File(media!));
      final subtitlesPath = _subtitles;
      final cues = subtitlesPath == null
          ? null
          : parseSubtitles(await File(subtitlesPath).readAsString());
      final raw = courseForMedia(
        id: 'local-${p.basenameWithoutExtension(relative)}',
        title: _title.text.trim().isEmpty ? l.untitledScene : _title.text.trim(),
        cues: cues ?? [],
      );
      final Course imported = codec.fromMap(raw, area: _area, mediaPath: relative);
      final exists = widget.app.state.courses.any((c) => c.id == imported.id);
      if (exists && mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.updateCourseTitle),
            content: Text(l.updateCourseBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.updateContent),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
      await widget.app.upsertCourse(imported);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(l, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _fileButton(String kind, String label, String? value, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: OutlinedButton.icon(
      onPressed: _busy ? null : () => _pick(kind),
      icon: Icon(icon),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(value == null ? label : p.basename(value), overflow: TextOverflow.ellipsis),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(l.importTitle),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.importSubtitle, style: TextStyle(color: context.sl.muted)),
                const SizedBox(height: 20),
                DropdownButtonFormField<Area>(
                  initialValue: _area,
                  decoration: InputDecoration(labelText: l.importAreaLabel),
                  items: [
                    for (final area in Area.values)
                      DropdownMenuItem(value: area, child: Text(Brand.areaLabel(l, area))),
                  ],
                  onChanged: _busy
                      ? null
                      : (area) {
                          if (area != null) setState(() => _area = area);
                        },
                ),
                const SizedBox(height: 16),
                _fileButton('media', l.pickMedia, _media, Icons.video_file_outlined),
                _fileButton('subtitles', l.pickSubtitles, _subtitles, Icons.subtitles_outlined),
                TextField(
                  controller: _title,
                  enabled: !_busy,
                  decoration: InputDecoration(labelText: l.courseNameLabel),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SlNotice(_error!, error: true),
                  ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l.cancel)),
          FilledButton(
            onPressed: _busy ? null : _import,
            child: Text(
              _busy
                  ? l.importing
                  : _transcribes
                  ? l.importAndTranscribe
                  : l.importToLibrary,
            ),
          ),
        ],
      ),
    );
  }
}
