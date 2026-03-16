// lib/screens/stock_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

import 'stock_detail_page.dart';
import 'stock_search_page.dart'; // ✅ 검색 페이지 import (새 파일)
import 'widgets/bottom_nav_bar.dart';
import '../services/watchlist_service.dart';
import '../services/news_api_service.dart';

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
  static final RegExp _shortCodePattern = RegExp(r'^[0-9A-Z]{6}$');
  static final RegExp _isuCdPattern = RegExp(r'^KR[0-9A-Z]{10}$');

  final List<_TrendItem> _top5 = const [
    _TrendItem(rank: 1, name: '삼성전자', code: '005930', priceText: '72,500원', changeText: '-1.2%', isUp: false, sentiment: '하락'),
    _TrendItem(rank: 2, name: 'SK하이닉스', code: '000660', priceText: '186,000원', changeText: '+2.3%', isUp: true, sentiment: '상승'),
    _TrendItem(rank: 3, name: 'SK하이닉스', code: '000660', priceText: '186,000원', changeText: '+2.3%', isUp: true, sentiment: '급등'),
    _TrendItem(rank: 4, name: 'SK하이닉스', code: '000660', priceText: '186,000원', changeText: '+2.3%', isUp: true, sentiment: '보합'),
    _TrendItem(rank: 5, name: 'SK하이닉스', code: '000660', priceText: '186,000원', changeText: '+2.3%', isUp: true, sentiment: '상승'),
  ];

  @override
  void initState() {
    super.initState();
    _loadNameCsv();
  }

  Future<void> _loadNameCsv() async {
    setState(() => _loading = true);
    try {
      final raw = await rootBundle.loadString('lib/screens/name.csv');
      final normalizedRaw = raw.replaceFirst('\uFEFF', '');
      final lines = const LineSplitter().convert(normalizedRaw);
      final parsed = <StockItem>[];
      int invalidCount = 0;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final t = line.trim();
        if (t.isEmpty) continue;
        final lower = t.toLowerCase();
        if (i == 0 && lower.contains('name') && lower.contains('isu_cd')) continue;
        final cols = t.split(',');
        if (cols.length < 3) { invalidCount++; continue; }
        final name = cols[0].trim();
        final isuCd = cols[2].trim();
        final explicitCode = cols.length >= 4 ? cols[3].trim().toUpperCase() : '';
        final code = _shortCodePattern.hasMatch(explicitCode)
            ? explicitCode
            : _toShortCode(isuCd);
        if (name.isEmpty || code == null) { invalidCount++; continue; }
        parsed.add(StockItem(name: name, code: code));
      }

      debugPrint('name.csv 파싱 완료: valid=${parsed.length}, invalid=$invalidCount');
      _allStocks = parsed;
    } catch (e) {
      debugPrint('name.csv 로드 실패: $e');
      _allStocks = [];
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  String? _toShortCode(String isuCd) {
    final normalized = isuCd.trim().toUpperCase();
    if (_shortCodePattern.hasMatch(normalized)) return normalized;
    if (_isuCdPattern.hasMatch(normalized)) return normalized.substring(3, 9);
    return null;
  }

  void _openSearch() {
    if (_loading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('종목 데이터를 불러오는 중입니다. 잠시 후 다시 시도해주세요.')),
      );
      return;
    }
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
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  ),
                  const SizedBox(width: 4),
                  const Text('주식', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                      Text('종목을 검색하세요', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                  children: [
                    TextSpan(text: '오늘의 '),
                    TextSpan(text: 'AI', style: TextStyle(color: Color(0xFF0EC272))),
                    TextSpan(text: '픽 '),
                    TextSpan(text: 'TOP 5', style: TextStyle(color: Color(0xFF0EC272))),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                  children: [
                    TextSpan(text: 'AI', style: TextStyle(color: Color(0xFF0EC272))),
                    TextSpan(text: '가 뉴스를 분석해 선정했어요'),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: _top5.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _TrendCard(item: _top5[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendItem {
  final int rank;
  final String name;
  final String code;
  final String priceText;
  final String changeText;
  final bool isUp;
  final String sentiment;

  const _TrendItem({
    required this.rank,
    required this.name,
    required this.code,
    required this.priceText,
    required this.changeText,
    required this.isUp,
    required this.sentiment,
  });
}

class _TrendCard extends StatefulWidget {
  final _TrendItem item;
  const _TrendCard({required this.item});

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  bool _isWatchlisted = false;
  bool _isExpanded = false;
  final WatchlistService _watchlistService = WatchlistService();
  String _aiSummary = '';
  bool _summaryLoading = false;

  @override
  void initState() {
    super.initState();
    _checkWatchlistStatus();
  }

  Future<void> _checkWatchlistStatus() async {
    try {
      final list = await _watchlistService.getWatchlist();
      if (!mounted) return;
      setState(() => _isWatchlisted = list.any((s) => s.code == widget.item.code));
    } catch (e) {
      debugPrint('관심 여부 확인 실패: $e');
    }
  }

  Future<void> _toggleWatchlist() async {
    try {
      bool success;
      if (_isWatchlisted) {
        success = await _watchlistService.deleteStock(widget.item.code);
      } else {
        success = await _watchlistService.addStock(widget.item.code, name: widget.item.name);
      }
      if (!mounted) return;
      if (success) {
        setState(() => _isWatchlisted = !_isWatchlisted);
      } else {
        debugPrint('관심종목 처리 실패: 서버 응답 false');
      }
    } catch (e) {
      debugPrint('관심종목 처리 실패: $e');
    }
  }

  Future<void> _loadSummary() async {
    if (_aiSummary.isNotEmpty) return;
    setState(() => _summaryLoading = true);
    try {
      final data = await NewsApiService.getStockSummary(widget.item.name);
      if (!mounted) return;
      setState(() { _aiSummary = data.summary.trim(); _summaryLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _aiSummary = '요약 정보를 불러오지 못했습니다.'; _summaryLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final changeColor = widget.item.isUp ? Colors.red : Colors.blue;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
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
                StockLogo(code: widget.item.code),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(widget.item.priceText, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                          const SizedBox(width: 8),
                          SvgPicture.asset(
                            widget.item.isUp ? 'assets/images/up_arrow.svg' : 'assets/images/down_arrow.svg',
                            width: 8, height: 8,
                            colorFilter: ColorFilter.mode(changeColor, BlendMode.srcIn),
                          ),
                          const SizedBox(width: 2),
                          Text(widget.item.changeText, style: TextStyle(fontSize: 13, color: changeColor, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SvgPicture.asset('assets/images/${widget.item.sentiment}.svg', width: 34, height: 34),
                const SizedBox(width: 8),
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
                  child: Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFFBEC4CC), size: 22,
                  ),
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
    );
  }
}

// ✅ public으로 변경 (search_page.dart에서도 사용)
class StockLogo extends StatelessWidget {
  final String code;
  const StockLogo({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36, height: 36,
      child: ClipOval(
        child: SvgPicture.asset(
          'assets/images/logo/$code.svg',
          width: 36, height: 36,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(color: Color(0xFFD1D5DB), shape: BoxShape.circle),
          ),
          // ✅ 파일 없을 때 fallback
          errorBuilder: (_, __, ___) => Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(color: Color(0xFFD1D5DB), shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}