import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock/services/notification_service.dart';

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
  return http.Response.bytes(
    bytes,
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
  });

  // ── NotificationResponse.fromJson ────────────────────────────
  group('NotificationResponse.fromJson', () {
    test('정상 JSON 파싱', () {
      final json = {
        'id': 1,
        'type': 'stock_news',
        'title': '삼성전자 관련 뉴스',
        'body': '뉴스 내용',
        'read': false,
        'star': true,
        'created_at': '2026-04-10T09:00:00',
      };
      final notification = NotificationResponse.fromJson(json);

      expect(notification.id, 1);
      expect(notification.type, 'stock_news');
      expect(notification.title, '삼성전자 관련 뉴스');
      expect(notification.body, '뉴스 내용');
      expect(notification.read, false);
      expect(notification.star, true);
      expect(notification.createdAt, isNotNull);
    });

    test('body null 허용', () {
      final json = {
        'id': 2,
        'type': 'alert',
        'title': '알림',
        'read': true,
        'created_at': '2026-04-10T09:00:00',
      };
      final notification = NotificationResponse.fromJson(json);
      expect(notification.body, isNull);
    });

    test('read/star 누락 시 기본값 false', () {
      final json = {
        'id': 3,
        'type': 'alert',
        'title': '알림',
        'created_at': '2026-04-10T09:00:00',
      };
      final notification = NotificationResponse.fromJson(json);
      expect(notification.read, false);
      expect(notification.star, false);
    });
  });

  // ── NotificationCreateRequest.toJson ─────────────────────────
  group('NotificationCreateRequest.toJson', () {
    test('모든 필드 직렬화', () {
      final req = NotificationCreateRequest(
        notificationId: 'noti-001',
        type: 'stock_news',
        title: '뉴스 알림',
        body: '내용',
        stockName: '삼성전자',
        sentimentScore: 0.85,
      );
      final json = req.toJson();

      expect(json['notification_id'], 'noti-001');
      expect(json['type'], 'stock_news');
      expect(json['title'], '뉴스 알림');
      expect(json['stock_name'], '삼성전자');
      expect(json['sentiment_score'], 0.85);
    });

    test('선택 필드 null 허용', () {
      final req = NotificationCreateRequest(
        notificationId: 'noti-002',
        type: 'alert',
        title: '알림',
      );
      final json = req.toJson();

      expect(json['body'], isNull);
      expect(json['stock_name'], isNull);
      expect(json['sentiment_score'], isNull);
    });
  });

  // ── NotificationApiService.getNotifications ──────────────────
  group('NotificationApiService.getNotifications', () {
    final validBody = [
      {
        'id': 1,
        'type': 'stock_news',
        'title': '삼성전자 뉴스',
        'body': '내용',
        'read': false,
        'star': false,
        'created_at': '2026-04-10T09:00:00',
      },
      {
        'id': 2,
        'type': 'alert',
        'title': '가격 알림',
        'read': true,
        'star': true,
        'created_at': '2026-04-10T10:00:00',
      },
    ];

    test('정상 응답 파싱', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => _jsonResponse(validBody, 200));

      final result = await http.runWithClient(
        () => NotificationApiService.getNotifications(),
        () => client,
      );

      expect(result.length, 2);
      expect(result[0].title, '삼성전자 뉴스');
      expect(result[1].read, true);
    });

    test('빈 배열 응답 처리', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => _jsonResponse([], 200));

      final result = await http.runWithClient(
        () => NotificationApiService.getNotifications(),
        () => client,
      );

      expect(result, isEmpty);
    });

    test('500 응답 시 예외 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('error', 500));

      expect(
        () => http.runWithClient(
          () => NotificationApiService.getNotifications(),
          () => client,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── NotificationApiService.markAsRead ────────────────────────
  group('NotificationApiService.markAsRead', () {
    test('단건 읽음 처리 후 unread_count 반환', () async {
      _mockSecureStorage();
      final client = MockClient(
        (_) async => _jsonResponse({'unread_count': 3}, 200),
      );

      final count = await http.runWithClient(
        () => NotificationApiService.markAsRead(id: 1),
        () => client,
      );

      expect(count, 3);
    });

    test('전체 읽음 처리 (id null) 후 unread_count 0 반환', () async {
      _mockSecureStorage();
      final client = MockClient(
        (_) async => _jsonResponse({'unread_count': 0}, 200),
      );

      final count = await http.runWithClient(
        () => NotificationApiService.markAsRead(),
        () => client,
      );

      expect(count, 0);
    });

    test('500 응답 시 예외 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('error', 500));

      expect(
        () => http.runWithClient(
          () => NotificationApiService.markAsRead(id: 1),
          () => client,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── NotificationApiService.toggleImportant ───────────────────
  group('NotificationApiService.toggleImportant', () {
    test('200 응답 시 star 상태 반환 (true)', () async {
      _mockSecureStorage();
      final client = MockClient(
        (_) async => _jsonResponse({'star': true}, 200),
      );

      final result = await http.runWithClient(
        () => NotificationApiService.toggleImportant(1),
        () => client,
      );

      expect(result, true);
    });

    test('200 응답 시 star 상태 반환 (false)', () async {
      _mockSecureStorage();
      final client = MockClient(
        (_) async => _jsonResponse({'star': false}, 200),
      );

      final result = await http.runWithClient(
        () => NotificationApiService.toggleImportant(1),
        () => client,
      );

      expect(result, false);
    });

    test('비정상 응답 시 예외 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('error', 500));

      expect(
        () => http.runWithClient(
          () => NotificationApiService.toggleImportant(1),
          () => client,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── NotificationApiService.deleteNotification ────────────────
  group('NotificationApiService.deleteNotification', () {
    test('200 응답 시 true 반환', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('', 200));

      final result = await http.runWithClient(
        () => NotificationApiService.deleteNotification(1),
        () => client,
      );

      expect(result, true);
    });

    test('404 응답 시 false 반환', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('not found', 404));

      final result = await http.runWithClient(
        () => NotificationApiService.deleteNotification(999),
        () => client,
      );

      expect(result, false);
    });

    test('네트워크 오류 시 false 반환', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => throw Exception('network error'));

      final result = await http.runWithClient(
        () => NotificationApiService.deleteNotification(1),
        () => client,
      );

      expect(result, false);
    });
  });

  // ── NotificationApiService.createNotification ────────────────
  group('NotificationApiService.createNotification', () {
    test('201 응답 시 생성된 id 반환', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => _jsonResponse({'id': 42}, 201));

      final req = NotificationCreateRequest(
        notificationId: 'noti-001',
        type: 'stock_news',
        title: '뉴스 알림',
      );

      final id = await http.runWithClient(
        () => NotificationApiService.createNotification(req),
        () => client,
      );

      expect(id, 42);
    });

    test('비정상 응답 시 null 반환', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('error', 500));

      final req = NotificationCreateRequest(
        notificationId: 'noti-001',
        type: 'stock_news',
        title: '뉴스 알림',
      );

      final id = await http.runWithClient(
        () => NotificationApiService.createNotification(req),
        () => client,
      );

      expect(id, isNull);
    });
  });
}
