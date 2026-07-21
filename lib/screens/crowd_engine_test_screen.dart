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
import '../engine/calculators/arbitrage_confidence_calculator.dart';
import '../engine/calculators/participation_spread_calculator.dart';
import '../engine/calculators/confidence_multiplier_calculator.dart';
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

  void _runCase({required bool broadParticipation}) {
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

    // Case A(broad): 여러 증권사에 고르게 분산 / Case B(narrow): 소수 증권사에 집중
    final brokerMetrics = broadParticipation
        ? BrokerMetrics(
            tradingValueByBroker: {
              'NH투자증권': 110000000,
              '키움증권': 105000000,
              '미래에셋증권': 100000000,
              '한국투자증권': 98000000,
              '삼성증권': 97000000,
            },
          )
        : BrokerMetrics(
            tradingValueByBroker: {
              'NH투자증권': 380000000,
              '키움증권': 60000000,
              '미래에셋증권': 30000000,
              '한국투자증권': 20000000,
              '삼성증권': 10000000,
            },
          );

    final todayInvestorMetrics = broadParticipation
        ? InvestorMetrics(
            individualTradingValue: 210000000,
            foreignTradingValue: 200000000,
            institutionTradingValue: 190000000,
          )
        : InvestorMetrics(
            individualTradingValue: 480000000,
            foreignTradingValue: 90000000,
            institutionTradingValue: 30000000,
          );

    final averageInvestorMetrics = InvestorMetrics(
      individualTradingValue: 220000000,
      foreignTradingValue: 220000000,
      institutionTradingValue: 180000000,
    );

    final programMetrics = broadParticipation
        ? ProgramMetrics(
            todayArbitrageTradingValue: 60000000,
            todayNonArbitrageTradingValue: 240000000,
            averageArbitrageTradingValue: 120000000,
            averageNonArbitrageTradingValue: 180000000,
          )
        : ProgramMetrics(
            todayArbitrageTradingValue: 180000000,
            todayNonArbitrageTradingValue: 120000000,
            averageArbitrageTradingValue: 120000000,
            averageNonArbitrageTradingValue: 180000000,
          );

    final historicalScaleValues = [0.0012, 0.0015, 0.0017, 0.0020, 0.0023];
    final historicalRatio1Day = [0.90, 0.95, 1.00, 1.05, 1.10];
    final historicalRatio5Days = [0.80, 0.90, 1.00, 1.10, 1.20];
    final historicalRatio20Days = [0.70, 0.85, 1.00, 1.15, 1.30];
    final historicalHhiValues = [0.18, 0.22, 0.26, 0.30, 0.35];
    // TVD는 원(₩) 단위 raw 값이라, 과거 기록도 같은 단위로 맞춰야 한다.
    // (기존 0~1 소수값은 단위가 안 맞아 투자자 점수가 항상 100으로 찍히던 버그)
    final historicalTvdValues = [
      20000000.0,
      50000000.0,
      90000000.0,
      150000000.0,
      250000000.0,
    ];
    final historicalNonArbitrageValues = [0.80, 0.90, 1.00, 1.10, 1.20];
    final historicalArbitrageValues = [0.80, 0.90, 1.00, 1.10, 1.20];

    final percentileCalculator = PercentileCalculator();

    final crowdEngine = CrowdEngine(
      scaleCalculator: ScaleCalculator(
        percentileCalculator: percentileCalculator,
      ),
      accelerationCalculator: AccelerationCalculator(
        percentileCalculator: percentileCalculator,
      ),
      brokerSpreadCalculator: BrokerSpreadCalculator(
        percentileCalculator: percentileCalculator,
      ),
      investorSpreadCalculator: InvestorSpreadCalculator(
        percentileCalculator: percentileCalculator,
      ),
      programConfidenceCalculator: ProgramConfidenceCalculator(
        percentileCalculator: percentileCalculator,
      ),
      arbitrageConfidenceCalculator: ArbitrageConfidenceCalculator(
        percentileCalculator: percentileCalculator,
      ),
      participationSpreadCalculator: const ParticipationSpreadCalculator(),
      confidenceMultiplierCalculator: const ConfidenceMultiplierCalculator(),
      crowdScoreCalculator: const DefaultCrowdScoreCalculator(),
      programInterpreter: const ProgramInterpreter(),
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
      historicalNonArbitrageValues: historicalNonArbitrageValues,
      historicalArbitrageValues: historicalArbitrageValues,
    );

    setState(() {
      result =
          '''
        ${broadParticipation ? "Case A (폭넓은 참여)" : "Case B (소수 집중)"}

        Crowd Score : ${engineResult.crowdScore.toStringAsFixed(2)}

        Base Participation : ${engineResult.baseParticipationScore.toStringAsFixed(2)}
        참여확산도 : ${engineResult.participationSpreadScore.toStringAsFixed(2)}
        Confidence Multiplier : ${engineResult.confidenceMultiplier.toStringAsFixed(2)}배

        Broker : ${engineResult.brokerSpreadScore.toStringAsFixed(2)}
        Investor : ${engineResult.investorSpreadScore.toStringAsFixed(2)}
        비차익 : ${engineResult.nonArbitrageScore.toStringAsFixed(2)}
        차익 : ${engineResult.arbitrageScore.toStringAsFixed(2)}
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => _runCase(broadParticipation: true),
                    child: const Text('Case A: 폭넓은 참여'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _runCase(broadParticipation: false),
                    child: const Text('Case B: 소수 집중'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
