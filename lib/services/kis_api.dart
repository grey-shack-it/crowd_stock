import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/kis_config.dart';
import 'investor_flow.dart';

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

  /// hts_avls. 억원 단위로 옴 (백만원 아님 — 실제 시세로 검증함)
  final String marketCap;

  /// lstn_stcn, 상장주식수(주 단위). marketCap 대신 이걸로
  /// "상장주식수 × 현재가"를 직접 계산하면 단위 실수가 생길 수 없음
  final String sharesOutstanding;
}

class InvestorDailyPoint {
  const InvestorDailyPoint({
    required this.date,
    required this.individualValue,
    required this.institutionValue,
    required this.foreignValue,
  });

  final String date; // yyyyMMdd

  /// 순매수 거래대금의 절대값(원). 방향(매수/매도)보다 "얼마나 활발히
  /// 움직였나"를 보려는 목적이라 절대값으로 다룬다.
  final double individualValue;
  final double institutionValue;
  final double foreignValue;
}

class KisApi {
  String? _accessToken;
  DateTime? _tokenCreatedAt;

  Future<String> _fetchAccessToken() async {
    if (_accessToken != null && _tokenCreatedAt != null) {
      final minutes = DateTime.now().difference(_tokenCreatedAt!).inMinutes;

      if (minutes < 50) {
        return _accessToken!;
      }
    }

    final uri = Uri.parse('${KisConfig.baseUrl}/oauth2/tokenP');

    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'grant_type': 'client_credentials',
        'appkey': KisConfig.appKey,
        'appsecret': KisConfig.appSecret,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('토큰 발급 실패: ${response.body}');
    }

    final data = jsonDecode(response.body);

    _accessToken = data['access_token'];
    _tokenCreatedAt = DateTime.now();

    return _accessToken!;
  }

  Future<StockQuote> fetchStockQuote(String stockCode) async {
    Future<InvestorFlow> fetchInvestorFlow(String stockCode) async {
      throw UnimplementedError();
    }

    final token = await _fetchAccessToken();

    final uri =
        Uri.parse(
          '${KisConfig.baseUrl}/uapi/domestic-stock/v1/quotations/inquire-price',
        ).replace(
          queryParameters: {
            'FID_COND_MRKT_DIV_CODE': 'J',
            'FID_INPUT_ISCD': stockCode,
          },
        );

    final response = await http.get(
      uri,
      headers: {
        'authorization': 'Bearer $token',
        'appkey': KisConfig.appKey,
        'appsecret': KisConfig.appSecret,
        'tr_id': KisConfig.trIdInquirePrice,
        'custtype': 'P',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('시세 조회 실패: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final output = data['output'];

    return StockQuote(
      currentPrice: output['stck_prpr']?.toString() ?? '-',
      volume: output['acml_vol']?.toString() ?? '-',
      tradingValue: output['acml_tr_pbmn']?.toString() ?? '-',
      marketCap: output['hts_avls']?.toString() ?? '-',
      sharesOutstanding: output['lstn_stcn']?.toString() ?? '-',
    );
  }

  /// 국내주식기간별시세(일/주/월/년), 종목당 한 번의 호출로 최대 100영업일치를 준다.
  /// startDate/endDate는 yyyyMMdd 형식.
  Future<List<DailyPricePoint>> fetchDailyPriceHistory({
    required String stockCode,
    required String startDate,
    required String endDate,
  }) async {
    final token = await _fetchAccessToken();

    final uri =
        Uri.parse(
          '${KisConfig.baseUrl}/uapi/domestic-stock/v1/quotations/inquire-daily-itemchartprice',
        ).replace(
          queryParameters: {
            'FID_COND_MRKT_DIV_CODE': 'J',
            'FID_INPUT_ISCD': stockCode,
            'FID_INPUT_DATE_1': startDate,
            'FID_INPUT_DATE_2': endDate,
            'FID_PERIOD_DIV_CODE': 'D',
            'FID_ORG_ADJ_PRC': '1',
          },
        );

    final response = await http.get(
      uri,
      headers: {
        'authorization': 'Bearer $token',
        'appkey': KisConfig.appKey,
        'appsecret': KisConfig.appSecret,
        'tr_id': 'FHKST03010100',
        'custtype': 'P',
      },
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
        // 휴장일 등 빈 행(날짜 없음)은 제외
        .where((point) => point.date.isNotEmpty && point.closePrice > 0)
        .toList();
  }

  /// 종목별 투자자매매동향(일별). 한 번에 다 안 올 수 있어서, 응답 헤더의
  /// tr_cont가 "M"/"F"(더 있음)인 동안 이어서 호출해 전부 모은다.
  Future<List<InvestorDailyPoint>> fetchInvestorTradeHistory({
    required String stockCode,
    required String date,
  }) async {
    final token = await _fetchAccessToken();
    final List<dynamic> allRows = [];
    String trCont = '';

    for (var page = 0; page < 10; page++) {
      final uri =
          Uri.parse(
            '${KisConfig.baseUrl}/uapi/domestic-stock/v1/quotations/investor-trade-by-stock-daily',
          ).replace(
            queryParameters: {
              'FID_COND_MRKT_DIV_CODE': 'J',
              'FID_INPUT_ISCD': stockCode,
              'FID_INPUT_DATE_1': date,
              'FID_ORG_ADJ_PRC': '',
              'FID_ETC_CLS_CODE': '',
            },
          );

      final response = await http.get(
        uri,
        headers: {
          'authorization': 'Bearer $token',
          'appkey': KisConfig.appKey,
          'appsecret': KisConfig.appSecret,
          'tr_id': 'FHPTJ04160001',
          'tr_cont': trCont,
          'custtype': 'P',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('투자자매매동향 조회 실패: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final List<dynamic> output2 = data['output2'] ?? [];
      allRows.addAll(output2);

      trCont = response.headers['tr_cont'] ?? '';
      if (trCont != 'M' && trCont != 'F') {
        break; // 더 이상 다음 페이지 없음
      }
      trCont = 'N'; // 다음 요청은 "이어서 주세요" 값으로 보냄
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
}
