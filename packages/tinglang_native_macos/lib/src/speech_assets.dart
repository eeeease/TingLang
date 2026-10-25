import 'dart:async';

import 'package:flutter/services.dart';
import 'package:tinglang_platform_interface/tinglang_platform_interface.dart';

import 'host_api.g.dart';
import 'live.dart';

/// Apple's system speech models (SpeechTranscriber and DictationTranscriber,
/// macOS 26+) per engine and locale, through `AssetInventory`. [locale] may
/// be a language (`en`) or a locale (`en-GB`).
final class MacSpeechAssetSupport implements SpeechAssetSupport {
  MacSpeechAssetSupport(this._api, this._events);
  final TinglangHostApi _api;
  final MacEvents _events;
  static var _counter = 0;

  @override
  Future<AssetState> status(String locale, SpeechEngine engine) async => _asset(
    await _api.speechAssetStatusFor(defaultRecognitionLocale(locale), appleEngineName(engine)),
  );

  @override
  SpeechAssetInstall install(String locale, SpeechEngine engine) {
    final name = appleEngineName(engine);
    final requestId = 'assets-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
    return _MacSpeechAssetInstall(
      requestId,
      _api,
      _events.stream,
      _api.installSpeechAssetsFor(requestId, defaultRecognitionLocale(locale), name),
    );
  }

  @override
  Future<bool> release(String locale, SpeechEngine engine) =>
      _api.releaseSpeechAssets(defaultRecognitionLocale(locale), appleEngineName(engine));

  @override
  Future<SpeechLocaleInventory> inventory() async {
    final inventory = await _api.speechInventory();
    return SpeechLocaleInventory(
      speechSupported: inventory.speechSupported.toSet(),
      speechInstalled: inventory.speechInstalled.toSet(),
      dictationSupported: inventory.dictationSupported.toSet(),
      dictationInstalled: inventory.dictationInstalled.toSet(),
    );
  }

  static AssetState _asset(AssetStatus status) => switch (status) {
    AssetStatus.installed => AssetState.installed,
    AssetStatus.supported => AssetState.downloadable,
    AssetStatus.unsupported => AssetState.unsupported,
  };
}

/// Thrown by [SpeechAssetInstall.done] after [SpeechAssetInstall.cancel].
final class SpeechAssetInstallCanceled implements Exception {
  const SpeechAssetInstallCanceled();
  @override
  String toString() => 'Cancelled the speech model download';
}

final class _MacSpeechAssetInstall implements SpeechAssetInstall {
  _MacSpeechAssetInstall(this._requestId, this._api, Stream<LiveEvent> events, Future<void> call) {
    _sub = events
        .where((e) => e.kind == 'assetProgress' && e.sessionId == _requestId)
        .listen((e) => _progress.add((e.level ?? 0).clamp(0, 1).toDouble()));
    call.then(
      (_) => _finish(null),
      onError: (Object e, StackTrace s) => _finish(
        e is PlatformException && e.code == 'canceled' ? const SpeechAssetInstallCanceled() : e,
        s,
      ),
    );
  }

  final String _requestId;
  final TinglangHostApi _api;
  late final StreamSubscription<LiveEvent> _sub;
  final _progress = StreamController<double>.broadcast();
  final _done = Completer<void>();

  @override
  Stream<double> get progress => _progress.stream;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> cancel() async {
    if (_done.isCompleted) return;
    await _api.cancelSpeechAssets(_requestId);
  }

  Future<void> _finish(Object? error, [StackTrace? stack]) async {
    // Events are delivered before the reply; let the last ones through.
    await Future<void>.delayed(Duration.zero);
    await _sub.cancel();
    await _progress.close();
    if (error == null) {
      _done.complete();
    } else {
      _done.completeError(error, stack);
    }
  }
}
