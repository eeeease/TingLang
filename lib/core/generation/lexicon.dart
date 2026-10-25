import 'dart:convert';
import 'dart:io';

/// One headword from the ECDICT-derived lexicon (MIT).
class LexEntry {
  const LexEntry(this.lemma, this.rank, this.tags, this.gloss);
  final String lemma;

  /// COCA (else BNC) frequency rank; 0 when unknown.
  final int rank;
  final int tags;
  final String gloss;

  static const ielts = 32, toefl = 64, gre = 128, cet6 = 8;
  bool get examWord => tags & (ielts | toefl | gre | cet6) != 0;

  /// Rough CEFR band from frequency; labelled approximate in the UI.
  String get approxCefr => rank == 0 || rank > 12000
      ? 'C2'
      : rank > 6000
      ? 'C1'
      : rank > 3000
      ? 'B2'
      : 'B1';
}

/// Frequency, exam tags and short Chinese glosses for English words, plus
/// inflection links and common phrases (assets/lexicon/en.v1.json.gz).
class Lexicon {
  Lexicon._(this._words, this._lemmas, this.phrases);

  factory Lexicon.fromGzip(List<int> bytes) {
    final data = jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, Object?>;
    return Lexicon._(
      (data['w']! as Map<String, Object?>).cast<String, List<Object?>>(),
      (data['l']! as Map<String, Object?>).cast<String, String>(),
      (data['p']! as Map<String, Object?>).cast<String, String>(),
    );
  }

  final Map<String, List<Object?>> _words;
  final Map<String, String> _lemmas;

  /// Multi-word expressions with a gloss (lowercase).
  final Map<String, String> phrases;

  LexEntry? _entry(String? word) {
    final row = word == null ? null : _words[word];
    return row == null
        ? null
        : LexEntry(word!, (row[0]! as num).toInt(), (row[1]! as num).toInt(), row[2]! as String);
  }

  /// The dictionary entry for a running-text token. Inflections resolve to
  /// their lemma first ("decided" → decide, "weeks" → week), so a rare
  /// homograph headword (a surname, an adjective sense) never wins.
  LexEntry? lookup(String token) {
    final w = token.toLowerCase().replaceAll('’', "'").replaceAll(RegExp(r"^[^a-z]+|[^a-z]+$"), '');
    if (w.isEmpty) return null;
    final lemma = _entry(_lemmas[w]);
    final direct = _entry(w);
    // "ground" is a word of its own, not just the past of grind: a more
    // frequent headword beats the lemma link.
    if (lemma != null && (direct == null || direct.rank == 0 || lemma.rank <= direct.rank)) {
      return lemma;
    }
    if (lemma != null) return direct;
    for (final stem in _stems(w)) {
      final entry = _entry(stem);
      if (entry == null) continue;
      // An inflectional stem that is more frequent is the real word.
      if (direct == null || (entry.rank > 0 && (direct.rank == 0 || entry.rank < direct.rank))) {
        return entry;
      }
    }
    return direct;
  }

  Map<String, Set<String>>? _forms;

  /// Every known surface form of [lemma], including itself.
  Set<String> formsOf(String lemma) {
    final forms = _forms ??= () {
      final map = <String, Set<String>>{};
      _lemmas.forEach((form, base) => (map[base] ??= {}).add(form));
      return map;
    }();
    return {lemma, ...?forms[lemma]};
  }

  /// Lexicon phrases occurring in [text], matching inflected first words
  /// ("kept showing up" → show up). Returns the exact source spelling.
  List<({String surface, String phrase, String gloss})> phrasesIn(String text) {
    final lower = text.toLowerCase().replaceAll('’', "'");
    final found = <({String surface, String phrase, String gloss})>[];
    phrases.forEach((phrase, gloss) {
      final parts = phrase.split(' ');
      if (parts.length < 2 || !lower.contains(parts.last)) return;
      final head = formsOf(parts.first).map(RegExp.escape).join('|');
      final rest = parts.skip(1).map(RegExp.escape).join(r'\s+');
      final match = RegExp('\\b(?:$head)\\s+$rest\\b').firstMatch(lower);
      if (match != null) {
        found.add((surface: text.substring(match.start, match.end), phrase: phrase, gloss: gloss));
      }
    });
    return found;
  }

  /// Inflectional stems only; derivations such as -ly are separate words
  /// ("hardly" is not "hard").
  static Iterable<String> _stems(String w) sync* {
    if (w.endsWith("'s")) yield w.substring(0, w.length - 2);
    if (w.endsWith('ies')) yield '${w.substring(0, w.length - 3)}y';
    if (w.endsWith('es')) yield w.substring(0, w.length - 2);
    if (w.endsWith('s')) yield w.substring(0, w.length - 1);
    if (w.endsWith('ed')) yield w.substring(0, w.length - 2);
    if (w.endsWith('ed')) yield w.substring(0, w.length - 1);
    if (w.endsWith('ing')) yield w.substring(0, w.length - 3);
    if (w.endsWith('ing')) yield '${w.substring(0, w.length - 3)}e';
  }
}
