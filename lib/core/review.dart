import 'fsrs.dart';
import 'json_helpers.dart';

enum Recall { again, hard, good, easy }

/// A review card scheduled with FSRS-6 (see fsrs.dart). The learner rates
/// their own recall; no pronunciation or AI scoring is implied.
class ReviewCard {
  const ReviewCard({
    required this.id,
    required this.courseId,
    required this.clipId,
    required this.text,
    required this.meaning,
    required this.dueAt,
    this.repetitions = 0,
    this.history = const [],
    this.stability,
    this.difficulty,
  });
  final String id, courseId, clipId, text, meaning;
  final DateTime dueAt;
  final int repetitions;
  final List<Map<String, Object?>> history;

  /// FSRS memory state; null until the first rating.
  final double? stability, difficulty;

  DateTime? get lastReview {
    for (final entry in history.reversed) {
      final at = entry['at'];
      if (at is String) return DateTime.tryParse(at)?.toUtc();
    }
    return null;
  }

  /// Days until the next review for each rating, for the button labels.
  int previewDays(Recall recall, DateTime now) => Fsrs.review(
    stability: stability,
    difficulty: difficulty,
    lastReview: lastReview,
    rating: recall.index + 1,
    now: now.toUtc(),
  ).intervalDays;

  ReviewCard rate(Recall recall, DateTime now) {
    final result = Fsrs.review(
      stability: stability,
      difficulty: difficulty,
      lastReview: lastReview,
      rating: recall.index + 1,
      now: now.toUtc(),
    );
    return ReviewCard(
      id: id,
      courseId: courseId,
      clipId: clipId,
      text: text,
      meaning: meaning,
      dueAt: result.due,
      repetitions: repetitions + 1,
      stability: result.stability,
      difficulty: result.difficulty,
      history: [
        ...history,
        {
          'at': now.toUtc().toIso8601String(),
          'rating': recall.name,
          's': double.parse(result.stability.toStringAsFixed(4)),
          'd': double.parse(result.difficulty.toStringAsFixed(4)),
        },
      ],
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'courseId': courseId,
    'clipId': clipId,
    'text': text,
    'meaning': meaning,
    'dueAt': dueAt.toUtc().toIso8601String(),
    'repetitions': repetitions,
    'history': history,
    if (stability != null) 'stability': stability,
    if (difficulty != null) 'difficulty': difficulty,
  };
  factory ReviewCard.fromJson(Map<String, Object?> j) => ReviewCard(
    id: jsonString(j['id'], 'review.id'),
    courseId: jsonString(j['courseId'], 'review.courseId'),
    clipId: jsonString(j['clipId'], 'review.clipId'),
    text: jsonString(j['text'], 'review.text'),
    meaning: jsonString(j['meaning'], 'review.meaning', fallback: ''),
    dueAt: DateTime.parse(jsonString(j['dueAt'], 'review.dueAt')),
    repetitions: jsonInt(j['repetitions'], 'repetitions', fallback: 0),
    stability: (j['stability'] as num?)?.toDouble(),
    difficulty: (j['difficulty'] as num?)?.toDouble(),
    history: jsonList(
      j['history'] ?? <Object?>[],
      'review.history',
    ).map((value) => jsonObject(value, 'history item')).toList(),
  );
}
