import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock/services/stock_api_service.dart';

http.Response _jsonResponse(Object body, int statusCode) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.Response.bytes(bytes, statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

void _mockSecureStorage({String? token = 'test_token'}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (MethodCall call) async {
      if (call.method == 'read') return token;
      return null;
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
  });

  // ── checkHealth ──────────────────────────────────────────────
  group('StockApiService.checkHealth', () {
    test('서버 200 응답 시 true 반환', () async {
      final client = MockClient((_) async => http.Response('ok', 200));
      final result = await http.runWithClient(
        () => StockApiService.checkHealth(),
        () => client,
      );
      expect(result, true);
    });

    test('서버 500 응답 시 false 반환', () async {
      final client = MockClient((_) async => http.Response('error', 500));
      final result = await http.runWithClient(
        () => StockApiService.checkHealth(),
        () => client,
      );
      expect(result, false);
    });

    test('네트워크 오류 시 false 반환', () async {
      final client = MockClient((_) async => throw Exception('connection refused'));
      final result = await http.runWithClient(
        () => StockApiService.checkHealth(),
        () => client,
      );
      expect(result, false);
    });
  });

  // ── getAiTrends ──────────────────────────────────────────────
  group('StockApiService.getAiTrends', () {
    final validBody = [
      {'rank': 1, 'code': '005930', 'name': '삼성전자', 'weather': 'SUNNY', 'score': 95, 'last_price': 72500, 'change_rate': 1.5},
      {'rank': 2, 'code': '000660', 'name': 'SK하이닉스', 'weather': 'CLOUDY', 'score': 80, 'last_price': null, 'change_rate': null},
    ];

    test('정상 응답 파싱', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => _jsonResponse(validBody, 200));

      final trends = await http.runWithClient(
        () => StockApiService.getAiTrends(topN: 2),
        () => client,
      );

      expect(trends.length, 2);
      expect(trends[0].name, '삼성전자');
      expect(trends[0].weather, 'SUNNY');
      expect(trends[0].lastPrice, 72500);
      expect(trends[1].lastPrice, isNull);
      expect(trends[1].changeRate, isNull);
    });

    test('500 응답 시 StockApiException 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('error', 500));

      expect(
        () => http.runWithClient(
          () => StockApiService.getAiTrends(),
          () => client,
        ),
        throwsA(isA<StockApiException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('타임아웃 시 StockApiException 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async {
        await Future.delayed(const Duration(seconds: 15));
        return http.Response('', 200);
      });

      expect(
        () => http.runWithClient(
          () => StockApiService.getAiTrends(),
          () => client,
        ),
        throwsA(isA<StockApiException>()),
      );
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('토큰 없으면 StockApiException 발생', () async {
      _mockSecureStorage(token: null);
      final client = MockClient((_) async => http.Response('', 200));

      expect(
        () => http.runWithClient(
          () => StockApiService.getAiTrends(),
          () => client,
        ),
        throwsA(isA<StockApiException>()),
      );
    });
  });

  // ── getStockWeather ──────────────────────────────────────────
  group('StockApiService.getStockWeather', () {
    test('stockId로 정상 응답 시 weather 반환', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => _jsonResponse({'weather': 'SUNNY'}, 200));

      final weather = await http.runWithClient(
        () => StockApiService.getStockWeather(stockId: '005930'),
        () => client,
      );

      expect(weather, 'SUNNY');
    });

    test('stockName으로 정상 응답 시 weather 반환', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => _jsonResponse({'weather': 'RAINY'}, 200));

      final weather = await http.runWithClient(
        () => StockApiService.getStockWeather(stockName: '삼성전자'),
        () => client,
      );

      expect(weather, 'RAINY');
    });

    test('stockId, stockName 둘 다 없으면 StockApiException(400) 발생', () {
      expect(
        () => StockApiService.getStockWeather(),
        throwsA(isA<StockApiException>().having((e) => e.statusCode, 'statusCode', 400)),
      );
    });

    test('404 응답 시 StockApiException 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('not found', 404));

      expect(
        () => http.runWithClient(
          () => StockApiService.getStockWeather(stockId: '999999'),
          () => client,
        ),
        throwsA(isA<StockApiException>()),
      );
    });
  });

  // ── getOverview ──────────────────────────────────────────────
  group('StockApiService.getOverview', () {
    test('정상 응답 파싱', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => _jsonResponse({
        'code': '005930',
        'name': '삼성전자',
        'last_price': 72500,
        'change': 1000.0,
        'change_rate': 1.5,
        'open': 71000,
        'high': 73000,
        'low': 70500,
        'volume': 5000000,
        'trading_value': 362500000000,
        'updated_at': null,
      }, 200));

      final overview = await http.runWithClient(
        () => StockApiService.getOverview('005930'),
        () => client,
      );

      expect(overview.lastPrice, 72500);
      expect(overview.changeRate, 1.5);
    });

    test('500 응답 시 StockApiException 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('error', 500));

      expect(
        () => http.runWithClient(
          () => StockApiService.getOverview('005930'),
          () => client,
        ),
        throwsA(isA<StockApiException>()),
      );
    });
  });
}
