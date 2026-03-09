import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class NotificationApiService {
  static const String get baseUrl {
    if (kIsWeb) return "http://localhost:8000";
    if (Platform.isAndroid) return "http://10.0.2.2:8000";
    if (Platform.isIOS) return "http://localhost:8000";
    return "http://192.168.x.x:8000";
  }
  static const _storage = FlutterSecureStorage();

  // 토큰 헤더 가져오기
  static Future<Map<String, String>> _getHeaders() async {
    String? token = await _storage.read(key: 'access_token');
    if (token == null || token.isEmpty){
      token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJzdHJpbmciLCJleHAiOjE3NzUyMjQ5MjB9.LlUBTA2q1aK1cHjZe8qyXtiS6eqU9q2_IavS6UvcmyU';
      // 나중에 로그인과 합쳤을 때에는 이 코드로 위에 코드는 지우고
      // throw Exception('Access token is missing');
    }
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
      ).timeout(const Duration(seconds: 10));;

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['id'] as int;
      }
      return null;
    } catch (e) {
      rethrow;
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
  final String targetOnesignalId;
  final String type;
  final String title;
  final String? body;
  final String? stockName;
  final double? sentimentScore;

  NotificationCreateRequest({
    required this.targetOnesignalId,
    required this.type,
    required this.title,
    this.body,
    this.stockName,
    this.sentimentScore,
  });

  Map<String, dynamic> toJson() => {
    'onesignal_id': targetOnesignalId,
    'type': type,
    'title': title,
    'body': body,
    'stock_name': stockName,
    'sentiment_score': sentimentScore,
  };
}