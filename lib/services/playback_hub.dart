import 'media_session.dart';

/// 原声与自己的录音分别保留位置，但不同时播放；录音前暂停两者。
/// Native players are created on first use, not at startup.
class PlaybackHub {
  MediaSession? _lesson, _voice;
  MediaSession get lesson => _lesson ??= MediaSession();
  MediaSession get voice => _voice ??= (MediaSession()..setLoop(false));
  String? voicePath;
  Future<void> pauseAll() async {
    await _lesson?.pause();
    await _voice?.pause();
  }

  Future<void> playVoice(String path) async {
    await _lesson?.pause();
    if (voicePath != path) {
      await voice.open(path, 0, null);
      voicePath = path;
    }
    await voice.toggle();
  }

  Future<void> toggleLesson() async {
    await _voice?.pause();
    await lesson.toggle();
  }

  void dispose() {
    _lesson?.dispose();
    _voice?.dispose();
  }
}
