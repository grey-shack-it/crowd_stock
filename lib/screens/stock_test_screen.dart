import 'package:flutter/material.dart';
import '../services/kis_api.dart';
import '../services/scale_history_builder.dart';
import '../services/acceleration_history_builder.dart';
import '../engine/metrics/scale_metrics.dart';
import '../engine/metrics/acceleration_metrics.dart';
import '../engine/calculators/scale_calculator.dart';
import '../engine/calculators/acceleration_calculator.dart';
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
  final AccelerationCalculator _accelerationCalculator = const AccelerationCalculator(
    percentileCalculator: PercentileCalculator(),
  );
  final AccelerationHistoryBuilder _accelerationHistoryBuilder =
      const AccelerationHistoryBuilder();
  final TextEditingController _stockController = TextEditingController(
    text: '005930',
  );

  bool _isLoading = false;
  String? _error;
  StockQuote? _quote;
  String _currentStockCode = '';
  double? _scaleScore;
  double? _accelerationScore;
  double? _baseParticipationScore;
  double? _marketCap;
  int? _historyDayCount;

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  Future<void> _fetchQuote() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final quote = await _kisApi.fetchStockQuote(_stockController.text.trim());
      _currentStockCode = _stockController.text.trim();

      // 시가총액 = 상장주식수 × 현재가 (둘 다 원 단위 기준이라 변환 실수가 안 생김)
      final tradingValue = double.tryParse(quote.tradingValue) ?? 0;
      final currentPrice = double.tryParse(quote.currentPrice) ?? 0;
      final sharesOutstanding = double.tryParse(quote.sharesOutstanding) ?? 0;
      final marketCap = sharesOutstanding * currentPrice;

      // 최근 60일치(넉넉하게) 기간별시세로 Scale 과거값 backfill
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 90)); // 휴장일 감안해 넉넉히
      final priceHistory = await _kisApi.fetchDailyPriceHistory(
        stockCode: _currentStockCode,
        startDate: _formatDate(start),
        endDate: _formatDate(now),
      );

      final historicalScaleValues = _scaleHistoryBuilder.build(
        priceHistory: priceHistory,
        sharesOutstanding: sharesOutstanding,
      );

      final scaleScore = _scaleCalculator.calculate(
        metrics: ScaleMetrics(tradingValue: tradingValue, marketCap: marketCap),
        historicalScaleValues: historicalScaleValues,
      );

      // 오늘의 실시간 참여도 (Scale과 같은 값: 거래대금÷시가총액)
      final todayParticipation = marketCap > 0 ? tradingValue / marketCap : 0.0;

      final accelHistory = _accelerationHistoryBuilder.build(
        priceHistory: priceHistory,
        sharesOutstanding: sharesOutstanding,
        todayDate: _formatDate(now),
      );

      double? accelerationScore;
      double? baseParticipationScore;

      if (accelHistory.isUsable) {
        accelerationScore = _accelerationCalculator.calculate(
          metrics: AccelerationMetrics(
            todayParticipation: todayParticipation,
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

      setState(() {
        _quote = quote;
        _scaleScore = scaleScore;
        _accelerationScore = accelerationScore;
        _baseParticipationScore = baseParticipationScore;
        _marketCap = marketCap;
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
              child: Text(_isLoading ? '조회 중...' : '조회'),
            ),

            const SizedBox(height: 24),

            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),

            if (_quote != null) ...[
              Text(
                '조회 종목 : $_currentStockCode',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 12),
              Text('현재가 : ${_quote!.currentPrice}'),
              const SizedBox(height: 8),

              Text('거래량 : ${_quote!.volume}'),
              const SizedBox(height: 8),

              Text('거래대금 : ${_quote!.tradingValue}'),
              const SizedBox(height: 8),

              Text('상장주식수 : ${_quote!.sharesOutstanding} 주'),
              const SizedBox(height: 8),

              Text('시가총액(계산값) : ${_marketCap?.toStringAsFixed(0) ?? "-"} 원'),
              const SizedBox(height: 16),

              Text(
                'Scale Score (실데이터) : ${_scaleScore?.toStringAsFixed(2) ?? "-"}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Acceleration Score (실데이터) : ${_accelerationScore?.toStringAsFixed(2) ?? "데이터 부족(20일치 미만)"}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Base Participation Score : ${_baseParticipationScore?.toStringAsFixed(2) ?? "-"}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                '※ 과거 기록은 기간별시세 API로 실제 backfill됨 (아직 저장은 안 함, 조회할 때마다 새로 받아옴)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                '※ 비교에 쓴 과거 기록 개수 : ${_historyDayCount ?? 0}일',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
