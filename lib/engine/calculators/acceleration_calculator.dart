import '../metrics/acceleration_metrics.dart';
import '../statistics/percentile_calculator.dart';

class AccelerationCalculator {
  final PercentileCalculator percentileCalculator;

  const AccelerationCalculator({required this.percentileCalculator});

  double calculate({
    required AccelerationMetrics metrics,
    required List<double> historicalRatio1Day,
    required List<double> historicalRatio5Days,
    required List<double> historicalRatio20Days,
  }) {
    final ratio1Day = metrics.todayParticipation / metrics.average1Day;
    final ratio5Days = metrics.todayParticipation / metrics.average5Days;
    final ratio20Days = metrics.todayParticipation / metrics.average20Days;

    final score1Day = percentileCalculator.calculate(
      value: ratio1Day,
      history: historicalRatio1Day,
    );

    final score5Days = percentileCalculator.calculate(
      value: ratio5Days,
      history: historicalRatio5Days,
    );

    final score20Days = percentileCalculator.calculate(
      value: ratio20Days,
      history: historicalRatio20Days,
    );

    return (score1Day + score5Days + score20Days) / 3.0;
  }
}
