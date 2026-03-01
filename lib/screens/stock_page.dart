// lib/screens/stock_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'stock_detail_page.dart'; // ✅ 추가

class StockItem {
  final String name;
  final String code;

  StockItem({required this.name, required this.code});
}

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  bool _loading = true;
  List<StockItem> _allStocks = [];

  // (1번 화면) Top5는 지금은 더미
  final List<_TrendItem> _top5 = const [
    _TrendItem(rank: 1, name: '삼성전자', priceText: '72,500원', changeText: '-1.2%', isUp: false),
    _TrendItem(rank: 2, name: 'SK하이닉스', priceText: '186,000원', changeText: '+2.3%', isUp: true),
    _TrendItem(rank: 3, name: 'SK하이닉스', priceText: '186,000원', changeText: '+2.3%', isUp: true),
    _TrendItem(rank: 4, name: 'SK하이닉스', priceText: '186,000원', changeText: '+2.3%', isUp: true),
    _TrendItem(rank: 5, name: 'SK하이닉스', priceText: '186,000원', changeText: '+2.3%', isUp: true),
  ];

  @override
  void initState() {
    super.initState();
    _loadNameCsv();
  }

  Future<void> _loadNameCsv() async {
    setState(() => _loading = true);

    try {
      // ✅ 너가 말한 경로
      final raw = await rootBundle.loadString('lib/screens/name.csv');
      final lines = const LineSplitter().convert(raw);

      final parsed = <StockItem>[];

      for (final line in lines) {
        final t = line.trim();
        if (t.isEmpty) continue;

        // 헤더 추정 스킵
        final lower = t.toLowerCase();
        if (lower.contains('code') && lower.contains('name')) continue;

        final cols = t.split(',');
        String name = '';
        String code = '';

        if (cols.length >= 2) {
          final a = cols[0].trim();
          final b = cols[1].trim();

          // code처럼 보이는 쪽을 code로 추정
          final looksA = RegExp(r'^[0-9A-Za-z]{4,}$').hasMatch(a);
          final looksB = RegExp(r'^[0-9A-Za-z]{4,}$').hasMatch(b);

          if (looksA && !looksB) {
            code = a;
            name = b;
          } else {
            name = a;
            code = b;
          }
        } else {
          name = cols[0].trim();
          code = '';
        }

        if (name.isEmpty) continue;
        parsed.add(StockItem(name: name, code: code));
      }

      _allStocks = parsed;
    } catch (e) {
      debugPrint('name.csv 로드 실패: $e');
      _allStocks = [];
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockSearchPage(
          allStocks: _allStocks,
          loading: _loading,
        ),
      ),
    );
  }

  void _onBottomTap(int index) {
    if (index == 3) return; // 현재 주식 페이지

    const routeMap = {0: '/home', 1: '/watchlist', 2: '/news'};
    final route = routeMap[index];
    if (route == null) return;

    Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      bottomNavigationBar: BottomNavBar(
        initialIndex: 3,
        onIndexChanged: _onBottomTap,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '주식',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('알림 화면은 아직 준비 중입니다.')),
                      );
                    },
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_none_outlined, size: 26),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
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
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('설정 화면은 아직 준비 중입니다.')),
                      );
                    },
                    icon: const Icon(Icons.settings, size: 26),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 검색바
              GestureDetector(
                onTap: _openSearch,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9EDF3),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.search, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        '종목을 검색하세요',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                '오늘의 AI 트렌드 TOP 5',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'AI가 뉴스와 이슈를 분석해 긍정 신호가 많은 종목을 골랐어요',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),

              const SizedBox(height: 14),

              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: _top5.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final t = _top5[i];
                    return _TrendCard(item: t);
                  },
                ),
              ),

              // TODO(나중에): API 연결 후 Top5를 실제 데이터로 대체
            ],
          ),
        ),
      ),
    );
  }
}

