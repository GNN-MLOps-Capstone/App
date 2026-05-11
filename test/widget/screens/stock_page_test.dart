import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock/screens/stock_page.dart';

void _mockSecureStorage({String? token = 'test_token'}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      if (call.method == 'read') return token;
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

    if (path.contains('/api/stocks/trends')) {
      return _jsonResponse([
        {'rank': 1, 'code': '005930', 'name': '삼성전자', 'weather': 'SUNNY', 'score': 95, 'last_price': 72500, 'change_rate': 1.5},
        {'rank': 2, 'code': '000660', 'name': 'SK하이닉스', 'weather': 'PARTLY_CLOUDY', 'score': 88, 'last_price': 185000, 'change_rate': 2.3},
        {'rank': 3, 'code': '035420', 'name': 'NAVER', 'weather': 'CLOUDY', 'score': 75, 'last_price': 215500, 'change_rate': 0.8},
        {'rank': 4, 'code': '035720', 'name': '카카오', 'weather': 'RAINY', 'score': 60, 'last_price': 41200, 'change_rate': -3.1},
        {'rank': 5, 'code': '006400', 'name': '삼성SDI', 'weather': 'PARTLY_CLOUDY', 'score': 55, 'last_price': 385000, 'change_rate': 0.8},
      ], 200);
    }

    if (path.contains('/theme-keywords')) {
      return _jsonResponse({
        'theme_keywords': [
          {'keyword': '반도체', 'score': 0.9},
          {'keyword': 'AI', 'score': 0.8},
        ],
      }, 200);
    }

    if (path.contains('/api/watchlist')) {
      return _jsonResponse([], 200);
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
      '/alarm': (_) => const Scaffold(body: Text('alarm')),
      '/settings': (_) => const Scaffold(body: Text('settings')),
    },
    home: const StockPage(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
    dotenv.env['API_BASE_URL'] = 'http://localhost:8000';
  });

  setUp(_mockSecureStorage);

  group('StockPage', () {
    testWidgets('주식 타이틀 렌더링', (tester) async {
      _mockSecureStorage();
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pump();

        expect(find.text('주식'), findsOneWidget);
      }, _buildMockClient);
    });

    testWidgets('검색창 힌트 텍스트 렌더링', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pump();

        expect(find.text('종목을 검색하세요'), findsOneWidget);
      }, _buildMockClient);
    });

    testWidgets('AI TOP 5 트렌드 카드 렌더링', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.text('삼성전자'), findsOneWidget);
        expect(find.text('SK하이닉스'), findsOneWidget);
        expect(find.text('NAVER'), findsOneWidget);
      }, _buildMockClient);
    });

    testWidgets('감성 날씨 아이콘 렌더링 (GNN 추천 태그)', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // 날씨는 SVG 아이콘으로 렌더링됨 — 트렌드 카드별로 SvgPicture 존재
        expect(find.byType(SvgPicture), findsWidgets);
      }, _buildMockClient);
    });

    testWidgets('TOP5 카드에 키워드 칩 2개 렌더링', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // getThemeKeywords가 '반도체', 'AI' 2개를 반환
        expect(find.text('반도체'), findsWidgets);
        expect(find.text('AI'), findsWidgets);
      }, _buildMockClient);
    });

    testWidgets('데이터 없을 때 빈 트렌드 안내 텍스트 표시', (tester) async {
      final emptyClient = MockClient((request) async {
        if (request.url.path.contains('/api/stocks/trends')) {
          return _jsonResponse([], 200);
        }
        return http.Response('{}', 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(find.text('표시할 트렌드가 없습니다.'), findsOneWidget);
      }, () => emptyClient);
    });
  });
}
