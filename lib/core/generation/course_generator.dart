import 'dart:math' as math;

import '../course_codec.dart';
import '../dictation.dart';
import '../models.dart';
import 'lexicon.dart';

/// A recognised sentence with real timings (ms into the session media).
class GenSentence {
  const GenSentence(this.text, this.startMs, this.endMs, [this.translation]);
  final String text;
  final int startMs, endMs;
  final String? translation;
}

/// Everything the generator needs; produced from a saved session.
class GenerationInput {
  const GenerationInput({
    required this.courseId,
    required this.title,
    required this.sentences,
    this.sourceLabel = 'Generated from your transcript',
    this.learnerLevel = 'B2',
    this.knownLemmas = const {},
  });
  final String courseId, title, sourceLabel, learnerLevel;
  final List<GenSentence> sentences;

  /// Lemmas already in the learner's library; not proposed again.
  final Set<String> knownLemmas;
}

/// Splits recognised lines into sentences using word timings (never
/// invented); lines without timings stay whole.
List<GenSentence> sentencesFromLines(
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
  lines,
) => [
  for (final item in dictationItems(lines, maxWords: 60, minWords: 1))
    GenSentence(item.text.trim(), item.startMs, item.endMs, item.context),
];

/// D2: a contiguous run of sentences, 30–120 s where the media allows.
class ClipWindow {
  ClipWindow(this.sentences);
  final List<GenSentence> sentences;
  double score = 0;
  int get startMs => sentences.first.startMs;
  int get endMs => sentences.last.endMs;
  int get durationMs => endMs - startMs;
  String get text => sentences.map((s) => s.text).join(' ');
}

List<ClipWindow> buildWindows(
  List<GenSentence> sentences, {
  int targetMs = 60000,
  int maxMs = 120000,
  int minMs = 30000,
}) {
  final windows = <ClipWindow>[];
  var current = <GenSentence>[];
  for (final s in sentences) {
    if (current.isNotEmpty) {
      final duration = current.last.endMs - current.first.startMs;
      final withNext = s.endMs - current.first.startMs;
      if (duration >= targetMs || withNext > maxMs) {
        windows.add(ClipWindow(current));
        current = [];
      }
    }
    current.add(s);
  }
  if (current.isNotEmpty) {
    final tail = ClipWindow(current);
    if (windows.isNotEmpty &&
        tail.durationMs < minMs &&
        tail.endMs - windows.last.startMs <= maxMs * 1.5) {
      windows[windows.length - 1] = ClipWindow([...windows.last.sentences, ...current]);
    } else {
      windows.add(tail);
    }
  }
  return windows;
}

class WordCandidate {
  const WordCandidate(this.surface, this.entry, this.sentence);
  final String surface;
  final LexEntry entry;
  final GenSentence sentence;
}

class ClipCandidates {
  const ClipCandidates(this.words, this.phrases, this.sentences, this.density);
  final List<WordCandidate> words;

  /// `surface` is the exact transcript spelling, `phrase` the lexicon form.
  final List<({String surface, String phrase, String gloss})> phrases;
  final List<GenSentence> sentences;

  /// Above-level tokens per 100 tokens (window score).
  final double density;
}

final _token = RegExp(r"[A-Za-z][A-Za-z'’\-]*");

int _minRank(String level) => switch (level) {
  'A2' || 'B1' => 2000,
  'C1' => 6000,
  'C2' => 9000,
  _ => 3000,
};

const _particles = {
  'up',
  'down',
  'out',
  'off',
  'on',
  'in',
  'over',
  'away',
  'back',
  'through',
  'together',
  'around',
  'into',
};
const _function = {
  'a',
  'an',
  'the',
  'of',
  'to',
  'in',
  'on',
  'at',
  'for',
  'by',
  'with',
  'and',
  'or',
  'it',
  'as',
  'be',
  'is',
  'are',
  'was',
  'were',
  'been',
  'have',
  'has',
  'had',
  'do',
  'does',
  'did',
};

