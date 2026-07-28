import 'package:supabase_flutter/supabase_flutter.dart';

class BrokerHistoryResult {
  const BrokerHistoryResult({
    required this.todayHhi,
    required this.historicalHhiValues,
  });

  final double? todayHhi;
  final List<double> historicalHhiValues;

  bool get isUsable => todayHhi != null && historicalHhiValues.length >= 5;
}

/// stock_daily_metrics 테이블(회원사 HHI, Supabase에 매일 자동 적재됨)을
/// 읽어서 targetDate의 값과 그 이전 과거 기록을 나눠서 돌려준다.
class SupabaseBrokerRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// 그래프처럼 넓은 기간이 필요할 때 쓰는, 날짜→HHI 전체 매핑.
  Future<Map<String, double>> fetchAllHistory({
    required String stockCode,
  }) async {
    final rows = await _client
        .from('stock_daily_metrics')
        .select('trade_date, broker_hhi')
        .eq('stock_code', stockCode)
        .not('broker_hhi', 'is', null)
        .order('trade_date', ascending: true);

    final map = <String, double>{};
    for (final row in rows) {
      final date = row['trade_date'] as String;
      final hhi = (row['broker_hhi'] as num?)?.toDouble();
      if (hhi != null) map[date] = hhi;
    }
    return map;
  }

  Future<BrokerHistoryResult> fetch({
    required String stockCode,
    required String targetDate, // yyyy-MM-dd
    int lookbackDays = 60,
  }) async {
    final rows = await _client
        .from('stock_daily_metrics')
        .select('trade_date, broker_hhi')
        .eq('stock_code', stockCode)
        .not('broker_hhi', 'is', null)
        .order('trade_date', ascending: false)
        .limit(lookbackDays + 1);

    double? todayHhi;
    final historicalHhiValues = <double>[];

    for (final row in rows) {
      final date = row['trade_date'] as String;
      final hhi = (row['broker_hhi'] as num?)?.toDouble();
      if (hhi == null) continue;

      if (date == targetDate) {
        todayHhi = hhi;
      } else {
        historicalHhiValues.add(hhi);
      }
    }

    return BrokerHistoryResult(
      todayHhi: todayHhi,
      historicalHhiValues: historicalHhiValues,
    );
  }
}
