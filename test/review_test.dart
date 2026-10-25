import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/review.dart';

void main() {
  final now = DateTime.utc(2026, 9, 22, 12);
  ReviewCard card() =>
      ReviewCard(id: 'x', courseId: 'c', clipId: 'a', text: 'show up', meaning: '坚持参与', dueAt: now);

  test('first Good schedules by FSRS-6 initial stability (2 days)', () {
    final first = card().rate(Recall.good, now);
    expect(first.dueAt, now.add(const Duration(days: 2)));
    expect(first.stability, closeTo(2.3065, 1e-4));
    expect(first.repetitions, 1);
  });

  test('reviews made on time grow the interval; Again shrinks it', () {
    final first = card().rate(Recall.good, now);
    final second = first.rate(Recall.good, first.dueAt);
    expect(second.dueAt.difference(first.dueAt).inDays, 11);
    final lapse = second.rate(Recall.again, second.dueAt);
    expect(lapse.dueAt.difference(second.dueAt).inDays, lessThan(11));
    expect(lapse.history, hasLength(3));
  });

  test('previewDays labels each rating without changing the card', () {
    final c = card();
    expect([for (final r in Recall.values) c.previewDays(r, now)], [1, 1, 2, 8]);
    expect(c.stability, isNull);
  });

  test('FSRS state and history survive JSON serialization', () {
    final reviewed = card().rate(Recall.easy, now);
    final restored = ReviewCard.fromJson(reviewed.toJson());
    expect(restored.dueAt, reviewed.dueAt);
    expect(restored.stability, reviewed.stability);
    expect(restored.difficulty, reviewed.difficulty);
    expect(restored.history.single['rating'], 'easy');
    expect(restored.lastReview, now);
  });
}
