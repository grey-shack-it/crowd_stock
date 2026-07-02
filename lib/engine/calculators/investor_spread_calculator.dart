import '../metrics/investor_metrics.dart';
import '../statistics/percentile_calculator.dart';

class InvestorSpreadCalculator {
  final PercentileCalculator percentileCalculator;

  const InvestorSpreadCalculator({required this.percentileCalculator});

  double calculate({
    required InvestorMetrics today,
    required InvestorMetrics average,
    required List<double> historicalTvdValues,
  }) {
    final tvd = _calculateTVD(today: today, average: average);

    return percentileCalculator.calculate(
      value: tvd,
      history: historicalTvdValues,
    );
  }

  double _calculateTVD({
    required InvestorMetrics today,
    required InvestorMetrics average,
  }) {
    final individualDiff =
        (today.individualTradingValue - average.individualTradingValue).abs();

    final foreignDiff =
        (today.foreignTradingValue - average.foreignTradingValue).abs();

    final institutionDiff =
        (today.institutionTradingValue - average.institutionTradingValue).abs();

    return (individualDiff + foreignDiff + institutionDiff) / 2.0;
  }
}
