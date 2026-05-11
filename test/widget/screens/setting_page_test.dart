import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock/screens/setting_page.dart';

void _mockChannels() {
  final messenger = TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger;

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
}

http.Response _jsonResponse(Object body, int statusCode) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.Response.bytes(bytes, statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

MockClient _buildMockClient() {
  return MockClient((request) async {
    final path = request.url.path;

    if (path.contains('/api/users/profile')) {
      return _jsonResponse({
        'id': 1,
        'google_id': 'google_abc',
        'email': 'test@gmail.com',
        'nickname': '홍길동',
        'img_url': null,
      }, 200);
    }

    if (path.contains('/api/users/settings')) {
      return _jsonResponse({
        'push': true,
        'risk_only': true,
        'positive_only': false,
        'interest_only': true,
        'night_push_prohibit': false,
        'dnd_start': '23:00:00',
        'dnd_finish': '07:00:00',
      }, 200);
    }

    return http.Response('{}', 200);
  });
}

Widget _buildApp() {
  return MaterialApp(
    routes: {
      '/home': (_) => const Scaffold(body: Text('home')),
      '/watchlist': (_) => const Scaffold(body: Text('watchlist')),
      '/news': (_) => const Scaffold(body: Text('news')),
      '/stocks': (_) => const Scaffold(body: Text('stocks')),
    },
    home: const SettingPage(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
  });

  setUp(_mockChannels);

  group('SettingPage', () {
    testWidgets('프로필 닉네임 렌더링', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.text('홍길동'), findsOneWidget);
      }, _buildMockClient);
    });

    testWidgets('프로필 이메일 렌더링', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.text('test@gmail.com'), findsOneWidget);
      }, _buildMockClient);
    });

    testWidgets('Switch 위젯 렌더링', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.byType(Switch), findsWidgets);
      }, _buildMockClient);
    });

    testWidgets('로그아웃 버튼 렌더링', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.text('로그아웃'), findsOneWidget);
      }, _buildMockClient);
    });

    testWidgets('API 오류 시 기본값 렌더링 (크래시 없음)', (tester) async {
      final errorClient = MockClient((_) async =>
          http.Response('error', 500));

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.byType(SettingPage), findsOneWidget);
      }, () => errorClient);
    });
  });
}
