import 'package:flutter/material.dart';
import '../engine/metrics/scale_metrics.dart';
import '../engine/metrics/acceleration_metrics.dart';
import '../engine/metrics/broker_metrics.dart';
import '../engine/metrics/investor_metrics.dart';
import '../engine/metrics/program_metrics.dart';
import '../engine/statistics/percentile_calculator.dart';
import '../engine/calculators/scale_calculator.dart';
import '../engine/calculators/acceleration_calculator.dart';
import '../engine/calculators/broker_spread_calculator.dart';
import '../engine/calculators/investor_spread_calculator.dart';
import '../engine/calculators/program_confidence_calculator.dart';
import '../engine/calculators/default_crowd_score_calculator.dart';
import '../engine/interpreters/program_interpreter.dart';
import '../engine/crowd_engine.dart';

class CrowdEngineTestScreen extends StatefulWidget {
  const CrowdEngineTestScreen({super.key});

  @override
  State<CrowdEngineTestScreen> createState() => _CrowdEngineTestScreenState();
}

class _CrowdEngineTestScreenState extends State<CrowdEngineTestScreen> {
  String result = '아직 실행하지 않음';
  void runTest() {
    final scaleMetrics = ScaleMetrics(
      tradingValue: 1200000000000,
      marketCap: 500000000000000,
    );

    final accelerationMetrics = AccelerationMetrics(
      todayParticipation: 0.85,
      average1Day: 0.70,
      average5Days: 0.60,
      average20Days: 0.45,
    );

    final brokerMetrics = BrokerMetrics(
      tradingValueByBroker: {
        'NH투자증권': 180000000,
        '키움증권': 150000000,
        '미래에셋증권': 120000000,
        '한국투자증권': 90000000,
        '삼성증권': 70000000,
      },
    );

    final todayInvestorMetrics = InvestorMetrics(
      individualTradingValue: 320000000,
      foreignTradingValue: 180000000,
      institutionTradingValue: 120000000,
    );

    final averageInvestorMetrics = InvestorMetrics(
      individualTradingValue: 220000000,
      foreignTradingValue: 220000000,
      institutionTradingValue: 180000000,
    );

    final programMetrics = ProgramMetrics(
      todayArbitrageTradingValue: 90000000,
      todayNonArbitrageTradingValue: 210000000,
      averageArbitrageTradingValue: 120000000,
      averageNonArbitrageTradingValue: 180000000,
    );

    final historicalScaleValues = [0.0012, 0.0015, 0.0017, 0.0020, 0.0023];

    final historicalRatio1Day = [0.90, 0.95, 1.00, 1.05, 1.10];

    final historicalRatio5Days = [0.80, 0.90, 1.00, 1.10, 1.20];

    final historicalRatio20Days = [0.70, 0.85, 1.00, 1.15, 1.30];

    final historicalHhiValues = [0.18, 0.22, 0.26, 0.30, 0.35];

    final historicalTvdValues = [0.10, 0.18, 0.25, 0.32, 0.40];

    final historicalProgramValues = [0.80, 0.90, 1.00, 1.10, 1.20];

    final percentileCalculator = PercentileCalculator();

    final scaleCalculator = ScaleCalculator(
      percentileCalculator: percentileCalculator,
    );

    final accelerationCalculator = AccelerationCalculator(
      percentileCalculator: percentileCalculator,
    );

    final brokerSpreadCalculator = BrokerSpreadCalculator(
      percentileCalculator: percentileCalculator,
    );

    final investorSpreadCalculator = InvestorSpreadCalculator(
      percentileCalculator: percentileCalculator,
    );

    final programConfidenceCalculator = ProgramConfidenceCalculator(
      percentileCalculator: percentileCalculator,
    );

    final crowdScoreCalculator = DefaultCrowdScoreCalculator();

    final programInterpreter = ProgramInterpreter();

    final crowdEngine = CrowdEngine(
      scaleCalculator: scaleCalculator,
      accelerationCalculator: accelerationCalculator,
      brokerSpreadCalculator: brokerSpreadCalculator,
      investorSpreadCalculator: investorSpreadCalculator,
      programConfidenceCalculator: programConfidenceCalculator,
      crowdScoreCalculator: crowdScoreCalculator,
      programInterpreter: programInterpreter,
    );

    final engineResult = crowdEngine.calculate(
      scaleMetrics: scaleMetrics,
      historicalScaleValues: historicalScaleValues,

      accelerationMetrics: accelerationMetrics,
      historicalRatio1Day: historicalRatio1Day,
      historicalRatio5Days: historicalRatio5Days,
      historicalRatio20Days: historicalRatio20Days,

      brokerMetrics: brokerMetrics,
      historicalHhiValues: historicalHhiValues,

      todayInvestorMetrics: todayInvestorMetrics,
      averageInvestorMetrics: averageInvestorMetrics,
      historicalTvdValues: historicalTvdValues,

      programMetrics: programMetrics,
      historicalProgramValues: historicalProgramValues,
    );

    setState(() {
      result =
          '''
        Crowd Score : ${engineResult.crowdScore.toStringAsFixed(2)}

        Scale : ${engineResult.scaleScore.toStringAsFixed(2)}
        Acceleration : ${engineResult.accelerationScore.toStringAsFixed(2)}

        Base : ${engineResult.baseParticipationScore.toStringAsFixed(2)}

        Broker : ${engineResult.brokerSpreadScore.toStringAsFixed(2)}
        Investor : ${engineResult.investorSpreadScore.toStringAsFixed(2)}

        Program : ${engineResult.programScore.toStringAsFixed(2)}
        ''';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crowd Engine Test')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(result, textAlign: TextAlign.center),
              const SizedBox(height: 30),
              ElevatedButton(onPressed: runTest, child: const Text('엔진 테스트')),
            ],
          ),
        ),
      ),
    );
  }
}
