import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/sentence.dart';

void main() {
  final cue = Sentence(
    index: 2,
    text: 'Show up again.',
    startTime: Duration(milliseconds: 1200),
    endTime: Duration(milliseconds: 2400),
  );
  test('JSON round-trips the tinglang_cues format', () {
    expect(cue.toJson(), {
      'index': 2,
      'text': 'Show up again.',
      'startTime': 1200,
      'endTime': 2400,
      'isBookmarked': false,
    });
    expect(Sentence.fromJson(cue.toJson()), cue);
    expect(
      Sentence.fromJson({'index': 0, 'text': 'x', 'startTime': 0, 'endTime': 5}).isBookmarked,
      isFalse,
    );
  });
  test('rejects malformed external cues with FormatException', () {
    for (final bad in <Map<String, Object?>>[
      {'index': 0, 'text': 'x', 'startTime': -1, 'endTime': 5},
      {'index': 0, 'text': 'x', 'startTime': 9, 'endTime': 5},
      {'index': -1, 'text': 'x', 'startTime': 0, 'endTime': 5},
      {'index': 0, 'text': 'x', 'startTime': '0', 'endTime': 5},
      {'index': 0, 'text': 3, 'startTime': 0, 'endTime': 5},
      {'index': 0, 'text': 'x', 'startTime': 0, 'endTime': 5, 'isBookmarked': 'yes'},
    ]) {
      expect(() => Sentence.fromJson(bad), throwsFormatException, reason: '$bad');
    }
  });
  test('contains is end-exclusive and duration is derived', () {
    expect(cue.contains(const Duration(milliseconds: 1200)), isTrue);
    expect(cue.contains(const Duration(milliseconds: 2399)), isTrue);
    expect(cue.contains(const Duration(milliseconds: 2400)), isFalse);
    expect(cue.duration, const Duration(milliseconds: 1200));
  });
  test('withBookmark returns a changed copy only when needed', () {
    expect(identical(cue.withBookmark(false), cue), isTrue);
    expect(cue.withBookmark(true).isBookmarked, isTrue);
    expect(cue.withBookmark(true), isNot(cue));
  });
}
