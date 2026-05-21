import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class NotificationApiService {
  static String get _baseUrl => ApiConfig.baseUrl;
  static const _storage = FlutterSecureStorage();

  // 토큰 헤더 가져오기
  static Future<Map<String, String>> _getHeaders() async {
    String? token = await _storage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ""}',
    };
  }

  /// 알림 내역 조회 (무한 스크롤 지원)
  static Future<List<NotificationResponse>> getNotifications({
    int page = 1,
    int size = 20,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/notifications')
          .replace(queryParameters: {
        'page': page.toString(),
        'size': size.toString(),
      });

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(utf8.decode(response.bodyBytes));
        return jsonList.map((j) => NotificationResponse.fromJson(j)).toList();
      } else {
        throw Exception('Failed to load notifications: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 읽음 처리 (특정 ID 전달 시 단건, null 전달 시 전체 읽음)
  static Future<int> markAsRead({int? id}) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/notifications/read');
      final response = await http.patch(
        uri,
        headers: await _getHeaders(),
        body: json.encode({'id': id}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['unread_count'] as int;
      } else {
        throw Exception('Failed to mark as read');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 중요 표시 토글
  static Future<bool> toggleImportant(int id) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/notifications/important');
      final response = await http.patch(
        uri,
        headers: await _getHeaders(),
        body: json.encode({'id': id}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['star'] as bool;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }

  /// 알림 삭제
  static Future<bool> deleteNotification(int id) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/notifications/$id');
      final response = await http.delete(uri, headers: await _getHeaders());
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 알림 저장 (앱에서 직접 생성 시)
  static Future<int?> createNotification(NotificationCreateRequest req) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/notifications');
      final response = await http.post(
        uri,
        headers: await _getHeaders(),
        body: json.encode(req.toJson()),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['id'] as int;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// 읽지 않은 알림 개수 가져오기
  static Future<int> getUnreadNotificationCount() async {
    try {
      // 백엔드에서 설정한 엔드포인트에 맞춰 경로를 수정하세요 (예: /api/notifications/unread-count)
      final uri = Uri.parse('$_baseUrl/api/notifications/unread-count');

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // 백엔드 응답 구조가 { "count": 5 } 형태라고 가정할 때
        final rawCount = data['count'] ?? data['unread_count']; // 혹시 모를 다른 키 이름까지 1차 방어
        final safeCount = int.tryParse(rawCount?.toString() ?? '0') ?? 0;
        return safeCount;
      } else {
        // 에러 발생 시 기본값 0 반환 또는 예외 처리
        print('❌ 알림 API 서버 에러 응답 코드: ${response.statusCode}');
        return 0;
      }
    } catch (e) {
      // 로그를 남기거나 에러를 던집니다.
      print('Error fetching unread count: $e');
      return 0;
    }
  }
}

/// 알림 응답 모델
class NotificationResponse {
  final int id;
  final String type;
  final String title;
  final String? body;
  final bool read;
  final bool star;
  final DateTime createdAt;

  NotificationResponse({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    required this.read,
    this.star = false,
    required this.createdAt,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    return NotificationResponse(
      id: json['id'],
      type: json['type'],
      title: json['title'],
      body: json['body'],
      read: json['read'] ?? false,
      star: json['star'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// 알림 생성 요청 모델
class NotificationCreateRequest {
  final String notificationId;
  final String type;
  final String title;
  final String? body;
  final String? stockName;
  final double? sentimentScore;

  NotificationCreateRequest({
    required this.notificationId,
    required this.type,
    required this.title,
    this.body,
    this.stockName,
    this.sentimentScore,
  });

  Map<String, dynamic> toJson() => {
    'notification_id': notificationId,
    'type': type,
    'title': title,
    'body': body,
    'stock_name': stockName,
    'sentiment_score': sentimentScore,
  };
}