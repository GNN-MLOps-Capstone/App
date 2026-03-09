import 'package:flutter/material.dart';

import '../models/watchlist_models.dart';
import '../services/watchlist_service.dart';
import 'main_page.dart'; // BottomNavBar
import 'search_page.dart';

// ── 정렬 옵션 ──────────────────────────────────────────

enum SortOption {
  userDefined('사용자 설정순'),
  issueHigh('이슈지수 높은 순'),
  issueLow('이슈지수 낮은 순'),
  changeRateHigh('등락률 높은 순'),
  changeRateLow('등락률 낮은 순'),
  priceHigh('가격 높은 순'),
  priceLow('가격 낮은 순'),
  volumeHigh('거래량 많은 순'),
  volumeLow('거래량 적은 순');

  final String label;

  const SortOption(this.label);
}

// ── 필터 ──────────────────────────────────────────

enum StockFilter { none, rising, falling }

// ══════════════════════════════════════════════════════
//  관심종목 메인 화면
// ══════════════════════════════════════════════════════

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
  StockFilter _filter = StockFilter.none;

  // 카드 펼침 상태
  final Set<String> _expandedCodes = {};

  // 편집 모드
  bool _editMode = false;
  final Set<String> _selectedCodes = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _service.getWatchlist(),
        _service.getBriefing(),
      ]);
      if (!mounted) return;
      setState(() {
        _stocks = results[0] as List<WatchlistStock>;
        _briefing = results[1] as WatchlistBriefing;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('관심종목 로드 실패: $e');
    }
  }

  // ── 정렬 ──

  List<WatchlistStock> get _sortedFilteredStocks {
    var list = List<WatchlistStock>.from(_stocks);

    // 필터
    if (_filter == StockFilter.rising) {
      list = list.where((s) => s.changeRate > 0).toList();
    } else if (_filter == StockFilter.falling) {
      list = list.where((s) => s.changeRate < 0).toList();
    }

    // 정렬
    switch (_sortOption) {
      case SortOption.changeRateHigh:
        list.sort((a, b) => b.changeRate.compareTo(a.changeRate));
        break;
      case SortOption.changeRateLow:
        list.sort((a, b) => a.changeRate.compareTo(b.changeRate));
        break;
      case SortOption.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortOption.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      default:
        break; // userDefined 및 미구현 옵션은 원래 순서
    }

    return list;
  }

  // ── 삭제 ──

  Future<void> _removeStock(String code) async {
    await _service.deleteStock(code);
    if (!mounted) return;
    setState(() {
      _stocks.removeWhere((s) => s.code == code);
      _expandedCodes.remove(code);
      _selectedCodes.remove(code);
    });
  }

  Future<void> _removeSelected() async {
    final codes = Set<String>.from(_selectedCodes);
    for (final code in codes) {
      await _service.deleteStock(code);
    }
    if (!mounted) return;
    setState(() {
      _stocks.removeWhere((s) => codes.contains(s.code));
      _expandedCodes.removeAll(codes);
      _selectedCodes.clear();
    });
  }

  // ── 네비게이션 ──

  void _onBottomTap(BuildContext context, int index) {
    if (index == 1) return; // 이미 관심

    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/news');
    } else if (index == 3) {
      Navigator.pushReplacementNamed(context, '/stock');
    }
  }

  // ── 정렬 바텀시트 ──

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '정렬 기준',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...SortOption.values.map((opt) {
                final isActive = _sortOption == opt;
                return ListTile(
                  title: Text(
                    opt.label,
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFF22C55E)
                          : Colors.black87,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: isActive
                      ? const Icon(Icons.check, color: Color(0xFF22C55E))
                      : null,
                  onTap: () {
                    setState(() => _sortOption = opt);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════
  //  빌드
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      bottomNavigationBar: BottomNavBar(
        initialIndex: 1,
        onIndexChanged: (i) => _onBottomTap(context, i),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: _stocks.isEmpty ? _buildEmptyView() : _buildBody(),
                  ),
                  if (_editMode && _selectedCodes.isNotEmpty) _buildDeleteBar(),
                ],
              ),
      ),
    );
  }

  // ── AppBar ──

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      child: Row(
        children: [
          const Text(
            '관심',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (!_editMode)
            IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/push_test');
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: const [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 26,
                    color: Colors.black87,
                  ),
                  Positioned(right: -2, top: -2, child: _Badge()),
                ],
              ),
            ),
          if (!_editMode)
            IconButton(
              onPressed: () => setState(() {
                _editMode = true;
                _selectedCodes.clear();
                _sortOption = SortOption.userDefined;
                _filter = StockFilter.none;
              }),
              icon: const Icon(
                Icons.edit_outlined,
                size: 24,
                color: Colors.black87,
              ),
            ),
          if (_editMode)
            TextButton(
              onPressed: () => setState(() {
                _editMode = false;
                _selectedCodes.clear();
              }),
              child: const Text(
                '완료',
                style: TextStyle(
                  color: Color(0xFF22C55E),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── 빈 화면 ──

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const Text(
              '아직 관심 종목이 없네요.\n요즘 핫한 종목을 추천해 드릴까요?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchPage()),
                  );
                },
                child: const Text(
                  '주식 탭으로 이동',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 메인 바디 ──

  Widget _buildBody() {
    final filtered = _sortedFilteredStocks;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 검색바
          _buildSearchBar(),
          const SizedBox(height: 16),

          // 종합 브리핑 카드
          if (_briefing != null) _buildBriefingCard(_briefing!),
          if (_briefing != null) const SizedBox(height: 16),

          // 종목 수 + 정렬 + 필터
          _buildSortFilterBar(filtered.length),
          const SizedBox(height: 12),

          // 종목 카드 리스트 (편집 모드에 따라 분기)
          if (_editMode)
            _buildEditableList(filtered)
          else
            _buildStockList(filtered),
        ],
      ),
    );
  }

  // ── 검색바 ──

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchPage()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.grey.shade400),
            const SizedBox(width: 10),
            Text(
              '종목명 검색',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  // ── 종합 브리핑 카드 ──

  Widget _buildBriefingCard(WatchlistBriefing briefing) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF34D399), Color(0xFF22C55E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI 종합 브리핑',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            briefing.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          if (briefing.topIssues.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: briefing.topIssues
                  .map(
                    (issue) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '#$issue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── 정렬/필터 바 ──

  Widget _buildSortFilterBar(int count) {
    return Row(
      children: [
        Text(
          '$count개',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _showSortSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _sortOption.label,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ),
        const Spacer(),
        _filterChip('상승', StockFilter.rising),
        const SizedBox(width: 6),
        _filterChip('하락', StockFilter.falling),
      ],
    );
  }

  Widget _filterChip(String label, StockFilter value) {
    final isActive = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filter = isActive ? StockFilter.none : value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF22C55E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF22C55E) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ── 종목 카드 리스트 (일반 모드) ──

  Widget _buildStockList(List<WatchlistStock> stocks) {
    return Column(
      children: stocks.map((stock) {
        final expanded = _expandedCodes.contains(stock.code);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _StockCard(
            stock: stock,
            expanded: expanded,
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedCodes.remove(stock.code);
                } else {
                  _expandedCodes.add(stock.code);
                }
              });
            },
            onHeartTap: () => _removeStock(stock.code),
          ),
        );
      }).toList(),
    );
  }

  // ── 편집 모드 리스트 ──

  Widget _buildEditableList(List<WatchlistStock> stocks) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stocks.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _stocks.removeAt(oldIndex);
          _stocks.insert(newIndex, item);
        });
      },
      itemBuilder: (context, index) {
        final stock = stocks[index];
        final selected = _selectedCodes.contains(stock.code);
        return Material(
          key: ValueKey(stock.code),
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Checkbox(
                  value: selected,
                  activeColor: const Color(0xFF22C55E),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedCodes.add(stock.code);
                      } else {
                        _selectedCodes.remove(stock.code);
                      }
                    });
                  },
                ),
                title: Text(
                  stock.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  '${_formatPrice(stock.price)}원',
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: const Icon(Icons.drag_handle, color: Colors.grey),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── 하단 삭제 바 ──

  Widget _buildDeleteBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _removeSelected,
            child: Text(
              '${_selectedCodes.length}개 종목 삭제',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 유틸 ──

  String _formatPrice(int price) {
    final str = price.toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return buf.toString();
  }
}

// ══════════════════════════════════════════════════════
//  종목 카드 위젯
// ══════════════════════════════════════════════════════

class _StockCard extends StatelessWidget {
  final WatchlistStock stock;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onHeartTap;

  const _StockCard({
    required this.stock,
    required this.expanded,
    required this.onTap,
    required this.onHeartTap,
  });

  String _weatherIcon(String weather) {
    switch (weather) {
      case 'SUNNY':
        return '\u2600\uFE0F'; // ☀️
      case 'CLOUDY':
        return '\u26C5'; // ⛅
      case 'RAINY':
        return '\u26C8\uFE0F'; // ⛈️
      default:
        return '\u26C5';
    }
  }

  Color _changeColor(double rate) {
    if (rate > 0) return const Color(0xFFEF4444); // 빨강 (상승)
    if (rate < 0) return const Color(0xFF3B82F6); // 파랑 (하락)
    return Colors.grey;
  }

  String _changeText(double rate) {
    final sign = rate > 0 ? '+' : '';
    return '$sign${rate.toStringAsFixed(1)}%';
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 행: 종목명 / 가격·등락률 / 하트
              Row(
                children: [
                  // 날씨 아이콘
                  Text(
                    _weatherIcon(stock.weather),
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 10),
                  // 종목명 + 태그
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stock.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (stock.keyword.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                stock.keyword,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF22C55E),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 가격 + 등락률
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_formatPrice(stock.price)}원',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _changeText(stock.changeRate),
                        style: TextStyle(
                          fontSize: 13,
                          color: _changeColor(stock.changeRate),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // 하트 아이콘
                  GestureDetector(
                    onTap: onHeartTap,
                    child: const Icon(
                      Icons.favorite,
                      color: Color(0xFF22C55E),
                      size: 22,
                    ),
                  ),
                ],
              ),

              // 펼침: AI 요약
              if (expanded && stock.aiSummary.isNotEmpty) ...[
                const Divider(height: 24),
                const Text(
                  'AI 요약',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF22C55E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  stock.aiSummary,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.6,
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

// ── 알림 뱃지 ──

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Color(0xFF22C55E),
        shape: BoxShape.circle,
      ),
      child: const Text(
        '2',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
