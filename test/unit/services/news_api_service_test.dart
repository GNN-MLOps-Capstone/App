import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock/services/news_api_service.dart';

// FlutterSecureStorage 플랫폼 채널 모킹
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
  group('NewsApiService.checkHealth', () {
    test('서버 200 응답 시 true 반환', () async {
      final client = MockClient((_) async => http.Response('ok', 200));
      final result = await http.runWithClient(
        () => NewsApiService.checkHealth(),
        () => client,
      );
      expect(result, true);
    });

    test('서버 500 응답 시 false 반환', () async {
      final client = MockClient((_) async => http.Response('error', 500));
      final result = await http.runWithClient(
        () => NewsApiService.checkHealth(),
        () => client,
      );
      expect(result, false);
    });

    test('네트워크 오류 시 false 반환', () async {
      final client = MockClient((_) async => throw Exception('connection refused'));
      final result = await http.runWithClient(
        () => NewsApiService.checkHealth(),
        () => client,
      );
      expect(result, false);
    });
  });

  // ── getRecommendations ───────────────────────────────────────
  group('NewsApiService.getRecommendations', () {
    final validResponse = jsonEncode({
      'user_id': 1,
      'request_id': 'req-001',
      'source': 'mab',
      'page': 1,
      'next_cursor': null,
      'served_count': 2,
      'logged': true,
      'items': [
        {'news_id': 1, 'title': '뉴스1', 'summary': '요약1'},
        {'news_id': 2, 'title': '뉴스2', 'summary': '요약2'},
      ],
    });

    test('정상 응답 파싱', () async {
      _mockSecureStorage();
      final client = MockClient((_) async =>
          http.Response(validResponse, 200, headers: {'content-type': 'application/json; charset=utf-8'}));

      final page = await http.runWithClient(
        () => NewsApiService.getRecommendations(),
        () => client,
      );

      expect(page.items.length, 2);
      expect(page.items[0].title, '뉴스1');
      expect(page.requestId, 'req-001');
    });

    test('401 응답 시 NewsApiException 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('unauthorized', 401));

      expect(
        () => http.runWithClient(
          () => NewsApiService.getRecommendations(),
          () => client,
        ),
        throwsA(isA<NewsApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('500 응답 시 NewsApiException 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('server error', 500));

      expect(
        () => http.runWithClient(
          () => NewsApiService.getRecommendations(),
          () => client,
        ),
        throwsA(isA<NewsApiException>()),
      );
    });

    test('타임아웃 시 NewsApiException 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async {
        await Future.delayed(const Duration(seconds: 25));
        return http.Response('', 200);
      });

      expect(
        () => http.runWithClient(
          () => NewsApiService.getRecommendations(),
          () => client,
        ),
        throwsA(isA<NewsApiException>()),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('토큰 없으면 NewsApiException 발생', () async {
      _mockSecureStorage(token: null);
      final client = MockClient((_) async => http.Response('', 200));

      expect(
        () => http.runWithClient(
          () => NewsApiService.getRecommendations(),
          () => client,
        ),
        throwsA(
          isA<NewsApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having(
                (e) => e.message,
                'message',
                contains('GOOGLE_CLIENT_ID'),
              ),
        ),
      );
    });
  });

  // ── getNewsDetail ────────────────────────────────────────────
  group('NewsApiService.getNewsDetail', () {
    test('정상 응답 파싱', () async {
      _mockSecureStorage();
      final body = jsonEncode({
        'news_id': 10,
        'title': '상세 뉴스',
        'summary': '요약',
        'body': '본문',
        'keywords': ['AI'],
        'related_stocks': [],
      });
      final client = MockClient((_) async =>
          http.Response(body, 200, headers: {'content-type': 'application/json; charset=utf-8'}));

      final detail = await http.runWithClient(
        () => NewsApiService.getNewsDetail(10),
        () => client,
      );

      expect(detail.newsId, 10);
      expect(detail.title, '상세 뉴스');
      expect(detail.keywords, ['AI']);
    });

    test('404 응답 시 NewsApiException(404) 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('not found', 404));

      expect(
        () => http.runWithClient(
          () => NewsApiService.getNewsDetail(999),
          () => client,
        ),
        throwsA(isA<NewsApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });
}
