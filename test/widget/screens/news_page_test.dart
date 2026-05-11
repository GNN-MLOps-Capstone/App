import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock/screens/news_page.dart';

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

final _mockNewsPage = {
  'user_id': 1,
  'request_id': 'req-001',
  'source': 'mab',
  'page': 1,
  'next_cursor': null,
  'served_count': 3,
  'logged': true,
  'items': [
    {
      'news_id': 1,
      'title': '삼성전자 HBM3E 양산 가속화',
      'summary': '삼성전자가 AI 메모리 공급을 확대합니다.',
      'pub_date': '2026-04-23T09:00:00',
      'path': '/news/1',
      'stock_name': '삼성전자',
      'stock_change': '+3.2%',
      'stock_up': true,
    },
    {
      'news_id': 2,
      'title': 'SK하이닉스 2분기 영업이익 최대 전망',
      'summary': 'SK하이닉스 HBM 수요가 급증하고 있습니다.',
      'pub_date': '2026-04-23T08:00:00',
      'path': '/news/2',
      'stock_name': 'SK하이닉스',
      'stock_change': '+7.2%',
      'stock_up': true,
    },
    {
      'news_id': 3,
      'title': '카카오 규제 이슈 지속',
      'summary': '공정위 조사가 이어지고 있습니다.',
      'pub_date': '2026-04-23T07:00:00',
      'path': '/news/3',
      'stock_name': '카카오',
      'stock_change': '-0.8%',
      'stock_up': false,
    },
  ],
};

Widget _buildApp() {
  return MaterialApp(
    routes: {
      '/home': (_) => const Scaffold(body: Text('home')),
      '/watchlist': (_) => const Scaffold(body: Text('watchlist')),
      '/stocks': (_) => const Scaffold(body: Text('stocks')),
    },
    home: const NewsScreen(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
  });

  setUp(_mockSecureStorage);

  group('NewsPage', () {
    testWidgets('뉴스 카드 목록 렌더링', (tester) async {
      final client = MockClient((req) async {
        if (req.url.path.contains('/api/news')) {
          return _jsonResponse(_mockNewsPage, 200);
        }
        return http.Response('{}', 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.text('삼성전자 HBM3E 양산 가속화'), findsOneWidget);
        expect(find.text('SK하이닉스 2분기 영업이익 최대 전망'), findsOneWidget);
        expect(find.text('카카오 규제 이슈 지속'), findsOneWidget);
      }, () => client);
    });

    testWidgets('종목 태그 렌더링', (tester) async {
      final client = MockClient((req) async {
        if (req.url.path.contains('/api/news')) {
          return _jsonResponse(_mockNewsPage, 200);
        }
        return http.Response('{}', 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.textContaining('삼성전자'), findsWidgets);
        expect(find.textContaining('SK하이닉스'), findsWidgets);
      }, () => client);
    });

    testWidgets('API 오류 시 크래시 없음', (tester) async {
      final client = MockClient((_) async => http.Response('error', 500));

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.byType(NewsScreen), findsOneWidget);
      }, () => client);
    });

    testWidgets('빈 목록 응답 시 크래시 없음', (tester) async {
      final client = MockClient((req) async {
        if (req.url.path.contains('/api/news')) {
          return _jsonResponse({..._mockNewsPage, 'items': [], 'served_count': 0}, 200);
        }
        return http.Response('{}', 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.byType(NewsScreen), findsOneWidget);
      }, () => client);
    });
  });
}
