import '../metrics/program_metrics.dart';
import '../statistics/percentile_calculator.dart';

/// 차익거래 비중이 평소보다 얼마나 튀었는지를 percentile로 계산한다.
/// 차익거래는 가격 갭을 노린 기계적 거래라서, 맥락(다른 지표와의 동행 여부)과
/// 무관하게 항상 감점 요인으로 다룬다 (ProgramConfidenceCalculator의 비차익과 다른 점).
class ArbitrageConfidenceCalculator {
  final PercentileCalculator percentileCalculator;

  const ArbitrageConfidenceCalculator({required this.percentileCalculator});

  double calculate({
    required ProgramMetrics metrics,
    required List<double> historicalArbitrageRatioValues,
  }) {
    final todayRatio =
        metrics.todayArbitrageTradingValue /
        (metrics.todayArbitrageTradingValue +
            metrics.todayNonArbitrageTradingValue);

    final averageRatio =
        metrics.averageArbitrageTradingValue /
        (metrics.averageArbitrageTradingValue +
            metrics.averageNonArbitrageTradingValue);

    final ratioChange = todayRatio / averageRatio;

    return percentileCalculator.calculate(
      value: ratioChange,
      history: historicalArbitrageRatioValues,
    );
  }
}
