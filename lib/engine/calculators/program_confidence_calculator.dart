import '../metrics/program_metrics.dart';
import '../statistics/percentile_calculator.dart';

class ProgramConfidenceCalculator {
  final PercentileCalculator percentileCalculator;

  const ProgramConfidenceCalculator({required this.percentileCalculator});

  double calculate({
    required ProgramMetrics metrics,
    required List<double> historicalProgramValues,
  }) {
    final todayRatio =
        metrics.todayNonArbitrageTradingValue /
        (metrics.todayArbitrageTradingValue +
            metrics.todayNonArbitrageTradingValue);

    final averageRatio =
        metrics.averageNonArbitrageTradingValue /
        (metrics.averageArbitrageTradingValue +
            metrics.averageNonArbitrageTradingValue);

    final ratioChange = todayRatio / averageRatio;

    return percentileCalculator.calculate(
      value: ratioChange,
      history: historicalProgramValues,
    );
  }
}
