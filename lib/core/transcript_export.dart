// Portions adapted from SubFlow TranscriptExporter (SessionStore.swift)
// Copyright (c) 2025 Jinsong Zhou, MIT License; modified 2026.
import 'live_repository.dart';

enum TranscriptFormat { txt, srt, vtt }

enum TranscriptLanguage { bilingual, source, translation }

/// Renders saved live lines. Times are relative to the start of capture (not
/// to any video's playback position); the TXT/VTT header says so.
String renderTranscript(
  List<SavedLine> lines, {
  required String title,
  required TranscriptFormat format,
  required TranscriptLanguage language,
  required String timesNote,
}) {
  String body(SavedLine line) {
    final translated = line.translation ?? '';
    return switch (language) {
      TranscriptLanguage.source => line.text,
      TranscriptLanguage.translation => translated.isEmpty ? line.text : translated,
      TranscriptLanguage.bilingual => [line.text, translated].where((t) => t.isNotEmpty).join('\n'),
    };
  }

  final sorted = [...lines.where((l) => l.text.trim().isNotEmpty)]
    ..sort((a, b) => a.startMs.compareTo(b.startMs));
  if (format == TranscriptFormat.txt) {
    return '$title\n$timesNote\n\n${sorted.map((l) => '[${timestamp(l.startMs, '.')}]\n${body(l)}').join('\n\n')}\n';
  }
  final separator = format == TranscriptFormat.srt ? ',' : '.';
  final cues = <String>[];
  for (var i = 0; i < sorted.length; i++) {
    final line = sorted[i];
    final start = line.startMs < 0 ? 0 : line.startMs;
    final end = line.endMs > start ? line.endMs : start + 1;
    var text = body(line).replaceAll('\r', '');
    if (format == TranscriptFormat.vtt) {
      text = text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
    }
    cues.add('${i + 1}\n${timestamp(start, separator)} --> ${timestamp(end, separator)}\n$text');
  }
  final header = format == TranscriptFormat.vtt ? 'WEBVTT\n\nNOTE $timesNote\n\n' : '';
  return '$header${cues.join('\n\n')}\n';
}

String timestamp(int ms, String separator) {
  final clamped = ms.clamp(0, 359999999);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(clamped ~/ 3600000)}:${two(clamped ~/ 60000 % 60)}:${two(clamped ~/ 1000 % 60)}'
      '$separator${(clamped % 1000).toString().padLeft(3, '0')}';
}
