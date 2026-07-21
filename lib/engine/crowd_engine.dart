import 'calculators/acceleration_calculator.dart';
import 'calculators/arbitrage_confidence_calculator.dart';
import 'calculators/broker_spread_calculator.dart';
import 'calculators/confidence_multiplier_calculator.dart';
import 'calculators/crowd_score_calculator.dart';
import 'calculators/investor_spread_calculator.dart';
import 'calculators/participation_spread_calculator.dart';
import 'calculators/program_confidence_calculator.dart';
import 'calculators/scale_calculator.dart';
import 'models/crowd_engine_result.dart';
import 'metrics/scale_metrics.dart';
import 'metrics/acceleration_metrics.dart';
import 'metrics/broker_metrics.dart';
import 'metrics/investor_metrics.dart';
import 'interpreters/program_interpreter.dart';
import 'metrics/program_metrics.dart';

class CrowdEngine {
  final ScaleCalculator scaleCalculator;
  final AccelerationCalculator accelerationCalculator;
  final BrokerSpreadCalculator brokerSpreadCalculator;
  final InvestorSpreadCalculator investorSpreadCalculator;
  final ProgramConfidenceCalculator programConfidenceCalculator; // 비차익
  final ArbitrageConfidenceCalculator arbitrageConfidenceCalculator; // 차익
  final ParticipationSpreadCalculator participationSpreadCalculator;
  final ConfidenceMultiplierCalculator confidenceMultiplierCalculator;
  final CrowdScoreCalculator crowdScoreCalculator;
  final ProgramInterpreter programInterpreter;

  const CrowdEngine({
    required this.scaleCalculator,
    required this.accelerationCalculator,
    required this.brokerSpreadCalculator,
    required this.investorSpreadCalculator,
    required this.programConfidenceCalculator,
    required this.arbitrageConfidenceCalculator,
    required this.participationSpreadCalculator,
    required this.confidenceMultiplierCalculator,
    required this.crowdScoreCalculator,
    required this.programInterpreter,
  });

  CrowdEngineResult calculate({
    required ScaleMetrics scaleMetrics,
    required List<double> historicalScaleValues,

    required AccelerationMetrics accelerationMetrics,
    required List<double> historicalRatio1Day,
    required List<double> historicalRatio5Days,
    required List<double> historicalRatio20Days,

    required BrokerMetrics brokerMetrics,
    required List<double> historicalHhiValues,

    required InvestorMetrics todayInvestorMetrics,
    required InvestorMetrics averageInvestorMetrics,
    required List<double> historicalTvdValues,

    required ProgramMetrics programMetrics,
    required List<double> historicalNonArbitrageValues,
    required List<double> historicalArbitrageValues,
  }) {
    // 1. Scale
    final scaleScore = scaleCalculator.calculate(
      metrics: scaleMetrics,
      historicalScaleValues: historicalScaleValues,
    );

    // 2. Acceleration
    final accelerationScore = accelerationCalculator.calculate(
      metrics: accelerationMetrics,
      historicalRatio1Day: historicalRatio1Day,
      historicalRatio5Days: historicalRatio5Days,
      historicalRatio20Days: historicalRatio20Days,
    );

    // 3. Broker (핵심근거 요소 1)
    final brokerScore = brokerSpreadCalculator.calculate(
      metrics: brokerMetrics,
      historicalHhiValues: historicalHhiValues,
    );

    // 4. Investor (핵심근거 요소 2)
    final investorScore = investorSpreadCalculator.calculate(
      today: todayInvestorMetrics,
      average: averageInvestorMetrics,
      historicalTvdValues: historicalTvdValues,
    );

    // 5. 비차익 (조건부 보강 요소)
    final nonArbitrageScore = programConfidenceCalculator.calculate(
      metrics: programMetrics,
      historicalProgramValues: historicalNonArbitrageValues,
    );

    // 6. 차익 (무조건 보정 요소)
    final arbitrageScore = arbitrageConfidenceCalculator.calculate(
      metrics: programMetrics,
      historicalArbitrageRatioValues: historicalArbitrageValues,
    );

    final baseParticipationScore = (scaleScore + accelerationScore) / 2.0;

    // 7. 참여확산도 종합
    final participationSpreadScore = participationSpreadCalculator.calculate(
      brokerScore: brokerScore,
      investorScore: investorScore,
      nonArbitrageScore: nonArbitrageScore,
      arbitrageScore: arbitrageScore,
    );

    // 8. Confidence Multiplier 변환
    final confidenceMultiplier = confidenceMultiplierCalculator.calculate(
      participationSpreadScore,
    );

    // 9. Crowd Score = Base × Confidence Multiplier
    final crowdScore = crowdScoreCalculator.calculate(
      baseParticipationScore: baseParticipationScore,
      confidenceMultiplier: confidenceMultiplier,
    );

    final programInterpretation = programInterpreter.interpret(
      nonArbitrageScore,
    );

    return CrowdEngineResult(
      scaleScore: scaleScore,
      accelerationScore: accelerationScore,
      baseParticipationScore: baseParticipationScore,
      brokerSpreadScore: brokerScore,
      investorSpreadScore: investorScore,
      nonArbitrageScore: nonArbitrageScore,
      arbitrageScore: arbitrageScore,
      participationSpreadScore: participationSpreadScore,
      confidenceMultiplier: confidenceMultiplier,
      crowdScore: crowdScore,
      programInterpretation: programInterpretation,
    );
  }
}