/// "of course", "a bit": every content word is very common and it is not a
/// phrasal verb. Phrasal verbs ("show up") are kept: they are what spoken
/// English is made of.
bool _tooBasic(String phrase, Lexicon lexicon, int minRank) {
  final parts = phrase.split(' ');
  if (parts.length == 2 && _particles.contains(parts[1]) && !_function.contains(parts[0])) {
    return false;
  }
  return parts.where((w) => !_function.contains(w)).every((w) {
    final rank = lexicon.lookup(w)?.rank ?? 0;
    return rank > 0 && rank < minRank;
  });
}

/// D3: words above the learner's level (by frequency/exam tags), lexicon
/// phrases and complete 8–25-word sentences — hints for the LLM, and the
/// whole content of a Basic course.
ClipCandidates candidatesFor(
  ClipWindow window,
  Lexicon lexicon, {
  String level = 'B2',
  Set<String> known = const {},
}) {
  final minRank = _minRank(level);
  final seen = <String>{...known};
  final words = <WordCandidate>[];
  var tokens = 0, above = 0;
  for (final sentence in window.sentences) {
    final matches = _token.allMatches(sentence.text).toList();
    for (var i = 0; i < matches.length; i++) {
      final surface = matches[i].group(0)!;
      tokens++;
      // Capitalised mid-sentence: likely a name; never teach proper nouns.
      if (i > 0 && surface[0] != surface[0].toLowerCase()) continue;
      if (surface.length < 4) continue;
      final entry = lexicon.lookup(surface);
      if (entry == null || entry.rank == 0) continue;
      final inBand = entry.rank >= minRank && entry.rank <= 30000;
      if (!inBand) continue;
      above++;
      if (!seen.add(entry.lemma)) continue;
      words.add(WordCandidate(surface, entry, sentence));
    }
  }
  // Most useful first: exam-list words, then the more frequent ones (a
  // B2 learner gains more from rank 4000 than from rank 25000).
  words.sort((a, b) {
    final exam = (b.entry.examWord ? 1 : 0) - (a.entry.examWord ? 1 : 0);
    return exam != 0 ? exam : a.entry.rank.compareTo(b.entry.rank);
  });
  final phrases = [
    for (final p in lexicon.phrasesIn(window.text))
      if (!_tooBasic(p.phrase, lexicon, minRank) && !seen.contains(p.phrase)) p,
  ];
  final sentences = [
    for (final s in window.sentences)
      if (diffTokens(s.text).length >= 8 &&
          diffTokens(s.text).length <= 25 &&
          RegExp(r'[.?!]$').hasMatch(s.text))
        s,
  ];
  return ClipCandidates(words, phrases, sentences, tokens == 0 ? 0 : 100 * above / tokens);
}

/// Teaching content for one clip, from the LLM (L2) or the Basic rules.
class ClipPlan {
  ClipPlan({
    this.title = '',
    this.topic = '',
    this.difficulty,
    this.items = const [],
    this.listeningWords = const [],
    this.shadowing = const [],
    this.retelling,
  });
  final String title, topic;
  final int? difficulty;
  final List<PlannedItem> items;

  /// Basic words used only as blind-listening blanks (no learning item).
  final List<String> listeningWords;
  final List<({String text, String reason})> shadowing;
  final PlannedRetelling? retelling;
}

class PlannedItem {
  PlannedItem({
    required this.kind,
    required this.text,
    this.meaning = '',
    this.explanation = '',
    this.whyUseful = '',
    this.cefr = '',
    this.levelNote = '',
    this.subtype = '',
    this.learnerExample = '',
    this.frame = '',
    this.patterns = const [],
    this.memoryType = '',
    this.memoryCue = '',
    this.memoryNote = '',
    this.blank = true,
  });

  /// `words`, `phrases` or `sentences`.
  final String kind;
  final String text, meaning, explanation, whyUseful, cefr, levelNote, subtype;
  final String learnerExample, frame, memoryType, memoryCue, memoryNote;
  final List<String> patterns;

