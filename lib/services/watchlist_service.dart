import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

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
    // 이미 6자리면 그대로 반환
    if (code.length == 6) return code;
    // ISIN 형식이면 3~8번째 자리 추출 (KR7XXXXXX000 → XXXXXX)
    if (code.startsWith('KR') && code.length >= 9) {
      return code.substring(3, 9);
    }
    return code;
  }

  /// baseUrl(non-nullable) 대신 configuredBaseUrl(nullable)을 사용:
  /// 서버 URL이 명시 설정되지 않으면 null을 반환하여 더미 데이터/오프라인 모드로 폴백한다.
  String? get _baseUrl {
    return ApiConfig.configuredBaseUrl;
  }

  // ── 로컬 캐시 (더미 모드에서 추가/삭제 반영) ──

  bool _localInitialized = false;
  final List<WatchlistStock> _localStocks = [];

  List<WatchlistStock> get _localList {
    if (!_localInitialized) {
      _localStocks.addAll(_dummyStocks);
      _localInitialized = true;
    }
    return _localStocks;
  }

  // ── 더미 데이터 ──────────────────────────────────────────

  static final List<WatchlistStock> _dummyStocks = [
    WatchlistStock(
      code: '005930',
      name: '삼성전자',
      weather: 'SUNNY',
      price: 72500,
      changeRate: 2.3,
      keyword: 'HBM',
      aiSummary: 'HBM 수요 증가로 반도체 실적 개선 기대감이 높아지고 있습니다.\n'
          '외국인 순매수가 3일 연속 이어지며 수급도 우호적입니다.\n'
          '목표주가 상향 리포트가 잇따르고 있어 긍정적 흐름입니다.',
    ),
    WatchlistStock(
      code: '000660',
      name: 'SK하이닉스',
      weather: 'SUNNY',
      price: 178000,
      changeRate: 1.8,
      keyword: 'AI반도체',
      aiSummary: 'AI 서버용 HBM3E 공급 확대로 분기 실적이 크게 개선되었습니다.\n'
          'NVIDIA향 매출 비중이 높아지며 수혜주로 주목받고 있습니다.\n'
          '글로벌 AI 투자 확대 기조에 따라 중장기 성장성이 부각됩니다.',
    ),
    WatchlistStock(
      code: '035420',
      name: 'NAVER',
      weather: 'CLOUDY',
      price: 215000,
      changeRate: -0.5,
      keyword: '검색광고',
      aiSummary: '검색 광고 매출은 안정적이나 성장률 둔화 우려가 있습니다.\n'
          '클라우드·커머스 사업 확장이 진행 중이나 수익성 개선은 미확인.\n'
          '하이퍼클로바X 상용화 일정에 따라 주가 변동 가능성이 있습니다.',
    ),
    WatchlistStock(
      code: '035720',
      name: '카카오',
      weather: 'RAINY',
      price: 41200,
      changeRate: -3.1,
      keyword: '규제리스크',
      aiSummary: '공정거래위 규제 이슈로 투자심리가 위축되고 있습니다.\n'
          '카카오톡 광고 수익은 견조하나 신사업 불확실성이 존재합니다.\n'
          '경영 리스크 해소 여부가 주가 반등의 핵심 변수입니다.',
    ),
    WatchlistStock(
      code: '006400',
      name: '삼성SDI',
      weather: 'CLOUDY',
      price: 385000,
      changeRate: 0.8,
      keyword: '전고체배터리',
      aiSummary: '전고체 배터리 양산 로드맵 발표로 기술력이 부각되었습니다.\n'
          '유럽 전기차 시장 둔화로 단기 실적은 보수적 전망입니다.\n'
          'BMW 등 프리미엄 고객사 확보가 중장기 성장 동력입니다.',
    ),
  ];

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
