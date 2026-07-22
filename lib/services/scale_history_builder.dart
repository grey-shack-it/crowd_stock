import 'kis_api.dart';

/// 기간별시세(날짜별 종가·거래대금)와 상장주식수를 받아
/// 날짜별 Scale 값(거래대금÷시가총액) 리스트를 만든다.
///
/// 시가총액은 "상장주식수 × 그날 종가"로 근사한다. 상장주식수는 최근 값을
/// 그대로 과거에 적용하는 거라, 그 사이 유상증자·자사주 매입 같은 큰 이벤트가
/// 있었다면 오차가 생길 수 있다 (v1에서는 허용 가능한 근사치로 취급).
class ScaleHistoryBuilder {
  const ScaleHistoryBuilder();

  List<double> build({
    required List<DailyPricePoint> priceHistory,
    required double sharesOutstanding,
  }) {
    if (sharesOutstanding <= 0) {
      return [];
    }

    return priceHistory
        .map((point) {
          final marketCap = sharesOutstanding * point.closePrice;
          if (marketCap <= 0) return 0.0;
          return point.tradingValue / marketCap;
        })
        .where((scale) => scale > 0)
        .toList();
  }
}
