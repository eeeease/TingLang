import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/captions.dart';

/// A track as yt-dlp lists it (its formats do not matter here).
const _track = <Object?>[];

void main() {
  test('the publisher\'s English track first, then machine captions of English speech', () {
    expect(
      englishCaptions({
        'subtitles': {'fr': _track, 'en-GB': _track, 'en': _track},
        'automatic_captions': {'en-orig': _track},
      })?.language,
      'en',
    );
    final auto = englishCaptions({
      'automatic_captions': {'en-orig': _track, 'en': _track, 'de': _track},
    });
    expect((auto?.language, auto?.automatic), ('en-orig', true));
    expect(
      englishCaptions({
        'language': 'en',
        'automatic_captions': {'en': _track},
      })?.language,
      'en',
    );
    // English captions of French speech are a machine translation.
    expect(
      englishCaptions({
        'language': 'fr',
        'automatic_captions': {'en': _track, 'fr-orig': _track},
      }),
      isNull,
    );
    expect(englishCaptions({'subtitles': {'live_chat': _track}}), isNull);
  });

  test('machine captions are regrouped into sentences with word timings', () {
    final json3 = jsonEncode({
      'events': [
        {'tStartMs': 0, 'dDurationMs': 4000},
        {
          'tStartMs': 1000,
          'dDurationMs': 2000,
          'segs': [
            {'utf8': '[Music]'},
          ],
        },
        {
          'tStartMs': 3000,
          'dDurationMs': 2000,
          'segs': [
            {'utf8': 'Good'},
            {'utf8': ' morning,', 'tOffsetMs': 300},
            {'utf8': ' everyone.', 'tOffsetMs': 700},
            {'utf8': ' Today', 'tOffsetMs': 1300},
          ],
        },
        {
          'tStartMs': 4800,
          'dDurationMs': 1000,
          'segs': [
            {'utf8': '\n'},
          ],
        },
        {
          'tStartMs': 5000,
          'dDurationMs': 1500,
          'segs': [
            {'utf8': 'we'},
            {'utf8': ' start', 'tOffsetMs': 400},
          ],
        },
        {
          'tStartMs': 8000,
          'dDurationMs': 1000,
          'segs': [
            {'utf8': 'after'},
            {'utf8': ' a pause', 'tOffsetMs': 300},
          ],
        },
      ],
    });
    final lines = captionLines(json3);
    expect(lines.map((l) => l.text), ['Good morning, everyone.', 'Today we start', 'after a pause']);
    expect((lines.first.startMs, lines.first.endMs), (3000, 4300));
    final words = jsonDecode(lines[1].wordsJson!) as List;
    expect(words.map((w) => (w as Map)['w']), ['Today', 'we', 'start']);
    expect(words.first, {'w': 'Today', 's': 4300, 'e': 5000});
    expect(jsonDecode(lines[2].wordsJson!) as List, hasLength(3));
  });

  test('the publisher\'s rows are joined until a sentence ends', () {
    final json3 = jsonEncode({
      'events': [
        {
          'tStartMs': 0,
          'dDurationMs': 2000,
          'segs': [
            {'utf8': 'When I was 17, I read a quote'},
          ],
        },
        {
          'tStartMs': 2000,
          'dDurationMs': 1500,
          'segs': [
            {'utf8': 'that went something like this.'},
          ],
        },
        {
          'tStartMs': 3500,
          'dDurationMs': 1000,
          'segs': [
            {'utf8': '♪ ♪'},
          ],
        },
        {
          'tStartMs': 5000,
          'dDurationMs': 1000,
          'segs': [
            {'utf8': 'It made an impression on me.'},
          ],
        },
      ],
    });
    final lines = captionLines(json3);
    expect(lines.map((l) => l.text), [
      'When I was 17, I read a quote that went something like this.',
      'It made an impression on me.',
    ]);
    expect(lines.first.words, isNull, reason: 'no word timings in these rows');
    expect((lines.first.startMs, lines.first.endMs), (0, 3500));
    expect(captionLines('not json'), isEmpty);
  });
}
