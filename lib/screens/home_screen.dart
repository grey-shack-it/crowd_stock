import 'package:flutter/material.dart';
import '../services/kis_api.dart';
import '../services/stock_search_repository.dart';
import '../services/business_day_helper.dart';
import '../theme/app_colors.dart';
import 'stock_test_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 앱 전체에서 하나만 사용 — 화면을 오가도 발급받은 토큰 캐시가 유지됨
  final KisApi _kisApi = KisApi();
  final BusinessDayHelper _bd = const BusinessDayHelper();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  DateTime? _selectedDate; // null이면 직전 영업일
  StockInfo? _selectedStock; // 조회 버튼 누를 때 실제로 넘어갈 종목

  List<StockInfo> _autocomplete = [];
  bool _showRecent = false; // "최근조회목록" 드롭다운 펼침 여부

  @override
  void initState() {
    super.initState();
    StockSearchRepository.instance.ensureLoaded();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _autocomplete = []);
      } else {
        setState(() {});
      }
    });
  }

  void _onChanged(String query) {
    setState(() {
      _selectedStock = null; // 직접 타이핑하면 이전 선택은 무효화
      _autocomplete = query.trim().isEmpty
          ? []
          : StockSearchRepository.instance.search(query.trim());
    });
  }

  /// 자동완성/최근조회 목록에서 하나를 골랐을 때 — 입력만 채우고 조회는 안 함
  void _pickStock(StockInfo stock) {
    setState(() {
      _controller.text = stock.name;
      _selectedStock = stock;
      _autocomplete = [];
      _showRecent = false;
    });
    _focusNode.unfocus();
  }

  DateTime get _lastSelectableDate => _bd.previousBusinessDay(DateTime.now());

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: _lastSelectableDate,
      initialDate: _selectedDate ?? _lastSelectableDate,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() {
    // 자동완성에서 고른 종목이 없으면, 입력값과 정확히 이름이 일치하는 걸로 보정 시도
    StockInfo? stock = _selectedStock;
    if (stock == null) {
      final matches = StockSearchRepository.instance
          .search(_controller.text.trim())
          .where((s) => s.name == _controller.text.trim())
          .toList();
      stock = matches.isEmpty ? null : matches.first;
    }

    if (stock == null) return;
    final resolvedStock = stock; // closure 안에서 null 아님을 확실히 하기 위한 재바인딩

    StockSearchRepository.instance.addRecent(resolvedStock);
    _focusNode.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockTestScreen(
          kisApi: _kisApi,
          stockCode: resolvedStock.code,
          stockName: resolvedStock.name,
          initialDate: _selectedDate ?? _lastSelectableDate,
        ),
      ),
    );
  }

  Widget _dateChangeButton() {
    return TextButton(
      onPressed: _pickDate,
      style: TextButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: const Text('변경'),
    );
  }

  Widget _suggestionTile(StockInfo s) {
    return ListTile(
      title: Row(
        children: [
          Text(s.name),
          const SizedBox(width: 8),
          Text(
            s.code,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      onTap: () => _pickStock(s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final recentList = StockSearchRepository.instance.recent;

    return GestureDetector(
      onTap: () => _focusNode.unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Prism Index')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: keyboardOpen ? 24 : 0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.of(context).size.height -
                    kToolbarHeight -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisAlignment: keyboardOpen
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onChanged,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      hintText: '종목명을 입력하세요',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),

                  // 타이핑 중 자동완성
                  if (_autocomplete.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _autocomplete.length,
                        itemBuilder: (context, index) =>
                            _suggestionTile(_autocomplete[index]),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // 최근조회목록 — 드롭다운 토글
                  if (recentList.isNotEmpty) ...[
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _showRecent = !_showRecent),
                      icon: Icon(
                        _showRecent
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                      ),
                      label: const Text('최근조회목록'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                    if (_showRecent)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: recentList.length,
                          itemBuilder: (context, index) =>
                              _suggestionTile(recentList[index]),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '조회일 : ${(_selectedDate ?? _lastSelectableDate).month}월 ${(_selectedDate ?? _lastSelectableDate).day}일${_selectedDate == null ? "(직전 영업일)" : ""}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 4),
                      _dateChangeButton(),
                    ],
                  ),

                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _selectedStock == null ? null : _submit,
                    child: const Text('조회'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
