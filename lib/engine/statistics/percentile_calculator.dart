class PercentileCalculator {
  const PercentileCalculator();

  double calculate({required double value, required List<double> history}) {
    if (history.isEmpty) {
      return 50.0;
    }

    final sorted = List<double>.from(history)..sort();

    int count = 0;

    for (final item in sorted) {
      if (item <= value) {
        count++;
      } else {
        break;
      }
    }

    return (count / sorted.length) * 100.0;
  }
}
