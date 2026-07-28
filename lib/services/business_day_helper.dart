/// 영업일(주말 제외) 관련 헬퍼. 공휴일은 아직 감안 안 함(v1).
class BusinessDayHelper {
  const BusinessDayHelper();

  String format(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  bool isBusinessDay(DateTime date) {
    return date.weekday != DateTime.saturday && date.weekday != DateTime.sunday;
  }

  DateTime previousBusinessDay(DateTime from) {
    var d = from.subtract(const Duration(days: 1));
    while (!isBusinessDay(d)) {
      d = d.subtract(const Duration(days: 1));
    }
    return d;
  }

  /// [end]를 포함해서 과거로 [count]개의 영업일을 오래된 순으로 돌려준다.
  List<DateTime> lastNBusinessDays({
    required DateTime end,
    required int count,
  }) {
    final result = <DateTime>[];
    var d = end;
    while (result.length < count) {
      if (isBusinessDay(d)) result.add(d);
      d = d.subtract(const Duration(days: 1));
    }
    return result.reversed.toList();
  }

  /// [start]~[end] 사이(둘 다 포함)의 영업일을 오래된 순으로 돌려준다.
  List<DateTime> businessDaysBetween({
    required DateTime start,
    required DateTime end,
  }) {
    final result = <DateTime>[];
    var d = start;
    while (!d.isAfter(end)) {
      if (isBusinessDay(d)) result.add(d);
      d = d.add(const Duration(days: 1));
    }
    return result;
  }
}
