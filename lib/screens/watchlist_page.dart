import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import '../models/watchlist_models.dart';
import '../services/watchlist_service.dart';
import '../services/stock_api_service.dart';
import '../services/news_api_service.dart';
import 'widgets/bottom_nav_bar.dart';
import 'stock_detail_page.dart';
import 'stock_page.dart';
import 'stock_search_page.dart';

enum SortOption {
  userDefined('사용자 설정순 (기본)'),
  issueIndexHigh('이슈지수 높은 순'),
  changeRateHigh('등락률 높은 순'),
  priceHigh('가격 높은 순'),
  volumeHigh('거래량 높은 순');

  final String label;
  const SortOption(this.label);
}

enum StockFilter { none, rising, falling }

List<String> _parseKeywords(String keyword) {
  if (keyword.trim().isEmpty) return [];
  return keyword
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .take(2)
      .toList();
}

class WatchlistPage extends StatefulWidget {
  const WatchlistPage({super.key});

  @override
  State<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends State<WatchlistPage> {
  final WatchlistService _service = WatchlistService();

  List<WatchlistStock> _stocks = [];
  WatchlistBriefing? _briefing;
  bool _loading = true;

  SortOption _sortOption = SortOption.userDefined;
  StockFilter _filter    = StockFilter.none;

  final Set<String> _expandedCodes = {};
  bool _editMode = false;

  List<StockItem> _allStocks = [];
  bool _stocksLoading = true;

  static final RegExp _shortCodePattern = RegExp(r'^[0-9A-Z]{6}$');
  static final RegExp _isuCdPattern = RegExp(r'^KR[0-9A-Z]{10}$');

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCsv();
  }

  Future<void> _loadCsv() async {
    try {
      final raw = await rootBundle.loadString('lib/screens/name.csv');
      final normalizedRaw = raw.replaceFirst('\uFEFF', '');
      final lines = const LineSplitter().convert(normalizedRaw);
      final parsed = <StockItem>[];
      for (int i = 0; i < lines.length; i++) {
        final t = lines[i].trim();
        if (t.isEmpty) continue;
        final lower = t.toLowerCase();
        if (i == 0 && lower.contains('name') && lower.contains('isu_cd')) continue;
        final cols = t.split(',');
        if (cols.length < 3) continue;
        final name = cols[0].trim();
        final isuCd = cols[2].trim();
        final explicitCode = cols.length >= 4 ? cols[3].trim().toUpperCase() : '';
        final code = _shortCodePattern.hasMatch(explicitCode)
            ? explicitCode
            : _toShortCode(isuCd);
        if (name.isEmpty || code == null) continue;
        parsed.add(StockItem(name: name, code: code));
      }
      if (!mounted) return;
      setState(() { _allStocks = parsed; _stocksLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _stocksLoading = false);
    }
  }

  String? _toShortCode(String isuCd) {
    final n = isuCd.trim().toUpperCase();
    if (_shortCodePattern.hasMatch(n)) return n;
    if (_isuCdPattern.hasMatch(n)) return n.substring(3, 9);
    return null;
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _service.getWatchlist(),
        _service.getBriefing(),
      ]);
      if (!mounted) return;

      final rawStocks = results[0] as List<WatchlistStock>;
      final briefing  = results[1] as WatchlistBriefing;
      final enriched  = await _enrichWithOverview(rawStocks);
      if (!mounted) return;

      setState(() {
        _stocks   = enriched;
        _briefing = briefing;
        _loading  = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('관심종목 로드 실패: $e');
    }
  }

  Future<List<WatchlistStock>> _enrichWithOverview(
      List<WatchlistStock> stocks) async {
    final futures = stocks.map((s) async {
      if (s.price != 0) return s;
      final shortCode = _service.toStockCode(s.code);
      try {
        final fetchResults = await Future.wait([
          StockApiService.getOverview(shortCode)
              .timeout(const Duration(seconds: 8)),
          StockApiService.getStockWeather(
              stockId: shortCode, stockName: s.name)
              .timeout(const Duration(seconds: 8))
              .catchError((_) => _rateToWeather(0.0)),
        ]);
        final overview = fetchResults[0] as StockOverview;
        final weather  = fetchResults[1] as String;
        return WatchlistStock(
          code: s.code, name: s.name, weather: weather,
          price: overview.lastPrice, changeRate: overview.changeRate,
          keyword: s.keyword, aiSummary: s.aiSummary,
          issueIndex: s.issueIndex, volume: overview.volume,
        );
      } catch (e) {
        debugPrint('overview 조회 실패 ($shortCode): $e');
        return s;
      }
    });
    return Future.wait(futures);
  }

