import 'dart:async';
import 'dart:typed_data';

import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

/// Whether [translator] may be used for [pair]: it lists the pair, or the
/// probe reports the OS pack installed, or it lists no pairs at all (Apple
/// Translation only knows at call time; a failing call then counts as the
/// pack missing).
bool translatorReady(TranslatorBackend translator, LanguagePair pair, PlatformProbe probe) =>
    translator.pairs.isEmpty ||
    translator.pairs.contains(pair) ||
    probe.translationPairs.contains(pair);

/// Topology B: native capture → recogniser (sherpa-onnx in a worker isolate,
/// reading the capture's PCM ring) → app and caption panel, with optional
/// translation of finals. Everything is picked from [platform]'s registries.
final class PortablePipelineHost implements LivePipelineHost {
  PortablePipelineHost(this.platform);
  final TinglangPlatform platform;

  @override
  PipelineTopology get topology => PipelineTopology.portable;

  @override
  Future<LiveSession> start(LivePipelineConfig config) async {
    final probe = await platform.probe();
    final asrFactory =
        platform.liveAsr.byId(config.asrBackendId) ??
        (throw StateError('Unknown live recogniser ${config.asrBackendId}.'));
    final asrAvailability = asrFactory.availability(probe);
    if (asrAvailability is! Available) {
      throw StateError('${config.asrBackendId} cannot run: $asrAvailability');
    }
    final captures = config.source == AudioSourceKind.systemAudio
        ? platform.systemAudio
        : platform.microphone;
    final capture = pickCapture(captures, probe).create();

    TranslatorBackend? translator;
    LanguagePair? pair;
    var translationReady = false;
    final target = config.translateTo;
    if (target != null) {
      pair = LanguagePair(config.language, target);
      final choice = platform.translators.pick(probe, config.translatorBackendId);
      if (choice.hasSelection) {
        translator = choice.create();
        translationReady = translatorReady(translator, pair, probe);
      }
    }
    final overlay = config.showOverlay ? platform.overlays.pick(probe).selected?.create() : null;

    final source = await capture.open(AudioCaptureRequest(recordPath: config.recordPath));
    final AsrSession asr;
    try {
      // The ring exists once capture runs; it buffers until the worker
      // attaches.
      await source.start();
      final ring = source.ring;
      final tier = LatencyTiers.sherpa(config.speech.latency);
      asr = await asrFactory.create().start(
        AsrSessionConfig(
          language: config.language,
          source: ring != null && ring.address != 0 ? source : null,
          latency: config.speech.latency,
          endpointSilenceMs: tier.endpointSilenceMs,
          numThreads: tier.numThreads,
        ),
      );
    } on Object {
      await source.close();
      rethrow;
    }
    final session = PortableLiveSession._(
      source,
      asr,
      pair,
      translationReady ? translator : null,
      overlay,
    );
    if (pair != null && !translationReady) {
      // After the caller has subscribed.
      final missing = TranslationPackMissing('$pair');
      Timer.run(() {
        if (!session._issues.isClosed) session._issues.add(missing);
      });
    }
    return session;
  }
}

/// A live session of [PortablePipelineHost].
final class PortableLiveSession implements LiveSession {
  PortableLiveSession._(this._source, this._asr, this._pair, this._translator, this._overlay)
    : sessionId = 'portable-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}' {
    _subs.addAll([
      _asr.events.listen(
        _onEvent,
        onError: (Object e) =>
            _issues.add(e is AsrFailure ? RecognizerFailed(e) : CaptureFailed('$e')),
      ),
      _asr.stats.listen(_stats.add),
      _source.issues.listen(_issues.add),
      _source.levels.listen(_onLevel),
      if (_source.ring == null || _source.ring!.address == 0)
        if (_source.debugBlocks case final blocks?)
          blocks.listen(
            (Float32List block) => _asr.acceptWaveform(block, _source.format.sampleRate),
          ),
    ]);
  }

  /// Captions and the panel update at most this often.
  static const uiInterval = Duration(milliseconds: 100);

  @override
  final String sessionId;
  final NativeAudioSource _source;
  final AsrSession _asr;
  final LanguagePair? _pair;
  final TranslatorBackend? _translator;
  final CaptionOverlay? _overlay;
  final _subs = <StreamSubscription<Object?>>[];
  final _captions = StreamController<AsrEvent>.broadcast();
  final _translations = StreamController<SegmentTranslation>.broadcast();
  final _stats = StreamController<AsrStats>.broadcast();
  final _issues = StreamController<AudioCaptureIssue>.broadcast();
  final _levels = StreamController<double>.broadcast();

