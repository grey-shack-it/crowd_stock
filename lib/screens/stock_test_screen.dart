import 'package:flutter/material.dart';
import '../services/kis_api.dart';
import '../services/scale_history_builder.dart';
import '../services/acceleration_history_builder.dart';
import '../services/investor_history_builder.dart';
import '../services/program_history_builder.dart';
import '../services/supabase_broker_repository.dart';
import '../engine/metrics/scale_metrics.dart';
import '../engine/metrics/acceleration_metrics.dart';
import '../engine/metrics/investor_metrics.dart';
import '../engine/metrics/program_metrics.dart';
import '../engine/calculators/scale_calculator.dart';
import '../engine/calculators/acceleration_calculator.dart';
import '../engine/calculators/investor_spread_calculator.dart';
import '../engine/calculators/program_confidence_calculator.dart';
import '../engine/calculators/participation_spread_calculator.dart';
import '../engine/calculators/confidence_multiplier_calculator.dart';
import '../engine/calculators/default_crowd_score_calculator.dart';
import '../engine/statistics/percentile_calculator.dart';

class StockTestScreen extends StatefulWidget {
  const StockTestScreen({super.key, required this.kisApi});

  final KisApi kisApi;

  @override
  State<StockTestScreen> createState() => _StockTestScreenState();
}

class _StockTestScreenState extends State<StockTestScreen> {
  KisApi get _kisApi => widget.kisApi;
  final ScaleCalculator _scaleCalculator = const ScaleCalculator(
    percentileCalculator: PercentileCalculator(),
  );
  final ScaleHistoryBuilder _scaleHistoryBuilder = const ScaleHistoryBuilder();
  final AccelerationCalculator _accelerationCalculator =
      const AccelerationCalculator(
        percentileCalculator: PercentileCalculator(),
      );
  final AccelerationHistoryBuilder _accelerationHistoryBuilder =
      const AccelerationHistoryBuilder();
  final InvestorSpreadCalculator _investorSpreadCalculator =
      const InvestorSpreadCalculator(
        percentileCalculator: PercentileCalculator(),
      );
  final InvestorHistoryBuilder _investorHistoryBuilder =
      const InvestorHistoryBuilder();
  final ProgramConfidenceCalculator _programConfidenceCalculator =
      const ProgramConfidenceCalculator(
        percentileCalculator: PercentileCalculator(),
      );
  final ProgramHistoryBuilder _programHistoryBuilder =
      const ProgramHistoryBuilder();
  final SupabaseBrokerRepository _brokerRepository = SupabaseBrokerRepository();
  final PercentileCalculator _percentileCalculator =
      const PercentileCalculator();
  final ParticipationSpreadCalculator _participationSpreadCalculator =
      const ParticipationSpreadCalculator();
  final ConfidenceMultiplierCalculator _confidenceMultiplierCalculator =
      const ConfidenceMultiplierCalculator();
  final DefaultCrowdScoreCalculator _crowdScoreCalculator =
      const DefaultCrowdScoreCalculator();

  final TextEditingController _stockController = TextEditingController(
    text: '005930',
  );

  bool _isLoading = false;
  String? _error;
  StockQuote? _quote;
  String _currentStockCode = '';
  String? _targetDate;
  double? _scaleScore;
  double? _accelerationScore;
  double? _investorScore;
  double? _programScore;
  double? _brokerScore;
  double? _baseParticipationScore;
  double? _participationSpreadScore;
  double? _confidenceMultiplier;
  double? _crowdScore;
  double? _marketCap;
  int? _historyDayCount;

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  /// Supabase(Postgres date)는 yyyy-MM-dd 형식을 쓴다. KIS API는 yyyyMMdd라
  /// 형식이 다르므로 변환이 필요하다.
  String _toDashedDate(String yyyymmdd) {
    return '${yyyymmdd.substring(0, 4)}-${yyyymmdd.substring(4, 6)}-${yyyymmdd.substring(6, 8)}';
  }

