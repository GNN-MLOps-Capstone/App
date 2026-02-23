import 'dart:convert';
import 'package:http/http.dart' as http;

/// 주식 API 서비스 (뉴스 API 서비스와 동일한 패턴)
class StockApiService {
  // iOS 시뮬레이터면 localhost OK
  static const String _baseUrl = 'http://localhost:8000';

  /// 서버 상태 확인
  static Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$_baseUrl/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 종목 요약 (가격/등락/고저 등)
  static Future<StockOverview> getOverview(String code) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/stocks/$code/overview');
      final res = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return StockOverview.fromJson(jsonDecode(res.body));
      }
      throw StockApiException('Failed to load overview: ${res.statusCode}', res.statusCode);
    } catch (e) {
      if (e is StockApiException) rethrow;
      throw StockApiException('Network error: $e', 0);
    }
  }

  /// 시계열 (그래프)
  /// range 예: 1d, 1m (백엔드 지원 범위에 맞춰 사용)
  static Future<StockSeries> getSeries(String code, {required String range}) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/stocks/$code/series?range=$range');
      final res = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return StockSeries.fromJson(jsonDecode(res.body));
      }
      throw StockApiException('Failed to load series: ${res.statusCode}', res.statusCode);
    } catch (e) {
      if (e is StockApiException) rethrow;
      throw StockApiException('Network error: $e', 0);
    }
  }
}

class StockApiException implements Exception {
  final String message;
  final int statusCode;
  StockApiException(this.message, this.statusCode);

  @override
  String toString() => 'StockApiException: $message (status: $statusCode)';
}

/// /overview 응답 모델
class StockOverview {
  final String code;
  final String? name;
  final int lastPrice;
  final double change;
  final double changeRate;
  final int open;
  final int high;
  final int low;
  final int volume;
  final int tradingValue;
  final DateTime? updatedAt;

  StockOverview({
    required this.code,
    required this.name,
    required this.lastPrice,
    required this.change,
    required this.changeRate,
    required this.open,
    required this.high,
    required this.low,
    required this.volume,
    required this.tradingValue,
    required this.updatedAt,
  });

  factory StockOverview.fromJson(Map<String, dynamic> json) {
    return StockOverview(
      code: json['code'] as String,
      name: json['name'] as String?,
      lastPrice: (json['last_price'] as num).toInt(),
      change: (json['change'] as num).toDouble(),
      changeRate: (json['change_rate'] as num).toDouble(),
      open: (json['open'] as num).toInt(),
      high: (json['high'] as num).toInt(),
      low: (json['low'] as num).toInt(),
      volume: (json['volume'] as num).toInt(),
      tradingValue: (json['trading_value'] as num).toInt(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }
}

/// /series 응답 모델
class StockSeries {
  final String code;
  final String range;
  final String tz;
  final String currency;
  final List<StockPoint> points;

  StockSeries({
    required this.code,
    required this.range,
    required this.tz,
    required this.currency,
    required this.points,
  });

  factory StockSeries.fromJson(Map<String, dynamic> json) {
    final raw = (json['points'] as List).cast<Map<String, dynamic>>();
    return StockSeries(
      code: json['code'] as String,
      range: json['range'] as String,
      tz: (json['tz'] as String?) ?? 'Asia/Seoul',
      currency: (json['currency'] as String?) ?? 'KRW',
      points: raw.map((e) => StockPoint.fromJson(e)).toList(),
    );
  }
}

class StockPoint {
  final int t; // ms timestamp
  final int o;
  final int h;
  final int l;
  final int c;
  final int v;

  StockPoint({
    required this.t,
    required this.o,
    required this.h,
    required this.l,
    required this.c,
    required this.v,
  });

  factory StockPoint.fromJson(Map<String, dynamic> json) {
    return StockPoint(
      t: (json['t'] as num).toInt(),
      o: (json['o'] as num).toInt(),
      h: (json['h'] as num).toInt(),
      l: (json['l'] as num).toInt(),
      c: (json['c'] as num).toInt(),
      v: (json['v'] as num).toInt(),
    );
  }
}