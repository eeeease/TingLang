// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Tinglang contributors.
import 'json_helpers.dart';

/// A timed line of transcript: what was said between two absolute positions
/// of the original media.
///
/// Its JSON form is the `tinglang_cues` course extension: `index`, `text`,
/// `startTime` and `endTime` (integer milliseconds) and optional
/// `isBookmarked`. The field names are a stable file format; keep them.
final class Sentence {
  Sentence({
    required this.index,
    required this.text,
    required this.startTime,
    required this.endTime,
    this.isBookmarked = false,
  }) : assert(index >= 0),
       assert(startTime >= Duration.zero),
       assert(endTime >= startTime);

  /// Reads one cue from untrusted course JSON. Anything malformed is a
  /// [FormatException] so importers can report it instead of crashing.
  factory Sentence.fromJson(Map<String, Object?> json) {
    final index = jsonInt(json['index'], 'cue index');
    final start = jsonInt(json['startTime'], 'cue startTime');
    final end = jsonInt(json['endTime'], 'cue endTime');
    final bookmark = json['isBookmarked'];
    if (index < 0 || start < 0 || end < start) {
      throw FormatException('Cue $index has invalid timing ($start–$end ms).');
    }
    if (bookmark != null && bookmark is! bool) {
      throw const FormatException('cue isBookmarked must be true or false.');
    }
    return Sentence(
      index: index,
      text: jsonString(json['text'], 'cue text'),
      startTime: Duration(milliseconds: start),
      endTime: Duration(milliseconds: end),
      isBookmarked: bookmark == true,
    );
  }

  /// Position of the cue within its transcript, starting at 0.
  final int index;
  final String text;

  /// Absolute offsets into the full original media.
  final Duration startTime, endTime;
  final bool isBookmarked;

  Duration get duration => endTime - startTime;

  /// Whether playback at [position] is inside this cue (end exclusive).
  bool contains(Duration position) => position >= startTime && position < endTime;

  Sentence withBookmark(bool value) => value == isBookmarked
      ? this
      : Sentence(
          index: index,
          text: text,
          startTime: startTime,
          endTime: endTime,
          isBookmarked: value,
        );

  Map<String, Object?> toJson() => {
    'index': index,
    'text': text,
    'startTime': startTime.inMilliseconds,
    'endTime': endTime.inMilliseconds,
    'isBookmarked': isBookmarked,
  };

  @override
  bool operator ==(Object other) =>
      other is Sentence &&
      other.index == index &&
      other.text == text &&
      other.startTime == startTime &&
      other.endTime == endTime &&
      other.isBookmarked == isBookmarked;

  @override
  int get hashCode => Object.hash(index, text, startTime, endTime, isBookmarked);

  @override
  String toString() => 'Sentence($index, ${startTime.inMilliseconds}–${endTime.inMilliseconds} ms)';
}
