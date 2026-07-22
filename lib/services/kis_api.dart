import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/kis_config.dart';
import 'investor_flow.dart';

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
}
