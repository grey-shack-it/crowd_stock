import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/kis_api.dart';
import '../services/business_day_helper.dart';
import '../services/crowd_score_series_builder.dart';
import '../services/supabase_broker_repository.dart';

enum _Period { week, month, year, custom }

class CrowdScoreGraphScreen extends StatefulWidget {
  const CrowdScoreGraphScreen({
    super.key,
    required this.kisApi,
    required this.stockCode,
  });

  final KisApi kisApi;
  final String stockCode;

  @override
  State<CrowdScoreGraphScreen> createState() => _CrowdScoreGraphScreenState();
}

class _CrowdScoreGraphScreenState extends State<CrowdScoreGraphScreen> {
  final BusinessDayHelper _bd = const BusinessDayHelper();
  final CrowdScoreSeriesBuilder _seriesBuilder = CrowdScoreSeriesBuilder();
  final SupabaseBrokerRepository _brokerRepository = SupabaseBrokerRepository();

  KisApi get _kisApi => widget.kisApi;

  _Period _period = _Period.month;
  DateTimeRange? _customRange;

  bool _isLoading = false;
  String? _error;
  List<CrowdScorePoint> _points = [];
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<DateTime> _resolveTargetDates() {
    final today = _bd.previousBusinessDay(DateTime.now());

    switch (_period) {
      case _Period.week:
        return _bd.lastNBusinessDays(end: today, count: 5);
      case _Period.month:
        return _bd.lastNBusinessDays(end: today, count: 21);
      case _Period.year:
        return _bd.lastNBusinessDays(end: today, count: 250);
      case _Period.custom:
        final range = _customRange;
        if (range == null) return _bd.lastNBusinessDays(end: today, count: 21);
        return _bd.businessDaysBetween(start: range.start, end: range.end);
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedIndex = null;
    });

