import 'package:flutter/material.dart';
import 'stock_test_screen.dart';
import 'crowd_engine_test_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                  MaterialPageRoute(builder: (_) => const StockTestScreen()),
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
