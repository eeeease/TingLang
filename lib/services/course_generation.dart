import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/db/database.dart';
import '../core/generation/course_generator.dart';
import '../core/generation/lexicon.dart';
import '../core/generation/llm_planner.dart';
import '../core/live_repository.dart';
import '../core/models.dart';
import '../core/providers/llm_client.dart';
import '../core/providers/provider_repository.dart';
import 'app_controller.dart';

enum GenerationStage { reading, selecting, planning, compiling, done, failed }

/// Progress of one "Make course" run.
class GenerationJob extends ChangeNotifier {
  GenerationJob(this.sessionId, this.provider);
  final String sessionId;

  /// Null for a Basic course (no LLM).
  final LlmProvider? provider;
  GenerationStage stage = GenerationStage.reading;
  int clipsDone = 0, clipsTotal = 0;

  /// Real LLM requests (cache hits excluded).
  int requests = 0;

  /// Clips that fell back to Basic content because the model failed.
  int fallbacks = 0;

  /// Tokens the provider reported for this run (cache hits cost nothing).
  int inputTokens = 0, outputTokens = 0;

  /// From the catalog price of the model; null when it has no price.
  double? costUsd;
  Course? course;
  String? error;

  void _changed() => notifyListeners();

  void _set(GenerationStage s) {
    stage = s;
    notifyListeners();
  }
}

/// Turns any saved transcript into a V3 course: D1 sentences → D2 windows →
/// (L1 selection) → D3 candidates → (L2 plans | Basic) → D4 compile and
/// validate → saved in the library, where D5 quiz/dictation already work.
class CourseGenerationService {
  CourseGenerationService({
    required this.live,
    required this.app,
    required this.providers,
    required this.cache,
    required this.loadLexicon,
    this._modelFor,
  });

  final LiveRepository live;
  final AppController app;
  final ProviderRepository providers;
  final LlmCacheStore cache;
  final Future<Lexicon> Function() loadLexicon;
  final JsonModel Function(LlmProvider provider, String? apiKey)? _modelFor;
  Lexicon? _lexicon;

  static String courseIdFor(String sessionId) => 'gen-$sessionId';

  /// `preferences` flags from the learner profile (learner.json), as plain
  /// phrases: `prefer_common_words: true` → "prefer common words". Only
  /// fixed-shape keys are used; values are never copied into the prompt.
  List<String> get learnerPreferences {
    final raw = app.state.settings[AppController.learnerProfileKey];
    if (raw == null) return const [];
    try {
      final json = jsonDecode(raw);
      final prefs = json is Map ? json['preferences'] : null;
      if (prefs is! Map) return const [];
      return [
        for (final e in prefs.entries)
          if (e.value == true &&
              e.key is String &&
              RegExp(r'^(prefer|avoid)_[a-z_]{3,40}$').hasMatch(e.key as String))
            (e.key as String).replaceAll('_', ' '),
      ];
    } on FormatException {
      return const [];
    }
  }

  String get learnerLevel {
    final raw = app.state.settings[AppController.learnerProfileKey];
    if (raw == null) return 'B2';
    try {
      final json = jsonDecode(raw);
      final level = json is Map && json['english_level'] is Map
          ? (json['english_level'] as Map)['approximate_cefr']
          : null;
      return level is String && RegExp(r'^[ABC][12]$').hasMatch(level) ? level : 'B2';
    } on FormatException {
      return 'B2';
    }
  }

  Future<JsonModel> _model(LlmProvider provider) async {
    final key = await providers.apiKey(provider.id);
    final make = _modelFor;
    if (make != null) return make(provider, key);
    return ClientJsonModel(provider.id, await providers.client(provider));
  }

  /// Model output problems degrade to null; unreachable providers and
  /// rejected keys stop the run (every later call would fail too).
  static Future<T?> _soft<T>(Future<T?> Function() call) async {
    try {
      return await call();
    } on LlmException catch (e) {
      // A refusal or a cut-off reply concerns this clip only.
      if (e.refused || e.truncated) return null;
      if (e.unauthorized || e.status == null || e.status == 429 || e.status! >= 500) rethrow;
      return null;
    } on FormatException {
      return null;
    }
  }

  GenerationJob start(String sessionId, {LlmProvider? provider}) {
    final job = GenerationJob(sessionId, provider);
    _run(job);
    return job;
  }

  Future<void> _run(GenerationJob job) async {
    try {
      job.course = await _generate(job);
      job._set(GenerationStage.done);
    } catch (e) {
      job.error = '$e';
      job._set(GenerationStage.failed);
    }
  }

