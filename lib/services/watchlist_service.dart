import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../models/watchlist_models.dart';

class WatchlistService {
  static final WatchlistService _instance = WatchlistService._internal();
  factory WatchlistService() => _instance;
  WatchlistService._internal();

  static const _storage = FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null || token.trim().isEmpty) {
      throw Exception('액세스 토큰이 없습니다. 다시 로그인해주세요.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// ISIN 코드(KR7005930003)를 6자리 종목코드(005930)로 변환
  String toStockCode(String code) {
    if (code.length == 6) return code;
    if (code.startsWith('KR') && code.length >= 9) {
      return code.substring(3, 9);
    }
    return code;
  }

  String? get _baseUrl => ApiConfig.configuredBaseUrl;

  // ── 로컬 캐시 ──

  bool _localInitialized = false;
  final List<WatchlistStock> _localStocks = [];

  List<WatchlistStock> get _localList {
    if (!_localInitialized) {
      // 더미 데이터 없음 → 빈 리스트
      _localInitialized = true;
    }
    return _localStocks;
  }

  // ── 더미 브리핑 ──

  static final WatchlistBriefing _dummyBriefing = WatchlistBriefing(
    text: '오늘 관심종목 중 반도체 섹터가 강세를 보이고 있습니다. '
        '삼성전자와 SK하이닉스가 HBM 수요 기대감에 동반 상승 중이며, '
        '카카오는 규제 이슈로 약세 흐름을 이어가고 있습니다.',
    topIssues: ['HBM 수요 급증', '카카오 규제 리스크', '전고체 배터리 기대'],
  );

  // ── API 호출 ──────────────────────────────────────────

  Future<List<WatchlistStock>> getWatchlist() async {
    final base = _baseUrl;
    if (base == null) return List.from(_localList);

    final res = await http.get(Uri.parse('$base/api/watchlist'),
        headers: await _getHeaders())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((e) => WatchlistStock.fromJson(e)).toList();
    }
    throw Exception('관심종목 조회 실패: ${res.statusCode}');
  }

  Future<bool> addStock(String code, {String? name}) async {
    final stockCode = toStockCode(code);
    final base = _baseUrl;
    if (base == null) {
      if (_localList.any((s) => s.code == stockCode)) return true;
      _localList.add(WatchlistStock(
        code: stockCode,
        name: name ?? stockCode,
        weather: 'CLOUDY',
        price: 0,
        changeRate: 0.0,
        keyword: '',
        aiSummary: '',
      ));
      return true;
    }

    try {
      final res = await http.post(
        Uri.parse('$base/api/watchlist'),
        headers: await _getHeaders(),
        body: jsonEncode({'code': stockCode}),
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      if (kDebugMode) print('addStock 오류: $e');
      return false;
    }
  }

  Future<bool> deleteStock(String code) async {
    final stockCode = toStockCode(code);
    final base = _baseUrl;
    if (base == null) {
      _localList.removeWhere((s) => s.code == stockCode);
      return true;
    }

    try {
      final res = await http.delete(Uri.parse('$base/api/watchlist/$stockCode'),
          headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      if (kDebugMode) print('deleteStock 오류: $e');
      return false;
    }
  }

  Future<WatchlistBriefing> getBriefing() async {
    final base = _baseUrl;
    if (base == null) return _dummyBriefing;

    final res = await http.get(Uri.parse('$base/api/watchlist/briefing'),
        headers: await _getHeaders())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      return WatchlistBriefing.fromJson(jsonDecode(res.body));
    }
    throw Exception('브리핑 조회 실패: ${res.statusCode}');
  }

  Future<WatchlistStock?> getStockDetail(String code) async {
    final base = _baseUrl;
    if (base == null) {
      try {
        return _localList.firstWhere((s) => s.code == code);
      } catch (_) {
        return null;
      }
    }

    final res = await http.get(Uri.parse('$base/api/stocks/$code'),
        headers: await _getHeaders())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      return WatchlistStock.fromJson(jsonDecode(res.body));
    }
    throw Exception('종목 상세 조회 실패: ${res.statusCode}');
  }
}