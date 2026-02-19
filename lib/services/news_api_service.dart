import 'dart:convert';
import 'package:http/http.dart' as http;

/// 뉴스 API 서비스
/// 
/// 백엔드 API 서버와 통신하여 뉴스 데이터를 가져옵니다.
/// 
/// 사용하는 테이블:
///   - naver_news: title, pub_date (정렬 기준)
///   - crawled_news: text (summary로 사용)
class NewsApiService {
  // API 서버 주소
  // 개발 환경: localhost
  // 배포 환경: 실제 서버 주소로 변경
  static const String _baseUrl = 'http://localhost:8000';
  
  /// 뉴스 목록 조회 (앱 메인 화면용)
  /// 
  /// naver_news 테이블에서 pub_date 기준 최신 뉴스를 가져옵니다.
  /// 
  /// Parameters:
  ///   limit: 가져올 뉴스 개수 (기본 20개)
  ///   search: 검색어 (제목에서 검색)
  /// 
  /// Returns:
  ///   List<NewsItem>: 뉴스 목록
  static Future<List<NewsItem>> getNewsList({
    int limit = 20,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      
      final uri = Uri.parse('$_baseUrl/api/news/simple')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => NewsItem.fromJson(json)).toList();
      } else {
        throw NewsApiException(
          'Failed to load news: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is NewsApiException) rethrow;
      throw NewsApiException('Network error: $e', 0);
    }
  }
  
  /// 뉴스 상세 조회
  static Future<NewsItem> getNewsDetail(int newsId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/news/$newsId');
      
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return NewsItem.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        throw NewsApiException('News not found', 404);
      } else {
        throw NewsApiException(
          'Failed to load news detail: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is NewsApiException) rethrow;
      throw NewsApiException('Network error: $e', 0);
    }
  }
  
  /// 서버 상태 확인
  static Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$_baseUrl/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

/// 뉴스 API 예외
class NewsApiException implements Exception {
  final String message;
  final int statusCode;
  
  NewsApiException(this.message, this.statusCode);
  
  @override
  String toString() => 'NewsApiException: $message (status: $statusCode)';
}

/// 뉴스 아이템 모델
/// 
/// API 응답을 담는 데이터 클래스입니다.
/// 
/// 필드:
///   - newsId: naver_news 테이블의 PK
///   - title: naver_news.title
///   - summary: crawled_news.text
///   - pubDate: naver_news.pub_date (정렬 기준)
class NewsItem {
  final int newsId;
  final String title;
  final String? summary;
  final DateTime? pubDate;
  
  NewsItem({
    required this.newsId,
    required this.title,
    this.summary,
    this.pubDate,
  });
  
  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      newsId: json['news_id'] as int,
      title: json['title'] as String,
      summary: json['summary'] as String?,
      pubDate: json['pub_date'] != null 
          ? DateTime.tryParse(json['pub_date'] as String)
          : null,
    );
  }
}
