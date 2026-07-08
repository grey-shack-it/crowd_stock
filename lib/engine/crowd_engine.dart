import 'calculators/scale_calculator.dart';
import 'calculators/acceleration_calculator.dart';
import 'calculators/broker_spread_calculator.dart';
import 'calculators/investor_spread_calculator.dart';
import 'calculators/program_confidence_calculator.dart';
import 'calculators/crowd_score_calculator.dart';

class CrowdEngine {
  final ScaleCalculator scaleCalculator;
  final AccelerationCalculator accelerationCalculator;
  final BrokerSpreadCalculator brokerSpreadCalculator;
  final InvestorSpreadCalculator investorSpreadCalculator;
  final ProgramConfidenceCalculator programConfidenceCalculator;
  final CrowdScoreCalculator crowdScoreCalculator;

  const CrowdEngine({
    required this.scaleCalculator,
    required this.accelerationCalculator,
    required this.brokerSpreadCalculator,
    required this.investorSpreadCalculator,
    required this.programConfidenceCalculator,
    required this.crowdScoreCalculator,
  });
}
