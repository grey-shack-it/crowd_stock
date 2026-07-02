class CrowdEngineResult {
  final double scaleScore;
  final double accelerationScore;
  final double baseParticipationScore;

  final double brokerSpreadScore;
  final double investorSpreadScore;

  final double confidenceMultiplier;
  final double crowdScore;

  const CrowdEngineResult({
    required this.scaleScore,
    required this.accelerationScore,
    required this.baseParticipationScore,
    required this.brokerSpreadScore,
    required this.investorSpreadScore,
    required this.confidenceMultiplier,
    required this.crowdScore,
  });
}

enum ConfidenceLevel { veryLow, low, normal, high, veryHigh }