  /// Partials waiting for the next UI tick, by segment.
  final _pendingPartials = <String, AsrPartial>{};
  Timer? _uiTimer;
  DateTime _lastLevel = DateTime.fromMillisecondsSinceEpoch(0);

  /// The panel's tail: finals and the newest partial, ≤ 30 lines.
  final _tail = <CaptionLine>[];
  bool _tailDirty = false;
  final _toTranslate = <AsrFinal>[];
  Future<void>? _translating;
  bool _translationsOff = false;
  bool _stopped = false;

  @override
  PipelineTopology get topology => PipelineTopology.portable;
  @override
  Stream<AsrEvent> get captions => _captions.stream;
  @override
  Stream<SegmentTranslation> get translations => _translations.stream;
  @override
  Stream<AsrStats> get stats => _stats.stream;
  @override
  Stream<AudioCaptureIssue> get issues => _issues.stream;
  @override
  Stream<double> get levels => _levels.stream;

  void _onEvent(AsrEvent event) {
    switch (event) {
      case AsrPartial():
        _pendingPartials[event.segmentId] = event;
        _schedule();
      case AsrFinal():
        _pendingPartials.remove(event.segmentId);
        _captions.add(event);
        _setLine(CaptionLine(segmentId: event.segmentId, text: event.text, isFinal: true));
        if (_translator != null && !_translationsOff) {
          _toTranslate.add(event);
          _translating ??= _translateQueued();
        }
      case AsrGap():
        _captions.add(event);
    }
  }

  void _schedule() => _uiTimer ??= Timer(uiInterval, _tick);

  void _tick() {
    _uiTimer = null;
    for (final partial in _pendingPartials.values) {
      _captions.add(partial);
      _setLine(CaptionLine(segmentId: partial.segmentId, text: partial.text));
    }
    _pendingPartials.clear();
    final overlay = _overlay;
    if (_tailDirty && overlay != null) {
      _tailDirty = false;
      overlay.pushTail(List.unmodifiable(_tail));
    }
  }

  void _setLine(CaptionLine line) {
    if (_overlay == null) return;
    final index = _tail.indexWhere((l) => l.segmentId == line.segmentId);
    if (index >= 0) {
      _tail[index] = CaptionLine(
        segmentId: line.segmentId,
        text: line.text,
        translation: line.translation ?? _tail[index].translation,
        isFinal: line.isFinal,
      );
    } else {
      _tail.add(line);
      if (_tail.length > CaptionOverlay.maxTailLines) _tail.removeAt(0);
    }
    _tailDirty = true;
    _schedule();
  }

  /// Translates queued finals one batch at a time (never partials).
  Future<void> _translateQueued() async {
    final translator = _translator!;
    final pair = _pair!;
    while (_toTranslate.isNotEmpty) {
      final batch = List.of(_toTranslate);
      _toTranslate.clear();
      try {
        final texts = await translator.translate([for (final f in batch) f.text], pair);
        for (var i = 0; i < batch.length && i < texts.length; i++) {
          if (_translations.isClosed) return;
          _translations.add(SegmentTranslation(batch[i].segmentId, pair, texts[i]));
          _setLine(
            CaptionLine(
              segmentId: batch[i].segmentId,
              text: batch[i].text,
              translation: texts[i],
              isFinal: true,
            ),
          );
        }
      } on Object {
        // A translator that cannot list its pairs fails when the pack is
        // missing: say so once and stop asking. Otherwise skip this batch.
        if (translator.pairs.isEmpty) {
          _translationsOff = true;
          _toTranslate.clear();
          if (!_issues.isClosed) _issues.add(TranslationPackMissing('$pair'));
        }
      }
    }
    _translating = null;
  }

  void _onLevel(AudioLevel level) {
    final now = DateTime.now();
    if (now.difference(_lastLevel) < uiInterval) return;
    _lastLevel = now;
    _levels.add(level.rms.clamp(0.0, 1.0));
  }

  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    await _source.stop();
    // The recogniser drains what the capture produced and flushes the line.
    await _asr.stop();
    _uiTimer?.cancel();
    _tick();
    await _translating;
    for (final sub in _subs) {
      await sub.cancel();
    }
    await _source.close();
    for (final c in [_captions, _translations, _stats, _issues, _levels]) {
      await c.close();
    }
  }
}
