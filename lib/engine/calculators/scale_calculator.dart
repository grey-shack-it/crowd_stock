import '../metrics/scale_metrics.dart';
import '../statistics/percentile_calculator.dart';

class ScaleCalculator {
  final PercentileCalculator percentileCalculator;

  const ScaleCalculator({required this.percentileCalculator});

  double calculate({
    required ScaleMetrics metrics,
    required List<double> historicalScaleValues,
  }) {
    if (metrics.marketCap <= 0) {
      return 0.0;
    }

    final todayScale = metrics.tradingValue / metrics.marketCap;

    return percentileCalculator.calculate(
      value: todayScale,
      history: historicalScaleValues,
    );
  }
}
