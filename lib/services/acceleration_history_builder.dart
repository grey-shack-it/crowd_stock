import 'kis_api.dart';

class AccelerationHistoryResult {
  const AccelerationHistoryResult({
    required this.average1Day,
    required this.average5Days,
    required this.average20Days,
    required this.historicalRatio1Day,
    required this.historicalRatio5Days,
    required this.historicalRatio20Days,
  });

  final double average1Day;
  final double average5Days;
  final double average20Days;

  final List<double> historicalRatio1Day;
  final List<double> historicalRatio5Days;
  final List<double> historicalRatio20Days;

  bool get isUsable =>
      average1Day > 0 && average5Days > 0 && average20Days > 0;
}

/// 기간별시세(priceHistory)를 날짜 오름차순 참여도(거래대금÷시가총액) 시계열로
/// 바꾸고, 그 시계열에서 "어제/5일평균/20일평균"과, 매일의 "그날÷직전평균" 비율
/// 분포(과거 비교용 historicalRatioXDay)까지 함께 만든다.
///
/// 오늘 날짜 데이터는 여기서 다루지 않는다 — 오늘 값은 실시간 조회(quote)로
/// 따로 받으므로, 여기서는 "어제까지"의 기록만 다룬다.
class AccelerationHistoryBuilder {
  const AccelerationHistoryBuilder();

  AccelerationHistoryResult build({
    required List<DailyPricePoint> priceHistory,
    required double sharesOutstanding,
    required String todayDate, // yyyyMMdd, 오늘 날짜는 제외하기 위해 필요
  }) {
    if (sharesOutstanding <= 0) {
      return _empty();
    }

    // 날짜 오름차순 정렬 + 오늘 데이터 제외
    final past = priceHistory.where((p) => p.date != todayDate).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final series = past
        .map((p) => (p.closePrice * sharesOutstanding) <= 0
            ? 0.0
            : p.tradingValue / (p.closePrice * sharesOutstanding))
        .where((v) => v > 0)
        .toList();

    if (series.length < 21) {
      // 20일 평균을 내기엔 기록이 부족함 (v1에서는 그냥 못 쓰는 걸로 처리)
      return _empty();
    }

    final average1Day = series.last;
    final average5Days = _average(series.sublist(series.length - 5));
    final average20Days = _average(series.sublist(series.length - 20));

    final historicalRatio1Day = <double>[];
    final historicalRatio5Days = <double>[];
    final historicalRatio20Days = <double>[];

    // series의 각 날짜를 "그날이 today였다면"으로 가정하고, 그 이전 기록으로
    // 같은 계산을 반복해서 과거 비율 분포를 만든다.
    for (var i = 20; i < series.length; i++) {
      final value = series[i];
      final prev1 = series[i - 1];
      final prev5 = _average(series.sublist(i - 5, i));
      final prev20 = _average(series.sublist(i - 20, i));

      if (prev1 > 0) historicalRatio1Day.add(value / prev1);
      if (prev5 > 0) historicalRatio5Days.add(value / prev5);
      if (prev20 > 0) historicalRatio20Days.add(value / prev20);
    }

    return AccelerationHistoryResult(
      average1Day: average1Day,
      average5Days: average5Days,
      average20Days: average20Days,
      historicalRatio1Day: historicalRatio1Day,
      historicalRatio5Days: historicalRatio5Days,
      historicalRatio20Days: historicalRatio20Days,
    );
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  AccelerationHistoryResult _empty() {
    return const AccelerationHistoryResult(
      average1Day: 0,
      average5Days: 0,
      average20Days: 0,
      historicalRatio1Day: [],
      historicalRatio5Days: [],
      historicalRatio20Days: [],
    );
  }
}
