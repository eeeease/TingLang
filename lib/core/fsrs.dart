import 'dart:math' as math;

/// FSRS-6 memory model with the default 21 parameters, matching the
/// reference scheduler py-fsrs 6.3.2 configured without learning or
/// relearning steps and without fuzzing (see test/fsrs_test.dart).
abstract final class Fsrs {
  static const w = [
    0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666, 0.796, //
    1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542,
  ];
  static const desiredRetention = 0.9;
  static const maximumInterval = 36500;
  static final double _decay = -w[20];
  static final double _factor = math.pow(0.9, 1 / _decay) - 1;

  static double _clampD(double d) => d.clamp(1.0, 10.0);
  static double _clampS(double s) => s < 0.001 ? 0.001 : s;

  static double _initialDifficulty(int rating) => w[4] - math.exp(w[5] * (rating - 1)) + 1;

  /// Probability of recall after [elapsedDays] whole days.
  static double retrievability(double stability, int elapsedDays) =>
      math.pow(1 + _factor * math.max(0, elapsedDays) / stability, _decay).toDouble();

  /// Days until retrievability falls to [desiredRetention] (≥ 1).
  static int interval(double stability) {
    final days = stability / _factor * (math.pow(desiredRetention, 1 / _decay) - 1);
    return _roundHalfEven(days).clamp(1, maximumInterval);
  }

  // Python's round(): halves go to the even neighbour.
  static int _roundHalfEven(double x) {
    final floor = x.floorToDouble();
    final diff = x - floor;
    if (diff > .5) return floor.toInt() + 1;
    if (diff < .5) return floor.toInt();
    return floor.toInt().isEven ? floor.toInt() : floor.toInt() + 1;
  }

  static double _nextDifficulty(double d, int rating) {
    final delta = -(w[6] * (rating - 3));
    final damped = d + (10 - d) * delta / 9;
    return _clampD(w[7] * _initialDifficulty(4) + (1 - w[7]) * damped);
  }

  static double _shortTermStability(double s, int rating) {
    var increase = math.exp(w[17] * (rating - 3 + w[18])) * math.pow(s, -w[19]);
    if (rating >= 2) increase = math.max(increase, 1.0);
    return _clampS(s * increase);
  }

  static double _recallStability(double d, double s, double r, int rating) {
    final hardPenalty = rating == 2 ? w[15] : 1.0;
    final easyBonus = rating == 4 ? w[16] : 1.0;
    return s *
        (1 +
            math.exp(w[8]) *
                (11 - d) *
                math.pow(s, -w[9]) *
                (math.exp((1 - r) * w[10]) - 1) *
                hardPenalty *
                easyBonus);
  }

  static double _forgetStability(double d, double s, double r) => math.min(
    w[11] * math.pow(d, -w[12]) * (math.pow(s + 1, w[13]) - 1) * math.exp((1 - r) * w[14]),
    s / math.exp(w[17] * w[18]),
  );

  /// Applies one rating (1 again, 2 hard, 3 good, 4 easy) at [now].
  static FsrsResult review({
    double? stability,
    double? difficulty,
    DateTime? lastReview,
    required int rating,
    required DateTime now,
  }) {
    assert(rating >= 1 && rating <= 4);
    double s, d;
    if (stability == null || difficulty == null) {
      s = _clampS(w[rating - 1]);
      d = _clampD(_initialDifficulty(rating));
    } else {
      final days = lastReview == null ? 0 : now.difference(lastReview).inDays;
      if (lastReview != null && days < 1) {
        s = _shortTermStability(stability, rating);
      } else {
        final r = retrievability(stability, days);
        s = _clampS(
          rating == 1
              ? _forgetStability(difficulty, stability, r)
              : _recallStability(difficulty, stability, r, rating),
        );
      }
      d = _nextDifficulty(difficulty, rating);
    }
    final days = interval(s);
    return FsrsResult(s, d, days, now.add(Duration(days: days)));
  }
}

class FsrsResult {
  const FsrsResult(this.stability, this.difficulty, this.intervalDays, this.due);
  final double stability, difficulty;
  final int intervalDays;
  final DateTime due;
}
