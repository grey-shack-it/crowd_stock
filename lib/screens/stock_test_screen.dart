import 'package:flutter/material.dart';
import '../services/kis_api.dart';

class StockTestScreen extends StatefulWidget {
  const StockTestScreen({super.key});

  @override
  State<StockTestScreen> createState() => _StockTestScreenState();
}

class _StockTestScreenState extends State<StockTestScreen> {
  final KisApi _kisApi = KisApi();

  bool _isLoading = false;
  String? _error;
  StockQuote? _quote;

  Future<void> _fetchQuote() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final quote = await _kisApi.fetchSamsungQuote();

      setState(() {
        _quote = quote;
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
            ElevatedButton(
              onPressed: _isLoading ? null : _fetchQuote,
              child: Text(_isLoading ? '조회 중...' : '삼성전자 조회'),
            ),

            const SizedBox(height: 24),

            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),

            if (_quote != null) ...[
              Text('현재가 : ${_quote!.currentPrice}'),
              const SizedBox(height: 8),

              Text('거래량 : ${_quote!.volume}'),
              const SizedBox(height: 8),

              Text('거래대금 : ${_quote!.tradingValue}'),
            ],
          ],
        ),
      ),
    );
  }
}
