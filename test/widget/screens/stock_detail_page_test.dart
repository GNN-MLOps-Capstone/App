import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock/screens/stock_detail_page.dart';

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

MockClient _buildMockClient({
  List<Map<String, dynamic>>? keywords,
  List<Map<String, dynamic>>? relatedStocks,
}) {
  return MockClient((request) async {
    final path = request.url.path;

    if (path.contains('/theme-keywords')) {
      return _jsonResponse({
        'theme_keywords': keywords ?? [
          {'keyword': '반도체', 'similarity_score': 0.9, 'color_level': 'HIGH'},
          {'keyword': 'HBM', 'similarity_score': 0.8, 'color_level': 'HIGH'},
          {'keyword': 'AI', 'similarity_score': 0.7, 'color_level': 'MEDIUM'},
        ],
      }, 200);
    }

    if (path.contains('/related')) {
      return _jsonResponse({
        'related_stocks': relatedStocks ?? [
          {'stock_code': '000660', 'stock_name': 'SK하이닉스'},
          {'stock_code': '035420', 'stock_name': 'NAVER'},
        ],
      }, 200);
    }

    if (path.contains('/api/stocks/') && path.contains('/overview')) {
      return _jsonResponse({
        'code': '005930', 'name': '삼성전자',
        'last_price': 72500, 'change': 1000.0, 'change_rate': 1.5,
        'open': 71000, 'high': 73000, 'low': 70500,
        'volume': 5000000, 'trading_value': 362500000000, 'updated_at': null,
      }, 200);
    }

    if (path.contains('/chart')) {
      return _jsonResponse([], 200);
    }

    if (path.contains('/summary')) {
      return _jsonResponse({'summary': '삼성전자 AI 요약 내용입니다.'}, 200);
    }

    return http.Response('{}', 200);
  });
}

Widget _buildApp({String stockName = '삼성전자', String stockCode = '005930'}) {
  return MaterialApp(
    routes: {
      '/home': (_) => const Scaffold(body: Text('home')),
      '/watchlist': (_) => const Scaffold(body: Text('watchlist')),
      '/news': (_) => const Scaffold(body: Text('news')),
    },
    home: StockDetailPage(stockName: stockName, stockCode: stockCode),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
  });

  setUp(_mockSecureStorage);

  group('StockDetailPage — 테마 키워드 섹션', () {
    testWidgets('종목명 앱바에 표시', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pump();

        expect(find.text('삼성전자'), findsWidgets);
      }, _buildMockClient);
    });

    testWidgets('테마 키워드 데이터 있을 때 키워드 칩 렌더링', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.text('반도체'), findsOneWidget);
        expect(find.text('HBM'), findsOneWidget);
        expect(find.text('AI'), findsOneWidget);
      }, _buildMockClient);
    });

    testWidgets('테마 키워드 데이터 없을 때 빈 섹션 처리 (크래시 없음)', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // 크래시 없이 렌더링되면 통과
        expect(find.byType(StockDetailPage), findsOneWidget);
      }, () => _buildMockClient(keywords: []));
    });
  });

  group('StockDetailPage — 연관 종목 섹션', () {
    testWidgets('연관 종목 데이터 있을 때 종목명 렌더링', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.text('SK하이닉스'), findsOneWidget);
        expect(find.text('NAVER'), findsOneWidget);
      }, _buildMockClient);
    });

    testWidgets('연관 종목 데이터 없을 때 크래시 없음', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.byType(StockDetailPage), findsOneWidget);
      }, () => _buildMockClient(relatedStocks: []));
    });

    testWidgets('로고 폴백: 종목 코드로 로고 없을 때 크래시 없음', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // 로고 이미지 로드 실패해도 폴백 위젯 렌더링
        expect(find.byType(StockDetailPage), findsOneWidget);
      }, () => _buildMockClient(relatedStocks: [
        {'stock_code': 'UNKNOWN', 'stock_name': '없는종목'},
      ]));
    });
  });
}
