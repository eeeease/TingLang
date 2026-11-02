import 'dart:convert';

/// A caption track a page offers, as yt-dlp names it.
class CaptionTrack {
  const CaptionTrack(this.language, {required this.automatic});

  /// yt-dlp's language code (`en`, `en-US`, `en-orig`…).
  final String language;

  /// Machine captions (YouTube's speech recognition), not the publisher's.
  final bool automatic;
}

/// The English track to read from yt-dlp's `-J` output: the publisher's own
/// first, else YouTube's recognition of English speech. Null when the page
/// has neither, or its speech is not English.
CaptionTrack? englishCaptions(Map<String, Object?> info) {
  bool english(String code) => code == 'en' || code.startsWith('en-');
  final manual = info['subtitles'];
  if (manual is Map) {
    final codes = [
      for (final code in manual.keys)
        if (code is String && english(code)) code,
    ]..sort((a, b) => a.length.compareTo(b.length));
    if (codes.isNotEmpty) return CaptionTrack(codes.first, automatic: false);
  }
  final auto = info['automatic_captions'];
  if (auto is Map) {
    // `en-orig` exists only when the speech itself is English; plain `en`
    // may be a machine translation of another language.
    if (auto.containsKey('en-orig')) return const CaptionTrack('en-orig', automatic: true);
    final language = info['language'];
    if (auto.containsKey('en') && language is String && english(language)) {
      return const CaptionTrack('en', automatic: true);
    }
  }
  return null;
}

/// One caption line, cut where a sentence would be.
class CaptionLine {
  const CaptionLine(this.startMs, this.endMs, this.text, [this.words]);
  final int startMs, endMs;
  final String text;

  /// Word timings (`[{"w", "s", "e"}]`), when the track has them (machine
  /// captions do; a publisher's usually do not).
  final List<({String w, int s, int e})>? words;

  String? get wordsJson => words == null
      ? null
      : jsonEncode([
          for (final w in words!) {'w': w.w, 's': w.s, 'e': w.e},
        ]);
}

final _noise = RegExp(r'\[[^\]]*\]|♪+');
final _sentenceEnd = RegExp(r'[.?!]["”’)]?$');

/// Lines from a YouTube `json3` caption file. Machine captions come in
/// short display rows; their words are regrouped into sentence-sized lines
/// at sentence ends, pauses of [pauseMs] or after [maxWords] words. The
/// publisher's rows are joined until a sentence ends (at most [maxMs]).
/// Sound tags such as `[Music]` are dropped.
List<CaptionLine> captionLines(
  String json3, {
  int pauseMs = 700,
  int maxWords = 30,
  int maxMs = 15000,
}) {
  final Object? root;
  try {
    root = jsonDecode(json3);
  } on FormatException {
    return const [];
  }
  final events = root is Map ? root['events'] : null;
  if (events is! List) return const [];

  // Words with times; a row without per-word offsets is one "word" whose
  // time is the row's.
  final words = <({String w, int s, int e, bool timed})>[];
  for (final event in events) {
    if (event is! Map || event['segs'] is! List) continue;
    final start = (event['tStartMs'] as num?)?.toInt() ?? 0;
    final duration = (event['dDurationMs'] as num?)?.toInt() ?? 0;
    final segs = (event['segs'] as List).whereType<Map<Object?, Object?>>().toList();
    final timed = segs.length > 1 || segs.any((s) => s['tOffsetMs'] != null);
    for (var i = 0; i < segs.length; i++) {
      final text = '${segs[i]['utf8'] ?? ''}'.replaceAll(_noise, ' ').replaceAll('\n', ' ').trim();
      if (text.isEmpty) continue;
      final s = start + ((segs[i]['tOffsetMs'] as num?)?.toInt() ?? 0);
      final e = i + 1 < segs.length
          ? start + ((segs[i + 1]['tOffsetMs'] as num?)?.toInt() ?? duration)
          : start + duration;
      for (final piece in timed ? text.split(RegExp(r'\s+')) : [text]) {
        words.add((w: piece, s: s, e: e < s ? s : e, timed: timed));
      }
    }
  }
  // Rows overlap on screen; a word's end is at most the next word's start.
  for (var i = 0; i + 1 < words.length; i++) {
    if (words[i].e > words[i + 1].s && words[i + 1].s >= words[i].s) {
      words[i] = (w: words[i].w, s: words[i].s, e: words[i + 1].s, timed: words[i].timed);
    }
  }

  final lines = <CaptionLine>[];
  var current = <({String w, int s, int e, bool timed})>[];
  void close() {
    if (current.isEmpty) return;
    final timed = current.every((w) => w.timed);
    lines.add(
      CaptionLine(
        current.first.s,
        current.last.e,
        current.map((w) => w.w).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
        timed ? [for (final w in current) (w: w.w, s: w.s, e: w.e)] : null,
      ),
    );
    current = [];
  }

  for (final word in words) {
    if (current.isNotEmpty) {
      final last = current.last;
      final count = current.fold(0, (n, w) => n + w.w.split(' ').length);
      if (_sentenceEnd.hasMatch(last.w) ||
          (word.timed && word.s - last.e >= pauseMs) ||
          count >= maxWords ||
          word.e - current.first.s > maxMs) {
        close();
      }
    }
    current.add(word);
  }
  close();
  return lines;
}
