import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock/services/watchlist_service.dart';

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

http.Response _jsonResponse(Object body, int statusCode) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.Response.bytes(bytes, statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
    dotenv.env['API_BASE_URL'] = 'http://localhost:8000';
  });

  // ── toStockCode ──────────────────────────────────────────────
  group('WatchlistService.toStockCode', () {
    final service = WatchlistService();

    test('6자리 코드는 그대로 반환', () {
      expect(service.toStockCode('005930'), '005930');
    });

    test('ISIN 코드(KR로 시작, 12자리)를 6자리로 변환', () {
      expect(service.toStockCode('KR7005930003'), '005930');
    });

    test('KR로 시작하지 않는 코드는 그대로 반환', () {
      expect(service.toStockCode('US12345678'), 'US12345678');
    });
  });

  // ── getWatchlist ─────────────────────────────────────────────
  group('WatchlistService.getWatchlist', () {
    final validBody = [
      {
        'code': '005930',
        'name': '삼성전자',
        'weather': 'SUNNY',
        'price': 72500,
        'changeRate': 1.5,
        'keyword': '반도체',
        'aiSummary': 'AI 요약',
      },
      {
        'code': '000660',
        'name': 'SK하이닉스',
        'weather': 'CLOUDY',
        'price': 185000,
        'changeRate': -0.5,
        'keyword': 'HBM',
        'aiSummary': '',
      },
    ];

    test('정상 응답 파싱', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => _jsonResponse(validBody, 200));

      final service = WatchlistService();
      final result = await http.runWithClient(
        () => service.getWatchlist(),
        () => client,
      );

      expect(result.length, 2);
      expect(result[0].code, '005930');
      expect(result[0].name, '삼성전자');
      expect(result[1].changeRate, -0.5);
    });

    test('빈 배열 응답 처리', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => _jsonResponse([], 200));

      final service = WatchlistService();
      final result = await http.runWithClient(
        () => service.getWatchlist(),
        () => client,
      );

      expect(result, isEmpty);
    });

    test('500 응답 시 예외 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('error', 500));

      final service = WatchlistService();
      expect(
        () => http.runWithClient(
          () => service.getWatchlist(),
          () => client,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── addStock ─────────────────────────────────────────────────
  group('WatchlistService.addStock', () {
    test('201 응답 시 true 반환', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('', 201));

      final service = WatchlistService();
      final result = await http.runWithClient(
        () => service.addStock('005930'),
        () => client,
      );

      expect(result, true);
    });

    test('200 응답 시 true 반환', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('', 200));

      final service = WatchlistService();
      final result = await http.runWithClient(
        () => service.addStock('005930'),
        () => client,
      );

      expect(result, true);
    });

    test('네트워크 오류 시 false 반환', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => throw Exception('network error'));

      final service = WatchlistService();
      final result = await http.runWithClient(
        () => service.addStock('005930'),
        () => client,
      );

      expect(result, false);
    });

    test('ISIN 코드를 6자리로 변환하여 전송', () async {
      _mockSecureStorage();
      http.Request? capturedRequest;
      final client = MockClient((req) async {
        capturedRequest = req;
        return http.Response('', 201);
      });

      final service = WatchlistService();
      await http.runWithClient(
        () => service.addStock('KR7005930003'),
        () => client,
      );

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['code'], '005930');
    });
  });

  // ── deleteStock ──────────────────────────────────────────────
  group('WatchlistService.deleteStock', () {
    test('200 응답 시 true 반환', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('', 200));

      final service = WatchlistService();
      final result = await http.runWithClient(
        () => service.deleteStock('005930'),
        () => client,
      );

      expect(result, true);
    });

    test('204 응답 시 true 반환', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('', 204));

      final service = WatchlistService();
      final result = await http.runWithClient(
        () => service.deleteStock('005930'),
        () => client,
      );

      expect(result, true);
    });

    test('네트워크 오류 시 false 반환', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => throw Exception('network error'));

      final service = WatchlistService();
      final result = await http.runWithClient(
        () => service.deleteStock('005930'),
        () => client,
      );

      expect(result, false);
    });
  });

  // ── getBriefing ──────────────────────────────────────────────
  group('WatchlistService.getBriefing', () {
    test('정상 응답 파싱', () async {
      _mockSecureStorage();
      final body = {
        'text': '오늘의 브리핑입니다.',
        'topIssues': ['이슈1', '이슈2'],
      };
      final client = MockClient((_) async => _jsonResponse(body, 200));

      final service = WatchlistService();
      final briefing = await http.runWithClient(
        () => service.getBriefing(),
        () => client,
      );

      expect(briefing.text, '오늘의 브리핑입니다.');
      expect(briefing.topIssues.length, 2);
    });

    test('500 응답 시 예외 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('error', 500));

      final service = WatchlistService();
      expect(
        () => http.runWithClient(
          () => service.getBriefing(),
          () => client,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── getStockDetail ───────────────────────────────────────────
  group('WatchlistService.getStockDetail', () {
    test('정상 응답 파싱', () async {
      _mockSecureStorage();
      final body = {
        'code': '005930',
        'name': '삼성전자',
        'weather': 'SUNNY',
        'price': 72500,
        'changeRate': 1.5,
        'keyword': '반도체',
        'aiSummary': 'AI 요약',
      };
      final client = MockClient((_) async => _jsonResponse(body, 200));

      final service = WatchlistService();
      final stock = await http.runWithClient(
        () => service.getStockDetail('005930'),
        () => client,
      );

      expect(stock, isNotNull);
      expect(stock!.code, '005930');
      expect(stock.weather, 'SUNNY');
    });

    test('500 응답 시 예외 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('error', 500));

      final service = WatchlistService();
      expect(
        () => http.runWithClient(
          () => service.getStockDetail('005930'),
          () => client,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
