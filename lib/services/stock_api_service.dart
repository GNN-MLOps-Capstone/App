import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

/// 주식 API 서비스 (REST + WebSocket)
class StockApiService {
  static String get _baseUrl => ApiConfig.baseUrl;
  static String get _wsBaseUrl => ApiConfig.wsBaseUrl;
  static const _storage = FlutterSecureStorage();

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

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
        headers: await _getHeaders(),
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
  /// range: 1d, 1w, 1m
  static Future<StockSeries> getSeries(
    String code, {
    required String range,
    bool forceRefresh = false,
  }) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final forceQuery = forceRefresh ? '&_ts=$ts' : '';
      final uri = Uri.parse('$_baseUrl/api/stocks/$code/series?range=$range$forceQuery');
      final res = await http.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        return StockSeries.fromJson(jsonDecode(res.body));
      }
      throw StockApiException('Failed to load series: ${res.statusCode}', res.statusCode);
    } catch (e) {
      if (e is StockApiException) rethrow;
      throw StockApiException('Network error: $e', 0);
    }
  }

  /// 실시간 현재가 WebSocket 스트림
  /// 종목코드(6자리)를 넘기면 실시간 가격 이벤트를 Stream으로 반환합니다.
  static Future<StockRealtimeConnection> connectRealtime(String code) async {
    final token = await _storage.read(key: 'access_token');
    final controller = StreamController<StockRealtimePrice>.broadcast();
    WebSocketChannel? channel;

    Future<void> safeCloseController() async {
      if (!controller.isClosed) {
        await controller.close();
      }
    }

    try {
      final query = token != null
          ? 'code=$code&access_token=$token'
          : 'code=$code';
      final uri = Uri.parse('$_wsBaseUrl/api/stocks/ws/current?$query');
      channel = WebSocketChannel.connect(uri);
    } catch (e) {
      debugPrint('[WS] 초기 연결 실패(code=$code): $e');
      return StockRealtimeConnection(
        stream: controller.stream,
        close: () {
          if (!controller.isClosed) {
            controller.close();
          }
        },
      );
    }

    final WebSocketChannel wsChannel = channel;

    final subscription = wsChannel.stream.listen(
      (raw) {
        try {
          final json = jsonDecode(raw as String) as Map<String, dynamic>;
          // 에러 메시지인 경우
          if (json.containsKey('error')) {
            debugPrint('[WS] 서버 에러: ${json['error']}');
            return;
          }
          controller.add(StockRealtimePrice.fromJson(json));
        } catch (e) {
          debugPrint('[WS] 파싱 에러: $e');
        }
      },
      onError: (e) {
        debugPrint('[WS] 연결 에러: $e');
        unawaited(safeCloseController());
      },
      onDone: () {
        debugPrint('[WS] 연결 종료');
        unawaited(safeCloseController());
      },
    );

    return StockRealtimeConnection(
      stream: controller.stream,
      close: () {
        unawaited(subscription.cancel());
        unawaited(wsChannel.sink.close());
        unawaited(safeCloseController());
      },
    );
  }
  
  /// AI 트렌드 종목 조회
  static Future<List<AiTrend>> getAiTrends({int topN = 3}) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/stocks/trends?top_n=$topN');
      final res = await http.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list
            .cast<Map<String, dynamic>>()
            .map((e) => AiTrend.fromJson(e))
            .toList();
      }
      throw StockApiException('Failed to load AI trends: ${res.statusCode}', res.statusCode);
    } catch (e) {
      if (e is StockApiException) rethrow;
      throw StockApiException('Network error: $e', 0);
    }
  }
  
  /// 종목 날씨 조회
  static Future<String> getStockWeather({String? stockId, String? stockName}) async {
    final normalizedStockId = stockId?.trim();
    final normalizedStockName = stockName?.trim();
    if ((normalizedStockId == null || normalizedStockId.isEmpty) &&
        (normalizedStockName == null || normalizedStockName.isEmpty)) {
      throw StockApiException('stockId 또는 stockName 중 하나는 필수입니다.', 400);
    }
    
    try {
      final params = <String, String>{};
      if (normalizedStockId != null && normalizedStockId.isNotEmpty) {
        params['stock_id'] = normalizedStockId;
      }
      if (normalizedStockName != null && normalizedStockName.isNotEmpty) {
        params['stock_name'] = normalizedStockName;
      }

      final uri = Uri.parse('$_baseUrl/api/stocks/weather').replace(queryParameters: params);
      final res = await http.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        return json['weather'] as String;
      }
      throw StockApiException('Failed to load stock weather: ${res.statusCode}', res.statusCode);
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

/// 실시간 현재가 모델 (WebSocket 메시지)
class StockRealtimePrice {
  final String code;
  final String time;
  final int price;
  final double change;
  final double changeRate;
  final int open;
  final int high;
  final int low;
  final int volume;
  final int tradingValue;

  StockRealtimePrice({
    required this.code,
    required this.time,
    required this.price,
    required this.change,
    required this.changeRate,
    required this.open,
    required this.high,
    required this.low,
    required this.volume,
    required this.tradingValue,
  });

  factory StockRealtimePrice.fromJson(Map<String, dynamic> json) {
    return StockRealtimePrice(
      code: json['code'] as String? ?? '',
      time: json['time'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      change: (json['change'] as num?)?.toDouble() ?? 0,
      changeRate: (json['change_rate'] as num?)?.toDouble() ?? 0,
      open: (json['open'] as num?)?.toInt() ?? 0,
      high: (json['high'] as num?)?.toInt() ?? 0,
      low: (json['low'] as num?)?.toInt() ?? 0,
      volume: (json['volume'] as num?)?.toInt() ?? 0,
      tradingValue: (json['trading_value'] as num?)?.toInt() ?? 0,
    );
  }
}

/// WebSocket 연결 핸들 (stream + close)
class StockRealtimeConnection {
  final Stream<StockRealtimePrice> stream;
  final VoidCallback close;

  StockRealtimeConnection({required this.stream, required this.close});
}

/// AI 트렌드 종목 모델
class AiTrend {
  final int rank;
  final String code;
  final String name;
  final String weather;
  final int score;
  final int? lastPrice;       // 추가
  final double? changeRate;   // 추가

  AiTrend({
    required this.rank,
    required this.code,
    required this.name,
    required this.weather,
    required this.score,
    this.lastPrice,
    this.changeRate,
  });

  factory AiTrend.fromJson(Map<String, dynamic> json) {
    return AiTrend(
      rank: (json['rank'] as num).toInt(),
      code: json['code'] as String,
      name: json['name'] as String,
      weather: json['weather'] as String,
      score: (json['score'] as num).toInt(),
      lastPrice: (json['last_price'] as num?)?.toInt(),
      changeRate: (json['change_rate'] as num?)?.toDouble(),
    );
  }
}