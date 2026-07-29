import '../engine/calculators/acceleration_calculator.dart';
import '../engine/calculators/confidence_multiplier_calculator.dart';
import '../engine/calculators/default_crowd_score_calculator.dart';
import '../engine/calculators/investor_spread_calculator.dart';
import '../engine/calculators/participation_spread_calculator.dart';
import '../engine/calculators/program_confidence_calculator.dart';
import '../engine/calculators/scale_calculator.dart';
import '../engine/metrics/acceleration_metrics.dart';
import '../engine/metrics/investor_metrics.dart';
import '../engine/metrics/program_metrics.dart';
import '../engine/metrics/scale_metrics.dart';
import '../engine/statistics/percentile_calculator.dart';
import 'acceleration_history_builder.dart';
import 'investor_history_builder.dart';
import 'kis_api.dart';
import 'program_history_builder.dart';
import 'scale_history_builder.dart';

class CrowdScorePoint {
  const CrowdScorePoint({
    required this.date,
    required this.crowdScore,
    required this.isDegraded,
    required this.scaleScore,
    required this.accelerationScore,
    required this.baseParticipationScore,
    required this.brokerScore,
    required this.investorScore,
    required this.programScore,
    required this.participationSpreadScore,
    required this.confidenceMultiplier,
  });

  final String date; // yyyyMMdd
  final double crowdScore;

  /// true면 회원사(Broker) 데이터가 아직 없어서, 핵심근거를 투자자 하나로만
  /// 계산한 근사값. 그래프에 "이 구간은 근사치"라고 표시해줘야 한다.
  final bool isDegraded;

  // 원재료(서브 지표) — 상세 보기 그래프용
  final double scaleScore;
  final double accelerationScore;
  final double baseParticipationScore;

  /// isDegraded가 true면 이건 investorScore와 동일한 값(근사 처리)
  final double brokerScore;
  final double investorScore;
  final double programScore;

  final double participationSpreadScore;
  final double confidenceMultiplier;
}

/// 여러 날짜에 대해 Crowd Score를 반복 계산해 그래프용 시계열을 만든다.
/// KIS 호출은 이미 넓은 기간으로 한 번에 받아온 걸 재사용하고(추가 호출 없음),
/// 회원사(Broker) 기록이 있는 날짜만 정식 계산, 없는 날짜는 투자자만으로
/// 근사 계산한다.
class CrowdScoreSeriesBuilder {
  final Map<String, String> skippedDates = {}; // 날짜 -> 빠진 이유
  final PercentileCalculator _percentileCalculator =
      const PercentileCalculator();
  final ScaleCalculator _scaleCalculator = const ScaleCalculator(
    percentileCalculator: const PercentileCalculator(),
  );
  final ScaleHistoryBuilder _scaleHistoryBuilder = const ScaleHistoryBuilder();
  final AccelerationCalculator _accelerationCalculator =
      const AccelerationCalculator(
        percentileCalculator: const PercentileCalculator(),
      );
  final AccelerationHistoryBuilder _accelerationHistoryBuilder =
      const AccelerationHistoryBuilder();
  final InvestorSpreadCalculator _investorSpreadCalculator =
      const InvestorSpreadCalculator(
        percentileCalculator: const PercentileCalculator(),
      );
  final InvestorHistoryBuilder _investorHistoryBuilder =
      const InvestorHistoryBuilder();
  final ProgramConfidenceCalculator _programConfidenceCalculator =
      const ProgramConfidenceCalculator(
        percentileCalculator: const PercentileCalculator(),
      );
  final ProgramHistoryBuilder _programHistoryBuilder =
      const ProgramHistoryBuilder();
  final ParticipationSpreadCalculator _participationSpreadCalculator =
      const ParticipationSpreadCalculator();
  final ConfidenceMultiplierCalculator _confidenceMultiplierCalculator =
      const ConfidenceMultiplierCalculator();
  final DefaultCrowdScoreCalculator _crowdScoreCalculator =
      const DefaultCrowdScoreCalculator();

  /// [targetDates]는 오래된 날짜 → 최근 날짜 순으로 정렬돼 있어야 한다 (yyyyMMdd).
  /// 데이터가 부족해 계산 자체가 안 되는 날짜는 결과 리스트에서 빠진다
  /// (그래프에서는 그 지점만 건너뛰면 됨).
  List<CrowdScorePoint> build({
    required List<String> targetDates,
    required List<DailyPricePoint> priceHistory,
    required List<InvestorDailyPoint> investorHistory,
    required List<DailyProgramPoint> programHistory,
    required Map<String, double> brokerHistoryByDate,
    required double sharesOutstanding,
  }) {
    final results = <CrowdScorePoint>[];

    for (final targetDate in targetDates) {
      final point = _buildOne(
        targetDate: targetDate,
        priceHistory: priceHistory,
        investorHistory: investorHistory,
        programHistory: programHistory,
        brokerHistoryByDate: brokerHistoryByDate,
        sharesOutstanding: sharesOutstanding,
      );
      if (point != null) results.add(point);
    }

    return results;
  }

