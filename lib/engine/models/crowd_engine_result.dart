class CrowdEngineResult {
  final double scaleScore;
  final double accelerationScore;
  final double baseParticipationScore;

  final double brokerSpreadScore;
  final double investorSpreadScore;
  final double nonArbitrageScore;
  final double arbitrageScore;

  final double participationSpreadScore;
  final double confidenceMultiplier;

  final double crowdScore;

  final ProgramInterpretation programInterpretation;

  const CrowdEngineResult({
    required this.scaleScore,
    required this.accelerationScore,
    required this.baseParticipationScore,
    required this.brokerSpreadScore,
    required this.investorSpreadScore,
    required this.nonArbitrageScore,
    required this.arbitrageScore,
    required this.participationSpreadScore,
    required this.confidenceMultiplier,
    required this.crowdScore,
    required this.programInterpretation,
  });
}

enum ProgramInterpretation { arbitrageDominant, neutral, nonArbitrageDominant }
