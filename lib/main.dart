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
    // Firebase 기본 앱 초기화
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    // 이미 [DEFAULT] 앱이 초기화되어 있으면, 그냥 무시하고 넘어감
    if (e.code == 'duplicate-app') {
      // 이미 만들어진 앱을 그냥 사용하면 됨
    } else {
      rethrow; // 다른 에러면 그대로 터뜨리기
    }
  }

  // OneSignal 초기화
  await OneSignalService().initializeOneSignal();

  runApp(const StockApp());
}

class StockApp extends StatelessWidget {
  const StockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',

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
