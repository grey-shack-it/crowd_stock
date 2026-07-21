import '../metrics/program_metrics.dart';
import '../statistics/percentile_calculator.dart';

/// 비차익거래 비중이 평소보다 얼마나 튀었는지를 percentile로 계산한다.
/// 비차익거래는 의도가 담긴 매매라, ParticipationSpreadCalculator에서
/// 핵심근거(회원사+투자자)가 "집중"이라고 할 때만 감점으로 반영된다
/// (조건 없이 항상 감점되는 ArbitrageConfidenceCalculator와 다른 점).
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
