// lib/screens/stock_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

import 'stock_detail_page.dart';
import 'stock_search_page.dart';
import 'widgets/bottom_nav_bar.dart';
import '../services/watchlist_service.dart';
import '../services/news_api_service.dart';
import '../services/stock_api_service.dart';
import '../services/notification_service.dart';

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

  List<_TrendItem> _top5 = [];
  bool _trendsLoading = false;

  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNameCsv();
    _loadTrends();
    _loadUnreadCount();
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

  // 더미데이터 사용
  /*
  Future<void> _loadTrends({int retryCount = 0}) async {
    setState(() => _trendsLoading = true);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() {
      _top5 = [
        const _TrendItem(rank: 1, name: '삼성전자', code: '005930', priceText: '72,500원', changeText: '-1.2%', isUp: false, weather: '하락'),
        const _TrendItem(rank: 2, name: 'SK하이닉스', code: '000660', priceText: '186,000원', changeText: '+2.3%', isUp: true, weather: '상승'),
        const _TrendItem(rank: 3, name: 'NAVER', code: '035420', priceText: '215,500원', changeText: '+0.8%', isUp: true, weather: '급등'),
        const _TrendItem(rank: 4, name: '카카오', code: '035720', priceText: '41,200원', changeText: '-3.1%', isUp: false, weather: '보합'),
        const _TrendItem(rank: 5, name: '삼성SDI', code: '006400', priceText: '385,000원', changeText: '+0.8%', isUp: true, weather: '상승'),
      ];
      _trendsLoading = false;
    });
  }
   */
  Future<void> _loadTrends({int retryCount = 0}) async {
    if (retryCount == 0) setState(() => _trendsLoading = true);
    try {
      final trends = await StockApiService.getAiTrends(topN: 5);
      if (!mounted) return;
      setState(() {
        _top5 = trends.map((t) => _TrendItem(
          rank: t.rank,
          name: t.name,
          code: t.code,
          weather: t.weather,
          priceText: t.lastPrice != null
              ? '${t.lastPrice!.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}원'
              : '-',
          changeText: t.changeRate != null
              ? '${t.changeRate! >= 0 ? '+' : ''}${t.changeRate!.toStringAsFixed(1)}%'
              : '-',
          isUp: t.changeRate == null ? null : t.changeRate! >= 0,
        )).toList();
        _trendsLoading = false;
      });
    } catch (e) {
      debugPrint('트렌드 로드 실패: $e');
      if (retryCount < 2) {
        await Future.delayed(const Duration(seconds: 2));
        return _loadTrends(retryCount: retryCount + 1);
      } else {
        if (!mounted) return;
        setState(() => _trendsLoading = false);
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await NotificationApiService.getUnreadNotificationCount();
      if (!mounted) return;
      setState(() {
        _unreadCount = count;
      });
    } catch (e) {
      debugPrint('❌ 주식 페이지 알림 개수 로드 실패: $e');
    }
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
                  const Text('주식', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/alarm').then((_) {
                            _loadUnreadCount(); // 알림 화면에서 돌아올 때 카운트 실시간 새로고침
                          });
                        },
                        icon: const Icon(
                          Icons.notifications_none_outlined,
                          size: 26,
                          color: Colors.black87,
                        ),
                      ),
                      if (_unreadCount > 0)
                        Positioned(
                          right: 6,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EC272),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 14,
                              minHeight: 14,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _unreadCount > 99 ? '99+' : '$_unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                    icon: const Icon(Icons.settings, size: 26, color: Colors.black87),
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

              _trendsLoading
                  ? const Expanded(child: Center(child: CircularProgressIndicator()))
                  : _top5.isEmpty
                  ? const Expanded(child: Center(child: Text('표시할 트렌드가 없습니다.')))
                  : Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: _top5.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final t = _top5[i];
                    return _TrendCard(
                      item: t,
                      onTap: () {
                        if (t.code.isEmpty) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StockDetailPage(
                              stockName: t.name,
                              stockCode: t.code.toUpperCase(),
                            ),
                          ),
                        );
                      },
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

class _TrendItem {
  final int rank;
  final String name;
  final String code;
  final String priceText;
  final String changeText;
  final bool? isUp;
  final String weather;

  const _TrendItem({
    required this.rank,
    required this.name,
    required this.code,
    required this.priceText,
    required this.changeText,
    required this.isUp,
    required this.weather,
  });
}

class _TrendCard extends StatefulWidget {
  final _TrendItem item;
  final VoidCallback? onTap;

  const _TrendCard({required this.item, this.onTap});

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  bool _isWatchlisted = false;
  bool _isExpanded = false;
  final WatchlistService _watchlistService = WatchlistService();
  String _aiSummary = '';
  bool _summaryLoading = false;
  List<String> _keywords = [];

  String _weatherSvg(String weather) {
    switch (weather) {
      case 'SUNNY':       return '급등';
      case 'PARTLY_CLOUDY': return '상승';
      case 'CLOUDY':      return '보합';
      case 'RAINY':       return '하락';
      case 'THUNDERSTORM': return '급락';
      default:            return '보합';
    }
  }

  @override
  void initState() {
    super.initState();
    _checkWatchlistStatus();
    _loadKeywords();
  }

  Future<void> _loadKeywords() async {
    try {
      final data = await StockApiService.getThemeKeywords(widget.item.code);
      if (!mounted) return;
      setState(() {
        _keywords = data.take(2).map((e) => e['keyword'] as String).toList();
      });
    } catch (e) {
      debugPrint('키워드 로드 실패: $e');
    }
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

  String _weatherToAsset(String weather) {
    const map = {
      'THUNDERSTORM': '급락',
      'RAINY': '하락',
      'CLOUDY': '보합',
      'PARTLY_CLOUDY': '상승',
      'SUNNY': '급등',
    };
    return map[weather] ?? '보합';
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
    final changeColor = widget.item.isUp == null
        ? Colors.grey
        : (widget.item.isUp! ? const Color(0xFFFF2B3A) : const Color(0xFF1E3CD6));

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
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StockLogo(code: widget.item.code, name: widget.item.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(widget.item.name, style: const TextStyle(fontSize: 15, color: Color(0xFF000000)), overflow: TextOverflow.ellipsis),
                            ),
                            if (_keywords.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              ..._keywords.map((kw) => Flexible(
                                child: Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(kw, style: const TextStyle(fontSize: 10, color: Color(
                                      0xFF7A818E), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                                ),
                              )),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(widget.item.priceText, style: const TextStyle(fontSize: 13, color: Color(0xFFA1A9B5))),
                            const SizedBox(width: 8),
                            Text(widget.item.changeText, style: TextStyle(fontSize: 13, color: changeColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SvgPicture.asset('assets/images/${_weatherSvg(widget.item.weather)}.svg', width: 34, height: 34),
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
      ),
    );
  }
}

class StockLogo extends StatelessWidget {
  final String code;
  final String name;
  const StockLogo({super.key, required this.code, required this.name});

  String get _assetCode {
    if (code.startsWith('KR') && code.length >= 9) return code.substring(3, 9);
    return code;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36, height: 36,
      child: ClipOval(
        child: Image.asset(
          'assets/images/stocks/$_assetCode.png',
          width: 36, height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      ),
    );
  }

  Widget _fallback() {
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFFE5E7EB),
      child: Text(
        name.isNotEmpty ? name[0] : '?',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }
}
