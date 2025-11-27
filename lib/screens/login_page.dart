// lib/screens/google_login_page.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main_page.dart'; // 홈 화면으로 이동할 때 필요

class GoogleLoginPage extends StatefulWidget {
  const GoogleLoginPage({super.key});

  @override
  State<GoogleLoginPage> createState() => _GoogleLoginPageState();
}

class _GoogleLoginPageState extends State<GoogleLoginPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  Future<void> _handleSignIn() async {
    try {
      // 계정 선택창 강제로 다시 띄우고 싶으면 기존 세션 정리
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final account = await _googleSignIn.signIn();
      if (account == null) return; // 취소

      if (!mounted) return;

      // 홈 화면으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StockHomeScreen(userName: account.displayName),
        ),
      );

      // 또는 라우트 이름으로 넘기고 싶으면 이렇게도 가능 (arguments 사용)
      // Navigator.pushReplacementNamed(
      //   context,
      //   '/home',
      //   arguments: account.displayName,
      // );
    } catch (e) {
      debugPrint('구글 로그인 에러: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Stock 앱 로그인")),
      body: Center(
        child: ElevatedButton(
          onPressed: _handleSignIn,
          child: const Text("구글로 로그인"),
        ),
      ),
    );
  }
}