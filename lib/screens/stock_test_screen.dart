import 'package:flutter/material.dart';
import '../services/kis_api.dart';
import '../services/scale_history_builder.dart';
import '../services/acceleration_history_builder.dart';
import '../services/investor_history_builder.dart';
import '../services/program_history_builder.dart';
import '../services/supabase_broker_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import 'crowd_score_graph_screen.dart';
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
  const StockTestScreen({
    super.key,
    required this.kisApi,
    required this.stockCode,
    required this.stockName,
    required this.initialDate,
  });

  final KisApi kisApi;
  final String stockCode;
  final String stockName;
  final DateTime initialDate;

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
  String? _stockName;
  bool _showBaseDetail = false;
  bool _showSpreadDetail = false;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentStockCode = widget.stockCode;
    _stockName = widget.stockName;
    _selectedDate = widget.initialDate;
    _fetchQuote();
  }

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
      // stockCode는 initState에서 이미 widget.stockCode로 설정됨

      // 기본값: 직전 영업일, 사용자가 날짜를 직접 골랐으면 그걸 사용
      final baseDate = _selectedDate ?? _previousBusinessDay(DateTime.now());
      final targetDate = _formatDate(baseDate);

      final quote = await _kisApi.fetchStockQuote(_currentStockCode);
      final sharesOutstanding = double.tryParse(quote.sharesOutstanding) ?? 0;

      String? stockName;
      try {
        final nameRow = await Supabase.instance.client
            .from('stock_universe')
            .select('stock_name')
            .eq('stock_code', _currentStockCode)
            .maybeSingle();
        stockName = nameRow?['stock_name'] as String?;
      } catch (_) {
        stockName = null; // 이름 조회 실패해도 나머지 조회는 계속 진행
      }

      // targetDate까지 90일치(넉넉하게) 기간별시세 조회
      final start = baseDate.subtract(const Duration(days: 90));
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
        _stockName = stockName;
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
        _showBaseDetail = false;
        _showSpreadDetail = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _dateChangeButton() {
    return TextButton(
      onPressed: () async {
        final now = DateTime.now();
        final lastSelectable = _previousBusinessDay(now);
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(now.year - 3),
          lastDate: lastSelectable,
          initialDate: _selectedDate ?? lastSelectable,
        );
        if (picked != null) {
          setState(() => _selectedDate = picked);
          _fetchQuote();
        }
      },
      style: TextButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: const Text('변경'),
    );
  }

  /// 세로로 긴 직사각형 게이지. 점수 비율만큼 아래에서부터 색이 채워진다.
  Widget _verticalGauge(double? score) {
    final ratio = score == null ? 0.0 : (score / 100).clamp(0.0, 1.0);
    final color = AppColors.confidenceColor(_confidenceMultiplier);

    return Container(
      width: 96,
      height: 110,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          FractionallySizedBox(
            heightFactor: ratio,
            widthFactor: 1,
            child: Container(color: color.withOpacity(0.25)),
          ),
          Center(
            child: Text(
              score?.toStringAsFixed(0) ?? '-',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summarySquare({
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
    bool expanded = false,
  }) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
                if (onTap != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, double? value, {String fallback = '데이터 부족'}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textPrimary)),
          Text(
            value?.toStringAsFixed(1) ?? fallback,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crowdScore = _crowdScore;

    return Scaffold(
      appBar: AppBar(title: const Text('Prism Index')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _stockName ?? widget.stockCode,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            Text(
              _currentStockCode,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '조회일 : ${_selectedDate != null ? "${_selectedDate!.month}월 ${_selectedDate!.day}일" : "직전 영업일"}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                _dateChangeButton(),
              ],
            ),

            const SizedBox(height: 16),

            if (_isLoading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.warning)),

            if (_quote != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 프리즘 지수 — 세로 게이지
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              '프리즘 지수',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _verticalGauge(crowdScore),
                          ],
                        ),
                      ),
                      if (crowdScore == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            '아래 지표 중 아직 데이터가 부족한 게 있어 계산이 안 됐어요',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // 3칸 요약 (크기 동일)
                      Row(
                        children: [
                          _summarySquare(
                            label: '기본 거래 점수',
                            value:
                                _baseParticipationScore?.toStringAsFixed(0) ??
                                '-',
                            color: AppColors.scoreColor(
                              _baseParticipationScore,
                            ),
                            expanded: _showBaseDetail,
                            onTap: () => setState(
                              () => _showBaseDetail = !_showBaseDetail,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _summarySquare(
                            label: '참여 분산 점수',
                            value:
                                _participationSpreadScore?.toStringAsFixed(0) ??
                                '-',
                            color: AppColors.scoreColor(
                              _participationSpreadScore,
                            ),
                            expanded: _showSpreadDetail,
                            onTap: () => setState(
                              () => _showSpreadDetail = !_showSpreadDetail,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _summarySquare(
                            label: '참여 가중치',
                            value: _confidenceMultiplier != null
                                ? 'x ${_confidenceMultiplier!.toStringAsFixed(2)}'
                                : '-',
                            color: AppColors.confidenceColor(
                              _confidenceMultiplier,
                            ),
                          ),
                        ],
                      ),

                      if (_showBaseDetail)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _detailRow('거래 규모', _scaleScore),
                              _detailRow(
                                '거래 가속도',
                                _accelerationScore,
                                fallback: '데이터 부족(20일치 미만)',
                              ),
                            ],
                          ),
                        ),

                      if (_showSpreadDetail)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _detailRow(
                                '거래원 집중도',
                                _brokerScore,
                                fallback: 'Supabase 기록 부족',
                              ),
                              _detailRow('투자자 집중도', _investorScore),
                              _detailRow('프로그램 변화량', _programScore),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),
                      const Text(
                        '※ 기준일은 직전 영업일 확정값 — 장중 실시간 값이 아니라 일관된 비교가 가능함',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CrowdScoreGraphScreen(
                                  kisApi: _kisApi,
                                  stockCode: _currentStockCode,
                                ),
                              ),
                            );
                          },
                          child: const Text('그래프 보기'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