  CrowdScorePoint? _buildOne({
    required String targetDate,
    required List<DailyPricePoint> priceHistory,
    required List<InvestorDailyPoint> investorHistory,
    required List<DailyProgramPoint> programHistory,
    required Map<String, double> brokerHistoryByDate,
    required double sharesOutstanding,
  }) {
    if (sharesOutstanding <= 0) {
      skippedDates[targetDate] = 'sharesOutstanding <= 0';
      return null;
    }

    final targetRows = priceHistory.where((p) => p.date == targetDate).toList();
    if (targetRows.isEmpty) {
      skippedDates[targetDate] = 'targetRow 없음 (priceHistory에 이 날짜 없음)';
      return null;
    }
    final targetRow = targetRows.first;

    final targetMarketCap = sharesOutstanding * targetRow.closePrice;
    if (targetMarketCap <= 0) {
      skippedDates[targetDate] = 'targetMarketCap <= 0';
      return null;
    }
    final targetTradingValue = targetRow.tradingValue;

    final historicalScaleValues = _scaleHistoryBuilder.build(
      priceHistory: priceHistory,
      sharesOutstanding: sharesOutstanding,
      excludeDate: targetDate,
    );
    final scaleScore = _scaleCalculator.calculate(
      metrics: ScaleMetrics(
        tradingValue: targetTradingValue,
        marketCap: targetMarketCap,
      ),
      historicalScaleValues: historicalScaleValues,
    );

    final targetParticipation = targetTradingValue / targetMarketCap;
    final accelHistory = _accelerationHistoryBuilder.build(
      priceHistory: priceHistory,
      sharesOutstanding: sharesOutstanding,
      todayDate: targetDate,
    );
    if (!accelHistory.isUsable) {
      skippedDates[targetDate] = 'accelHistory 사용불가 (20일치 부족)';
      return null;
    }
    final accelerationScore = _accelerationCalculator.calculate(
      metrics: AccelerationMetrics(
        todayParticipation: targetParticipation,
        average1Day: accelHistory.average1Day,
        average5Days: accelHistory.average5Days,
        average20Days: accelHistory.average20Days,
      ),
      historicalRatio1Day: accelHistory.historicalRatio1Day,
      historicalRatio5Days: accelHistory.historicalRatio5Days,
      historicalRatio20Days: accelHistory.historicalRatio20Days,
    );
    final baseParticipationScore = (scaleScore + accelerationScore) / 2.0;

    final investorResult = _investorHistoryBuilder.build(
      history: investorHistory,
      todayDate: targetDate,
    );
    if (!investorResult.isUsable) {
      skippedDates[targetDate] = 'investorResult 사용불가 (10일치 부족)';
      return null;
    }
    final investorScore = _investorSpreadCalculator.calculate(
      today: InvestorMetrics(
        individualTradingValue: investorResult.todayIndividual,
        institutionTradingValue: investorResult.todayInstitution,
        foreignTradingValue: investorResult.todayForeign,
      ),
      average: InvestorMetrics(
        individualTradingValue: investorResult.averageIndividual,
        institutionTradingValue: investorResult.averageInstitution,
        foreignTradingValue: investorResult.averageForeign,
      ),
      historicalTvdValues: investorResult.historicalTvdValues,
    );

    final programResult = _programHistoryBuilder.build(
      history: programHistory,
      todayDate: targetDate,
    );
    if (!programResult.isUsable) {
      skippedDates[targetDate] = 'programResult 사용불가 (10일치 부족)';
      return null;
    }
    final programScore = _programConfidenceCalculator.calculate(
      metrics: ProgramMetrics(
        todayProgramTradingValue: programResult.todayValue,
        averageProgramTradingValue: programResult.averageValue,
      ),
      historicalProgramValues: programResult.historicalProgramValues,
    );

    // 회원사(Broker) — 있으면 정식 계산, 없으면 투자자만으로 근사(degraded)
    final priorBrokerValues = brokerHistoryByDate.entries
        .where((e) => e.key.compareTo(targetDate) < 0)
        .map((e) => e.value)
        .toList();
    final todayHhi = brokerHistoryByDate[targetDate];

    final isDegraded = todayHhi == null || priorBrokerValues.length < 5;

    final double coreEvidenceInput; // brokerScore 자리에 들어갈 값
    if (!isDegraded) {
      final brokerScore = _percentileCalculator.calculate(
        value: todayHhi,
        history: priorBrokerValues,
      );
      coreEvidenceInput = brokerScore;
    } else {
      // 근사 모드: 핵심근거를 투자자 하나로만 취급 (평균 대신 그대로 사용하려고
      // 같은 값을 두 번 넣어서 평균해도 investorScore 그대로 나오게 함)
      coreEvidenceInput = investorScore;
    }

    final participationSpreadScore = _participationSpreadCalculator.calculate(
      brokerScore: coreEvidenceInput,
      investorScore: investorScore,
      programScore: programScore,
    );
    final confidenceMultiplier = _confidenceMultiplierCalculator.calculate(
      participationSpreadScore,
    );
    final crowdScore = _crowdScoreCalculator.calculate(
      baseParticipationScore: baseParticipationScore,
      confidenceMultiplier: confidenceMultiplier,
    );

    return CrowdScorePoint(
      date: targetDate,
      crowdScore: crowdScore,
      isDegraded: isDegraded,
      scaleScore: scaleScore,
      accelerationScore: accelerationScore,
      baseParticipationScore: baseParticipationScore,
      brokerScore: coreEvidenceInput,
      investorScore: investorScore,
      programScore: programScore,
      participationSpreadScore: participationSpreadScore,
      confidenceMultiplier: confidenceMultiplier,
    );
  }
}
