import 'package:flutter_test/flutter_test.dart';
import 'package:stock/models/news_models.dart';

void main() {
  group('NewsRecommendationItem.fromJson', () {
    test('정상 JSON 파싱', () {
      final json = {
        'news_id': 1,
        'title': '삼성전자 실적 발표',
        'summary': '요약 내용',
        'pub_date': '2026-04-08T09:00:00',
        'path': '/news/1',
        'stock_name': '삼성전자',
        'stock_change': '+1.5%',
        'stock_up': true,
        'is_placeholder': false,
      };

      final item = NewsRecommendationItem.fromJson(json);

      expect(item.newsId, 1);
      expect(item.title, '삼성전자 실적 발표');
      expect(item.summary, '요약 내용');
      expect(item.pubDate, isNotNull);
      expect(item.path, '/news/1');
      expect(item.stockName, '삼성전자');
      expect(item.stockChange, '+1.5%');
      expect(item.stockUp, true);
      expect(item.isPlaceholder, false);
    });

    test('필드 누락 시 기본값 적용', () {
      final item = NewsRecommendationItem.fromJson({});

      expect(item.newsId, 0);
      expect(item.title, '');
      expect(item.summary, '');
      expect(item.pubDate, isNull);
      expect(item.isPlaceholder, false);
    });

    test('pub_date 잘못된 형식이면 null', () {
      final item = NewsRecommendationItem.fromJson({'pub_date': 'invalid-date'});
      expect(item.pubDate, isNull);
    });
  });

  group('NewsRecommendationPage.fromJson', () {
    test('정상 JSON 파싱 및 items 리스트 변환', () {
      final json = {
        'user_id': 42,
        'request_id': 'req-001',
        'source': 'mab',
        'page': 1,
        'next_cursor': 'cursor-abc',
        'served_count': 2,
        'logged': true,
        'items': [
          {'news_id': 1, 'title': '뉴스1', 'summary': '요약1'},
          {'news_id': 2, 'title': '뉴스2', 'summary': '요약2'},
        ],
      };

      final page = NewsRecommendationPage.fromJson(json);

      expect(page.userId, 42);
      expect(page.requestId, 'req-001');
      expect(page.source, 'mab');
      expect(page.items.length, 2);
      expect(page.items[0].title, '뉴스1');
      expect(page.items[1].newsId, 2);
    });

    test('items 빈 배열 처리', () {
      final page = NewsRecommendationPage.fromJson({'items': []});
      expect(page.items, isEmpty);
    });

    test('필드 누락 시 기본값 적용', () {
      final page = NewsRecommendationPage.fromJson({});

      expect(page.userId, 0);
      expect(page.requestId, '');
      expect(page.items, isEmpty);
    });
  });

  group('NewsDetailItem.fromJson', () {
    test('정상 JSON 파싱', () {
      final json = {
        'news_id': 10,
        'title': '상세 뉴스',
        'summary': '요약',
        'body': '본문 내용',
        'pub_date': '2026-04-08T10:00:00',
        'url': 'https://example.com',
        'sentiment': 'positive',
        'keywords': ['반도체', 'AI'],
        'related_stocks': [
          {'stock_id': '005930', 'stock_name': '삼성전자', 'stock_up': true},
        ],
      };

      final item = NewsDetailItem.fromJson(json);

      expect(item.newsId, 10);
      expect(item.body, '본문 내용');
      expect(item.sentiment, 'positive');
      expect(item.keywords, ['반도체', 'AI']);
      expect(item.relatedStocks.length, 1);
      expect(item.relatedStocks[0].stockName, '삼성전자');
    });

    test('stock_name 공백만 있는 related_stocks 필터링', () {
      final json = {
        'news_id': 1,
        'title': '',
        'summary': '',
        'body': '',
        'related_stocks': [
          {'stock_id': '', 'stock_name': '   '},
        ],
      };

      final item = NewsDetailItem.fromJson(json);
      expect(item.relatedStocks, isEmpty);
    });
  });

  group('NewsDetailItem.fromRecommendationItem', () {
    test('stockName 있을 때 relatedStocks 생성', () {
      const rec = NewsRecommendationItem(
        newsId: 1,
        title: '제목',
        summary: '요약',
        stockName: '삼성전자',
        stockChange: '+1%',
        stockUp: true,
      );

      final detail = NewsDetailItem.fromRecommendationItem(rec);

      expect(detail.relatedStocks.length, 1);
      expect(detail.relatedStocks[0].stockName, '삼성전자');
    });

    test('stockName null이면 relatedStocks 비어있음', () {
      const rec = NewsRecommendationItem(
        newsId: 2,
        title: '제목',
        summary: '요약',
      );

      final detail = NewsDetailItem.fromRecommendationItem(rec);
      expect(detail.relatedStocks, isEmpty);
    });
  });
}
