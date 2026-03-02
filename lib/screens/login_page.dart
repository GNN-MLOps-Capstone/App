import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main_page.dart';

class GoogleLoginPage extends StatefulWidget {
  const GoogleLoginPage({super.key});

  @override
  State<GoogleLoginPage> createState() => _GoogleLoginPageState();
}

class _GoogleLoginPageState extends State<GoogleLoginPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'image': 'assets/images/login_image1.png',
      'text': '뉴스가 보이니\n마음 놓고 투자!',
    },
    {
      'image': 'assets/images/login_image2.png',
      'text': '내 종목 소식\n알아서 챙겨줄게요',
    },
    {
      'image': 'assets/images/login_image3.png',
      'text': '호재? 악재?\n한눈에 파악!',
    },
    {
      'image': 'assets/images/login_image4.png',
      'text': '지금 관심 종목\n선택하고 시작하기',
    },
  ];

  Future<void> _handleSignIn() async {
    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final account = await _googleSignIn.signIn();
      if (account == null) return;

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StockHomeScreen(userName: account.displayName),
        ),
      );
    } catch (e) {
      debugPrint('구글 로그인 에러: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 실패: $e')),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            // 이미지 + 텍스트 스와이프 영역
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 200,
                            child: Image.asset(
                              _pages[index]['image']!,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0E0E0),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.image_outlined,
                                    size: 60,
                                    color: Color(0xFFBDBDBD),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            _pages[index]['text']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),
                  // 인디케이터 - 텍스트 바로 아래 고정
                  Positioned(
                    bottom: 110,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                            (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == i ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == i
                                ? const Color(0xFF1A1A1A)
                                : const Color(0xFFBDBDBD),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 0),

            // 버튼
            OutlinedButton.icon(
              onPressed: _handleSignIn,
              icon: Image.asset(
                'assets/images/google_logo.png',
                height: 20,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.g_mobiledata,
                  size: 24,
                  color: Color(0xFF4285F4),
                ),
              ),
              label: const Text(
                'Sign up with Google',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F1F1F),
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF747775), width: 1),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),

            const SizedBox(height: 12),

            GestureDetector(
              onTap: _handleSignIn,
              child: const Text(
                '구글계정으로 로그인',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF757575),
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF757575),
                ),
              ),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
