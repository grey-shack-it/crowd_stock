abstract class ConfidenceCalculator {
  double calculate({
    required double brokerSpreadScore,
    required double investorSpreadScore,
    required double programConfidenceScore,
  });
}
