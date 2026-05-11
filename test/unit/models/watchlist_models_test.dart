import 'package:flutter_test/flutter_test.dart';
import 'package:stock/models/watchlist_models.dart';

void main() {
  group('WatchlistStock.fromJson', () {
    test('정상 JSON 파싱', () {
      final json = {
        'code': '005930',
        'name': '삼성전자',
        'weather': 'SUNNY',
        'price': 72500,
        'changeRate': 1.5,
        'keyword': '반도체',
        'aiSummary': 'AI 요약 텍스트',
        'issueIndex': 0.8,
        'volume': 1000000,
      };

      final stock = WatchlistStock.fromJson(json);

      expect(stock.code, '005930');
      expect(stock.name, '삼성전자');
      expect(stock.weather, 'SUNNY');
      expect(stock.price, 72500);
      expect(stock.changeRate, 1.5);
      expect(stock.keyword, '반도체');
      expect(stock.aiSummary, 'AI 요약 텍스트');
      expect(stock.issueIndex, 0.8);
      expect(stock.volume, 1000000);
    });

    test('필드 누락 시 기본값 적용', () {
      final stock = WatchlistStock.fromJson({});

      expect(stock.code, '');
      expect(stock.name, '');
      expect(stock.weather, 'CLOUDY');
      expect(stock.price, 0);
      expect(stock.changeRate, 0.0);
      expect(stock.keyword, '');
      expect(stock.aiSummary, '');
      expect(stock.issueIndex, 0.0);
      expect(stock.volume, 0);
    });

    test('price가 double로 오는 경우 int 변환', () {
      final stock = WatchlistStock.fromJson({'price': 72500.9});
      expect(stock.price, 72500);
    });

    test('changeRate가 int로 오는 경우 double 변환', () {
      final stock = WatchlistStock.fromJson({'changeRate': 2});
      expect(stock.changeRate, 2.0);
    });
  });

  group('WatchlistBriefing.fromJson', () {
    test('정상 JSON 파싱', () {
      final json = {
        'text': '오늘의 브리핑입니다.',
        'topIssues': ['이슈1', '이슈2'],
      };

      final briefing = WatchlistBriefing.fromJson(json);

      expect(briefing.text, '오늘의 브리핑입니다.');
      expect(briefing.topIssues, ['이슈1', '이슈2']);
    });

    test('필드 누락 시 기본값 적용', () {
      final briefing = WatchlistBriefing.fromJson({});

      expect(briefing.text, '');
      expect(briefing.topIssues, isEmpty);
    });
  });
}
