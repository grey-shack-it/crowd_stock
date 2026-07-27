import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';

// TODO: 라라시간표 Supabase 프로젝트의 Project URL / anon(publishable) key로 채우기
// KIS 앱키·시크릿과 달리 이 anon key는 클라이언트 코드에 그대로 둬도 되는
// "공개용" 키예요 (RLS로 접근 범위를 제한하는 게 정석이지만, 이건 다음 단계에서).
const supabaseUrl = 'https://zanepzdffiqhzifvuapa.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InphbmVwemRmZmlxaHppZnZ1YXBhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxNTI2NTQsImV4cCI6MjA5NDcyODY1NH0.AS9BG0F3_Bh_JqrQMCKMS5XeyRTPEwxpsyaKE-rgTkU';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Crowd Stock',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const HomeScreen(),
    );
  }
}
