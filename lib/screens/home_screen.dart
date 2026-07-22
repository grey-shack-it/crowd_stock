import 'package:flutter/material.dart';
import '../services/kis_api.dart';
import 'stock_test_screen.dart';
import 'crowd_engine_test_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 앱 전체에서 하나만 사용 — 화면을 오가도 발급받은 토큰 캐시가 유지됨
  final KisApi _kisApi = KisApi();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crowd Stock')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StockTestScreen(kisApi: _kisApi),
                  ),
                );
              },
              child: const Text('종목 시세 조회 (StockTestScreen)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CrowdEngineTestScreen(),
                  ),
                );
              },
              child: const Text('Crowd Engine 테스트 (CrowdEngineTestScreen)'),
            ),
          ],
        ),
      ),
    );
  }
}
