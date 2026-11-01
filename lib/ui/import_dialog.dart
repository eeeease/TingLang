import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:tinglang_ui/tinglang_ui.dart';

import '../core/course_codec.dart';
import '../core/models.dart';
import '../services/app_controller.dart';
import '../services/link_import.dart';
import 'brand.dart';
import 'errors.dart';
import 'file_picking.dart';

/// [onTranscribe] receives a media file chosen without a course or
/// subtitles; it is transcribed into a session instead of an empty course.
Future<void> showImportDialog(
  BuildContext context,
  AppController app, {
  required Future<void> Function(File media) onTranscribe,
  LinkImportService? links,
  VoidCallback? onLinkImported,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => ImportDialog(
    app: app,
    onTranscribe: onTranscribe,
    links: links,
    onLinkImported: onLinkImported,
  ),
);

class ImportDialog extends StatefulWidget {
  const ImportDialog({
    super.key,
    required this.app,
    required this.onTranscribe,
    this.links,
    this.onLinkImported,
  });
  final AppController app;
  final Future<void> Function(File media) onTranscribe;

  /// Video links (YouTube and other sites); null hides the field.
  final LinkImportService? links;

  /// A link's audio is being transcribed (show where the progress is).
  final VoidCallback? onLinkImported;
  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  Area _area = Area.life;
  String? _media, _subtitles, _error;
  bool _busy = false;
  final _title = TextEditingController();
  final _link = TextEditingController();

  /// What the link import is doing ("Downloading yt-dlp…"), while busy.
  String? _linkStage;
  @override
  void dispose() {
    _title.dispose();
    _link.dispose();
    super.dispose();
  }

  /// yt-dlp first (once, after the user agreed to its size), then the page,
  /// then its audio; the transcript and a Basic course follow under History.
  Future<void> _importLink() async {
    final l = context.l10n;
    final links = widget.links!;
    final url = _link.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!links.installed) {
        setState(() => _linkStage = l.linkCheckingTool);
        final offer = await links.offer();
        if (!mounted) return;
        final agreed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.linkToolTitle),
            content: SizedBox(
              width: 440,
              child: Text(l.linkToolBody('${(offer.bytes / 1e6).round()} MB', offer.version)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
              FilledButton(
                key: const ValueKey('link-tool-agree'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.linkToolDownload('${(offer.bytes / 1e6).round()} MB')),
              ),
            ],
          ),
        );
        if (agreed != true || !mounted) return;
        setState(() => _linkStage = l.linkDownloadingTool);
        await links.install(offer);
      }
      if (!mounted) return;
      setState(() => _linkStage = l.linkReading);
      final info = await links.inspect(url);
      if (!mounted) return;
      setState(() => _linkStage = l.linkDownloadingAudio(info.title));
      await links.import(info);
      widget.onLinkImported?.call();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(l, error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _linkStage = null;
        });
      }
    }
  }

  Widget _linkSection(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    final links = widget.links!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.linkTitle, style: SlType.label.copyWith(color: c.text)),
        const SizedBox(height: SlSpace.xs),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('link-field'),
                controller: _link,
                enabled: !_busy,
                decoration: InputDecoration(hintText: l.linkHint, isDense: true),
                onSubmitted: (_) => _importLink(),
              ),
            ),
            const SizedBox(width: SlSpace.sm),
            FilledButton.tonal(
              key: const ValueKey('link-import'),
              onPressed: _busy ? null : _importLink,
              child: Text(l.linkImport),
            ),
          ],
        ),
        const SizedBox(height: SlSpace.xs),
        Text(l.linkNote, style: SlType.caption.copyWith(color: c.muted)),
        if (_linkStage != null) ...[
          const SizedBox(height: SlSpace.sm),
          ListenableBuilder(
            listenable: links,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_linkStage!, style: SlType.caption.copyWith(color: c.inkSoft)),
                const SizedBox(height: SlSpace.xs),
                LinearProgressIndicator(value: links.progress, minHeight: 3),
              ],
            ),
          ),
        ],
        const SizedBox(height: SlSpace.lg),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SlSpace.sm),
              child: Text(l.linkOrFile, style: SlType.caption.copyWith(color: c.muted)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: SlSpace.md),
      ],
    );
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
                if (widget.links != null) _linkSection(context),
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
                if (_busy && _linkStage == null)
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
