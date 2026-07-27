import 'kis_api.dart';

class ProgramHistoryResult {
  const ProgramHistoryResult({
    required this.todayValue,
    required this.averageValue,
    required this.historicalProgramValues,
  });

  final double todayValue;
  final double averageValue;
  final List<double> historicalProgramValues;

  bool get isUsable => historicalProgramValues.length >= 5 && averageValue > 0;
}

/// 종목별 프로그램매매추이(일별) 결과를 오늘값/최근평균/과거 비율 분포로 변환한다.
/// (Acceleration/Investor 빌더와 같은 패턴 — "그날이 today였다면"을 반복해서
/// 과거 percentile 비교용 분포를 직접 만든다.)
class ProgramHistoryBuilder {
  const ProgramHistoryBuilder();

  ProgramHistoryResult build({
    required List<DailyProgramPoint> history,
    required String todayDate,
  }) {
    final sorted = List<DailyProgramPoint>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));

    final todayIndex = sorted.indexWhere((p) => p.date == todayDate);
    final hasToday = todayIndex != -1;

    final today = hasToday ? sorted[todayIndex] : null;
    final past = hasToday ? sorted.sublist(0, todayIndex) : sorted;

    if (past.length < 10) {
      return const ProgramHistoryResult(
        todayValue: 0,
        averageValue: 0,
        historicalProgramValues: [],
      );
    }

    double avg(Iterable<double> values) =>
        values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

    final averageValue = avg(past.map((p) => p.programTradingValue));

    final historicalProgramValues = <double>[];
    for (var i = 5; i < past.length; i++) {
      final windowAvg = avg(
        past.sublist(0, i).map((p) => p.programTradingValue),
      );
      if (windowAvg > 0) {
        historicalProgramValues.add(past[i].programTradingValue / windowAvg);
      }
    }

    return ProgramHistoryResult(
      todayValue: today?.programTradingValue ?? 0,
      averageValue: averageValue,
      historicalProgramValues: historicalProgramValues,
    );
  }
}
