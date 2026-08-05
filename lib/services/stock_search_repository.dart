import 'package:supabase_flutter/supabase_flutter.dart';

class StockInfo {
  const StockInfo({required this.code, required this.name});
  final String code;
  final String name;
}

/// stock_universe(3,556개)를 앱 켤 때 한 번만 통째로 받아서 메모리에 캐싱한다.
/// 이후 검색/자동완성은 전부 로컬에서 처리 — 타이핑할 때마다 서버에 안 물어봄.
class StockSearchRepository {
  StockSearchRepository._internal();
  static final StockSearchRepository instance = StockSearchRepository._internal();

  List<StockInfo> _all = [];
  final List<StockInfo> _recent = []; // 세션 동안의 최근 조회 (앱 재시작 시 초기화)
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;

    final rows = await Supabase.instance.client
        .from('stock_universe')
        .select('stock_code, stock_name')
        .eq('is_active', true);

    _all = (rows as List)
        .map((r) => StockInfo(code: r['stock_code'] as String, name: r['stock_name'] as String))
        .toList();
    _loaded = true;
  }

  List<StockInfo> search(String query) {
    if (query.isEmpty) return [];
    final q = query.trim();
    return _all.where((s) => s.name.contains(q) || s.code.contains(q)).take(20).toList();
  }

  List<StockInfo> get recent => List.unmodifiable(_recent);

  void addRecent(StockInfo stock) {
    _recent.removeWhere((s) => s.code == stock.code);
    _recent.insert(0, stock);
    if (_recent.length > 10) _recent.removeLast();
  }
}
