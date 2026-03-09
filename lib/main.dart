// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'screens/main_page.dart';
import 'screens/push_test_screen.dart';
import 'screens/news_page.dart';
import 'screens/search_page.dart';
import 'screens/stock_detail_page.dart';
import 'services/onesignal_service.dart';
import 'screens/stock_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      routes: {
        '/home': (_) => const StockHomeScreen(),
        '/push_test': (_) => const PushTestScreen(),
        '/news': (_) => const NewsScreen(),
        '/search': (_) => const SearchPage(),
        '/stock': (_) => const StockPage(),
      },
      // ✅ API 연결 전 임시: arguments로 stockName 받기
      onGenerateRoute: (settings) {
        if (settings.name == '/stock-detail') {
          final stockName = settings.arguments as String? ?? '삼성전자';
          return MaterialPageRoute(
            builder: (_) => StockDetailPage(stockName: stockName),
          );
        }
        return null;
      },
    );
  }
}