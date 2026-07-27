class CrowdEngineResult {
  final double scaleScore;
  final double accelerationScore;
  final double baseParticipationScore;

  final double brokerSpreadScore;
  final double investorSpreadScore;
  final double programScore; // 프로그램매매(차익+비차익 합계) percentile

  final double participationSpreadScore;
  final double confidenceMultiplier;

  final double crowdScore;

  const CrowdEngineResult({
    required this.scaleScore,
    required this.accelerationScore,
    required this.baseParticipationScore,
    required this.brokerSpreadScore,
    required this.investorSpreadScore,
    required this.programScore,
    required this.participationSpreadScore,
    required this.confidenceMultiplier,
    required this.crowdScore,
  });
}
