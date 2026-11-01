import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/models.dart';

void main() {
  test('courses made before the rename keep their YouTube video', () {
    final course = Course(
      id: 'lex-276',
      title: 'Bitcoin, Inflation, and the Future of Money',
      area: Area.podcasts,
      clips: const [],
      raw: const {'sayloom_youtube_id': 'dQw4w9WgXcQ'},
      importedAt: DateTime.utc(2026, 10, 1),
    );
    expect(course.youtubeId, 'dQw4w9WgXcQ');
    expect(course.playsOnline, isTrue);
  });
}
