import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tinglang_ui/tinglang_ui.dart';

import '../core/models.dart';
import '../core/providers/provider_repository.dart';
import '../services/course_generation.dart';
import 'brand.dart';

/// Chooses Basic (offline, dictionary-based) or AI (a BYOK provider), shows
/// progress and returns the finished course.
Future<Course?> showMakeCourseSheet(
  BuildContext context, {
  required CourseGenerationService generation,
  required String sessionId,
}) => showDialog<Course>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _MakeCourseDialog(generation: generation, sessionId: sessionId),
);

class _MakeCourseDialog extends StatefulWidget {
  const _MakeCourseDialog({required this.generation, required this.sessionId});
  final CourseGenerationService generation;
  final String sessionId;
  @override
  State<_MakeCourseDialog> createState() => _MakeCourseDialogState();
}

class _MakeCourseDialogState extends State<_MakeCourseDialog> {
  List<LlmProvider> _providers = const [];
  String? _providerId;
  bool _ai = false, _consent = false, _loaded = false;
  GenerationJob? _job;
  CostEstimate? _estimate;
  String? _estimateFor;

  bool get _exists => widget.generation.app.state.courses.any(
    (c) => c.id == CourseGenerationService.courseIdFor(widget.sessionId),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final all = (await widget.generation.providers.list()).where((p) => p.enabled).toList();
    final routed = await widget.generation.providers.routed(Features.courseGeneration);
    if (!mounted) return;
    setState(() {
      _providers = all;
      _providerId = routed?.id ?? all.firstOrNull?.id;
      _ai = _providerId != null;
      _loaded = true;
    });
    unawaited(_estimateCost());
  }

  /// Rough token use and price for the chosen provider, from the catalog.
  Future<void> _estimateCost() async {
    final provider = _provider;
    if (provider == null || _estimateFor == '${provider.id}/${provider.model}') return;
    _estimateFor = '${provider.id}/${provider.model}';
    try {
      final estimate = await widget.generation.estimate(widget.sessionId, provider);
      if (mounted && _estimateFor == '${provider.id}/${provider.model}') {
        setState(() => _estimate = estimate);
      }
    } catch (_) {
      // The estimate is advisory; generation reports real errors.
    }
  }

  String _estimateText(BuildContext context, LlmProvider provider) {
    final l = context.l10n;
    final e = _estimate;
    if (e == null) return '';
    final usd = e.usd;
    final cost = !provider.cloud
        ? l.makeCourseLocalFree
        : usd == null
        ? l.makeCourseNoPrice
        : l.makeCourseAbout(formatUsd(usd));
    return l.makeCourseEstimate(
      e.calls,
      formatTokens(e.inputTokens),
      formatTokens(e.outputTokens),
      cost,
    );
  }

  LlmProvider? get _provider => _providers.where((p) => p.id == _providerId).firstOrNull;

  void _start() {
    final job = widget.generation.start(widget.sessionId, provider: _ai ? _provider : null);
    job.addListener(() {
      if (mounted) setState(() {});
    });
    setState(() => _job = job);
  }

