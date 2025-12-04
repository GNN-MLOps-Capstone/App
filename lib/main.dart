// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'screens/main_page.dart';
import 'screens/news_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // ✅ Firebase 기본 앱 초기화
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    // ✅ 이미 [DEFAULT] 앱이 초기화되어 있으면, 그냥 무시하고 넘어감
    if (e.code == 'duplicate-app') {
      // 이미 만들어진 앱을 그냥 사용하면 됨
    } else {
      rethrow; // 다른 에러면 그대로 터뜨리기
    }
  }

  runApp(const StockApp());
}

class StockApp extends StatelessWidget {
  const StockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (_) => const GoogleLoginPage(),
        '/home': (_) => const StockHomeScreen(),
        '/news': (_) => const NewsScreen(),
      },
    );
  }
}
