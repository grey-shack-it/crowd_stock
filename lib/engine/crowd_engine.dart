import 'calculators/acceleration_calculator.dart';
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
import 'metrics/program_metrics.dart';

class CrowdEngine {
  final ScaleCalculator scaleCalculator;
  final AccelerationCalculator accelerationCalculator;
  final BrokerSpreadCalculator brokerSpreadCalculator;
  final InvestorSpreadCalculator investorSpreadCalculator;
  final ProgramConfidenceCalculator programConfidenceCalculator; // 프로그램매매(합계)
  final ParticipationSpreadCalculator participationSpreadCalculator;
  final ConfidenceMultiplierCalculator confidenceMultiplierCalculator;
  final CrowdScoreCalculator crowdScoreCalculator;

  const CrowdEngine({
    required this.scaleCalculator,
    required this.accelerationCalculator,
    required this.brokerSpreadCalculator,
    required this.investorSpreadCalculator,
    required this.programConfidenceCalculator,
    required this.participationSpreadCalculator,
    required this.confidenceMultiplierCalculator,
    required this.crowdScoreCalculator,
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
    final scaleScore = scaleCalculator.calculate(
      metrics: scaleMetrics,
      historicalScaleValues: historicalScaleValues,
    );

    final accelerationScore = accelerationCalculator.calculate(
      metrics: accelerationMetrics,
      historicalRatio1Day: historicalRatio1Day,
      historicalRatio5Days: historicalRatio5Days,
      historicalRatio20Days: historicalRatio20Days,
    );

    final brokerScore = brokerSpreadCalculator.calculate(
      metrics: brokerMetrics,
      historicalHhiValues: historicalHhiValues,
    );

    final investorScore = investorSpreadCalculator.calculate(
      today: todayInvestorMetrics,
      average: averageInvestorMetrics,
      historicalTvdValues: historicalTvdValues,
    );

    final programScore = programConfidenceCalculator.calculate(
      metrics: programMetrics,
      historicalProgramValues: historicalProgramValues,
    );

    final baseParticipationScore = (scaleScore + accelerationScore) / 2.0;

    final participationSpreadScore = participationSpreadCalculator.calculate(
      brokerScore: brokerScore,
      investorScore: investorScore,
      programScore: programScore,
    );

    final confidenceMultiplier = confidenceMultiplierCalculator.calculate(
      participationSpreadScore,
    );

    final crowdScore = crowdScoreCalculator.calculate(
      baseParticipationScore: baseParticipationScore,
      confidenceMultiplier: confidenceMultiplier,
    );

    return CrowdEngineResult(
      scaleScore: scaleScore,
      accelerationScore: accelerationScore,
      baseParticipationScore: baseParticipationScore,
      brokerSpreadScore: brokerScore,
      investorSpreadScore: investorScore,
      programScore: programScore,
      participationSpreadScore: participationSpreadScore,
      confidenceMultiplier: confidenceMultiplier,
      crowdScore: crowdScore,
    );
  }
}
