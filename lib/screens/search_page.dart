import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

class StockItem {
  final String displayName; // ✅ 한글명(대표명)만 화면에 표시
  final List<String> aliases; // ✅ 추가명(별칭들)
  final String code; // ✅ 표준코드

  StockItem({
    required this.displayName,
    required this.aliases,
    required this.code,
  });
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<StockItem> _allStocks = [];
  List<StockItem> _filtered = [];

  int _selectedIndex = -1;
  bool _loading = true;

  String _norm(String s) => s.trim().toLowerCase().replaceAll(' ', '');

  @override
  void initState() {
    super.initState();
    _loadCsv();

    _controller.addListener(() {
      _applyFilter(_controller.text);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCsv() async {
    try {
      // ✅ CSV 경로 유지
      final bytes = await rootBundle.load('lib/screens/stock_list.csv');
      final text = utf8.decode(bytes.buffer.asUint8List());

      final lines = text.split(RegExp(r'\r?\n')).map((e) => e.trim()).toList();
      final List<StockItem> items = [];

      for (final line in lines) {
        if (line.isEmpty) continue;

        // CSV: 한글명,추가명,표준코드
        final parts = line.split(',');
        if (parts.isEmpty) continue;

        final colA = parts[0].trim(); // 한글명(대표명)
        final colB = (parts.length >= 2) ? parts[1].trim() : ''; // 추가명
        final colC = (parts.length >= 3) ? parts[2].trim() : ''; // 표준코드

        // ✅ 헤더 제거
        if (colA == '한글명') continue;

        if (colA.isEmpty) continue;

        // ✅ 추가명은 "삼에스"처럼 1개일 수도 있고, "동부화재,DB손해보험"처럼 여러 개일 수도 있음
        // (콤마로 이미 split되므로 여러 별칭이 한 셀에 들어오는 케이스면 세미콜론/슬래시/공백 등으로 추가 분리 가능)
        final List<String> aliases = [];
        if (colB.isNotEmpty) aliases.add(colB);

        items.add(
          StockItem(
            displayName: colA,
            aliases: aliases,
            code: colC,
          ),
        );
      }

      setState(() {
        _allStocks = items;
        _filtered = [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV 로드 실패: $e')),
      );
    }
  }

  // ✅ 대표명/추가명 둘 다에서 대소문자 무시 검색
  void _applyFilter(String q) {
    final query = _norm(q);
    if (query.isEmpty) {
      setState(() {
        _filtered = [];
        _selectedIndex = -1;
      });
      return;
    }

    final result = _allStocks.where((s) {
      // 대표명 매칭
      if (_norm(s.displayName).contains(query)) return true;

      // 추가명(별칭) 매칭
      for (final a in s.aliases) {
        if (_norm(a).contains(query)) return true;
      }
      return false;
    }).take(50).toList();

    setState(() {
      _filtered = result;
      _selectedIndex = -1;
    });
  }

  void _onBottomTap(int index) {
    if (index == 0) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
              (route) => false,
        );
      }
      return;
    }

    const labels = ['홈', '관심', '뉴스', '주식'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${labels[index]} 화면은 아직 준비 중입니다.'),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),

      // ✅ 검색화면: 선택 없음(-1) => 아이콘 전부 회색 유지
      bottomNavigationBar: _BottomNavBar(
        initialIndex: -1,
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
                  const Text(
                    '검색',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
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
                        const Icon(
                          Icons.notifications_none_outlined,
                          size: 26,
                          color: Colors.black87,
                        ),
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
                    icon: const Icon(
                      Icons.settings,
                      size: 26,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 검색창
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        decoration: const InputDecoration(
                          hintText: '원하는 종목을 검색해 보세요',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const Icon(Icons.search, color: Colors.grey),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : (_controller.text.trim().isEmpty
                    ? const SizedBox.shrink()
                    : (_filtered.isEmpty
                    ? const Center(
                  child: Text(
                    '검색 결과가 없습니다.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final item = _filtered[index];
                    final isSelected = index == _selectedIndex;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedIndex = index),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ✅ 화면에는 대표명(한글명)만 표시
                                  Text(
                                    item.displayName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _pill('HBM'),
                                      const SizedBox(width: 8),
                                      _pill('실적'),
                                    ],
                                  ),

                                  // (선택) 별칭도 참고로 보여주고 싶으면 주석 해제
                                  // if (item.aliases.isNotEmpty) ...[
                                  //   const SizedBox(height: 6),
                                  //   Text(
                                  //     item.aliases.join(' · '),
                                  //     style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  //   ),
                                  // ],

                                  if (item.code.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      item.code,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.star_border,
                              color: Colors.grey,
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ================== 하단 네비게이션 바 (SearchPage 전용: 회색 유지) ==================
class _BottomNavBar extends StatefulWidget {
  final int initialIndex;
  final ValueChanged<int> onIndexChanged;

  const _BottomNavBar({
    required this.initialIndex,
    required this.onIndexChanged,
  });

  @override
  State<_BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<_BottomNavBar> {
  late int selectedIndex;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
  }

  void onTap(int index) {
    // ✅ SearchPage에서는 색이 바뀌면 안 되므로 selectedIndex 유지(-1)
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
            onTap: () => onTap(0),
          ),
          _BottomNavItem(
            icon: Icons.favorite_border,
            label: '관심',
            isActive: selectedIndex == 1,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => onTap(1),
          ),
          _BottomNavItem(
            icon: Icons.article_outlined,
            label: '뉴스',
            isActive: selectedIndex == 2,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => onTap(2),
          ),
          _BottomNavItem(
            icon: Icons.candlestick_chart,
            label: '주식',
            isActive: selectedIndex == 3,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => onTap(3),
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