  /// 직전 영업일(어제 이전의 가장 최근 평일). 공휴일은 아직 감안 안 함(v1).
  DateTime _previousBusinessDay(DateTime from) {
    var d = from.subtract(const Duration(days: 1));
    while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
      d = d.subtract(const Duration(days: 1));
    }
    return d;
  }

  Future<void> _fetchQuote() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _currentStockCode = _stockController.text.trim();

      // 기본값: 직전 영업일 (장중 실시간 값은 API 자체 제약도 있고, 의미도 약함)
      final targetDate = _formatDate(_previousBusinessDay(DateTime.now()));

      final quote = await _kisApi.fetchStockQuote(_currentStockCode);
      final sharesOutstanding = double.tryParse(quote.sharesOutstanding) ?? 0;

      // targetDate까지 90일치(넉넉하게) 기간별시세 조회
      final start = _previousBusinessDay(
        DateTime.now(),
      ).subtract(const Duration(days: 90));
      final priceHistory = await _kisApi.fetchDailyPriceHistory(
        stockCode: _currentStockCode,
        startDate: _formatDate(start),
        endDate: targetDate,
      );

      final targetRows = priceHistory
          .where((p) => p.date == targetDate)
          .toList();
      final targetRow = targetRows.isEmpty ? null : targetRows.first;

      if (targetRow == null || sharesOutstanding <= 0) {
        throw Exception('targetDate($targetDate) 데이터를 못 찾았어요 (휴장일이거나 API 지연).');
      }

      final targetMarketCap = sharesOutstanding * targetRow.closePrice;
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

      final targetParticipation = targetMarketCap > 0
          ? targetTradingValue / targetMarketCap
          : 0.0;

      final accelHistory = _accelerationHistoryBuilder.build(
        priceHistory: priceHistory,
        sharesOutstanding: sharesOutstanding,
        todayDate: targetDate,
      );

      double? accelerationScore;
      double? baseParticipationScore;

      if (accelHistory.isUsable) {
        accelerationScore = _accelerationCalculator.calculate(
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
        baseParticipationScore = (scaleScore + accelerationScore) / 2.0;
      }

      // 투자자 편중도 (TVD) — targetDate 기준으로 조회하면 15:40 제약과 무관해짐
      final investorHistory = await _kisApi.fetchInvestorTradeHistory(
        stockCode: _currentStockCode,
        date: targetDate,
      );

      final investorResult = _investorHistoryBuilder.build(
        history: investorHistory,
        todayDate: targetDate,
      );

      double? investorScore;
      if (investorResult.isUsable) {
        investorScore = _investorSpreadCalculator.calculate(
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
      }

      // 프로그램매매(전체 합계) — backfill 가능
      final programHistory = await _kisApi.fetchProgramTradeHistory(
        stockCode: _currentStockCode,
        date: targetDate,
      );

      final programResult = _programHistoryBuilder.build(
        history: programHistory,
        todayDate: targetDate,
      );

      double? programScore;
      if (programResult.isUsable) {
        programScore = _programConfidenceCalculator.calculate(
          metrics: ProgramMetrics(
            todayProgramTradingValue: programResult.todayValue,
            averageProgramTradingValue: programResult.averageValue,
          ),
          historicalProgramValues: programResult.historicalProgramValues,
        );
      }

      // 회원사 집중도(HHI) — Supabase에 매일 자동 적재된 것을 읽어옴
      final brokerResult = await _brokerRepository.fetch(
        stockCode: _currentStockCode,
        targetDate: _toDashedDate(targetDate),
      );

      double? brokerScore;
      if (brokerResult.isUsable) {
        brokerScore = _percentileCalculator.calculate(
          value: brokerResult.todayHhi!,
          history: brokerResult.historicalHhiValues,
        );
      }

      // 네 지표가 모두 준비됐을 때만 참여확산도 → Confidence Multiplier → Crowd Score까지 계산
      double? participationSpreadScore;
      double? confidenceMultiplier;
      double? crowdScore;

      if (brokerScore != null &&
          investorScore != null &&
          programScore != null &&
          baseParticipationScore != null) {
        participationSpreadScore = _participationSpreadCalculator.calculate(
          brokerScore: brokerScore,
          investorScore: investorScore,
          programScore: programScore,
        );
        confidenceMultiplier = _confidenceMultiplierCalculator.calculate(
          participationSpreadScore,
        );
        crowdScore = _crowdScoreCalculator.calculate(
          baseParticipationScore: baseParticipationScore,
          confidenceMultiplier: confidenceMultiplier,
        );
      }

      setState(() {
        _quote = quote;
        _targetDate = targetDate;
        _scaleScore = scaleScore;
        _accelerationScore = accelerationScore;
        _investorScore = investorScore;
        _programScore = programScore;
        _brokerScore = brokerScore;
        _baseParticipationScore = baseParticipationScore;
        _participationSpreadScore = participationSpreadScore;
        _confidenceMultiplier = confidenceMultiplier;
        _crowdScore = crowdScore;
        _marketCap = targetMarketCap;
        _historyDayCount = historicalScaleValues.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crowd Stock MVP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _stockController,
              decoration: const InputDecoration(
                labelText: '종목코드',
                hintText: '예: 005930',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _fetchQuote,
              child: Text(_isLoading ? '조회 중...' : '조회 (기준일: 직전 영업일)'),
            ),

            const SizedBox(height: 24),

            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),

            if (_quote != null) ...[
              Text(
                '조회 종목 : $_currentStockCode  (기준일 : $_targetDate)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 12),
              Text('상장주식수 : ${_quote!.sharesOutstanding} 주'),
              const SizedBox(height: 8),
              Text(
                '시가총액(기준일 종가 기준) : ${_marketCap?.toStringAsFixed(0) ?? "-"} 원',
              ),

              const Divider(height: 32),

              Text(
                'Crowd Score : ${_crowdScore?.toStringAsFixed(2) ?? "계산 불가 (아래 지표 중 부족한 것 있음)"}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              Text(
                'Confidence Multiplier : ${_confidenceMultiplier != null ? "${_confidenceMultiplier!.toStringAsFixed(2)}배" : "-"}',
              ),
              Text(
                '참여확산도 : ${_participationSpreadScore?.toStringAsFixed(2) ?? "-"}',
              ),

              const Divider(height: 32),

              Text(
                'Base Participation Score : ${_baseParticipationScore?.toStringAsFixed(2) ?? "-"}',
              ),
              Text('  ├ Scale : ${_scaleScore?.toStringAsFixed(2) ?? "-"}'),
              Text(
                '  └ Acceleration : ${_accelerationScore?.toStringAsFixed(2) ?? "데이터 부족(20일치 미만)"}',
              ),
              const SizedBox(height: 8),
              Text(
                'Broker(회원사) : ${_brokerScore?.toStringAsFixed(2) ?? "Supabase 기록 부족"}',
              ),
              Text(
                'Investor(투자자) : ${_investorScore?.toStringAsFixed(2) ?? "데이터 부족"}',
              ),
              Text(
                'Program(프로그램매매) : ${_programScore?.toStringAsFixed(2) ?? "데이터 부족"}',
              ),

              const SizedBox(height: 16),
              const Text(
                '※ 기준일은 직전 영업일 확정값 — 장중 실시간 값이 아니라 일관된 비교가 가능함',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                '※ Scale 비교에 쓴 과거 기록 개수 : ${_historyDayCount ?? 0}일',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
