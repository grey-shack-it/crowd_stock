import 'package:flutter/material.dart';

class CrowdEngineTestScreen extends StatefulWidget {
  const CrowdEngineTestScreen({super.key});

  @override
  State<CrowdEngineTestScreen> createState() => _CrowdEngineTestScreenState();
}

class _CrowdEngineTestScreenState extends State<CrowdEngineTestScreen> {
  String result = '아직 실행하지 않음';
  void runTest() {
    setState(() {
      result = '테스트 실행 중...';
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