  String _stage(GenerationJob job) {
    final l = context.l10n;
    return switch (job.stage) {
      GenerationStage.reading => l.makeCourseReading,
      GenerationStage.selecting => l.makeCourseSelecting,
      GenerationStage.planning => l.makeCoursePlanning(
        (job.clipsDone + 1).clamp(1, job.clipsTotal),
        job.clipsTotal,
      ),
      GenerationStage.compiling => l.makeCourseCompiling,
      GenerationStage.done => l.makeCourseDone(job.course?.clips.length ?? 0),
      GenerationStage.failed => job.error ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.sl;
    final job = _job;
    final provider = _provider;
    final needsConsent = _ai && provider != null && provider.cloud;
    final running =
        job != null && job.stage != GenerationStage.done && job.stage != GenerationStage.failed;
    return AlertDialog(
      title: Text(l.makeCourse),
      content: SizedBox(
        width: 480,
        child: job != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (running)
                    LinearProgressIndicator(
                      value: job.stage == GenerationStage.planning && job.clipsTotal > 0
                          ? job.clipsDone / job.clipsTotal
                          : null,
                    ),
                  const SizedBox(height: 14),
                  job.stage == GenerationStage.failed
                      ? SlNotice(l.makeCourseFailed(job.error ?? ''), error: true)
                      : Text(_stage(job)),
                  if (job.provider != null && job.stage == GenerationStage.done) ...[
                    const SizedBox(height: 8),
                    Text(
                      [
                        l.makeCourseRequests(job.requests),
                        if (job.inputTokens + job.outputTokens > 0)
                          l.makeCourseTokens(
                            formatTokens(job.inputTokens),
                            formatTokens(job.outputTokens),
                          ),
                        if (job.costUsd != null && job.requests > 0)
                          l.makeCourseAbout(formatUsd(job.costUsd!)),
                        if (job.fallbacks > 0) l.makeCourseFallbacks(job.fallbacks),
                      ].join(' · '),
                      key: const ValueKey('make-usage'),
                      style: TextStyle(color: c.muted, fontSize: 13),
                    ),
                  ],
                ],
              )
            : !_loaded
            ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator.adaptive()))
            : RadioGroup<bool>(
                groupValue: _ai,
                onChanged: (v) => setState(() => _ai = v ?? false),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RadioListTile<bool>(
                      key: const ValueKey('make-basic'),
                      value: false,
                      title: Text(l.makeCourseBasic),
                      subtitle: Text(l.makeCourseBasicBody),
                    ),
                    RadioListTile<bool>(
                      key: const ValueKey('make-ai'),
                      value: true,
                      enabled: _providers.isNotEmpty,
                      title: Text(l.makeCourseAi),
                      subtitle: Text(
                        _providers.isEmpty ? l.makeCourseNoProvider : l.makeCourseAiBody,
                      ),
                    ),
                    if (_ai && _providers.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: DropdownButtonFormField<String>(
                          initialValue: _providerId,
                          decoration: InputDecoration(labelText: l.makeCourseProvider),
                          items: [
                            for (final p in _providers)
                              DropdownMenuItem(value: p.id, child: Text('${p.label} · ${p.model}')),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _providerId = v;
                              _consent = false;
                              _estimate = null;
                            });
                            unawaited(_estimateCost());
                          },
                        ),
                      ),
                      if (provider != null && _estimate != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text(
                            _estimateText(context, provider),
                            key: const ValueKey('make-estimate'),
                            style: TextStyle(color: c.muted, fontSize: 13),
                          ),
                        ),
                      if (needsConsent)
                        CheckboxListTile(
                          key: const ValueKey('make-consent'),
                          value: _consent,
                          onChanged: (v) => setState(() => _consent = v ?? false),
                          title: Text(
                            l.makeCourseConsent(
                              Uri.tryParse(provider.baseUrl)?.host ?? provider.baseUrl,
                            ),
                          ),
                          secondary: const Icon(Icons.cloud_outlined),
                        ),
                    ],
                    if (_exists) ...[const SizedBox(height: 8), SlNotice(l.makeCourseReplace)],
                  ],
                ),
              ),
      ),
      actions: [
        if (job == null) ...[
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
          FilledButton(
            key: const ValueKey('make-start'),
            onPressed: !_loaded || (needsConsent && !_consent) || (_ai && provider == null)
                ? null
                : _start,
            child: Text(l.makeCourseStart),
          ),
        ] else if (job.stage == GenerationStage.done)
          FilledButton(
            key: const ValueKey('make-open'),
            onPressed: () => Navigator.pop(context, job.course),
            child: Text(l.makeCourseOpen),
          )
        else if (job.stage == GenerationStage.failed)
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close))
        else
          const SizedBox.shrink(),
      ],
    );
  }
}
