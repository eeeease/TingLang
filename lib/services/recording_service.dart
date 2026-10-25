import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../core/library_store.dart';

class RecordingResult {
  const RecordingResult(this.path, this.durationMs);
  final String path;
  final int durationMs;
}

/// 录音写在应用私有目录；权限失败与空录音是显式错误，不生成虚假成功记录。
class RecordingService extends ChangeNotifier {
  RecordingService(this.store);
  final LibraryStore store;
  final AudioRecorder _recorder = AudioRecorder();
  final Stopwatch _clock = Stopwatch();
  Timer? _timer;
  String? activeKey, _relative;
  bool recording = false, busy = false;
  int get elapsedMs => _clock.elapsedMilliseconds;
  bool get navigationLocked => recording || busy;

  Future<void> start(String key, {Future<void> Function()? beforeStart}) async {
    if (navigationLocked) throw StateError('A recording is already active.');
    busy = true;
    notifyListeners();
    try {
      if (beforeStart != null) await beforeStart();
      if (!await _recorder.hasPermission()) {
        throw StateError(
          'Microphone permission denied. Enable Tinglang in System Settings → Privacy & Security → Microphone.',
        );
      }
      final relative = await store.recordingDestination();
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 44100, numChannels: 1),
        path: store.resolve(relative),
      );
      activeKey = key;
      _relative = relative;
      recording = true;
      _clock.reset();
      _clock.start();
      _timer = Timer.periodic(const Duration(milliseconds: 300), (_) => notifyListeners());
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<RecordingResult> stop() async {
    if (!recording || busy) throw StateError('No active recording.');
    busy = true;
    notifyListeners();
    try {
      final absolute = await _recorder.stop();
      _clock.stop();
      _timer?.cancel();
      recording = false;
      final relative = _relative;
      if (absolute == null ||
          relative == null ||
          !await File(absolute).exists() ||
          await File(absolute).length() <= 44) {
        throw StateError('No usable audio was captured. Check your input device.');
      }
      return RecordingResult(relative, elapsedMs);
    } finally {
      busy = false;
      if (!recording) activeKey = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }
}
