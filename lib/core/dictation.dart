import 'dart:convert';

import 'package:tinglang_platform_interface/tinglang_platform_interface.dart' show TimedWord;

/// Grading shared with the English V3 course player: lowercase,
/// curly apostrophes folded, punctuation stripped, whitespace collapsed;
/// exact → correct, character-LCS similarity ≥ 0.85 → close, else incorrect.
String normalizeAnswer(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('’', "'")
    .replaceAll(RegExp(r"[^\p{L}\p{N}_\s']", unicode: true), '')
    .replaceAll(RegExp(r'\s+'), ' ');

int _lcs<T>(List<T> a, List<T> b) {
  final dp = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    var previous = 0;
    for (var j = 1; j <= b.length; j++) {
      final keep = dp[j];
      dp[j] = a[i - 1] == b[j - 1] ? previous + 1 : (dp[j] > dp[j - 1] ? dp[j] : dp[j - 1]);
      previous = keep;
    }
  }
  return dp[b.length];
}

double answerSimilarity(String actual, String expected) {
  final a = normalizeAnswer(actual).runes.toList(), b = normalizeAnswer(expected).runes.toList();
  if (a.isEmpty && b.isEmpty) return 1;
  if (a.isEmpty || b.isEmpty) return 0;
  return 2 * _lcs(a, b) / (a.length + b.length);
}

enum DictationResult { correct, close, incorrect }

enum WordMark { matched, missed, extra }

class GradedWord {
  const GradedWord(this.text, this.mark);
  final String text;
  final WordMark mark;
}

class DictationGrade {
  const DictationGrade(this.result, this.similarity, this.words);
  final DictationResult result;
  final double similarity;

  /// Expected words in order (matched / missed) with the learner's extra
  /// words inserted where they were typed.
  final List<GradedWord> words;
}

/// Tokens for the word diff: CJK characters count one by one (no spaces in
/// Chinese/Japanese), other scripts split on whitespace.
List<String> diffTokens(String text) {
  final normalized = normalizeAnswer(text);
  final tokens = <String>[];
  for (final word in normalized.split(' ').where((w) => w.isNotEmpty)) {
    if (RegExp(r'[぀-ヿ㐀-鿿가-힯]').hasMatch(word)) {
      tokens.addAll(word.runes.map(String.fromCharCode));
    } else {
      tokens.add(word);
    }
  }
  return tokens;
}

DictationGrade gradeDictation(String answer, String expected) {
  final similarity = answerSimilarity(answer, expected);
  final result = normalizeAnswer(answer) == normalizeAnswer(expected)
      ? DictationResult.correct
      : similarity >= .85
      ? DictationResult.close
      : DictationResult.incorrect;
  final want = diffTokens(expected), got = diffTokens(answer);
  // Word-level LCS table, then walk it to mark matches/misses/extras.
  final n = want.length, m = got.length;
  final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      dp[i][j] = want[i] == got[j]
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] >= dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }
  final words = <GradedWord>[];
  var i = 0, j = 0;
  while (i < n || j < m) {
    if (i < n && j < m && want[i] == got[j]) {
      words.add(GradedWord(want[i++], WordMark.matched));
      j++;
    } else if (j < m && (i == n || dp[i][j + 1] >= dp[i + 1][j])) {
      words.add(GradedWord(got[j++], WordMark.extra));
    } else {
      words.add(GradedWord(want[i++], WordMark.missed));
    }
  }
  return DictationGrade(result, similarity, words);
}

/// Playback span for a sentence: its timing ± [padMs], clamped at 0.
({int startMs, int endMs}) sentenceSpan(int startMs, int endMs, {int padMs = 200}) =>
    (startMs: startMs - padMs < 0 ? 0 : startMs - padMs, endMs: endMs + padMs);

String? wordsToJson(List<TimedWord>? words) => words == null || words.isEmpty
    ? null
    : jsonEncode([
        for (final w in words) {'w': w.text, 's': w.startMs, 'e': w.endMs},
      ]);

/// One dictation item: a sentence with exact audio timing.
class DictationItem {
  const DictationItem({
    required this.id,
    required this.text,
    required this.startMs,
    required this.endMs,
    this.context,
  });

  /// `<segmentId>#<n>` when split out of a longer recognised line.
  final String id;
  final String text;
  final int startMs, endMs;

  /// Translation of the whole line the sentence came from (shown as a hint).
  final String? context;
}

/// Splits recognised lines into dictation-sized sentences using word
/// timings: at `.?!。？！`, and at commas once a sentence passes [maxWords]
/// words. Lines without word timings stay whole (times are never invented).
List<DictationItem> dictationItems(
  Iterable<
    ({
      String segmentId,
      String text,
      int startMs,
      int endMs,
      String? wordsJson,
      String? translation,
    })
  >
  lines, {
  int maxWords = 25,
  int minWords = 2,
}) {
  final items = <DictationItem>[];
  for (final line in lines) {
    final words = _decodeWords(line.wordsJson);
    if (words == null || words.isEmpty) {
      if (diffTokens(line.text).length >= minWords) {
        items.add(
          DictationItem(
            id: line.segmentId,
            text: line.text,
            startMs: line.startMs,
            endMs: line.endMs,
            context: line.translation,
          ),
        );
      }
      continue;
    }
    var current = <({String w, int s, int e})>[];
    var part = 0;
    void emit() {
      if (current.isEmpty) return;
      final text = current.map((w) => w.w).join(' ');
      if (diffTokens(text).length >= minWords) {
        items.add(
          DictationItem(
            id: '${line.segmentId}#${part++}',
            text: text,
            startMs: current.first.s,
            endMs: current.last.e,
            context: line.translation,
          ),
        );
      }
      current = [];
    }

    for (final word in words) {
      current.add(word);
      final end = RegExp(r'[.?!。？！]["”’)]*$').hasMatch(word.w);
      final soft = current.length >= maxWords && RegExp(r'[,;:，；：]$').hasMatch(word.w);
      if (end || soft || current.length >= maxWords * 2) emit();
    }
    emit();
  }
  return items;
}

List<({String w, int s, int e})>? _decodeWords(String? json) {
  if (json == null) return null;
  try {
    return [
      for (final m in (jsonDecode(json) as List<Object?>).cast<Map<String, Object?>>())
        (w: m['w']! as String, s: (m['s']! as num).toInt(), e: (m['e']! as num).toInt()),
    ];
  } on Object {
    return null;
  }
}