  /// Use as a blind-listening blank.
  final bool blank;
}

class PlannedRetelling {
  const PlannedRetelling({
    required this.prompt,
    this.outline = const [],
    this.evidence = const [],
    this.targets = const [],
    this.followUp = '',
  });
  final String prompt, followUp;
  final List<String> outline, evidence, targets;
}

/// Basic plan: no LLM, only lexicon facts and deterministic choices. Items
/// carry dictionary glosses; memory aids are left empty rather than made up.
ClipPlan basicPlan(ClipWindow window, ClipCandidates c) {
  final words = c.words.take(5).toList();
  final phrases = c.phrases.take(3).toList();
  final sentence = c.sentences.isEmpty
      ? null
      : (c.sentences.toList()..sort((a, b) => _targets(b, words).compareTo(_targets(a, words))))
            .first;
  final shadow =
      (window.sentences.where((s) => diffTokens(s.text).length >= 6).toList()
            ..sort((a, b) => _targets(b, words).compareTo(_targets(a, words))))
          .take(2)
          .toList();
  return ClipPlan(
    title: _titleFrom(window),
    items: [
      for (final w in words)
        PlannedItem(
          kind: 'words',
          text: w.surface,
          meaning: w.entry.gloss,
          cefr: w.entry.approxCefr,
          levelNote: 'Approximate level from word frequency (ECDICT).',
        ),
      for (final p in phrases)
        PlannedItem(
          kind: 'phrases',
          text: p.surface,
          meaning: p.gloss,
          subtype: p.phrase.split(' ').length == 2 && _particles.contains(p.phrase.split(' ')[1])
              ? 'phrasal_verb'
              : 'phrase',
        ),
      if (sentence != null)
        PlannedItem(kind: 'sentences', text: sentence.text, meaning: sentence.translation ?? ''),
    ],
    shadowing: [for (final s in shadow) (text: s.text, reason: 'Contains words above your level.')],
    retelling: const PlannedRetelling(
      prompt: 'Retell this part in your own words.',
      followUp: 'Tell someone about a similar idea from your own life.',
    ),
  );
}

int _targets(GenSentence s, List<WordCandidate> words) =>
    words.where((w) => identical(w.sentence, s) || s.text.contains(w.surface)).length;

String _titleFrom(ClipWindow w) {
  final words = w.sentences.first.text.split(RegExp(r'\s+'));
  return words.length <= 8 ? w.sentences.first.text : '${words.take(8).join(' ')}…';
}

/// D4: compiles plans into an English V3 `course.json` map (schema 2 /
/// design 3). IDs, timings, exact source quotes and the blind template are
/// produced here, never by the LLM; anything not found verbatim in the clip
/// transcript is dropped. The result is validated by [CourseCodec].
Map<String, Object?> compileCourse(
  GenerationInput input,
  List<ClipWindow> windows,
  List<ClipPlan> plans, {
  Map<String, Object?>? overview,
}) {
  final clips = <Map<String, Object?>>[];
  for (var i = 0; i < windows.length; i++) {
    final clipId = 'clip_${(i + 1).toString().padLeft(3, '0')}';
    clips.add(_compileClip(clipId, windows[i], plans[i]));
  }
  return {
    'schema_version': 2,
    'design_version': 3,
    'podcast_id': input.courseId,
    'title': input.title,
    'learner_level': input.learnerLevel,
    'tinglang_source': input.sourceLabel,
    'overview': overview ?? {'selected_clip_count': clips.length},
    'clips': clips,
  };
}

