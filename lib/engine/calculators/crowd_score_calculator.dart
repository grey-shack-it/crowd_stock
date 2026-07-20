abstract class CrowdScoreCalculator {
  double calculate({
    required double baseParticipationScore,
    required double brokerSpreadScore,
    required double investorSpreadScore,
  });
}
