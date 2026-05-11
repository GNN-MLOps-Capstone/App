import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock/screens/alarm_page.dart';

void _mockSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      if (call.method == 'read') return 'test_token';
      return null;
    },
  );
}

http.Response _jsonResponse(Object body, int statusCode) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.Response.bytes(bytes, statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

final _mockNotifications = [
  {
    'id': 1,
    'type': 'high_risk',
    'title': '삼성전자 급락 리스크 감지',
    'body': '부정적 뉴스 급증',
    'read': false,
    'star': false,
    'created_at': '2026-04-23T09:00:00',
  },
  {
    'id': 2,
    'type': 'keyword',
    'title': 'NAVER 키워드 급등',
    'body': '관련 언급량 증가',
    'read': true,
    'star': true,
    'created_at': '2026-04-23T08:00:00',
  },
];

Widget _buildApp() {
  return MaterialApp(
    routes: {
      '/home': (_) => const Scaffold(body: Text('home')),
      '/watchlist': (_) => const Scaffold(body: Text('watchlist')),
      '/news': (_) => const Scaffold(body: Text('news')),
      '/stocks': (_) => const Scaffold(body: Text('stocks')),
    },
    home: const AlarmPage(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
  });

  setUp(_mockSecureStorage);

  group('AlarmPage', () {
    testWidgets('TabBar 4개 탭 렌더링', (tester) async {
      final client = MockClient((req) async =>
          _jsonResponse(_mockNotifications, 200));

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.byType(TabBar), findsOneWidget);
        expect(find.textContaining('전체'), findsOneWidget);
        expect(find.textContaining('중요'), findsOneWidget);
        expect(find.textContaining('읽지 않음'), findsOneWidget);
        expect(find.textContaining('긴급/리스크'), findsOneWidget);
      }, () => client);
    });

    testWidgets('알림 카드 목록 렌더링', (tester) async {
      final client = MockClient((req) async =>
          _jsonResponse(_mockNotifications, 200));

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.text('삼성전자 급락 리스크 감지'), findsOneWidget);
        expect(find.text('NAVER 키워드 급등'), findsOneWidget);
      }, () => client);
    });

    testWidgets('API 오류 시 크래시 없이 빈 화면 렌더링', (tester) async {
      final client = MockClient((_) async =>
          http.Response('error', 500));

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.byType(AlarmPage), findsOneWidget);
      }, () => client);
    });

    testWidgets('중요 탭 탭하면 중요 알림만 표시', (tester) async {
      final client = MockClient((req) async =>
          _jsonResponse(_mockNotifications, 200));

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.textContaining('중요'));
        await tester.pumpAndSettle();

        // star=true인 항목만 표시
        expect(find.text('NAVER 키워드 급등'), findsOneWidget);
        expect(find.text('삼성전자 급락 리스크 감지'), findsNothing);
      }, () => client);
    });

    testWidgets('읽지 않음 탭 탭하면 미읽음 알림만 표시', (tester) async {
      final client = MockClient((req) async =>
          _jsonResponse(_mockNotifications, 200));

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.textContaining('읽지 않음'));
        await tester.pumpAndSettle();

        // read=false인 항목만 표시
        expect(find.text('삼성전자 급락 리스크 감지'), findsOneWidget);
        expect(find.text('NAVER 키워드 급등'), findsNothing);
      }, () => client);
    });
  });
}
