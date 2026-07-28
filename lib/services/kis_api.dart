import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';

/// KIS 호출은 이제 전부 Supabase Edge Function(kis-proxy)을 거쳐요.
/// 이 클래스는 더 이상 KIS appkey/appsecret을 몰라요 — 서버가 대신 알고 있어요.
class _KisProxy {
  static final Uri _base = Uri.parse('$supabaseUrl/functions/v1/kis-proxy');

  static Future<http.Response> get({
    required String path,
    required Map<String, String> queryParams,
    required String trId,
    String trCont = '',
  }) {
    final uri = _base.replace(queryParameters: {'path': path, ...queryParams});

    return http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $supabaseAnonKey',
        'apikey': supabaseAnonKey,
        'x-kis-tr-id': trId,
        'x-kis-tr-cont': trCont,
      },
    );
  }
}

class DailyPricePoint {
  const DailyPricePoint({
    required this.date,
    required this.closePrice,
    required this.tradingValue,
  });

  final String date; // yyyyMMdd
  final double closePrice;
  final double tradingValue;
}

class InvestorDailyPoint {
  const InvestorDailyPoint({
    required this.date,
    required this.individualValue,
    required this.institutionValue,
    required this.foreignValue,
  });

  final String date; // yyyyMMdd
  final double individualValue;
  final double institutionValue;
  final double foreignValue;
}

class DailyProgramPoint {
  const DailyProgramPoint({
    required this.date,
    required this.programTradingValue,
  });

  final String date; // yyyyMMdd
  final double programTradingValue;
}

class StockQuote {
  const StockQuote({
    required this.currentPrice,
    required this.volume,
    required this.tradingValue,
    required this.marketCap,
    required this.sharesOutstanding,
  });

  final String currentPrice;
  final String volume;
  final String tradingValue;
  final String marketCap;
  final String sharesOutstanding;
}

class KisApi {
  Future<StockQuote> fetchStockQuote(String stockCode) async {
    final response = await _KisProxy.get(
      path: '/uapi/domestic-stock/v1/quotations/inquire-price',
      queryParams: {'FID_COND_MRKT_DIV_CODE': 'J', 'FID_INPUT_ISCD': stockCode},
      trId: 'FHKST01010100',
    );

    if (response.statusCode != 200) {
      throw Exception('현재가 조회 실패: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final output = data['output'] ?? {};

    return StockQuote(
      currentPrice: output['stck_prpr']?.toString() ?? '-',
      volume: output['acml_vol']?.toString() ?? '-',
      tradingValue: output['acml_tr_pbmn']?.toString() ?? '-',
      marketCap: output['hts_avls']?.toString() ?? '-',
      sharesOutstanding: output['lstn_stcn']?.toString() ?? '-',
    );
  }

  Future<List<DailyPricePoint>> fetchDailyPriceHistory({
    required String stockCode,
    required String startDate,
    required String endDate,
  }) async {
    final response = await _KisProxy.get(
      path: '/uapi/domestic-stock/v1/quotations/inquire-daily-itemchartprice',
      queryParams: {
        'FID_COND_MRKT_DIV_CODE': 'J',
        'FID_INPUT_ISCD': stockCode,
        'FID_INPUT_DATE_1': startDate,
        'FID_INPUT_DATE_2': endDate,
        'FID_PERIOD_DIV_CODE': 'D',
        'FID_ORG_ADJ_PRC': '1',
      },
      trId: 'FHKST03010100',
    );

    if (response.statusCode != 200) {
      throw Exception('기간별시세 조회 실패: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final List<dynamic> output2 = data['output2'] ?? [];

    return output2
        .map((row) {
          final closePrice =
              double.tryParse(row['stck_clpr']?.toString() ?? '') ?? 0;
          final tradingValue =
              double.tryParse(row['acml_tr_pbmn']?.toString() ?? '') ?? 0;
          final date = row['stck_bsop_date']?.toString() ?? '';

          return DailyPricePoint(
            date: date,
            closePrice: closePrice,
            tradingValue: tradingValue,
          );
        })
        .where((point) => point.date.isNotEmpty && point.closePrice > 0)
        .toList();
  }

  Future<List<InvestorDailyPoint>> fetchInvestorTradeHistory({
    required String stockCode,
    required String date,
  }) async {
    final List<dynamic> allRows = [];
    String trCont = '';

    for (var page = 0; page < 60; page++) {
      // 1년치까지 커버하도록 여유있게
      final response = await _KisProxy.get(
        path:
            '/uapi/domestic-stock/v1/quotations/investor-trade-by-stock-daily',
        queryParams: {
          'FID_COND_MRKT_DIV_CODE': 'J',
          'FID_INPUT_ISCD': stockCode,
          'FID_INPUT_DATE_1': date,
          'FID_ORG_ADJ_PRC': '',
          'FID_ETC_CLS_CODE': '1',
        },
        trId: 'FHPTJ04160001',
        trCont: trCont,
      );

      if (response.statusCode != 200) {
        throw Exception('투자자매매동향 조회 실패: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final List<dynamic> output2 = data['output2'] ?? [];
      allRows.addAll(output2);

      trCont = response.headers['tr_cont'] ?? '';
      if (trCont != 'M' && trCont != 'F') break;
      trCont = 'N';
    }

    double abs(dynamic v) => (double.tryParse(v?.toString() ?? '') ?? 0).abs();

    return allRows
        .map((row) {
          return InvestorDailyPoint(
            date: row['stck_bsop_date']?.toString() ?? '',
            individualValue: abs(row['prsn_ntby_tr_pbmn']),
            institutionValue: abs(row['orgn_ntby_tr_pbmn']),
            foreignValue: abs(row['frgn_ntby_tr_pbmn']),
          );
        })
        .where((point) => point.date.isNotEmpty)
        .toList();
  }

  Future<List<DailyProgramPoint>> fetchProgramTradeHistory({
    required String stockCode,
    required String date,
  }) async {
    final List<dynamic> allRows = [];
    String trCont = '';

    for (var page = 0; page < 60; page++) {
      // 1년치까지 커버하도록 여유있게
      final response = await _KisProxy.get(
        path: '/uapi/domestic-stock/v1/quotations/program-trade-by-stock-daily',
        queryParams: {
          'FID_COND_MRKT_DIV_CODE': 'J',
          'FID_INPUT_ISCD': stockCode,
          'FID_INPUT_DATE_1': date,
        },
        trId: 'FHPPG04650201',
        trCont: trCont,
      );

      if (response.statusCode != 200) {
        throw Exception('프로그램매매추이 조회 실패: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final rawOutput = data['output2'] ?? data['output'] ?? [];
      final List<dynamic> rows = rawOutput is List ? rawOutput : [rawOutput];
      allRows.addAll(rows);

      trCont = response.headers['tr_cont'] ?? '';
      if (trCont != 'M' && trCont != 'F') break;
      trCont = 'N';
    }

    double num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

    return allRows
        .map((row) {
          final sell = num(row['whol_smtn_seln_tr_pbmn']);
          final buy = num(row['whol_smtn_shnu_tr_pbmn']);
          return DailyProgramPoint(
            date: row['stck_bsop_date']?.toString() ?? '',
            programTradingValue: sell + buy,
          );
        })
        .where((point) => point.date.isNotEmpty)
        .toList();
  }
}
