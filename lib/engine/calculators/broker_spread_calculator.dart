import '../metrics/broker_metrics.dart';
import '../statistics/percentile_calculator.dart';

class BrokerSpreadCalculator {
  final PercentileCalculator percentileCalculator;

  const BrokerSpreadCalculator({required this.percentileCalculator});

  double calculate({
    required BrokerMetrics metrics,
    required List<double> historicalHhiValues,
  }) {
    final hhi = _calculateHHI(metrics.tradingValueByBroker);

    return percentileCalculator.calculate(
      value: hhi,
      history: historicalHhiValues,
    );
  }

  double _calculateHHI(Map<String, double> tradingValueByBroker) {
    if (tradingValueByBroker.isEmpty) {
      return 0.0;
    }

    final totalTradingValue = tradingValueByBroker.values.fold(
      0.0,
      (sum, value) => sum + value,
    );

    if (totalTradingValue <= 0) {
      return 0.0;
    }

    double hhi = 0.0;

    for (final tradingValue in tradingValueByBroker.values) {
      final share = tradingValue / totalTradingValue;
      hhi += share * share;
    }

    return hhi;
  }
}
