import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

class StockItem {
  final String name;
  final String code;
  StockItem({required this.name, required this.code});
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

  @override
  void initState() {
    super.initState();
    _loadCsv();

    _controller.addListener(() {
      _applyFilter(_controller.text);
    });

    // 화면 들어오면 키보드 바로 올라오게
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
      // ✅ pubspec.yaml에 assets 등록되어 있어야 함 (아래 3번 참고)
      // stock_list.csv가 "lib/screens/stock_list.csv"에 있으니 그대로 경로 사용
      final bytes = await rootBundle.load('lib/screens/stock_list.csv');
      final text = utf8.decode(bytes.buffer.asUint8List());

      // CSV 예시: "삼성전자,KR7005930003"
      final lines = text.split(RegExp(r'\r?\n')).map((e) => e.trim()).toList();
      final List<StockItem> items = [];

      for (final line in lines) {
        if (line.isEmpty) continue;
        final parts = line.split(',');
        if (parts.isEmpty) continue;

        final name = parts[0].trim();
        final code = (parts.length >= 2) ? parts[1].trim() : '';

        if (name.isEmpty) continue;
        items.add(StockItem(name: name, code: code));
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

  void _applyFilter(String q) {
    final query = q.trim();
    if (query.isEmpty) {
      setState(() {
        _filtered = [];
        _selectedIndex = -1;
      });
      return;
    }

    final result = _allStocks
        .where((s) => s.name.contains(query)) // ✅ "삼성" 포함 종목 전부
        .take(50) // 너무 많으면 UI 느려질 수 있어서 상한
        .toList();

    setState(() {
      _filtered = result;
      _selectedIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: "검색" + 아이콘들
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

              // 리스트 영역
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
                      onTap: () {
                        setState(() => _selectedIndex = index);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF3B82F6)
                                : Colors.transparent,
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
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
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

                            // 오른쪽: (지금은 등락률 미구현) + 즐겨찾기
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: const [
                                SizedBox(height: 6),
                                Icon(
                                  Icons.star_border,
                                  color: Colors.grey,
                                  size: 28,
                                ),
                              ],
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