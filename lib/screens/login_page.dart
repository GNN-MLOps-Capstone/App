import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/user_api_service.dart';
import '../config/api_config.dart';
import '../services/onesignal_service.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class GoogleLoginPage extends StatefulWidget {
  const GoogleLoginPage({super.key});

  @override
  State<GoogleLoginPage> createState() => _GoogleLoginPageState();
}

class _GoogleLoginPageState extends State<GoogleLoginPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: ApiConfig.googleClientId,
  );
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'image': 'assets/images/login_image1.svg',
      'text': '뉴스가 보이니\n마음 놓고 투자!',
    },
    {
      'image': 'assets/images/login_image2.svg',
      'text': '내 종목 소식\n알아서 챙겨줄게요',
    },
    {
      'image': 'assets/images/login_image3.svg',
      'text': '호재? 악재?\n한눈에 파악!',
    },
    {
      'image': 'assets/images/login_image4.svg',
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

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw Exception('Google ID 토큰을 가져올 수 없습니다.');
      }

      if (!mounted) return;

      final loginRequest = UserLoginRequest(
        idToken: idToken,
      );

      final authResponse = await UserApiService.login(loginRequest);

      try {
        await OneSignalService().setUserId(authResponse.user.googleId.toString());
        debugPrint('🔔 OneSignal External User ID 설정 완료');
      } catch (e) {
        debugPrint('❌ OneSignal ID 설정 실패: $e');
      }

      try {
        final settings = await UserApiService.getSettings();
        await OneSignal.User.addTagWithKey(
            "is_dnd",
            settings.nightPushProhibit ? "true" : "false"
        );
        print("OneSignal 태그 동기화 완료: is_dnd = ${settings.nightPushProhibit}");
      } catch (e) {
        print("로그인 시 OneSignal 태그 동기화 실패: $e");
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StockHomeScreen(
            userName: authResponse.user.nickname, // ✅ 서버 응답값 사용
          ),
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
                          // ✅ 잘못된 return Container 블록 제거, SvgPicture만 남김
                          SizedBox(
                            height: 200,
                            child: SvgPicture.asset(
                              _pages[index]['image']!,
                              fit: BoxFit.contain,
                              height: 200,
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
                  // 인디케이터
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

            // 구글 로그인 버튼
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
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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