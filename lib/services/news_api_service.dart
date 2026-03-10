import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// 뉴스 API 서비스
/// 
/// 백엔드 API 서버와 통신하여 뉴스 데이터를 가져옵니다.
/// 
/// 사용하는 테이블:
///   - naver_news: title, pub_date (정렬 기준)
///   - crawled_news: text (summary로 사용)
class NewsApiService {
  static String get _baseUrl => ApiConfig.baseUrl;
  
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
  static Future<StockSummary> getStockSummary(String stockName) async {
    try {
      // 종목명은 URL 경로에 포함되므로 인코딩 처리
      final encodedStockName = Uri.encodeComponent(stockName);
      final uri = Uri.parse('$_baseUrl/api/news/summary/$encodedStockName');

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15)); // AI 생성 시간이 걸릴 수 있으므로 15초 설정

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(utf8.decode(response.bodyBytes));
        return StockSummary.fromJson(jsonData);
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
      throw NewsApiException('네트워크 오류가 발생했습니다: $e', 0);
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