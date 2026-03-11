// lib/screens/main_page.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'search_page.dart';

class StockHomeScreen extends StatelessWidget {
  final String? userName;

  const StockHomeScreen({super.key, this.userName});

  Future<void> _logout(BuildContext context) async {
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      await googleSignIn.signOut();
    } catch (e) {
      debugPrint('로그아웃 중 에러: $e');
    }

    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
          (route) => false,
    );
  }

  void _onBottomTap(BuildContext context, int index) {
    if (index == 0) return; // 현재 홈 페이지

    const routeMap = {1: '/watchlist', 2: '/news', 3: '/stock'};
    final route = routeMap[index];
    if (route == null) return;

    Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final String greetingName = (userName ?? '').isEmpty ? '사용자' : userName!;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),

      // ✅ 홈 화면은 홈만 초록색(0)
      bottomNavigationBar: BottomNavBar(
        initialIndex: 0,
        onIndexChanged: (i) => _onBottomTap(context, i),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _logout(context),
                    child: const Text(
                      '로그아웃',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/alarm');
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
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/settings'); // ✅ 설정 페이지로 이동
                    },
                    icon: const Icon(
                      Icons.settings,
                      size: 26,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              const Text(
                '안녕하세요!\n어떤 종목을 찾으세요?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$greetingName 님, 환영합니다 👋',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 24),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  readOnly: true,
                  decoration: const InputDecoration(
                    hintText: '종목, 뉴스, 키워드 등',
                    border: InputBorder.none,
                    icon: Icon(Icons.search),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchPage()),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              GestureDetector(
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/watchlist');
                },
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF34D399), Color(0xFF22C55E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: const [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '내 관심종목',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '인기종목, 관심종목',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: _MiniBarChart(),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}


// ================== 오른쪽 작은 막대 차트 ==================
class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _bar(height: 30, color: Colors.white.withOpacity(0.7)),
          const SizedBox(width: 4),
          _bar(height: 50, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 4),
          _bar(height: 40, color: const Color(0xFFE5FDF1)),
        ],
      ),
    );
  }

  Widget _bar({required double height, required Color color}) {
    return Container(
      width: 8,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}