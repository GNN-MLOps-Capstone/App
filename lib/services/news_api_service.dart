import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_auth_headers.dart';
import '../models/news_models.dart';

/// 뉴스 API 서비스
///
/// 백엔드 API 서버와 통신하여 뉴스 데이터를 가져옵니다.
///
/// 사용하는 테이블:
///   - naver_news: title, pub_date (정렬 기준)
///   - crawled_news: text (summary로 사용)
class NewsApiService {
  static String get _baseUrl => ApiConfig.baseUrl;

  /// 추천 뉴스 조회
  static Future<NewsRecommendationPage> getRecommendations({
    String? cursor,
    String? requestId,
    String? screenSessionId,
    String? appSessionId,
    bool logServed = true,
  }) async {
    try {
      final queryParams = <String, String>{
        'log_served': logServed.toString(),
      };
      if (cursor != null && cursor.isNotEmpty) {
        queryParams['cursor'] = cursor;
      }
      if (requestId != null && requestId.isNotEmpty) {
        queryParams['request_id'] = requestId;
      }
      if (screenSessionId != null && screenSessionId.isNotEmpty) {
        queryParams['screen_session_id'] = screenSessionId;
      }
      if (appSessionId != null && appSessionId.isNotEmpty) {
        queryParams['app_session_id'] = appSessionId;
      }

      final uri = Uri.parse('$_baseUrl/api/news/recommendations')
          .replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: await getAuthHeaders(),
      )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body =
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return NewsRecommendationPage.fromJson(body);
      }
      if (_isAuthFailure(response.statusCode)) {
        throw NewsApiException(_authFailureMessage, response.statusCode);
      }
      throw NewsApiException(
        'Failed to load recommendations: ${response.statusCode}',
        response.statusCode,
      );
    } catch (e) {
      if (e is NewsApiException) rethrow;
      if (e is AuthRequiredException) {
        throw NewsApiException(e.message, 401);
      }
      throw NewsApiException('Network error: $e', 0);
    }
  }

  /// 뉴스 상세 조회
  static Future<NewsDetailItem> getNewsDetail(int newsId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/news/$newsId');
      final response = await http.get(
        uri,
        headers: await getAuthHeaders(),
      )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body =
            json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return NewsDetailItem.fromJson(body);
      }
      if (response.statusCode == 404) {
        throw NewsApiException('News not found', 404);
      }
      if (_isAuthFailure(response.statusCode)) {
        throw NewsApiException(_authFailureMessage, response.statusCode);
      }
      throw NewsApiException(
        'Failed to load news detail: ${response.statusCode}',
        response.statusCode,
      );
    } catch (e) {
      if (e is NewsApiException) rethrow;
      if (e is AuthRequiredException) {
        throw NewsApiException(e.message, 401);
      }
      throw NewsApiException('Network error: $e', 0);
    }
  }

  /// 기존 종목 요약 API 유지
  static Future<StockSummary> getStockSummary(String stockName) async {
    try {
      final encodedStockName = Uri.encodeComponent(stockName);
      final uri = Uri.parse('$_baseUrl/api/news/summary/$encodedStockName');

      final response = await http.get(
        uri,
        headers: await getAuthHeaders(),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(utf8.decode(response.bodyBytes));
        return StockSummary.fromJson(jsonData);
      } else if (_isAuthFailure(response.statusCode)) {
        throw NewsApiException(_authFailureMessage, response.statusCode);
      } else if (response.statusCode == 404) {
        throw NewsApiException('존재하지 않는 종목입니다.', 404);
      } else {
        throw NewsApiException(
          '요약 정보를 가져오는데 실패했습니다: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is NewsApiException) rethrow;
      if (e is AuthRequiredException) {
        throw NewsApiException(e.message, 401);
      }
      throw NewsApiException('네트워크 오류가 발생했습니다: $e', 0);
    }
  }

  /// 서버 상태 확인
  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static bool _isAuthFailure(int statusCode) {
    return statusCode == 401 || statusCode == 403;
  }

  static const String _authFailureMessage =
      '인증이 만료되었거나 거부되었습니다. 다시 로그인해주세요. 로그인 직후에도 반복되면 GOOGLE_CLIENT_ID가 서버 검증용 Google OAuth Web Client ID와 일치하는지 확인하세요.';
}

/// 뉴스 API 예외
class NewsApiException implements Exception {
  final String message;
  final int statusCode;

  NewsApiException(this.message, this.statusCode);

  @override
  String toString() => 'NewsApiException: $message (status: $statusCode)';
}

class StockSummary {
  final String stockName;
  final String summary;
  final DateTime lastUpdated;
  final String message;

  StockSummary({
    required this.stockName,
    required this.summary,
    required this.lastUpdated,
    required this.message,
  });

  factory StockSummary.fromJson(Map<String, dynamic> json) {
    return StockSummary(
      stockName: json['stock_name'] as String,
      summary: json['summary'] as String,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
      message: json['message'] as String,
    );
  }
}