  String _rateToWeather(double rate) {
    if (rate >= 3) return 'SUNNY';
    if (rate > 0)  return 'SUNNY';
    if (rate == 0) return 'CLOUDY';
    if (rate > -3) return 'CLOUDY';
    return 'RAINY';
  }

  List<WatchlistStock> get _sortedFilteredStocks {
    var list = List<WatchlistStock>.from(_stocks);
    if (_filter == StockFilter.rising) {
      list = list.where((s) => s.changeRate > 0).toList();
    } else if (_filter == StockFilter.falling) {
      list = list.where((s) => s.changeRate < 0).toList();
    }
    switch (_sortOption) {
      case SortOption.issueIndexHigh:
        list.sort((a, b) => b.issueIndex.compareTo(a.issueIndex)); break;
      case SortOption.changeRateHigh:
        list.sort((a, b) => b.changeRate.compareTo(a.changeRate)); break;
      case SortOption.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price)); break;
      case SortOption.volumeHigh:
        list.sort((a, b) => b.volume.compareTo(a.volume)); break;
      default: break;
    }
    return list;
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _stocks.removeAt(oldIndex);
      _stocks.insert(newIndex, item);
      _sortOption = SortOption.userDefined;
    });
  }

  Future<void> _removeStock(String code) async {
    await _service.deleteStock(code);
    _loadData();
  }

  void _onBottomTap(BuildContext context, int index) {
    if (index == 1) return;
    final routes = {0: '/home', 2: '/news', 3: '/stock'};
    if (routes.containsKey(index)) Navigator.pushReplacementNamed(context, routes[index]!);
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: SortOption.values.map((opt) {
            final isSelected = _sortOption == opt;
            return ListTile(
              title: Text(opt.label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF0EC272) : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  )),
              trailing: isSelected
                  ? const Icon(Icons.check, color: Color(0xFF0EC272))
                  : null,
              onTap: () {
                setState(() => _sortOption = opt);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      bottomNavigationBar: BottomNavBar(
          initialIndex: 1, onIndexChanged: (i) => _onBottomTap(context, i)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EC272)))
            : _stocks.isEmpty
            ? _buildEmptyView()
            : Column(children: [
          _buildAppBar(),
          Expanded(child: _editMode ? _buildEditBody() : _buildBody()),
        ]),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
        child: Row(children: [
          const Text('관심', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_outlined, size: 26)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings, size: 24)),
        ]),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: _buildSearchBar()),
      Expanded(
        child: Stack(children: [
          Align(
            alignment: const Alignment(0, -0.15),
            child: const Text(
              '아직 관심 종목이 없어요.\n요즘 많이 주목받는 종목을\n확인해 보실래요?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, height: 1.55),
            ),
          ),
          const Positioned(right: 16, bottom: 20, child: _StockTabSpeechBubble()),
        ]),
      ),
    ]);
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      child: Row(children: [
        const Text('관심', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (!_editMode) ...[
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_outlined, size: 26)),
          IconButton(
              onPressed: () => setState(() => _editMode = true),
              icon: const Icon(Icons.edit_outlined, size: 24)),
        ] else
          TextButton(
            onPressed: () => setState(() => _editMode = false),
            child: const Text('완료',
                style: TextStyle(color: Color(0xFF0EC272), fontWeight: FontWeight.bold)),
          ),
      ]),
    );
  }

  Widget _buildBody() {
    final filtered = _sortedFilteredStocks;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        const SizedBox(height: 8),
        _buildSearchBar(),
        const SizedBox(height: 16),
        if (_briefing != null) _buildBriefingCard(_briefing!),
        const SizedBox(height: 16),
        _buildSortFilterBar(filtered.length),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final s = filtered[i];
            final expanded = _expandedCodes.contains(s.code);
            return _WatchlistStockCard(
              key: ValueKey(s.code),
              stock: s,
              expanded: expanded,
              onExpandTap: () => setState(() =>
              expanded ? _expandedCodes.remove(s.code) : _expandedCodes.add(s.code)),
              onHeartTap: () => _removeStock(s.code),
            );
          },
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildEditBody() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: _buildSearchBar(),
      ),
      if (_briefing != null) ...[
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildBriefingCard(_briefing!),
        ),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(children: [
          Text('${_stocks.length}개',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(width: 8),
          const Text('드래그하여 순서를 변경하세요',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
      Expanded(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          itemCount: _stocks.length,
          onReorder: _onReorder,
          proxyDecorator: (child, index, animation) {
            return Material(
              elevation: 0,
              color: Colors.transparent,
              child: child,
            );
          },
          itemBuilder: (context, i) {
            final s = _stocks[i];
            return Padding(
              key: ValueKey(s.code),
              padding: const EdgeInsets.only(bottom: 12),
              child: _EditModeCard(stock: s),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(
            builder: (_) => StockSearchPage(
              allStocks: _allStocks,
              loading: _stocksLoading,
            ),
          )),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: const Color(0xFFE9EDF3),
            borderRadius: BorderRadius.circular(22)),
        child: const Row(children: [
          Icon(Icons.search, color: Colors.grey),
          SizedBox(width: 8),
          Text('종목을 검색하세요',
              style: TextStyle(color: Colors.grey, fontSize: 15)),
        ]),
      ),
    );
  }

  Widget _buildBriefingCard(WatchlistBriefing briefing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFF2F5F6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD3D3D3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SvgPicture.asset('assets/images/AI요약.svg', width: 32),
          const SizedBox(width: 8),
          const Text('종합 브리핑',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        const SizedBox(height: 10),
        Text(briefing.text, style: const TextStyle(fontSize: 15, height: 1.6)),
      ]),
    );
  }

  Widget _buildSortFilterBar(int count) {
    return Row(children: [
      Text('$count개',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const Spacer(),
      GestureDetector(
        onTap: _showSortSheet,
        child: Row(children: [
          Text(_sortOption.label,
              style: const TextStyle(fontSize: 13, color: Colors.black87)),
          const Icon(Icons.keyboard_arrow_down, size: 18),
        ]),
      ),
      const SizedBox(width: 10),
      _buildFilterText('상승', StockFilter.rising),
      const Text(' | ', style: TextStyle(color: Colors.grey)),
      _buildFilterText('하락', StockFilter.falling),
    ]);
  }

  Widget _buildFilterText(String label, StockFilter filterType) {
    final isSelected = _filter == filterType;
    return GestureDetector(
      onTap: () => setState(
              () => _filter = isSelected ? StockFilter.none : filterType),
      child: Text(label, style: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? const Color(0xFF0EC272) : Colors.black87,
      )),
    );
  }
}

