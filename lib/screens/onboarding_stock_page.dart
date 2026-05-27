import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main_page.dart';
import 'onboarding_keyword_page.dart';
import '../services/stock_api_service.dart';
import '../services/watchlist_service.dart';

List<String> _resolveCategoriesFromThemes(
  Set<String> selectedThemes,
  Map<String, List<String>> themeCategoryMap,
) {
  final categories = <String>{};
  for (final theme in selectedThemes) {
    final mapped = themeCategoryMap[theme];
    if (mapped != null) {
      categories.addAll(mapped);
    } else {
      // 기타 서브카테고리는 그대로 DB 카테고리명으로 사용
      categories.add(theme);
    }
  }
  return categories.toList();
}

class OnboardingStockPage extends StatefulWidget {
  final String userName;
  final Set<String> selectedThemes;
  final Map<String, List<String>> themeCategoryMap;

  const OnboardingStockPage({
    super.key,
    required this.userName,
    required this.selectedThemes,
    required this.themeCategoryMap,
  });

  @override
  State<OnboardingStockPage> createState() => _OnboardingStockPageState();
}

class _OnboardingStockPageState extends State<OnboardingStockPage> {
  final WatchlistService _watchlistService = WatchlistService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<OnboardingStock> _recommended = [];
  List<_CsvStock> _allCsvStocks = [];
  List<_CsvStock> _searchResults = [];
  final Map<String, String> _selectedStocks = {}; // code → name

  bool _recommendLoading = true;
  bool _csvLoading = true;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _loadRecommended();
    _loadCsv();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecommended() async {
    try {
      final categories = _resolveCategoriesFromThemes(widget.selectedThemes, widget.themeCategoryMap);
      final stocks = await StockApiService.getStocksByCategories(categories, limit: 10);
      if (!mounted) return;
      setState(() {
        _recommended = stocks;
        _recommendLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _recommendLoading = false);
    }
  }

  Future<void> _loadCsv() async {
    try {
      final raw = await rootBundle.loadString('lib/screens/name.csv');
      final normalized = raw.replaceFirst('﻿', '');
      final lines = const LineSplitter().convert(normalized);
      final result = <_CsvStock>[];
      final shortCode = RegExp(r'^[0-9A-Z]{6}$');

      for (int i = 0; i < lines.length; i++) {
        final t = lines[i].trim();
        if (t.isEmpty) continue;
        if (i == 0 && t.toLowerCase().contains('name')) continue;
        final cols = t.split(',');
        if (cols.length < 3) continue;
        final name = cols[0].trim();
        final isuCd = cols[2].trim();
        final explicit = cols.length >= 4 ? cols[3].trim().toUpperCase() : '';
        final code = shortCode.hasMatch(explicit) ? explicit : _toShortCode(isuCd);
        if (name.isEmpty || code == null) continue;
        result.add(_CsvStock(name: name, code: code));
      }

      if (!mounted) return;
      setState(() {
        _allCsvStocks = result;
        _csvLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _csvLoading = false);
    }
  }

  String? _toShortCode(String isuCd) {
    if (isuCd.length == 6) return isuCd;
    if (isuCd.startsWith('KR') && isuCd.length >= 9) return isuCd.substring(3, 9);
    return null;
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() {
      _searchResults = _allCsvStocks
          .where((s) => s.name.toLowerCase().contains(q) || s.code.toLowerCase().contains(q))
          .take(30)
          .toList();
    });
  }

  void _toggleStock(String code, String name) {
    setState(() {
      if (_selectedStocks.containsKey(code)) {
        _selectedStocks.remove(code);
      } else {
        _selectedStocks[code] = name;
      }
    });
  }

  Future<void> _onNext() async {
    setState(() => _completing = true);
    try {
      for (final entry in _selectedStocks.entries) {
        await _watchlistService.addStock(entry.key, name: entry.value);
      }
    } catch (e) {
      debugPrint('온보딩 종목 저장 오류: $e');
    }
    if (!mounted) return;
    setState(() => _completing = false);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OnboardingKeywordPage(userName: widget.userName)),
    );
  }

  bool get _isSearching => _searchController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, size: 24, color: Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            value: 2 / 3,
                            backgroundColor: Color(0xFFE0E0E0),
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C37A)),
                            minHeight: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    '관심 종목을 선택하세요',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A), height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '관심 테마 기반 추천 종목이에요',
                    style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
                  ),
                  const SizedBox(height: 20),
                  // 검색창
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Color(0xFF9E9E9E), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                            decoration: const InputDecoration(
                              hintText: '종목명 또는 코드 검색',
                              hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBDBDBD)),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_isSearching)
                          GestureDetector(
                            onTap: () => _searchController.clear(),
                            child: const Icon(Icons.close, color: Color(0xFF9E9E9E), size: 18),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // 선택된 종목 칩
            if (_selectedStocks.isNotEmpty)
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _selectedStocks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final entry = _selectedStocks.entries.elementAt(i);
                    return GestureDetector(
                      onTap: () => _toggleStock(entry.key, entry.value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C37A),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(entry.value, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 4),
                            const Icon(Icons.close, size: 14, color: Colors.white),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (_selectedStocks.isNotEmpty) const SizedBox(height: 12),

            // 추천 종목 or 검색 결과
            Expanded(
              child: _isSearching ? _buildSearchResults() : _buildRecommended(),
            ),

            // 다음 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _completing ? null : _onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C37A),
                    disabledBackgroundColor: const Color(0xFFBDBDBD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _completing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _selectedStocks.isEmpty ? '건너뛰기' : '다음 (${_selectedStocks.length}개 선택)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommended() {
    if (_recommendLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00C37A)));
    }
    if (_recommended.isEmpty) {
      return const Center(child: Text('추천 종목을 불러오지 못했어요', style: TextStyle(color: Color(0xFF9E9E9E))));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '테마별 시가총액 TOP ${_recommended.length}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _recommended.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final stock = _recommended[i];
              final isSelected = _selectedStocks.containsKey(stock.code);
              return _StockRow(
                rank: i + 1,
                name: stock.name,
                code: stock.code,
                isSelected: isSelected,
                onTap: () => _toggleStock(stock.code, stock.name),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_csvLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00C37A)));
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          '"${_searchController.text.trim()}" 검색 결과가 없어요',
          style: const TextStyle(color: Color(0xFF9E9E9E)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final stock = _searchResults[i];
        final isSelected = _selectedStocks.containsKey(stock.code);
        return _StockRow(
          name: stock.name,
          code: stock.code,
          isSelected: isSelected,
          onTap: () => _toggleStock(stock.code, stock.name),
        );
      },
    );
  }
}

class _CsvStock {
  final String name;
  final String code;
  const _CsvStock({required this.name, required this.code});
}

class _StockRow extends StatelessWidget {
  final String name;
  final String code;
  final bool isSelected;
  final VoidCallback onTap;
  final int? rank;

  const _StockRow({
    required this.name,
    required this.code,
    required this.isSelected,
    required this.onTap,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F8F1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF00C37A) : const Color(0xFFEEEEEE),
          ),
        ),
        child: Row(
          children: [
            if (rank != null) ...[
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF00C37A)),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 2),
                  Text(code, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
                ],
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF00C37A) : const Color(0xFFF2F2F2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected ? Icons.check : Icons.add,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF9E9E9E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
