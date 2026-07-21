import 'crowd_score_calculator.dart';

class DefaultCrowdScoreCalculator implements CrowdScoreCalculator {
  const DefaultCrowdScoreCalculator();

  @override
  double calculate({
    required double baseParticipationScore,
    required double confidenceMultiplier,
  }) {
    return baseParticipationScore * confidenceMultiplier;
  }
}
