// lib/screens/main_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../models/news_models.dart';
import '../models/watchlist_models.dart';
import '../services/watchlist_service.dart';
import '../services/news_api_service.dart';
import '../services/user_api_service.dart';
import '../services/notification_service.dart';
import 'widgets/bottom_nav_bar.dart';

// TODO: 팀원이 키워드 API 구현 시 교체
const List<String> _dummyKeywords = ['HBM', 'AI반도체', '2차전지', '전고체', '반도체'];

class StockHomeScreen extends StatefulWidget {
  final String? userName;
  const StockHomeScreen({super.key, this.userName});

  @override
  State<StockHomeScreen> createState() => _StockHomeScreenState();
}

class _StockHomeScreenState extends State<StockHomeScreen> {
  List<WatchlistStock> _watchlist = [];
  List<NewsRecommendationItem> _news = [];
  String _userName = '';
  int _unreadCount = 0;

  bool _watchlistLoading = true;
  bool _newsLoading = true;
  bool _watchlistError = false;
  bool _newsError = false;

  @override
  void initState() {
    super.initState();
    _userName = widget.userName ?? '';
    _loadWatchlist();
    _loadNews();
    _loadProfile();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await NotificationApiService.getUnreadNotificationCount();
      print('🔔 받아온 안읽은 알림 개수: $count'); // 디버깅 로그
      if (!mounted) return;
      setState(() {
        _unreadCount = count;
      });
    } catch (e, stackTrace) {
      print('❌ 알림 개수 로드 실패: $e'); // 에러 내용 출력
      print(stackTrace);
    }
  }

  Future<void> _loadWatchlist() async {
    try {
      final data = await WatchlistService().getWatchlist();
      if (!mounted) return;
      setState(() {
        _watchlist = data.take(3).toList();
        _watchlistLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _watchlistLoading = false;
        _watchlistError = true;
      });
    }
  }

  Future<void> _loadNews() async {
    try {
      final page = await NewsApiService.getRecommendations();
      if (!mounted) return;
      setState(() {
        _news = page.items.take(3).toList();
        _newsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _newsLoading = false;
        _newsError = true;
      });
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await UserApiService.getProfile();
      if (!mounted) return;
      setState(() => _userName = profile.nickname);
    } catch (_) {}
  }

  void _onBottomTap(int index) {
    const routeMap = {1: '/watchlist', 2: '/news', 3: '/stock'};
    final route = routeMap[index];
    if (route == null) return;
    Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
  }

  String _formatDate() {
    final now = DateTime.now();
    const weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    return '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}';
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final greetingName = _userName.isEmpty ? '사용자' : _userName;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      bottomNavigationBar: BottomNavBar(
        initialIndex: 0,
        onIndexChanged: _onBottomTap,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 바
              Row(
                children: [
                  const Spacer(),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () {
                            Navigator.pushNamed(context, '/alarm').then((_) {
                              _loadUnreadCount();
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EC272),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _unreadCount > 99 ? '99+' : '$_unreadCount',
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
                  IconButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/settings'),
                    icon: const Icon(Icons.settings,
                        size: 26, color: Colors.black87),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 날짜
              Text(
                _formatDate(),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),

              const SizedBox(height: 6),

              // 인삿말
              Text(
                '$greetingName님, 관심종목에\n새로운 소식이 있어요',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.35),
              ),

              const SizedBox(height: 24),

              // 관심종목 섹션
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _SectionHeader(
                  title: '관심종목이 움직이고 있어요',
                  onMore: () => Navigator.pushNamed(context, '/watchlist'),
                ),
              ),
              const SizedBox(height: 8),
              _Card(
                child: _watchlistLoading
                    ? const _LoadingIndicator()
                    : _watchlistError
                        ? const _EmptyHint(message: '관심종목을 불러오지 못했어요')
                        : _watchlist.isEmpty
                        ? const _EmptyHint(message: '관심종목을 추가해보세요')
                        : Column(
                            children: _watchlist.asMap().entries.map((e) {
                              return Column(
                                children: [
                                  if (e.key > 0)
                                    const Divider(
                                        height: 1,
                                        color: Color(0xFFF0F0F0)),
                                  _StockRow(stock: e.value),
                                ],
                              );
                            }).toList(),
                          ),
              ),

              const SizedBox(height: 24),

              // 뉴스 섹션
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _SectionHeader(
                  title: '오늘 꼭 봐야 할 뉴스예요',
                  onMore: () => Navigator.pushNamed(context, '/news'),
                ),
              ),
              const SizedBox(height: 8),
              _Card(
                child: _newsLoading
                    ? const _LoadingIndicator()
                    : _newsError
                        ? const _EmptyHint(message: '뉴스를 불러오지 못했어요')
                        : _news.isEmpty
                        ? const _EmptyHint(message: '뉴스를 불러오지 못했어요')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _news.asMap().entries.map((e) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (e.key > 0)
                                    const Divider(
                                        height: 1,
                                        color: Color(0xFFF0F0F0)),
                                  _NewsRow(
                                    news: e.value,
                                    timeAgo: _timeAgo(e.value.pubDate),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
              ),

              const SizedBox(height: 24),

              // 키워드 섹션
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Text(
                  '지금 뜨는 키워드예요',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              _Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _dummyKeywords
                          .map((k) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _KeywordChip(label: k),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 섹션 헤더 ────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onMore;
  const _SectionHeader({required this.title, required this.onMore});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 20, top: 20), // ← right: 왼쪽이동, top: 아래이동
          child: GestureDetector(
            onTap: onMore,
            child: const Text('더보기',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ),
        ),
      ],
    );
  }
}

// ─── 카드 컨테이너 ─────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

// ─── 로딩 / 빈 상태 ───────────────────────────────────────────

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String message;
  const _EmptyHint({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(message,
            style: const TextStyle(color: Colors.grey, fontSize: 14)),
      ),
    );
  }
}

