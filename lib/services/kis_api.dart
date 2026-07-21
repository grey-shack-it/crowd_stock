import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/kis_config.dart';
import 'investor_flow.dart';

class StockQuote {
  const StockQuote({
    required this.currentPrice,
    required this.volume,
    required this.tradingValue,
  });

  final String currentPrice;
  final String volume;
  final String tradingValue;
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
    );
  }
}
