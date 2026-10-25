import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 单播放器、串行装载和 session token，避免快速切换片段时旧 seek 覆盖新范围。
class MediaSession extends ChangeNotifier {
  MediaSession() {
    video = VideoController(player);
    _subscriptions.addAll([
      player.stream.position.listen((value) {
        positionMs = value.inMilliseconds;
        _enforceBoundary();
        _notify();
      }),
      player.stream.duration.listen((value) {
        durationMs = value.inMilliseconds;
        if (!loading) _validateBounds();
        _notify();
      }),
      player.stream.completed.listen((completed) {
        if (completed && !loading && loop && ready) _restartAtEnd();
      }),
      player.stream.playing.listen((value) {
        playing = value;
        _notify();
      }),
      player.stream.error.listen((value) {
        error = value;
        _notify();
      }),
    ]);
  }
  final Player player = Player(configuration: const PlayerConfiguration(title: 'Tinglang'));
  late final VideoController video;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool playing = false, loading = false, loop = true;
  int positionMs = 0, durationMs = 0, startMs = 0;
  int? endMs;
  String? error, _path;

  /// The course clip lies outside the attached media; UI shows a localised
  /// explanation instead of [error].
  bool boundsMismatch = false;
  double rate = 1;

  /// 0–100, as media_kit counts it; kept for every file this session opens.
  double volume = 100;

  /// Volume before [toggleMute] silenced the player.
  double _unmutedVolume = 100;
  int _token = 0;
  bool _disposed = false, _boundaryBusy = false;
  Future<void> _loadTail = Future.value();
  int get effectiveEnd => endMs ?? durationMs;
  bool get ready => _path != null && !loading && error == null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> open(String path, int start, int? end) {
    final token = ++_token;
    loading = true;
    error = null;
    boundsMismatch = false;
    _notify();
    final work = _loadTail.then((_) async {
      if (_disposed || token != _token) return;
      await player.pause();
      if (_path != path) {
        durationMs = 0;
        positionMs = start;
        _path = null;
        await player.open(Media(path), play: false);
        // 记录播放器的真实装载状态，即使本次请求已过期；否则 A→B→A 可能误播 B。
        _path = path;
        if (_disposed || token != _token) return;
      }
      startMs = start;
      endMs = end;
      if (durationMs > 0 && start >= durationMs) {
        boundsMismatch = true;
        throw const FormatException('Clip starts after the media ends.');
      }
      await player.seek(Duration(milliseconds: start));
      if (_disposed || token != _token) return;
      await player.setRate(rate);
      await player.setVolume(volume);
      loading = false;
      _validateBounds();
      _notify();
    });
    _loadTail = work.then<void>(
      (_) {},
      onError: (Object e, StackTrace s) {
        if (!_disposed && token == _token) {
          loading = false;
          error = e.toString();
          _notify();
        }
      },
    );
    // 错误通过状态展示；避免用户点击触发未处理 Future 异常。
    return _loadTail;
  }

  Future<void> toggle() async {
    if (!ready) return;
    try {
      if (playing) {
        await player.pause();
        return;
      }
      if (positionMs < startMs || (effectiveEnd > 0 && positionMs >= effectiveEnd - 40)) {
        await player.seek(Duration(milliseconds: startMs));
      }
      await player.play();
    } catch (e) {
      error = e.toString();
      _notify();
    }
  }

  Future<void> pause() => player.pause();
  Future<void> seek(int ms) async {
    final maximum = effectiveEnd > startMs ? effectiveEnd : startMs;
    try {
      await player.seek(Duration(milliseconds: ms.clamp(startMs, maximum).toInt()));
    } catch (e) {
      error = e.toString();
      _notify();
    }
  }

  Future<void> setVolume(double value) async {
    final next = value.clamp(0.0, 100.0).toDouble();
    try {
      await player.setVolume(next);
      volume = next;
      if (next > 0) _unmutedVolume = next;
      _notify();
    } catch (e) {
      error = e.toString();
      _notify();
    }
  }

  /// Silences the player, or brings back the volume it had.
  Future<void> toggleMute() => setVolume(volume > 0 ? 0 : _unmutedVolume);

  Future<void> setRate(double value) async {
    try {
      await player.setRate(value);
      rate = value;
      _notify();
    } catch (e) {
      error = e.toString();
      _notify();
    }
  }

  void setLoop(bool value) {
    loop = value;
    _notify();
  }

  void _validateBounds() {
    if (durationMs <= 0) return;
    final end = endMs;
    if (startMs >= durationMs || (end != null && end > durationMs + 250)) {
      boundsMismatch = true;
      error = 'Course times exceed the media duration.';
    }
  }

  void _restartAtEnd() {
    if (_disposed || _boundaryBusy || _path == null) return;
    _boundaryBusy = true;
    final token = _token;
    unawaited(() async {
      try {
        await player.seek(Duration(milliseconds: startMs));
        if (!_disposed && token == _token && loop) await player.play();
      } catch (e) {
        if (!_disposed) error = e.toString();
      } finally {
        _boundaryBusy = false;
        _notify();
      }
    }());
  }

  void _enforceBoundary() {
    if (_disposed ||
        loading ||
        _boundaryBusy ||
        !playing ||
        effectiveEnd <= startMs ||
        positionMs < effectiveEnd - 25) {
      return;
    }
    _boundaryBusy = true;
    final token = _token;
    unawaited(() async {
      try {
        if (loop) {
          await player.seek(Duration(milliseconds: startMs));
          if (!_disposed && token == _token) await player.play();
        } else {
          await player.pause();
        }
      } catch (e) {
        if (!_disposed) error = e.toString();
      } finally {
        _boundaryBusy = false;
        _notify();
      }
    }());
  }

  @override
  void dispose() {
    _disposed = true;
    ++_token;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    // 已排队的 open 完成以后才销毁 native player。
    unawaited(_loadTail.whenComplete(player.dispose));
    super.dispose();
  }
}
