import 'package:flutter_test/flutter_test.dart';
import 'package:tinglang/core/fsrs.dart';

/// Vectors generated with py-fsrs 6.3.2:
/// Scheduler(learning_steps=(), relearning_steps=(), enable_fuzzing=False),
/// each review made exactly when due unless a gap in days is given.
const vectors = {
  'good_x4': [
    (3, 0, 2.3065, 2.1181, 2),
    (3, null, 10.9643, 2.1112, 11),
    (3, null, 46.2802, 2.1043, 46),
    (3, null, 162.8622, 2.0975, 163),
  ],
  'again_then_good': [
    (1, 0, 0.212, 6.4133, 1),
    (3, 1, 1.8868, 6.4021, 2),
    (3, null, 6.2692, 6.3909, 6),
    (1, null, 1.0634, 8.799, 1),
    (3, 1, 2.2575, 8.7854, 2),
  ],
  'hard_easy': [
    (2, 0, 1.2931, 5.1122, 1),
    (4, null, 7.3855, 3.4641, 7),
    (2, null, 19.821, 5.6464, 20),
  ],
  'easy_first': [(4, 0, 8.2956, 1.0, 8), (1, null, 1.3886, 7.027, 1), (3, 2, 5.0004, 7.0152, 5)],
};

void main() {
  for (final MapEntry(key: name, value: steps) in vectors.entries) {
    test('matches py-fsrs 6.3.2: $name', () {
      double? s, d;
      DateTime? last, due;
      var now = DateTime.utc(2026, 10, 21, 9);
      for (final (rating, gap, wantS, wantD, wantDays) in steps) {
        now = gap == null ? due! : now.add(Duration(days: gap));
        final r = Fsrs.review(
          stability: s,
          difficulty: d,
          lastReview: last,
          rating: rating,
          now: now,
        );
        expect(r.stability, closeTo(wantS, 1e-3), reason: '$name S');
        expect(r.difficulty, closeTo(wantD, 1e-3), reason: '$name D');
        expect(r.intervalDays, wantDays, reason: '$name interval');
        s = r.stability;
        d = r.difficulty;
        last = now;
        due = r.due;
      }
    });
  }

  test('same-day review uses short-term stability and never shrinks on success', () {
    final first = Fsrs.review(rating: 3, now: DateTime.utc(2026));
    final again = Fsrs.review(
      stability: first.stability,
      difficulty: first.difficulty,
      lastReview: DateTime.utc(2026),
      rating: 3,
      now: DateTime.utc(2026, 1, 1, 6),
    );
    expect(again.stability, greaterThanOrEqualTo(first.stability));
  });
}
