// lib/screens/search_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'stock_detail_page.dart';
import 'stock_page.dart';
import 'widgets/bottom_nav_bar.dart';
import '../services/watchlist_service.dart';
import '../services/news_api_service.dart';
import '../services/stock_api_service.dart';

class StockSearchPage extends StatefulWidget {
  final List<StockItem> allStocks;
  final bool loading;

  const StockSearchPage({
    super.key,
    required this.allStocks,
    required this.loading,
  });

  @override
  State<StockSearchPage> createState() => _StockSearchPageState();
}

class _StockSearchPageState extends State<StockSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  static final RegExp _shortCodePattern = RegExp(r'^[0-9A-Z]{6}$');
  List<StockItem> _filtered = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    _controller.addListener(() => _applyFilter(_controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _applyFilter(String q) {
    final query = q.trim();
    if (query.isEmpty) { setState(() => _filtered = []); return; }
    final lower = query.toLowerCase();
    final results = widget.allStocks.where((s) =>
    s.name.toLowerCase().contains(lower) || s.code.toLowerCase().contains(lower)
    ).take(30).toList();
    setState(() => _filtered = results);
  }

  void _onTapStock(StockItem item) {
    if (!_shortCodePattern.hasMatch(item.code.toUpperCase())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('유효하지 않은 종목코드입니다.')));
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => StockDetailPage(stockName: item.name, stockCode: item.code.toUpperCase()),
    ));
  }

  void _onBottomTap(int index) {
    if (index == 3) return;
    const routeMap = {0: '/home', 1: '/watchlist', 2: '/news'};
    final route = routeMap[index];
    if (route == null) return;
    Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      bottomNavigationBar: BottomNavBar(initialIndex: 3, onIndexChanged: _onBottomTap),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.black87)),
                  const SizedBox(width: 4),
                  const Text('검색', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_none_outlined, size: 26),
                        Positioned(
                          right: -2, top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                            child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.settings, size: 26)),
                ],
              ),

              const SizedBox(height: 10),

              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: const Color(0xFFE9EDF3), borderRadius: BorderRadius.circular(22)),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.black),
                        decoration: const InputDecoration(
                          hintText: '종목명을 검색하세요',
                          hintStyle: TextStyle(color: Colors.black),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              if (widget.loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_controller.text.trim().isEmpty)
                const Expanded(child: Center(child: Text('종목명을 입력하면 자동완성 리스트가 나와요', style: TextStyle(color: Colors.grey))))
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final s = _filtered[i];
                      return SearchResultCard(
                        key: ValueKey(s.code),
                        stock: s,
                        onTap: () => _onTapStock(s),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchResultCard extends StatefulWidget {
  final StockItem stock;
  final VoidCallback onTap;

  const SearchResultCard({super.key, required this.stock, required this.onTap});

  @override
  State<SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<SearchResultCard> {
  bool _isWatchlisted = false;
  bool _isExpanded = false;
  String _aiSummary = '';
  bool _summaryLoading = false;
  StockOverview? _overview;
  bool _overviewLoading = true;
  static final _wonFormat = NumberFormat('#,###');
  final WatchlistService _watchlistService = WatchlistService();

  @override
  void initState() {
    super.initState();
    _checkWatchlistStatus();
    _loadOverview();
  }

  Future<void> _checkWatchlistStatus() async {
    try {
      final list = await _watchlistService.getWatchlist();
      if (!mounted) return;
      setState(() => _isWatchlisted = list.any((s) => s.code == widget.stock.code));
    } catch (e) {
      debugPrint('관심 여부 확인 실패: $e');
    }
  }

  Future<void> _toggleWatchlist() async {
    final ok = _isWatchlisted
        ? await _watchlistService.deleteStock(widget.stock.code)
        : await _watchlistService.addStock(widget.stock.code, name: widget.stock.name);
    if (!mounted || !ok) return;
    setState(() => _isWatchlisted = !_isWatchlisted);
  }

  Future<void> _loadSummary() async {
    if (_aiSummary.isNotEmpty) return;
    setState(() => _summaryLoading = true);
    try {
      final data = await NewsApiService.getStockSummary(widget.stock.name);
      if (!mounted) return;
      setState(() { _aiSummary = data.summary.trim(); _summaryLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _aiSummary = '요약 정보를 불러오지 못했습니다.'; _summaryLoading = false; });
    }
  }

  Future<void> _loadOverview() async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final data = await StockApiService.getOverview(widget.stock.code);
        if (!mounted) return;
        setState(() { _overview = data; _overviewLoading = false; });
        return;
      } catch (e) {
        debugPrint('overview 로드 실패 (시도 ${attempt + 1}): $e');
        if (attempt < 2) await Future.delayed(const Duration(seconds: 1));
      }
    }
    if (!mounted) return;
    setState(() => _overviewLoading = false);
  }

  Widget _buildSentimentIcon(double changeRate) {
    String svgName;
    if (changeRate > 3) svgName = '급등';
    else if (changeRate > 0) svgName = '상승';
    else if (changeRate == 0) svgName = '보합';
    else if (changeRate > -3) svgName = '하락';
    else svgName = '급락';
    return SvgPicture.asset('assets/images/$svgName.svg', width: 34, height: 34);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StockLogo(code: widget.stock.code),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.stock.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        if (!_overviewLoading && _overview != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('${_wonFormat.format(_overview!.lastPrice)}원', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                              const SizedBox(width: 8),
                              SvgPicture.asset(
                                _overview!.changeRate >= 0 ? 'assets/images/up_arrow.svg' : 'assets/images/down_arrow.svg',
                                width: 8, height: 8,
                                colorFilter: ColorFilter.mode(_overview!.changeRate >= 0 ? Colors.red : Colors.blue, BlendMode.srcIn),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${_overview!.changeRate >= 0 ? "+" : ""}${_overview!.changeRate.toStringAsFixed(1)}%',
                                style: TextStyle(fontSize: 13, color: _overview!.changeRate >= 0 ? Colors.red : Colors.blue, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ] else if (_overviewLoading) ...[
                          const SizedBox(height: 4),
                          const SizedBox(height: 13, width: 80, child: LinearProgressIndicator(color: Color(0xFF0EC272), backgroundColor: Color(0xFFE9EDF3))),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_overviewLoading && _overview != null)
                    Padding(padding: const EdgeInsets.only(right: 8), child: _buildSentimentIcon(_overview!.changeRate)),
                  GestureDetector(
                    onTap: _toggleWatchlist,
                    child: Icon(Icons.favorite, color: _isWatchlisted ? const Color(0xFF0EC272) : const Color(0xFFD3D3D3), size: 22),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      if (!_isExpanded) _loadSummary();
                      setState(() => _isExpanded = !_isExpanded);
                    },
                    child: Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFFBEC4CC), size: 22),
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SvgPicture.asset('assets/images/AI요약.svg', width: 20, height: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _summaryLoading
                            ? const SizedBox(height: 20, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0EC272)))))
                            : Text(_aiSummary.isEmpty ? '요약 정보가 없습니다.' : _aiSummary, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.6)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}