import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StockInfo {
  const StockInfo({required this.code, required this.name});
  final String code;
  final String name;

  Map<String, String> toJson() => {'code': code, 'name': name};
  factory StockInfo.fromJson(Map<String, dynamic> json) =>
      StockInfo(code: json['code'] as String, name: json['name'] as String);
}

/// stock_universe(3,556개)를 앱 켤 때 한 번만 통째로 받아서 메모리에 캐싱한다.
/// 이후 검색/자동완성은 전부 로컬에서 처리 — 타이핑할 때마다 서버에 안 물어봄.
/// 최근 조회 목록은 shared_preferences로 폰에 영구 저장한다.
class StockSearchRepository {
  StockSearchRepository._internal();
  static final StockSearchRepository instance =
      StockSearchRepository._internal();

  static const _recentKey = 'recent_stocks';

  List<StockInfo> _all = [];
  List<StockInfo> _recent = [];
  bool _loaded = false;
  bool _recentLoaded = false;

  Future<void> ensureLoaded() async {
    if (!_recentLoaded) {
      await _loadRecent();
    }
    if (_loaded) return;

    final rows = await Supabase.instance.client
        .from('stock_universe')
        .select('stock_code, stock_name')
        .eq('is_active', true);

    _all = (rows as List)
        .map(
          (r) => StockInfo(
            code: r['stock_code'] as String,
            name: r['stock_name'] as String,
          ),
        )
        .toList();
    _loaded = true;
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _recent = list
          .map((e) => StockInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    _recentLoaded = true;
  }

  Future<void> _saveRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_recent.map((s) => s.toJson()).toList());
    await prefs.setString(_recentKey, raw);
  }

  List<StockInfo> search(String query) {
    if (query.isEmpty) return [];
    final q = query.trim();
    return _all
        .where((s) => s.name.contains(q) || s.code.contains(q))
        .take(20)
        .toList();
  }

  List<StockInfo> get recent => List.unmodifiable(_recent);

  void addRecent(StockInfo stock) {
    _recent.removeWhere((s) => s.code == stock.code);
    _recent.insert(0, stock);
    if (_recent.length > 10) _recent.removeLast();
    _saveRecent();
  }

  void removeRecent(StockInfo stock) {
    _recent.removeWhere((s) => s.code == stock.code);
    _saveRecent();
  }
}
