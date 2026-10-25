import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/live_repository.dart';
import 'package:tinglang/core/transcript_export.dart';

const lines = [
  SavedLine(
    segmentId: 'b',
    startMs: 4200,
    endMs: 6100,
    text: 'Second <line> & more',
    translation: '第二行',
  ),
  SavedLine(segmentId: 'a', startMs: 1000, endMs: 3500, text: 'First line'),
];

void main() {
  test('SRT sorts by time, numbers cues and uses comma milliseconds', () {
    final srt = renderTranscript(
      lines,
      title: 'T',
      format: TranscriptFormat.srt,
      language: TranscriptLanguage.bilingual,
      timesNote: 'note',
    );
    expect(
      srt,
      '1\n00:00:01,000 --> 00:00:03,500\nFirst line\n\n'
      '2\n00:00:04,200 --> 00:00:06,100\nSecond <line> & more\n第二行\n',
    );
  });

  test('VTT escapes markup and carries the time-base note', () {
    final vtt = renderTranscript(
      lines,
      title: 'T',
      format: TranscriptFormat.vtt,
      language: TranscriptLanguage.source,
      timesNote: 'Times are relative to capture start.',
    );
    expect(
      vtt,
      startsWith('WEBVTT\n\nNOTE Times are relative to capture start.\n\n1\n00:00:01.000'),
    );
    expect(vtt, contains('Second &lt;line&gt; &amp; more'));
  });

  test('translation-only falls back to the original when untranslated', () {
    final txt = renderTranscript(
      lines,
      title: 'Session',
      format: TranscriptFormat.txt,
      language: TranscriptLanguage.translation,
      timesNote: 'note',
    );
    expect(txt, 'Session\nnote\n\n[00:00:01.000]\nFirst line\n\n[00:00:04.200]\n第二行\n');
  });

  test('timestamp clamps negatives and formats hours', () {
    expect(timestamp(-5, ','), '00:00:00,000');
    expect(timestamp(3723004, '.'), '01:02:03.004');
  });
}
