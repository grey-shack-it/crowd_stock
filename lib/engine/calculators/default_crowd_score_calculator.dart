import 'crowd_score_calculator.dart';

class DefaultCrowdScoreCalculator implements CrowdScoreCalculator {
  const DefaultCrowdScoreCalculator();

  @override
  double calculate({
    required double baseParticipationScore,
    required double brokerSpreadScore,
    required double investorSpreadScore,
  }) {
    final spreadScore = (brokerSpreadScore + investorSpreadScore) / 2.0;

    return (baseParticipationScore + spreadScore) / 2.0;
  }
}
