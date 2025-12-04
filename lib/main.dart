// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'screens/main_page.dart';
import 'screens/news_page.dart'; // ✅ 새로 추가

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const StockApp());
}

class StockApp extends StatelessWidget {
  const StockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // 처음 열리는 화면
      initialRoute: '/home',
      routes: {
        // 처음 열리는 화면 (로그인 건너뛰고 바로 홈 화면)
        '/login': (_) => const GoogleLoginPage(),
        '/home': (_) => const StockHomeScreen(),
        '/news': (_) => const NewsScreen(), // ✅ 뉴스 라우트
      },
    );
  }
}