    try {
      final targetDates = _resolveTargetDates();
      if (targetDates.isEmpty) {
        throw Exception('선택한 기간에 영업일이 없어요.');
      }

      final earliest = targetDates.first;
      final latest = targetDates.last;
      // Acceleration(20일)·Investor/Program(10일) 계산에 필요한 여유분
      final fetchStart = earliest.subtract(const Duration(days: 60));

      final quote = await _kisApi.fetchStockQuote(widget.stockCode);
      final sharesOutstanding = double.tryParse(quote.sharesOutstanding) ?? 0;

      final priceHistory = await _kisApi.fetchDailyPriceHistory(
        stockCode: widget.stockCode,
        startDate: _bd.format(fetchStart),
        endDate: _bd.format(latest),
      );

      final investorHistory = await _kisApi.fetchInvestorTradeHistory(
        stockCode: widget.stockCode,
        date: _bd.format(latest),
      );

      final programHistory = await _kisApi.fetchProgramTradeHistory(
        stockCode: widget.stockCode,
        date: _bd.format(latest),
      );

      final brokerHistory = await _brokerRepository.fetchAllHistory(
        stockCode: widget.stockCode,
      );
      // Supabase는 yyyy-MM-dd, 나머지는 yyyyMMdd라 키를 맞춰줌
      final normalizedBrokerHistory = <String, double>{
        for (final entry in brokerHistory.entries)
          entry.key.replaceAll('-', ''): entry.value,
      };

      final points = _seriesBuilder.build(
        targetDates: targetDates.map(_bd.format).toList(),
        priceHistory: priceHistory,
        investorHistory: investorHistory,
        programHistory: programHistory,
        brokerHistoryByDate: normalizedBrokerHistory,
        sharesOutstanding: sharesOutstanding,
      );

      setState(() {
        _points = points;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openPeriodPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('1주 (직전 5영업일)'),
                onTap: () => Navigator.pop(context, _Period.week),
              ),
              ListTile(
                title: const Text('1개월 (직전 21영업일)'),
                onTap: () => Navigator.pop(context, _Period.month),
              ),
              ListTile(
                title: const Text('1년 (직전 250영업일)'),
                onTap: () => Navigator.pop(context, _Period.year),
              ),
              ListTile(
                title: const Text('직접 입력'),
                onTap: () => Navigator.pop(context, _Period.custom),
              ),
            ],
          ),
        );
      },
    ).then((selected) async {
      if (selected == null) return;

      if (selected == _Period.custom) {
        final now = DateTime.now();
        final lastSelectable = _bd.previousBusinessDay(now);
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 3),
          lastDate: lastSelectable,
          initialDateRange:
              _customRange ??
              DateTimeRange(
                start: lastSelectable.subtract(const Duration(days: 30)),
                end: lastSelectable,
              ),
        );
        if (range == null) return;
        setState(() {
          _period = _Period.custom;
          _customRange = range;
        });
      } else {
        setState(() => _period = selected);
      }

      _load();
    });
  }

  String _periodLabel() {
    switch (_period) {
      case _Period.week:
        return '1주';
      case _Period.month:
        return '1개월';
      case _Period.year:
        return '1년';
      case _Period.custom:
        if (_customRange == null) return '직접 입력';
        final s = _customRange!.start;
        final e = _customRange!.end;
        return '${s.month}/${s.day} ~ ${e.month}/${e.day}';
    }
  }

  /// isDegraded 여부가 바뀔 때마다 선을 끊어서, 근사 구간은 점선/회색으로
  /// 따로 그릴 수 있게 값들을 구간별로 쪼갠다.
  List<LineChartBarData> _buildSegments(
    List<double> Function(CrowdScorePoint) valueOf,
    Color color,
  ) {
    if (_points.isEmpty) return [];

    final segments = <LineChartBarData>[];
    var segStart = 0;

    for (var i = 1; i <= _points.length; i++) {
      final atEnd = i == _points.length;
      final degradedChanged =
          !atEnd && _points[i].isDegraded != _points[segStart].isDegraded;

      if (atEnd || degradedChanged) {
        final isDegraded = _points[segStart].isDegraded;
        final spots = <FlSpot>[];
        for (var j = segStart; j < i; j++) {
          final values = valueOf(_points[j]);
          for (final v in values) {
            spots.add(FlSpot(j.toDouble(), v));
          }
        }
        segments.add(
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: isDegraded ? color.withOpacity(0.4) : color,
            dashArray: isDegraded ? [6, 4] : null,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        );
        segStart = i;
      }
    }

    return segments;
  }

  Widget _buildSingleLineChart(
    String title,
    List<double> Function(CrowdScorePoint) valueOf,
    Color color,
  ) {
    if (_points.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              lineBarsData: _buildSegments(valueOf, color),
              titlesData: const FlTitlesData(show: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchCallback: (event, response) {
                  final spots = response?.lineBarSpots;
                  if (spots == null || spots.isEmpty) return;
                  final idx = spots.first.x.round();
                  if (idx != _selectedIndex) {
                    setState(() => _selectedIndex = idx);
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailPanel() {
    if (_selectedIndex == null || _points.isEmpty) {
      return const Text(
        '그래프를 눌러서 드래그하면 그 시점의 상세 점수를 볼 수 있어요.',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    final index = _selectedIndex!.clamp(0, _points.length - 1);
    final p = _points[index];
    final dateLabel =
        '${p.date.substring(0, 4)}-${p.date.substring(4, 6)}-${p.date.substring(6, 8)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (p.isDegraded)
            const Text(
              '※ 회원사 데이터가 아직 없어 투자자 지표만으로 계산한 근사값이에요',
              style: TextStyle(fontSize: 11, color: Colors.orange),
            ),
          const SizedBox(height: 6),
          Text('Crowd Score : ${p.crowdScore.toStringAsFixed(2)}'),
          Text(
            'Confidence Multiplier : ${p.confidenceMultiplier.toStringAsFixed(2)}배',
          ),
          Text(
            'Base(Scale ${p.scaleScore.toStringAsFixed(1)} / Accel ${p.accelerationScore.toStringAsFixed(1)}) : ${p.baseParticipationScore.toStringAsFixed(2)}',
          ),
          Text('참여확산도 : ${p.participationSpreadScore.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.stockCode} Crowd Score 추이'),
        actions: [
          TextButton(
            onPressed: _openPeriodPicker,
            child: Text(
              _periodLabel(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailPanel(),
                  const SizedBox(height: 24),
                  _buildSingleLineChart(
                    'Crowd Score',
                    (p) => [p.crowdScore],
                    Colors.blue,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '상세 1 — Scale / Acceleration',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        lineBarsData: [
                          ..._buildSegments((p) => [p.scaleScore], Colors.teal),
                          ..._buildSegments(
                            (p) => [p.accelerationScore],
                            Colors.purple,
                          ),
                        ],
                        titlesData: const FlTitlesData(show: false),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          touchCallback: (event, response) {
                            final spots = response?.lineBarSpots;
                            if (spots == null || spots.isEmpty) return;
                            final idx = spots.first.x.round();
                            if (idx != _selectedIndex)
                              setState(() => _selectedIndex = idx);
                          },
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    '● Scale   ● Acceleration',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  _buildSingleLineChart(
                    '상세 2 — Confidence Multiplier',
                    (p) => [p.confidenceMultiplier],
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '점선/옅은 색 구간 = 회원사 데이터 없어 근사 계산된 구간',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
    );
  }
}
