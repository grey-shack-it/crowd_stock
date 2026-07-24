import 'kis_api.dart';

class InvestorHistoryResult {
  const InvestorHistoryResult({
    required this.todayIndividual,
    required this.todayInstitution,
    required this.todayForeign,
    required this.averageIndividual,
    required this.averageInstitution,
    required this.averageForeign,
    required this.historicalTvdValues,
  });

  final double todayIndividual;
  final double todayInstitution;
  final double todayForeign;

  final double averageIndividual;
  final double averageInstitution;
  final double averageForeign;

  final List<double> historicalTvdValues;

  bool get isUsable => historicalTvdValues.length >= 5;
}

/// 종목별 투자자매매동향(일별) 결과를 오늘값/최근평균/과거 TVD 분포로 변환한다.
/// TVD(Total Variation Distance) = 개인·기관·외국인 값이 "최근 평균과 얼마나
/// 다른가"를 하나의 숫자로 합친 것. 값이 클수록 평소와 다른 쏠림이 있다는 뜻.
class InvestorHistoryBuilder {
  const InvestorHistoryBuilder();

  InvestorHistoryResult build({
    required List<InvestorDailyPoint> history,
    required String todayDate,
  }) {
    // 날짜 오름차순 정렬
    final sorted = List<InvestorDailyPoint>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));

    final todayIndex = sorted.indexWhere((p) => p.date == todayDate);
    final hasToday = todayIndex != -1;

    final today = hasToday ? sorted[todayIndex] : null;
    final past = hasToday ? sorted.sublist(0, todayIndex) : sorted;

    if (past.length < 10) {
      return _empty();
    }

    double avg(Iterable<double> values) =>
        values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

    final averageIndividual = avg(past.map((p) => p.individualValue));
    final averageInstitution = avg(past.map((p) => p.institutionValue));
    final averageForeign = avg(past.map((p) => p.foreignValue));

    double tvd(InvestorDailyPoint p, double avgI, double avgO, double avgF) {
      final diffI = (p.individualValue - avgI).abs();
      final diffO = (p.institutionValue - avgO).abs();
      final diffF = (p.foreignValue - avgF).abs();
      return (diffI + diffO + diffF) / 2.0;
    }

    // "그날이 today였다면"을 반복해서 과거 TVD 분포를 만든다
    // (직전 5일 이상 있는 시점부터 시작)
    final historicalTvdValues = <double>[];
    for (var i = 5; i < past.length; i++) {
      final window = past.sublist(0, i);
      final wAvgI = avg(window.map((p) => p.individualValue));
      final wAvgO = avg(window.map((p) => p.institutionValue));
      final wAvgF = avg(window.map((p) => p.foreignValue));
      historicalTvdValues.add(tvd(past[i], wAvgI, wAvgO, wAvgF));
    }

    return InvestorHistoryResult(
      todayIndividual: today?.individualValue ?? 0,
      todayInstitution: today?.institutionValue ?? 0,
      todayForeign: today?.foreignValue ?? 0,
      averageIndividual: averageIndividual,
      averageInstitution: averageInstitution,
      averageForeign: averageForeign,
      historicalTvdValues: historicalTvdValues,
    );
  }

  InvestorHistoryResult _empty() {
    return const InvestorHistoryResult(
      todayIndividual: 0,
      todayInstitution: 0,
      todayForeign: 0,
      averageIndividual: 0,
      averageInstitution: 0,
      averageForeign: 0,
      historicalTvdValues: [],
    );
  }
}
