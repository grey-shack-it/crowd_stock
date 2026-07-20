class CrowdEngineResult {
  final double scaleScore;
  final double accelerationScore;
  final double baseParticipationScore;
  final double brokerSpreadScore;
  final double investorSpreadScore;
  final double crowdScore;
  final double programScore;
  final ProgramInterpretation programInterpretation;

  const CrowdEngineResult({
    required this.scaleScore,
    required this.accelerationScore,
    required this.baseParticipationScore,
    required this.brokerSpreadScore,
    required this.investorSpreadScore,
    required this.crowdScore,
    required this.programScore,
    required this.programInterpretation,
  });
}

enum ProgramInterpretation { arbitrageDominant, neutral, nonArbitrageDominant }