class _KeywordTag extends StatelessWidget {
  final String label;
  const _KeywordTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black54,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _EmptyKeywordBox extends StatelessWidget {
  const _EmptyKeywordBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 18,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF3),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

Widget _buildKeywordTags(String keyword) {
  final tags = _parseKeywords(keyword);
  if (tags.isEmpty) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 4),
        const _EmptyKeywordBox(),
        const SizedBox(width: 4),
        const _EmptyKeywordBox(),
      ],
    );
  }
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: tags.map((t) => Padding(
      padding: const EdgeInsets.only(left: 4),
      child: _KeywordTag(t),
    )).toList(),
  );
}

class _EditModeCard extends StatelessWidget {
  final WatchlistStock stock;
  const _EditModeCard({required this.stock});

  String _formatPrice(int price) {
    final str = price.toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final rate  = stock.changeRate;
    final color = rate > 0
        ? const Color(0xFFEF4444)
        : (rate < 0 ? const Color(0xFF3B82F6) : Colors.grey);
    final rateText = '${rate > 0 ? '+' : ''}${rate.toStringAsFixed(1)}%';

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          const Icon(Icons.reorder, color: Colors.grey, size: 24),
          const SizedBox(width: 12),
          Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(
                  color: Color(0xFFEEEEEE), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(stock.name[0],
                  style: const TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(stock.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                _buildKeywordTags(stock.keyword),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Text('${_formatPrice(stock.price)}원',
                    style: const TextStyle(fontSize: 13, color: Colors.black87)),
                const SizedBox(width: 6),
                if (rate != 0) ...[
                  Icon(rate > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 10, color: color),
                  const SizedBox(width: 2),
                ],
                Text(rateText,
                    style: TextStyle(
                        fontSize: 13, color: color, fontWeight: FontWeight.bold)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _WatchlistStockCard extends StatefulWidget {
  final WatchlistStock stock;
  final bool expanded;
  final VoidCallback onExpandTap;
  final VoidCallback onHeartTap;

  _WatchlistStockCard(
      {super.key,
        required this.stock,
        required this.expanded,
        required this.onExpandTap,
        required this.onHeartTap});

  @override
  State<_WatchlistStockCard> createState() => _WatchlistStockCardState();
}

class _WatchlistStockCardState extends State<_WatchlistStockCard> {
  String _summary = '';
  bool _summaryLoading = false;
  List<String> _keywords = [];

  @override
  void initState() {
    super.initState();
    _summary = widget.stock.aiSummary;
    _loadKeywords();
  }

  @override
  void didUpdateWidget(_WatchlistStockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded && !oldWidget.expanded && _summary.isEmpty) {
      _loadSummary();
    }
  }

  Future<void> _loadSummary() async {
    if (_summaryLoading || _summary.isNotEmpty) return;
    setState(() => _summaryLoading = true);
    try {
      final data = await NewsApiService.getStockSummary(widget.stock.name);
      if (!mounted) return;
      setState(() {
        _summary = data.summary.trim().isEmpty
            ? '요약 정보가 없습니다.'
            : data.summary.trim();
        _summaryLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summary = '요약 정보를 불러오지 못했습니다.';
        _summaryLoading = false;
      });
    }
  }

  Future<void> _loadKeywords() async {
    try {
      final shortCode = WatchlistService().toStockCode(widget.stock.code);
      final data = await StockApiService.getThemeKeywords(shortCode);
      if (!mounted) return;
      setState(() {
        _keywords = data
            .take(2)
            .where((e) => e['keyword'] is String)
            .map((e) => e['keyword'] as String)
            .toList();
      });
    } catch (e) {
      debugPrint('키워드 로드 실패: $e');
    }
  }

  String _formatPrice(int price) {
    final str = price.toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final rate  = widget.stock.changeRate;
    final color = rate > 0
        ? const Color(0xFFEF4444)
        : (rate < 0 ? const Color(0xFF3B82F6) : Colors.grey);

    final weatherAsset = rate >= 5.0 ? '급등.svg'
        : rate > 0    ? '상승.svg'
        : rate <= -5.0 ? '급락.svg'
        : rate < 0    ? '하락.svg'
        : '보합.svg';

    final rateText = '${rate > 0 ? '+' : ''}${rate.toStringAsFixed(1)}%';

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    final shortCode = WatchlistService().toStockCode(widget.stock.code);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StockDetailPage(
                          stockName: widget.stock.name,
                          stockCode: shortCode.toUpperCase(),
                        ),
                      ),
                    );
                  },
                  child: Row(children: [
                    StockLogo(code: widget.stock.code, name: widget.stock.name),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(
                            child: Text(
                              widget.stock.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (_keywords.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            ..._keywords.map((kw) => Flexible(
                              child: Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  kw,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF7A818E),
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            )),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Text('${_formatPrice(widget.stock.price)}원',
                              style: const TextStyle(fontSize: 13, color: Colors.black87)),
                          const SizedBox(width: 6),
                          if (rate != 0) ...[
                            Icon(rate > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                                size: 10, color: color),
                            const SizedBox(width: 2),
                          ],
                          Text(rateText,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: color,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ),
              SvgPicture.asset('assets/images/$weatherAsset', width: 32, height: 32),
              const SizedBox(width: 12),
              GestureDetector(
                  onTap: widget.onHeartTap,
                  child: const Icon(Icons.favorite, color: Color(0xFF0EC272), size: 22)),
              const SizedBox(width: 8),
              GestureDetector(
                  onTap: () {
                    widget.onExpandTap();
                    if (!widget.expanded && _summary.isEmpty) _loadSummary();
                  },
                  child: Icon(
                      widget.expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey)),
            ]),
          ),
          if (widget.expanded)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SvgPicture.asset('assets/images/AI요약.svg', width: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryLoading
                      ? const SizedBox(
                      height: 20,
                      child: Center(
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0EC272)),
                          )))
                      : Text(
                      _summary.isEmpty ? '요약 정보가 없습니다.' : _summary,
                      style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: Colors.black87)),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _StockTabSpeechBubble extends StatelessWidget {
  const _StockTabSpeechBubble();
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, '/stock'),
      child: CustomPaint(
        painter: _SpeechBubblePainter(),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(22, 14, 22, 28),
          child: Text('주식 탭으로 이동하기',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ),
      ),
    );
  }
}

class _SpeechBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF0EC272);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width, size.height - 14),
            const Radius.circular(24)),
        paint);
    final path = Path()
      ..moveTo(size.width - 71, size.height - 14)
      ..lineTo(size.width - 53, size.height - 14)
      ..lineTo(size.width - 53, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}