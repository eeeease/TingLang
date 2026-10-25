import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/course_codec.dart';
import 'package:tinglang/core/json_helpers.dart';
import 'package:tinglang/core/models.dart';

Map<String, Object?> demoMap() =>
    jsonObject(jsonDecode(File('assets/demo/course.json').readAsStringSync()), 'demo');
Map<String, Object?> firstClip(Map<String, Object?> root) =>
    jsonObject(jsonList(root['clips'], 'clips').first, 'clip');

void main() {
  const codec = CourseCodec();
  test('English V3 uses schema 2 and imports all three demo scenes', () {
    final course = codec.fromMap(demoMap(), area: Area.nba);
    expect(course.clips, hasLength(3));
    expect(course.mediaPath, isNull);
    expect(course.clips.first.items, isNotEmpty);
    expect(course.clips.first.sentences, hasLength(3));
  });
  test('preserves unknown metadata without interpreting paths or commands', () {
    final raw = demoMap();
    raw['future_field'] = {'content': 'preserve me'};
    raw['mediaPath'] = '/etc/passwd';
    raw['source_url'] = 'https://example.invalid/video';
    final course = codec.fromMap(raw);
    expect(course.raw['future_field'], raw['future_field']);
    expect(course.mediaPath, isNull);
  });
  test('rejects future schemas and duplicate clip ids', () {
    final raw = demoMap();
    raw['schema_version'] = 99;
    expect(() => codec.fromMap(raw), throwsFormatException);
    final duplicate = demoMap();
    final clips = jsonList(duplicate['clips'], 'clips');
    clips.add(clips.first);
    expect(() => codec.fromMap(duplicate), throwsFormatException);
  });
  test('rejects end before start', () {
    final raw = demoMap();
    firstClip(raw)['end'] = 0;
    expect(() => codec.fromMap(raw), throwsFormatException);
  });
  test('blind answers must reconstruct source exactly apart from whitespace', () {
    final raw = demoMap();
    final blind = jsonObject(firstClip(raw)['blind_listening'], 'blind');
    final blanks = jsonList(blind['blanks'], 'blanks');
    jsonObject(blanks.first, 'blank')['answer'] = 'not in source';
    expect(() => codec.fromMap(raw), throwsFormatException);
  });
  test('rejects fabricated shadowing text', () {
    final raw = demoMap();
    firstClip(raw)['shadowing'] = [
      {'text': 'Invented evidence.'},
    ];
    expect(() => codec.fromMap(raw), throwsFormatException);
  });
  test('parses hours, comma timestamps and millisecond fractions', () {
    expect(parseTimestamp('01:02:03.045'), 3723045);
    expect(parseTimestamp('02:03,45'), 123450);
    expect(parseTimestamp(1.125), 1125);
    expect(() => parseTimestamp('00:60:00'), throwsFormatException);
    expect(() => parseTimestamp(-1), throwsFormatException);
  });
  test('SRT keeps cue timing and removes formatting tags', () {
    final cues = parseSubtitles(
      '1\n00:00:01,125 --> 00:00:02,500\n<b>Hello</b> there.\n\n'
      '2\n00:00:03,000 --> 00:00:04,000\nHow are you?\n',
    );
    expect(cues, hasLength(2));
    expect(cues.first.startTime.inMilliseconds, 1125);
    expect(cues.first.text, 'Hello there.');
  });
  test('VTT accepts cue ids and position settings, ignores NOTE blocks', () {
    final cues = parseSubtitles(
      'WEBVTT\n\nNOTE not a cue\n\nintro\n'
      '00:01.100 --> 00:04.200 align:start position:0%\nHello.\n',
    );
    expect(cues.single.endTime.inMilliseconds, 4200);
  });
  test('local media without subtitles has unknown, not fabricated, duration', () {
    final raw = courseForMedia(id: 'local-test', title: 'My recording');
    final course = codec.fromMap(raw);
    expect(course.clips.single.endMs, isNull);
    expect(course.clips.single.transcript, isEmpty);
  });
  test('entity keys do not collide when ids contain delimiters', () {
    expect(entityKey('a:b', 'c'), isNot(entityKey('a', 'b:c')));
  });
  test('answer normalization accepts whitespace and curly apostrophes', () {
    expect(normalizeAnswer('  It’s   practice. '), "it's practice");
  });
}