// ─── 관심종목 행 ──────────────────────────────────────────────

class _StockRow extends StatelessWidget {
  final WatchlistStock stock;
  const _StockRow({required this.stock});

  @override
  Widget build(BuildContext context) {
    final rate = stock.changeRate;
    final Color changeColor;
    final String changeStr;
    if (rate > 0) {
      changeColor = const Color(0xFFFF2B3A);
      changeStr = '+${rate.toStringAsFixed(1)}%';
    } else if (rate < 0) {
      changeColor = const Color(0xFF0885FE);
      changeStr = '${rate.toStringAsFixed(1)}%';
    } else {
      changeColor = Colors.grey;
      changeStr = '0.0%';
    }
    final priceStr =
        '${NumberFormat('#,###').format(stock.price)}원';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _StockLogo(code: stock.code, name: stock.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stock.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                Text(stock.code,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(priceStr,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              Text(changeStr,
                  style: TextStyle(
                      fontSize: 13,
                      color: changeColor,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 종목 로고 ────────────────────────────────────────────────
// PNG 파일 경로: assets/images/stocks/{종목코드}.png

class _StockLogo extends StatelessWidget {
  final String code;
  final String name;
  const _StockLogo({required this.code, required this.name});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/stocks/$code.png',
      width: 40,
      height: 40,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFFE5E7EB),
      child: Text(
        name.isNotEmpty ? name[0] : '?',
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black54),
      ),
    );
  }
}

// ─── 뉴스 행 ─────────────────────────────────────────────────

class _NewsRow extends StatelessWidget {
  final NewsRecommendationItem news;
  final String timeAgo;
  const _NewsRow({required this.news, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            news.title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(timeAgo,
              style:
                  const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ─── 키워드 칩 ────────────────────────────────────────────────

class _KeywordChip extends StatelessWidget {
  final String label;
  const _KeywordChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0EC272),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500),
      ),
    );
  }
}
