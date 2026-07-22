import 'package:flutter/material.dart';
import '../services/kis_api.dart';
import '../engine/metrics/scale_metrics.dart';
import '../engine/calculators/scale_calculator.dart';
import '../engine/statistics/percentile_calculator.dart';

class StockTestScreen extends StatefulWidget {
  const StockTestScreen({super.key});

  @override
  State<StockTestScreen> createState() => _StockTestScreenState();
}

class _StockTestScreenState extends State<StockTestScreen> {
  final KisApi _kisApi = KisApi();
  final ScaleCalculator _scaleCalculator = const ScaleCalculator(
    percentileCalculator: PercentileCalculator(),
  );
  final TextEditingController _stockController = TextEditingController(
    text: '005930',
  );

  bool _isLoading = false;
  String? _error;
  StockQuote? _quote;
  String _currentStockCode = '';
  double? _scaleScore;
  double? _marketCap;

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

      // TODO: 백엔드(Supabase)가 준비되면 실제 과거 기록으로 교체
      const historicalScaleValues = [0.0012, 0.0015, 0.0017, 0.0020, 0.0023];

      final scaleScore = _scaleCalculator.calculate(
        metrics: ScaleMetrics(tradingValue: tradingValue, marketCap: marketCap),
        historicalScaleValues: historicalScaleValues,
      );

      setState(() {
        _quote = quote;
        _scaleScore = scaleScore;
        _marketCap = marketCap;
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
              const Text(
                '※ 과거 기록은 아직 임시값 — 백엔드 연결 전까지는 참고용',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
