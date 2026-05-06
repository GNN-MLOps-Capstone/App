import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock/screens/main_page.dart';
import 'package:stock/screens/setting_page.dart';
import 'package:stock/screens/widgets/bottom_nav_bar.dart';

void _mockChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      if (call.method == 'read') return 'test_token';
      return null;
    },
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/google_sign_in'),
    (call) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/google_sign_in_v2'),
    (call) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.onesignal.flutter'),
    (call) async => null,
  );
}

http.Response _jsonResponse(Object body, int statusCode) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.Response.bytes(bytes, statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

MockClient _buildHomeClient() {
  return MockClient((request) async {
    final path = request.url.path;
    if (path.contains('/api/watchlist')) {
      return _jsonResponse([], 200);
    }
    if (path.contains('/api/news/recommendations')) {
      return _jsonResponse({
        'user_id': 1,
        'request_id': 'r1',
        'source': 'mock',
        'page': 1,
        'next_cursor': null,
        'served_count': 0,
        'logged': false,
        'items': [],
      }, 200);
    }
    if (path.contains('/api/users/profile')) {
      return _jsonResponse({
        'id': 1,
        'google_id': 'g1',
        'email': 'test@test.com',
        'nickname': '테스트',
        'img_url': null,
      }, 200);
    }
    return http.Response('{}', 200);
  });
}

MockClient _buildSettingClient() {
  return MockClient((request) async {
    final path = request.url.path;
    if (path.contains('/api/users/profile')) {
      return _jsonResponse({
        'id': 1,
        'google_id': 'g1',
        'email': 'test@test.com',
        'nickname': '홍길동',
        'img_url': null,
      }, 200);
    }
    if (path.contains('/api/users/settings')) {
      return _jsonResponse({
        'push': true,
        'risk_only': true,
        'positive_only': true,
        'interest_only': true,
        'night_push_prohibit': false,
        'dnd_start': '23:00:00',
        'dnd_finish': '07:00:00',
      }, 200);
    }
    return http.Response('{}', 200);
  });
}

Widget _buildHomeApp() {
  return MaterialApp(
    routes: {
      '/watchlist': (_) => const Scaffold(body: Text('관심종목 페이지')),
      '/news': (_) => const Scaffold(body: Text('뉴스 페이지')),
      '/stock': (_) => const Scaffold(body: Text('주식 페이지')),
      '/alarm': (_) => const Scaffold(body: Text('알림 페이지')),
      '/settings': (_) => const Scaffold(body: Text('설정 페이지')),
    },
    home: const StockHomeScreen(),
  );
}

Widget _buildSettingApp() {
  return MaterialApp(
    routes: {
      '/home': (_) => const Scaffold(body: Text('홈 페이지')),
      '/watchlist': (_) => const Scaffold(body: Text('관심종목 페이지')),
      '/news': (_) => const Scaffold(body: Text('뉴스 페이지')),
      '/stock': (_) => const Scaffold(body: Text('주식 페이지')),
      '/login': (_) => const Scaffold(body: Text('로그인 페이지')),
    },
    home: const SettingPage(),
  );
}

// BottomNavBar 내 GestureDetector 탐색 헬퍼
Finder _navItem(int index) => find
    .descendant(of: find.byType(BottomNavBar), matching: find.byType(GestureDetector))
    .at(index);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
  });

  setUp(_mockChannels);

  group('홈 화면 상단 아이콘 네비게이션', () {
    testWidgets('알림 아이콘 탭 → 알림 페이지로 이동', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildHomeApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.notifications_none_outlined));
        await tester.pumpAndSettle();

        expect(find.text('알림 페이지'), findsOneWidget);
      }, _buildHomeClient);
    });

    testWidgets('설정 아이콘 탭 → 설정 페이지로 이동', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildHomeApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();

        expect(find.text('설정 페이지'), findsOneWidget);
      }, _buildHomeClient);
    });
  });

  group('홈 화면 더보기 네비게이션', () {
    testWidgets('관심종목 더보기 탭 → 관심종목 페이지로 이동', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildHomeApp());
        await tester.pumpAndSettle();

        // 첫 번째 더보기 = 관심종목 섹션
        await tester.tap(find.text('더보기').at(0));
        await tester.pumpAndSettle();

        expect(find.text('관심종목 페이지'), findsOneWidget);
      }, _buildHomeClient);
    });

    testWidgets('뉴스 더보기 탭 → 뉴스 페이지로 이동', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildHomeApp());
        await tester.pumpAndSettle();

        // 두 번째 더보기 = 뉴스 섹션
        await tester.tap(find.text('더보기').at(1));
        await tester.pumpAndSettle();

        expect(find.text('뉴스 페이지'), findsOneWidget);
      }, _buildHomeClient);
    });
  });

  group('하단 내비게이션 탭 전환 (홈 기준)', () {
    testWidgets('관심종목 탭(1) → 관심종목 페이지로 전환', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildHomeApp());
        await tester.pumpAndSettle();

        await tester.tap(_navItem(1));
        await tester.pumpAndSettle();

        expect(find.text('관심종목 페이지'), findsOneWidget);
      }, _buildHomeClient);
    });

    testWidgets('뉴스 탭(2) → 뉴스 페이지로 전환', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildHomeApp());
        await tester.pumpAndSettle();

        await tester.tap(_navItem(2));
        await tester.pumpAndSettle();

        expect(find.text('뉴스 페이지'), findsOneWidget);
      }, _buildHomeClient);
    });

    testWidgets('주식 탭(3) → 주식 페이지로 전환', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildHomeApp());
        await tester.pumpAndSettle();

        await tester.tap(_navItem(3));
        await tester.pumpAndSettle();

        expect(find.text('주식 페이지'), findsOneWidget);
      }, _buildHomeClient);
    });

    testWidgets('홈 탭(0) 탭 → 홈 화면 유지 (pushNamed 없음)', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildHomeApp());
        await tester.pumpAndSettle();

        await tester.tap(_navItem(0));
        await tester.pumpAndSettle();

        // 홈 화면 위젯이 그대로 존재
        expect(find.byType(StockHomeScreen), findsOneWidget);
      }, _buildHomeClient);
    });
  });

  group('설정 화면 하단 내비게이션 탭 전환', () {
    testWidgets('홈 탭(0) → 홈 페이지로 전환', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildSettingApp());
        await tester.pumpAndSettle();

        await tester.tap(_navItem(0));
        await tester.pumpAndSettle();

        expect(find.text('홈 페이지'), findsOneWidget);
      }, _buildSettingClient);
    });

    testWidgets('관심종목 탭(1) → 관심종목 페이지로 전환', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildSettingApp());
        await tester.pumpAndSettle();

        await tester.tap(_navItem(1));
        await tester.pumpAndSettle();

        expect(find.text('관심종목 페이지'), findsOneWidget);
      }, _buildSettingClient);
    });

    testWidgets('뉴스 탭(2) → 뉴스 페이지로 전환', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildSettingApp());
        await tester.pumpAndSettle();

        await tester.tap(_navItem(2));
        await tester.pumpAndSettle();

        expect(find.text('뉴스 페이지'), findsOneWidget);
      }, _buildSettingClient);
    });

    testWidgets('주식 탭(3) → 주식 페이지로 전환', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildSettingApp());
        await tester.pumpAndSettle();

        await tester.tap(_navItem(3));
        await tester.pumpAndSettle();

        expect(find.text('주식 페이지'), findsOneWidget);
      }, _buildSettingClient);
    });
  });
}
