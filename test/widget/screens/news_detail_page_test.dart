import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock/models/news_models.dart';
import 'package:stock/screens/news_detail_page.dart';

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

const _mockDetailJson = {
  'news_id': 1,
  'title': '삼성전자 HBM3E 양산 가속화',
  'summary': '삼성전자가 AI 메모리 공급을 확대합니다.',
  'body': '삼성전자는 2분기부터 HBM3E 양산을 본격화한다고 밝혔습니다.',
  'pub_date': '2026-04-23T09:00:00',
  'url': 'https://example.com/news/1',
  'sentiment': '긍정',
  'keywords': ['반도체', 'HBM', 'AI'],
  'related_stocks': [
    {'stock_id': '005930', 'stock_name': '삼성전자', 'stock_up': true},
  ],
};

Widget _buildApp({int newsId = 1, NewsRecommendationItem? initialItem}) {
  return MaterialApp(
    home: NewsDetailPage(newsId: newsId, initialItem: initialItem),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
  });

  setUp(_mockSecureStorage);

  group('NewsDetailPage', () {
    testWidgets('API 응답으로 뉴스 제목 렌더링', (tester) async {
      final client = MockClient((_) async =>
          _jsonResponse(_mockDetailJson, 200));

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.text('삼성전자 HBM3E 양산 가속화'), findsOneWidget);
      }, () => client);
    });

    testWidgets('키워드 태그 렌더링', (tester) async {
      final client = MockClient((_) async =>
          _jsonResponse(_mockDetailJson, 200));

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.text('반도체'), findsOneWidget);
        expect(find.text('HBM'), findsOneWidget);
        expect(find.text('AI'), findsOneWidget);
      }, () => client);
    });

    testWidgets('연관 종목 태그 렌더링', (tester) async {
      final client = MockClient((_) async =>
          _jsonResponse(_mockDetailJson, 200));

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.text('삼성전자'), findsWidgets);
      }, () => client);
    });

    testWidgets('initialItem으로 즉시 렌더링 (API 호출 없음)', (tester) async {
      const initialItem = NewsRecommendationItem(
        newsId: 99,
        title: '초기 뉴스 제목',
        summary: '초기 요약',
        stockName: 'NAVER',
        isPlaceholder: true,
      );

      final client = MockClient((_) async => http.Response('{}', 200));

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp(newsId: 99, initialItem: initialItem));
        await tester.pump();

        expect(find.text('초기 뉴스 제목'), findsOneWidget);
      }, () => client);
    });

    testWidgets('API 오류 시 에러 메시지 표시', (tester) async {
      final client = MockClient((_) async =>
          http.Response('error', 500));

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.text('뉴스 상세를 불러오지 못했습니다.'), findsOneWidget);
      }, () => client);
    });
  });
}
