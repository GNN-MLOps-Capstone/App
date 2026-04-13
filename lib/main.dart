// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'screens/main_page.dart';
import 'screens/push_test_screen.dart';
import 'screens/news_page.dart';
import 'screens/search_page.dart';
import 'screens/watchlist_page.dart';
import 'services/onesignal_service.dart';
import 'screens/alarm_page.dart';
import 'screens/setting_page.dart';
import 'screens/login_page.dart';
import 'screens/stock_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env.local 파일 로드
  await dotenv.load(fileName: ".env.local");

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      // 이미 초기화된 경우 무시
    } else {
      rethrow;
    }
  }

  await OneSignalService().initializeOneSignal();

  runApp(const StockApp());
}

class StockApp extends StatelessWidget {
  const StockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/home',

      // ✅ Noto Sans KR 폰트 전체 적용
      theme: ThemeData(
        textTheme: GoogleFonts.notoSansKrTextTheme(
          ThemeData.light().textTheme,
        ),
      ),

      routes: {
        '/home': (_) => const StockHomeScreen(),
        '/push_test': (_) => const PushTestScreen(),
        '/news': (_) => const NewsScreen(),
        '/search': (_) => const SearchPage(),
        '/alarm': (_) => const AlarmPage(),
        '/settings': (_) => const SettingPage(),
        '/login': (_) => const GoogleLoginPage(),
        '/watchlist': (_) => const WatchlistPage(),
        '/stock': (context) => const StockPage(),
      },
    );
  }
}