import '../metrics/program_metrics.dart';
import '../statistics/percentile_calculator.dart';

/// 프로그램매매(차익+비차익 합계) 비중이 평소보다 얼마나 튀었는지를
/// percentile로 계산한다.
///
/// 원래는 차익/비차익을 나눠서 다르게 다루려 했으나, KIS API가 "종목별 +
/// 차익/비차익 구분"을 동시에 제공하지 않아 전체 합계 하나로 합쳤다.
/// ParticipationSpreadCalculator에서 핵심근거(회원사+투자자)가 "집중"이라고
/// 할 때만 감점으로 반영되는 조건부 가중치 역할은 그대로 유지된다.
class ProgramConfidenceCalculator {
  final PercentileCalculator percentileCalculator;

  const ProgramConfidenceCalculator({required this.percentileCalculator});

  double calculate({
    required ProgramMetrics metrics,
    required List<double> historicalProgramValues,
  }) {
    if (metrics.averageProgramTradingValue <= 0) {
      return 50.0;
    }

    final ratioChange =
        metrics.todayProgramTradingValue / metrics.averageProgramTradingValue;

    return percentileCalculator.calculate(
      value: ratioChange,
      history: historicalProgramValues,
    );
  }
}