/// Same-length folding (case, curly quotes) so indices map back to the
/// source and quotes keep the transcript's own spelling.
String _fold(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[’‘]'), "'").replaceAll(RegExp(r'[“”]'), '"');

/// Searches [needle] in [hay] ignoring case and quote style; returns the
/// span in [hay]. Whitespace differences are not tolerated (quotes are
/// meant to be exact).
({int start, int end})? _find(String hay, String needle, {int from = 0}) {
  final n = needle.trim();
  if (n.isEmpty) return null;
  final at = _fold(hay).indexOf(_fold(n), from);
  return at < 0 ? null : (start: at, end: at + n.length);
}

/// The sentence of [transcript] containing [start]–[end].
String _sentenceAround(String transcript, int start, int end) {
  final before = transcript.substring(0, start);
  final stop = RegExp(r'[.?!]["”’)]*\s').allMatches(before).lastOrNull;
  final a = stop?.end ?? 0;
  final after = RegExp(r'[.?!]["”’)]*(\s|$)').firstMatch(transcript.substring(end));
  final b = after == null ? transcript.length : end + after.start + 1;
  return transcript.substring(a, b).trim();
}

Map<String, Object?> _compileClip(String clipId, ClipWindow window, ClipPlan plan) {
  final transcript = window.text;
  final items = <String, List<Map<String, Object?>>>{'words': [], 'phrases': [], 'sentences': []};
  final blankSpecs = <({String type, String text, String? itemId})>[];
  final itemIdByText = <String, String>{};
  for (final item in plan.items) {
    final span = _find(transcript, item.text);
    if (span == null) continue;
    final exact = transcript.substring(span.start, span.end);
    final list = items[item.kind];
    if (list == null || itemIdByText.containsKey(exact.toLowerCase())) continue;
    final type = switch (item.kind) {
      'words' => 'word',
      'phrases' => 'phrase',
      _ => 'sentence',
    };
    final id = '${clipId}_${type}_${(list.length + 1).toString().padLeft(2, '0')}';
    itemIdByText[exact.toLowerCase()] = id;
    list.add({
      'id': id,
      'type': type,
      'text': exact,
      'meaning_zh': item.meaning,
      'simple_explanation_en': item.explanation,
      'why_useful': item.whyUseful,
      'original_example': type == 'sentence'
          ? exact
          : _sentenceAround(transcript, span.start, span.end),
      'timestamp': window.startMs / 1000,
      'usage_note': null,
      'common_patterns': item.patterns,
      'learner_example': item.learnerExample,
      'memory_aid': {'type': item.memoryType, 'cue_zh': item.memoryCue, 'note': item.memoryNote},
      if (type == 'word') 'cefr': item.cefr,
      if (type == 'word') 'level_note_zh': item.levelNote,
      if (type == 'phrase') 'subtype': item.subtype.isEmpty ? 'phrase' : item.subtype,
      if (type == 'sentence') 'reusable_frame': item.frame,
    });
    if (item.blank) blankSpecs.add((type: type, text: exact, itemId: id));
  }
  for (final w in plan.listeningWords) {
    blankSpecs.add((type: 'word', text: w, itemId: null));
  }

  // Blind listening: sentences first (internal only, ≥20 chars of context
  // each side), then phrases, then words; first non-overlapping match.
  final taken = <({int start, int end, String id, String answer, String type, String? itemId})>[];
  final counters = <String, int>{'word': 0, 'phrase': 0, 'sentence': 0};
  const limits = {'word': 5, 'phrase': 3, 'sentence': 1};
  for (final type in ['sentence', 'phrase', 'word']) {
    for (final spec in blankSpecs.where((b) => b.type == type)) {
      if (counters[type]! >= limits[type]!) break;
      var from = 0;
      while (true) {
        final span = _find(transcript, spec.text, from: from);
        if (span == null) break;
        from = span.start + 1;
        final overlaps = taken.any((t) => span.start < t.end && t.start < span.end);
        final boundary =
            (span.start == 0 || !RegExp(r'\w').hasMatch(transcript[span.start - 1])) &&
            (span.end == transcript.length || !RegExp(r'\w').hasMatch(transcript[span.end]));
        final internal =
            type != 'sentence' || (span.start >= 20 && transcript.length - span.end >= 20);
        if (overlaps || !boundary || !internal) continue;
        counters[type] = counters[type]! + 1;
        taken.add((
          start: span.start,
          end: span.end,
          id: '${clipId}_blank_${type}_${counters[type].toString().padLeft(2, '0')}',
          answer: transcript.substring(span.start, span.end),
          type: type,
          itemId: spec.itemId,
        ));
        break;
      }
    }
  }
  taken.sort((a, b) => a.start.compareTo(b.start));
  var template = transcript;
  for (final t in taken.reversed) {
    template = '${template.substring(0, t.start)}{{${t.id}}}${template.substring(t.end)}';
  }

  final shadowing = <Map<String, Object?>>[];
  for (final s in plan.shadowing) {
    final span = _find(transcript, s.text);
    if (span == null) continue;
    shadowing.add({
      'id': '${clipId}_shadow_${(shadowing.length + 1).toString().padLeft(2, '0')}',
      'text': transcript.substring(span.start, span.end),
      'reason': s.reason,
    });
  }

  final retell = plan.retelling;
  final outline = <String>[], evidence = <String>[];
  if (retell != null) {
    for (var i = 0; i < retell.outline.length && i < retell.evidence.length; i++) {
      final span = _find(transcript, retell.evidence[i]);
      if (span == null) continue;
      outline.add(retell.outline[i]);
      evidence.add(transcript.substring(span.start, span.end));
    }
  }
  final targets = [
    for (final t in retell?.targets ?? const <String>[])
      if (itemIdByText[t.trim().toLowerCase()] != null) itemIdByText[t.trim().toLowerCase()]!,
  ];

  final cueEnd = window.sentences.map((s) => math.max(s.endMs, s.startMs + 1)).reduce(math.max);
  return {
    'id': clipId,
    'start': window.startMs / 1000,
    'end': cueEnd / 1000,
    'title': plan.title.isEmpty ? _titleFrom(window) : plan.title,
    'topic': plan.topic,
    if (plan.difficulty != null) 'difficulty': plan.difficulty,
    'transcript': transcript,
    'learning': items,
    'blind_listening': {
      'template': taken.isEmpty ? '' : template,
      'blanks': [
        for (final t in taken)
          {'id': t.id, 'type': t.type, 'answer': t.answer, 'learning_item_id': ?t.itemId},
      ],
    },
    'shadowing': shadowing,
    'retelling': {
      'id': '${clipId}_retell',
      'prompt': retell?.prompt ?? 'Retell this part in your own words.',
      'outline': outline,
      'source_evidence': evidence,
      'target_item_ids': targets,
      'follow_up': retell?.followUp ?? '',
    },
    'tinglang_cues': [
      for (var i = 0; i < window.sentences.length; i++)
        {
          'index': i,
          'text': window.sentences[i].text,
          'startTime': window.sentences[i].startMs,
          'endTime': math.max(window.sentences[i].endMs, window.sentences[i].startMs + 1),
          'isBookmarked': false,
        },
    ],
  };
}

/// Picks about one clip per six minutes (1–25), best-scoring first, kept
/// in media order. Scores come from above-level word density.
List<int> selectWindows(List<ClipWindow> windows, {int? count}) {
  if (windows.isEmpty) return const [];
  final totalMs = windows.last.endMs - windows.first.startMs;
  final int n = (count ?? (totalMs / 360000).round())
      .clamp(1, math.min(25, windows.length))
      .toInt();
  final ranked = [for (var i = 0; i < windows.length; i++) i]
    ..sort((a, b) => windows[b].score.compareTo(windows[a].score));
  return ranked.take(n).toList()..sort();
}

/// Validates the compiled map with the same rules as imported courses.
Course validateCompiled(
  Map<String, Object?> json, {
  Area area = Area.personal,
  String? mediaPath,
  String? sourceLabel,
}) => const CourseCodec(strictSource: true).fromMap(
  json,
  area: area,
  mediaPath: mediaPath,
  sourceLabel: sourceLabel,
  importedAt: DateTime.now().toUtc(),
);
