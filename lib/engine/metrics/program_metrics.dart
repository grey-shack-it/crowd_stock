class ProgramMetrics {
  final double todayArbitrageTradingValue;
  final double todayNonArbitrageTradingValue;

  final double averageArbitrageTradingValue;
  final double averageNonArbitrageTradingValue;

  const ProgramMetrics({
    required this.todayArbitrageTradingValue,
    required this.todayNonArbitrageTradingValue,
    required this.averageArbitrageTradingValue,
    required this.averageNonArbitrageTradingValue,
  });
}
