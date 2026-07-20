import 'calculators/acceleration_calculator.dart';
import 'calculators/broker_spread_calculator.dart';
import 'calculators/crowd_score_calculator.dart';
import 'calculators/investor_spread_calculator.dart';
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
  final ProgramConfidenceCalculator programConfidenceCalculator;
  final CrowdScoreCalculator crowdScoreCalculator;
  final ProgramInterpreter programInterpreter;

  const CrowdEngine({
    required this.scaleCalculator,
    required this.accelerationCalculator,
    required this.brokerSpreadCalculator,
    required this.investorSpreadCalculator,
    required this.programConfidenceCalculator,
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
    required List<double> historicalProgramValues,
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

    // 3. Broker
    final brokerScore = brokerSpreadCalculator.calculate(
      metrics: brokerMetrics,
      historicalHhiValues: historicalHhiValues,
    );

    // 4. Investor
    final investorScore = investorSpreadCalculator.calculate(
      today: todayInvestorMetrics,
      average: averageInvestorMetrics,
      historicalTvdValues: historicalTvdValues,
    );

    // 5. Program
    final programScore = programConfidenceCalculator.calculate(
      metrics: programMetrics,
      historicalProgramValues: historicalProgramValues,
    );

    final baseParticipationScore = (scaleScore + accelerationScore) / 2.0;

    // 6. Crowd Score
    final crowdScore = crowdScoreCalculator.calculate(
      baseParticipationScore: baseParticipationScore,
      brokerSpreadScore: brokerScore,
      investorSpreadScore: investorScore,
    );

    final programInterpretation = programInterpreter.interpret(programScore);

    return CrowdEngineResult(
      scaleScore: scaleScore,
      accelerationScore: accelerationScore,
      baseParticipationScore: baseParticipationScore,
      brokerSpreadScore: brokerScore,
      investorSpreadScore: investorScore,
      crowdScore: crowdScore,
      programScore: programScore,
      programInterpretation: programInterpretation,
    );
  }
}