/// ----------------------
/// (2번 화면) 검색 페이지
/// ----------------------
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

  List<StockItem> _filtered = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    _controller.addListener(() {
      _applyFilter(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _applyFilter(String q) {
    final query = q.trim();
    if (query.isEmpty) {
      setState(() => _filtered = []);
      return;
    }

    final lower = query.toLowerCase();
    final results = widget.allStocks.where((s) {
      return s.name.toLowerCase().contains(lower) ||
          s.code.toLowerCase().contains(lower);
    }).take(30).toList();

    setState(() => _filtered = results);
  }

  // ✅ 여기서 종목 탭 시 상세 화면으로 이동
  void _onTapStock(StockItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockDetailPage(stockName: item.name),
      ),
    );
  }

  void _onBottomTap(int index) {
    if (index == 3) return; // 현재 주식 탭

    const routeMap = {0: '/home', 1: '/watchlist', 2: '/news'};
    final route = routeMap[index];
    if (route == null) return;

    Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.loading;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      bottomNavigationBar: BottomNavBar(
        initialIndex: 3,
        onIndexChanged: _onBottomTap,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context), // ✅ 뒤로가기 → 주식 메인 복귀
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '검색',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_none_outlined, size: 26),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
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
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.settings, size: 26),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 검색 입력바
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9EDF3),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        decoration: const InputDecoration(
                          hintText: '종목명을 검색하세요',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              if (loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_controller.text.trim().isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      '종목명을 입력하면 자동완성 리스트가 나와요',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final s = _filtered[i];
                      return _SearchResultCard(
                        name: s.name,
                        onTap: () => _onTapStock(s), // ✅ 탭하면 상세 화면으로
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

/// ----------------------
/// UI 컴포넌트들
/// ----------------------
class _TrendItem {
  final int rank;
  final String name;
  final String priceText;
  final String changeText;
  final bool isUp;

  const _TrendItem({
    required this.rank,
    required this.name,
    required this.priceText,
    required this.changeText,
    required this.isUp,
  });
}

class _TrendCard extends StatelessWidget {
  final _TrendItem item;

  const _TrendCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final changeColor = item.isUp ? Colors.red : Colors.blue;
    final arrow = item.isUp ? '↗' : '↘';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${item.rank}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(item.priceText, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                    const SizedBox(width: 8),
                    Text(
                      '$arrow ${item.changeText}',
                      style: TextStyle(fontSize: 12, color: changeColor, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(Icons.wb_sunny, color: Color(0xFF22C55E)),
              ),
              const SizedBox(height: 4),
              const Text('AI 긍정', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _SearchResultCard({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      _TagChip(text: 'HBM'),
                      SizedBox(width: 8),
                      _TagChip(text: '실적'),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.star_border, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String text;
  const _TagChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// ----------------------
/// 하단바
/// ----------------------
class BottomNavBar extends StatefulWidget {
  final int initialIndex;
  final ValueChanged<int> onIndexChanged;

  const BottomNavBar({
    super.key,
    required this.initialIndex,
    required this.onIndexChanged,
  });

  @override
  State<BottomNavBar> createState() => BottomNavBarState();
}

class BottomNavBarState extends State<BottomNavBar> {
  late int selectedIndex;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
  }

  void _onTap(int index) {
    setState(() => selectedIndex = index);
    widget.onIndexChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    final Color activeColor = const Color(0xFF22C55E);
    final Color inactiveColor = Colors.grey.shade400;

    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomNavItem(
            icon: Icons.home,
            label: '홈',
            isActive: selectedIndex == 0,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => _onTap(0),
          ),
          _BottomNavItem(
            icon: Icons.favorite_border,
            label: '관심',
            isActive: selectedIndex == 1,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => _onTap(1),
          ),
          _BottomNavItem(
            icon: Icons.article_outlined,
            label: '뉴스',
            isActive: selectedIndex == 2,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => _onTap(2),
          ),
          _BottomNavItem(
            icon: Icons.candlestick_chart,
            label: '주식',
            isActive: selectedIndex == 3,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => _onTap(3),
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: isActive ? activeColor : inactiveColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: isActive ? activeColor : inactiveColor),
          ),
        ],
      ),
    );
  }
}