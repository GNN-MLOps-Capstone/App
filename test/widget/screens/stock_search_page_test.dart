import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock/screens/stock_page.dart';
import 'package:stock/screens/stock_search_page.dart';

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

MockClient _buildMockClient() {
  return MockClient((request) async {
    final path = request.url.path;
    if (path.contains('/overview')) {
      return _jsonResponse({
        'code': path.split('/')[3],
        'name': '테스트종목',
        'last_price': 70000,
        'change': 500.0,
        'change_rate': 0.7,
        'open': 69500,
        'high': 70500,
        'low': 69000,
        'volume': 1000000,
        'trading_value': 70000000000,
        'updated_at': null,
      }, 200);
    }
    return http.Response('[]', 200);
  });
}

final _testStocks = [
  StockItem(name: '삼성전자', code: '005930'),
  StockItem(name: 'SK하이닉스', code: '000660'),
  StockItem(name: 'NAVER', code: '035420'),
  StockItem(name: '카카오', code: '035720'),
  StockItem(name: '삼성SDI', code: '006400'),
];

Widget _buildApp({bool loading = false}) {
  return MaterialApp(
    routes: {
      '/home': (_) => const Scaffold(body: Text('home')),
      '/watchlist': (_) => const Scaffold(body: Text('watchlist')),
      '/news': (_) => const Scaffold(body: Text('news')),
    },
    home: StockSearchPage(allStocks: _testStocks, loading: loading),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
  });

  setUp(_mockSecureStorage);

  group('StockSearchPage', () {
    testWidgets('검색 TextField 렌더링', (tester) async {
      final client = _buildMockClient();
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pump();

        expect(find.byType(TextField), findsOneWidget);
      }, () => client);
    });

    testWidgets('초기 빈 검색어 상태에서 안내 메시지 표시', (tester) async {
      final client = _buildMockClient();
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pump();

        // 검색어가 없으면 안내 메시지 표시 (자동완성 목록 없음)
        expect(find.text('종목명을 입력하면 자동완성 리스트가 나와요'), findsOneWidget);
        expect(find.text('삼성전자'), findsNothing);
      }, () => client);
    });

    testWidgets('검색어 입력 시 결과 필터링', (tester) async {
      final client = _buildMockClient();
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pump();

        await tester.enterText(find.byType(TextField), '삼성');
        await tester.pump();

        expect(find.text('삼성전자'), findsOneWidget);
        expect(find.text('삼성SDI'), findsOneWidget);
        expect(find.text('NAVER'), findsNothing);
        expect(find.text('카카오'), findsNothing);
      }, () => client);
    });

    testWidgets('검색어 지우면 안내 메시지 표시', (tester) async {
      final client = _buildMockClient();
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pump();

        await tester.enterText(find.byType(TextField), '삼성');
        await tester.pump();
        await tester.enterText(find.byType(TextField), '');
        await tester.pump();

        // 검색어가 없으면 안내 메시지가 표시됨 (빈 목록이 아님)
        expect(find.text('종목명을 입력하면 자동완성 리스트가 나와요'), findsOneWidget);
        expect(find.text('삼성전자'), findsNothing);
      }, () => client);
    });

    testWidgets('일치하는 종목 없을 때 빈 결과', (tester) async {
      final client = _buildMockClient();
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'xxxxxx');
        await tester.pump();

        expect(find.text('삼성전자'), findsNothing);
        expect(find.text('NAVER'), findsNothing);
      }, () => client);
    });
  });
}