  /// D1–D3 for a session: sentences, scored windows and their candidates.
  Future<_Prepared> _prepare(String sessionId) async {
    final session = await live.session(sessionId);
    if (session == null) throw StateError('Session not found');
    final lines = await live.lines(sessionId);
    final lexicon = _lexicon ??= await loadLexicon();
    final level = learnerLevel;
    final sentences = sentencesFromLines([
      for (final l in lines)
        (
          segmentId: l.segmentId,
          text: l.text,
          startMs: l.startMs,
          endMs: l.endMs,
          wordsJson: l.wordsJson,
          translation: l.translation,
        ),
    ]).where((s) => s.text.isNotEmpty).toList();
    if (sentences.isEmpty) throw StateError('This transcript has no text yet');
    final windows = buildWindows(sentences);
    final known = <String>{
      for (final c in app.state.courses)
        if (c.id != courseIdFor(sessionId))
          for (final clip in c.clips)
            for (final item in clip.items)
              if (item.kind == 'words') lexicon.lookup(item.text)?.lemma ?? item.text.toLowerCase(),
    };
    final candidates = [
      for (final w in windows) candidatesFor(w, lexicon, level: level, known: known),
    ];
    for (var i = 0; i < windows.length; i++) {
      windows[i].score = candidates[i].density + (windows[i].durationMs >= 30000 ? 1 : 0);
    }
    return _Prepared(session, sentences, windows, candidates, level);
  }

  /// What an AI course from [sessionId] would roughly cost with [provider].
  Future<CostEstimate> estimate(String sessionId, LlmProvider provider) async {
    final p = await _prepare(sessionId);
    final picked = selectWindows(p.windows);
    return CostEstimate.forCourse(
      windows: p.windows.length,
      clips: picked.length,
      transcriptChars: picked.fold(0, (sum, i) => sum + p.windows[i].text.length),
      model: providers.modelInfo(provider),
    );
  }

  Future<Course> _generate(GenerationJob job) async {
    final p = await _prepare(job.sessionId);
    final session = p.session, sentences = p.sentences, windows = p.windows;
    final candidates = p.candidates, level = p.level;
    final preferences = learnerPreferences;
    final mediaId = session.mediaId;
    final media = mediaId == null ? null : await live.media(mediaId);

    final provider = job.provider;
    final model = provider == null ? null : CachedJsonModel(await _model(provider), cache);
    final info = provider == null ? null : providers.modelInfo(provider);
    void count() {
      job.requests = model?.requests ?? 0;
      final usage = model?.usage;
      if (usage == null) return;
      job.inputTokens = usage.inputTokens;
      job.outputTokens = usage.outputTokens;
      job.costUsd = info != null && info.priced
          ? info.cost(usage.inputTokens, usage.outputTokens)
          : null;
    }

    // L1 (optional): the model picks clips; rule-based selection otherwise.
    job._set(GenerationStage.selecting);
    var picked = selectWindows(windows);
    Map<String, Object?>? overview;
    if (model != null && windows.length > picked.length) {
      final choice = await _soft(
        () => selectWithModel(model, windows, picked.length, level: level),
      );
      count();
      if (choice != null) {
        picked = choice.indices;
        overview = choice.overview;
      }
    }

    // D3 + L2 / Basic.
    job.clipsTotal = picked.length;
    job._set(GenerationStage.planning);
    final plans = <ClipPlan>[];
    for (final i in picked) {
      ClipPlan? plan;
      if (model != null) {
        // A clip the model fails on gets Basic content; one bad reply does
        // not lose the course.
        plan = await _soft(
          () => planWithModel(
            model,
            windows[i],
            candidates[i],
            level: level,
            preferences: preferences,
          ),
        );
        count();
        if (plan == null) job.fallbacks++;
      }
      plans.add(plan ?? basicPlan(windows[i], candidates[i]));
      job.clipsDone++;
      job._changed();
    }

    // D4.
    job._set(GenerationStage.compiling);
    final input = GenerationInput(
      courseId: courseIdFor(job.sessionId),
      title: session.title,
      sentences: sentences,
      learnerLevel: level,
      sourceLabel: provider == null
          ? 'Basic course from your transcript'
          : 'Generated with ${provider.label}',
    );
    final json = compileCourse(
      input,
      [for (final i in picked) windows[i]],
      plans,
      overview: overview,
    );
    if (provider == null) json['tinglang_generator'] = 'basic';
    final course = validateCompiled(
      json,
      mediaPath: media?.relPath,
      sourceLabel: input.sourceLabel,
    );
    await app.upsertCourse(course);
    return course;
  }
}

class _Prepared {
  _Prepared(this.session, this.sentences, this.windows, this.candidates, this.level);
  final SessionRow session;
  final List<GenSentence> sentences;
  final List<ClipWindow> windows;
  final List<ClipCandidates> candidates;
  final String level;
}
