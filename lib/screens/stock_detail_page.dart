// lib/screens/stock_detail_page.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/stock_api_service.dart';

import 'widgets/bottom_nav_bar.dart';

enum ChartRange { day, week, month }
enum Sentiment { positive, neutral, negative }

class StockDetailPage extends StatefulWidget {
  final String stockName;
  final String stockCode; // 6자리 종목코드

  const StockDetailPage({
    super.key,
    required this.stockName,
    required this.stockCode,
  });

  @override
  State<StockDetailPage> createState() => _StockDetailPageState();
}

class _StockDetailPageState extends State<StockDetailPage> {
  ChartRange _range = ChartRange.day;
  static final RegExp _stockCodePattern = RegExp(r'^[A-Za-z0-9]{6}$');

  // 로딩 / 에러 상태
  bool _loading = true;
  String? _error;

  // API 데이터
  StockOverview? _overview;
  final Map<ChartRange, StockSeries> _seriesCache = {};

  // 실시간 WebSocket
  StockRealtimeConnection? _wsConnection;
  StockRealtimePrice? _realtimePrice;
  Timer? _seriesRefreshTimer;
  final Map<ChartRange, Future<StockSeries>> _seriesInFlight = {};
  int _rangeChangeSeq = 0;
  static const Duration _daySeriesRefreshInterval = Duration(seconds: 30);
  static const Duration _otherSeriesRefreshInterval = Duration(minutes: 5);
  static const Duration _seriesWarningSnackInterval = Duration(seconds: 60);
  static const String _seriesWarningMessage =
      '시세 그래프 최신 갱신에 실패했습니다. (서버 502 가능)';
  String? _seriesSyncWarning;
  DateTime? _lastSeriesWarnAt;

  // 천 단위 콤마 포맷
  static final _wonFormat = NumberFormat('#,###');
  static final DateFormat _tooltipDayFormat = DateFormat('MM/dd HH:mm');
  static final DateFormat _tooltipDateFormat = DateFormat('yyyy/MM/dd');

  @override
  void initState() {
    super.initState();
    if (!_isStockCodeValid) {
      _loading = false;
      _error = '유효하지 않은 종목코드입니다.\n(${widget.stockCode})';
      return;
    }
    _loadData();
    _connectWebSocket();
    _startSeriesAutoRefresh();
  }
  // ✅ 월간 급변 뉴스 펼침 상태
  bool _newsExpanded = false;

  // ✅ API 연동 시 수정 필요: dummy() → fromApi()로 변경
  late final vm = StockDetailViewModel.dummy(widget.stockName);

  void _onBottomTap(int index) {
    if (index == 3) return; // 현재 페이지

    const routes = ['/home', '/watchlist', '/news'];

    Navigator.pushNamedAndRemoveUntil(
      context,
      routes[index],
          (route) => false, // 모든 이전 스택 제거
    );
  }

  @override
  void dispose() {
    _stopSeriesAutoRefresh();
    _wsConnection?.close();
    super.dispose();
  }

  /// Overview + 현재 range의 Series를 동시에 불러옴
  Future<void> _loadData() async {
    if (!_isStockCodeValid) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '유효하지 않은 종목코드입니다.\n(${widget.stockCode})';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final overview = await StockApiService.getOverview(widget.stockCode);

      // series 실패가 overview 화면 전체를 막지 않도록 분리 처리
      try {
        await _fetchSeries(_range);
      } catch (e) {
        debugPrint('[상세] 초기 시리즈 로드 실패: $e');
        _setSeriesWarning(_seriesWarningMessage, showSnackBar: true);
      }

      if (!mounted) return;
      setState(() {
        _overview = overview;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '데이터를 불러올 수 없습니다.\n$e';
        _loading = false;
      });
    }
  }

  /// Series 데이터를 캐시 / 네트워크에서 가져옴
  Future<StockSeries> _fetchSeries(ChartRange range) async {
    return _requestSeries(range);
  }

  Future<StockSeries> _requestSeries(
    ChartRange range, {
    bool forceRefresh = false,
  }) {
    if (!forceRefresh && _seriesCache.containsKey(range)) {
      return Future.value(_seriesCache[range]!);
    }

    final inFlight = _seriesInFlight[range];
    if (inFlight != null) return inFlight;

    late final Future<StockSeries> future;
    future = (() async {
      final rangeStr = _rangeToString(range);
      final series = await StockApiService.getSeries(
        widget.stockCode,
        range: rangeStr,
        forceRefresh: forceRefresh,
      );
      _seriesCache[range] = series;
      _clearSeriesWarning();
      debugPrint(
        '[상세] series loaded range=${_rangeToString(range)} '
        'points=${series.points.length} force=$forceRefresh',
      );
      return series;
    })();

    _seriesInFlight[range] = future;
    unawaited(
      future.then<void>(
        (_) {
          if (identical(_seriesInFlight[range], future)) {
            _seriesInFlight.remove(range);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_seriesInFlight[range], future)) {
            _seriesInFlight.remove(range);
          }
        },
      ),
    );
    return future;
  }

  /// Range 변경 시
  Future<void> _onRangeChanged(ChartRange newRange) async {
    if (!_isStockCodeValid) return;
    if (newRange == _range) {
      unawaited(_refreshRange(newRange));
      return;
    }

    final seq = ++_rangeChangeSeq;
    setState(() => _range = newRange);
    _startSeriesAutoRefresh();
    final hasCache = _seriesCache.containsKey(newRange);
    if (!hasCache) {
      setState(() => _loading = true);
    }

    try {
      await _requestSeries(newRange);
    } catch (e) {
      debugPrint('Series 로드 실패(${_rangeToString(newRange)}): $e');
      _setSeriesWarning(_seriesWarningMessage, showSnackBar: true);
    } finally {
      if (mounted &&
          seq == _rangeChangeSeq &&
          _range == newRange &&
          !hasCache) {
        setState(() => _loading = false);
      }
    }

    if (!mounted || seq != _rangeChangeSeq || _range != newRange) return;
    unawaited(_refreshRange(newRange));
  }

  /// 실시간 WebSocket 연결
  void _connectWebSocket() {
    if (!_isStockCodeValid) return;
    _wsConnection = StockApiService.connectRealtime(widget.stockCode);
    _wsConnection!.stream.listen((price) {
      // 비정상 실시간 틱(0원)은 overview 값을 덮어쓰지 않도록 무시
      if (price.price <= 0) return;
      if (mounted) {
        setState(() => _realtimePrice = price);
      }
    }, onError: (e) => debugPrint('[상세] WS 에러: $e'));
  }

  void _startSeriesAutoRefresh() {
    _seriesRefreshTimer?.cancel();
    final interval = _range == ChartRange.day
        ? _daySeriesRefreshInterval
        : _otherSeriesRefreshInterval;
    _seriesRefreshTimer = Timer.periodic(interval, (_) {
      final targetRange = _range;
      unawaited(_refreshRange(targetRange));
    });
  }

  void _stopSeriesAutoRefresh() {
    _seriesRefreshTimer?.cancel();
    _seriesRefreshTimer = null;
  }

  void _clearSeriesWarning() {
    if (!mounted || _seriesSyncWarning == null) return;
    setState(() => _seriesSyncWarning = null);
  }

  void _setSeriesWarning(String message, {bool showSnackBar = false}) {
    if (!mounted) return;
    final now = DateTime.now();
    final shouldShowSnackBar =
        showSnackBar &&
        (_lastSeriesWarnAt == null ||
            now.difference(_lastSeriesWarnAt!) >= _seriesWarningSnackInterval);

    if (_seriesSyncWarning != message || shouldShowSnackBar) {
      setState(() {
        _seriesSyncWarning = message;
        if (shouldShowSnackBar) {
          _lastSeriesWarnAt = now;
        }
      });
    }

    if (shouldShowSnackBar) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _refreshRange(ChartRange range) async {
    if (!mounted || !_isStockCodeValid) return;
    try {
      final latest = await _requestSeries(range, forceRefresh: true);
      if (!mounted) return;
      if (_range == range) {
        setState(() {});
      }
      debugPrint(
        '[상세] series refresh requested=${_rangeToString(range)} '
        'applied=${_rangeToString(_range)} points=${latest.points.length}',
      );
    } catch (e) {
      debugPrint('[상세] 시리즈 자동 갱신 실패 (${_rangeToString(range)}): $e');
      _setSeriesWarning(_seriesWarningMessage, showSnackBar: true);
    }
  }

  String _rangeToString(ChartRange r) {
    switch (r) {
      case ChartRange.day:
        return '1d';
      case ChartRange.week:
        return '1w';
      case ChartRange.month:
        return '1m';
    }
  }

  // ─── 현재가 표시용 헬퍼 (실시간 > overview 우선) ───
  bool get _isStockCodeValid => _stockCodePattern.hasMatch(widget.stockCode);

  int get _currentPrice => _realtimePrice?.price ?? _overview?.lastPrice ?? 0;

  double get _currentChange => _realtimePrice?.change ?? _overview?.change ?? 0;

  double get _currentChangeRate =>
      _realtimePrice?.changeRate ?? _overview?.changeRate ?? 0;

  bool get _isUp => _currentChange > 0;
  bool get _isFlat => _currentChange == 0;

  int get _currentOpen => _realtimePrice?.open ?? _overview?.open ?? 0;
  int get _currentHigh => _realtimePrice?.high ?? _overview?.high ?? 0;
  int get _currentLow => _realtimePrice?.low ?? _overview?.low ?? 0;
  int get _currentVolume => _realtimePrice?.volume ?? _overview?.volume ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: _buildAppBar(),
      bottomNavigationBar: BottomNavBar(
        initialIndex: 3,
        onIndexChanged: _onBottomTap,
      ),
      body: SafeArea(
        child: _loading && _overview == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _overview == null
            ? _buildError()
            : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    final invalidCode = !_isStockCodeValid;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _error ?? '알 수 없는 오류',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: invalidCode
                  ? () => Navigator.maybePop(context)
                  : _loadData,
              child: Text(invalidCode ? '뒤로가기' : '재시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final series = _seriesCache[_range];
    List<double> chartPoints = [];
    List<XAxisLabelSpec> xAxisLabels = [];
    List<DateTime?> pointTimes = [];

    if (series != null && series.points.isNotEmpty) {
      final prepared = _prepareChartData(series);
      chartPoints = prepared.points;
      xAxisLabels = prepared.xAxisLabels;
      pointTimes = prepared.pointTimes;
    }

    final finitePoints = chartPoints.where((v) => v.isFinite).toList();
    final allZero =
        finitePoints.isNotEmpty && finitePoints.every((v) => v == 0);
    if (allZero) {
      chartPoints = [];
      xAxisLabels = [];
      pointTimes = [];
      finitePoints.clear();
    }

    final maxLabel = finitePoints.length >= 2
        ? '최고 ${_wonFormat.format(finitePoints.reduce(max).round())}원'
        : '';
    final minLabel = finitePoints.length >= 2
        ? '최저 ${_wonFormat.format(finitePoints.reduce(min).round())}원'
        : '';

    final stats = StockStats(
      open: '${_wonFormat.format(_currentOpen)}원',
      high: '${_wonFormat.format(_currentHigh)}원',
      low: '${_wonFormat.format(_currentLow)}원',
    );
    const monthlyNews = <MonthlyNewsItem>[];

    Widget statsAndNewsSection() {
      Widget collapsedRow() {
        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 118,
              child: _StatsCard(stats: stats),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MonthlyNewsCard(
                items: monthlyNews,
                expanded: false,
                onExpandedChanged: (v) => setState(() => _newsExpanded = v),
              ),
            ),
          ],
        );
        return IntrinsicHeight(child: row);
      }

      Widget expandedFullWidth() {
        return _MonthlyNewsCard(
          items: monthlyNews,
          expanded: true,
          onExpandedChanged: (v) => setState(() => _newsExpanded = v),
        );
      }

      return Column(
        children: [
          if (!_newsExpanded) collapsedRow(),
          if (_newsExpanded) expandedFullWidth(),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 종목명 + 가격 헤더 ──
          _HeaderPriceSection(
            stockName: widget.stockName,
            priceText: '${_wonFormat.format(_currentPrice)}원',
            changeText:
                '${_currentChangeRate >= 0 ? "+" : ""}${_currentChangeRate.toStringAsFixed(2)}%',
            isUp: _isUp,
            isFlat: _isFlat,
            sentiment: _isFlat ? Sentiment.neutral : (_isUp ? Sentiment.positive : Sentiment.negative),
          ),

          const SizedBox(height: 14),

          // ── 시세 정보 요약 카드 ──
          _buildOverviewCard(),

          const SizedBox(height: 14),

          // ── 차트 범위 선택 ──
          Row(
            children: [
              const Text(
                '가격 추이',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              _RangeSelector(range: _range, onChanged: _onRangeChanged),
            ],
          ),
          if (_seriesSyncWarning != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _seriesSyncWarning!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // ── 차트 카드 ──
          Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            decoration: _cardDeco(),
            child: _loading && series == null
                ? const SizedBox(
                    height: 210,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : SizedBox(
                    height: 210,
                    child: chartPoints.isEmpty
                        ? const Center(
                            child: Text(
                              '장 마감 또는 데이터가 없습니다',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : LineChartInteractive(
                            points: chartPoints,
                            xAxisLabels: xAxisLabels,
                            maxLabel: maxLabel,
                            minLabel: minLabel,
                            tooltipData: (idx) {
                              final hasTime =
                                  idx >= 0 && idx < pointTimes.length;
                              final headerText = hasTime
                                  ? _formatTooltipHeader(pointTimes[idx])
                                  : '';
                              final priceText =
                                  '${_wonFormat.format(chartPoints[idx].round())}원';
                              return TooltipInfo(
                                headerText: headerText,
                                priceText: priceText,
                              );
                            },
                          ),
                  ),
          ),
          
              const SizedBox(height: 14),
              statsAndNewsSection(),
          
          const SizedBox(height: 18),

          // ── AI 요약 (추후 API 연동 가능) ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI 요약',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ..._buildAiSummary().map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            line,
                            style: const TextStyle(fontSize: 14, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildAiTags()
                      .map((t) => _TagChip(text: t))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 시세 정보 카드 (시가/고가/저가/거래량)
  Widget _buildOverviewCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _cardDeco(),
      child: Row(
        children: [
          _OverviewItem(
            label: '시가',
            value: '${_wonFormat.format(_currentOpen)}원',
          ),
          _OverviewItem(
            label: '고가',
            value: '${_wonFormat.format(_currentHigh)}원',
            valueColor: Colors.red,
          ),
          _OverviewItem(
            label: '저가',
            value: '${_wonFormat.format(_currentLow)}원',
            valueColor: Colors.blue,
          ),
          _OverviewItem(label: '거래량', value: _wonFormat.format(_currentVolume)),
        ],
      ),
    );
  }

  _PreparedChartData _prepareChartData(StockSeries series) {
    if (_range == ChartRange.day) {
      return _buildDayTimelineChart(series);
    }
    return _PreparedChartData(
      points: series.points.map((p) => p.c.toDouble()).toList(),
      xAxisLabels: _buildXAxisLabels(series),
      pointTimes: series.points
          .map((p) => DateTime.fromMillisecondsSinceEpoch(p.t))
          .toList(),
    );
  }

  _PreparedChartData _buildDayTimelineChart(StockSeries series) {
    if (series.points.isEmpty) {
      return _PreparedChartData(
        points: const [],
        xAxisLabels: const [],
        pointTimes: const [],
      );
    }

    const startHour = 8;
    const endHour = 20;
    const intervalMinutes = 5;
    const totalMinutes = (endHour - startHour) * 60;
    const slotCount = (totalMinutes ~/ intervalMinutes) + 1; // 08:00~20:00

    final sorted = [...series.points]..sort((a, b) => a.t.compareTo(b.t));
    final anchorDt = DateTime.fromMillisecondsSinceEpoch(sorted.last.t);
    final dayStart = DateTime(
      anchorDt.year,
      anchorDt.month,
      anchorDt.day,
      startHour,
    );
    final dayEnd = DateTime(
      anchorDt.year,
      anchorDt.month,
      anchorDt.day,
      endHour,
    );

    final points = List<double>.filled(slotCount, double.nan);
    final pointTimes = List<DateTime?>.generate(
      slotCount,
      (i) => dayStart.add(Duration(minutes: i * intervalMinutes)),
    );

    for (final p in sorted) {
      final dt = DateTime.fromMillisecondsSinceEpoch(p.t);
      if (dt.year != dayStart.year ||
          dt.month != dayStart.month ||
          dt.day != dayStart.day) {
        continue;
      }
      if (dt.isBefore(dayStart) || dt.isAfter(dayEnd)) {
        continue;
      }
      final minutesFromStart = dt.difference(dayStart).inMinutes;
      final idx = minutesFromStart ~/ intervalMinutes;
      if (idx >= 0 && idx < slotCount) {
        points[idx] = p.c.toDouble();
      }
    }

    // 현재 시각 이후 구간은 NaN으로 유지하여 축만 보이고 라인은 미표시
    final now = DateTime.now();
    if (now.year == dayStart.year &&
        now.month == dayStart.month &&
        now.day == dayStart.day) {
      final nowMinutes = now.difference(dayStart).inMinutes;
      final nowIdx = nowMinutes ~/ intervalMinutes;
      final startClear = (nowIdx + 1).clamp(0, slotCount);
      for (int i = startClear; i < slotCount; i++) {
        points[i] = double.nan;
      }
    }

    return _PreparedChartData(
      points: points,
      xAxisLabels: const [
        XAxisLabelSpec(text: '08:00', pointIndex: 0),
        XAxisLabelSpec(text: '10:00', pointIndex: 24),
        XAxisLabelSpec(text: '12:00', pointIndex: 48),
        XAxisLabelSpec(text: '14:00', pointIndex: 72),
        XAxisLabelSpec(text: '16:00', pointIndex: 96),
        XAxisLabelSpec(text: '18:00', pointIndex: 120),
        XAxisLabelSpec(text: '20:00', pointIndex: 144),
      ],
      pointTimes: pointTimes,
    );
  }

  String _formatTooltipHeader(DateTime? dt) {
    if (dt == null) return '';
    if (_range == ChartRange.day) {
      return _tooltipDayFormat.format(dt);
    }
    return _tooltipDateFormat.format(dt);
  }

  /// X축 라벨 생성 (5~7개로 균등 분할)
  List<XAxisLabelSpec> _buildXAxisLabels(StockSeries series) {
    if (series.points.isEmpty) return [];

    final points = series.points;
    final n = points.length;

    // 표시할 라벨 수 (최대 7개)
    final labelCount = min(7, n);
    if (labelCount <= 1) {
      final dt = DateTime.fromMillisecondsSinceEpoch(points[0].t);
      return [XAxisLabelSpec(text: _formatTime(dt), pointIndex: 0)];
    }

    final labels = <XAxisLabelSpec>[];
    for (int i = 0; i < labelCount; i++) {
      // 균등 분할 인덱스
      final idx = (i * (n - 1)) ~/ (labelCount - 1);
      final dt = DateTime.fromMillisecondsSinceEpoch(points[idx].t);
      labels.add(XAxisLabelSpec(text: _formatTime(dt), pointIndex: idx));
    }
    return labels;
  }

  String _formatTime(DateTime dt) {
    if (_range == ChartRange.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}';
  }

  /// AI 요약 (현재는 더미, 추후 API 연동 가능)
  List<String> _buildAiSummary() {
    return [
      '${widget.stockName}의 현재가는 ${_wonFormat.format(_currentPrice)}원입니다.',
      '전일 대비 ${_isFlat ? "보합" : (_isUp ? "상승" : "하락")} (${_currentChangeRate > 0 ? "+" : ""}${_currentChangeRate.toStringAsFixed(2)}%)',
      '거래량 ${_wonFormat.format(_currentVolume)}주로 시장 참여가 ${_currentVolume > 100000 ? "활발" : "보통"}합니다.',
    ];
  }

  /// AI 태그 (현재는 더미)
  List<String> _buildAiTags() {
    final tags = <String>[];
    if (_isFlat) {
      tags.add('보합');
    } else if (_isUp) {
      tags.add('상승');
    } else {
      tags.add('하락');
    }
    if (_currentVolume > 500000) tags.add('거래활발');
    tags.add(widget.stockName);
    return tags;
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    leading: const BackButton(color: Colors.black),
    title: const Text('종목 상세', style: TextStyle(color: Colors.black)),
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh, color: Colors.black),
        onPressed: () {
          if (!_isStockCodeValid) {
            Navigator.maybePop(context);
            return;
          }
          _seriesCache.clear();
          _seriesInFlight.clear();
          _rangeChangeSeq++;
          _loadData();
          _startSeriesAutoRefresh();
        },
      ),
      IconButton(
        icon: const Icon(Icons.notifications_none, color: Colors.black),
        onPressed: () {},
      ),
    ],
  );
}

class _PreparedChartData {
  final List<double> points;
  final List<XAxisLabelSpec> xAxisLabels;
  final List<DateTime?> pointTimes;

  const _PreparedChartData({
    required this.points,
    required this.xAxisLabels,
    required this.pointTimes,
  });
}

class XAxisLabelSpec {
  final String text;
  final int pointIndex;

  const XAxisLabelSpec({required this.text, required this.pointIndex});
}

class TooltipInfo {
  final String headerText;
  final String priceText;

  const TooltipInfo({required this.headerText, required this.priceText});
}

BoxDecoration _cardDeco() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: const Color(0xFFE5E7EB)),
);

/* ==================== 데이터 모델 (API 연동 시 수정 필요) ==================== */

class StockDetailViewModel {
  final Map<ChartRange, StockDetailData> _data;
  StockDetailViewModel(this._data);
  StockDetailData dataFor(ChartRange r) => _data[r]!;

  factory StockDetailViewModel.dummy(String name) {
    final now = DateTime.now();
    final endHour = min(now.hour, 15);
    final _ = max(1, endHour - 8);

    final labels = List.generate(7, (i) => '${(i + 9).toString().padLeft(2, '0')}:00');
    final series = List.generate(labels.length, (i) => 74.0 + (i % 3) * 0.5 - 1.0 + (i * 0.2));

    return StockDetailViewModel({
      ChartRange.day: _mk(
        series,
        labels,
        '72,500원',
        '-1.2%',
        false,
        Sentiment.negative,
        const [
          'HBM3E 공급 계약 체결로 AI 반도체 시장에서 기대감 상승 중',
          '엔비디아와의 협력 강화로 2026년 상반기 대규모 납품 예정',
          '단기 조정에도 불구하고 중장기 펀더멘털은 견고한 상태',
        ],
        const ['HBM', '실적', '엔비디아'],
        const StockStats(open: '72,500', high: '75,980', low: '72,570'),
        const [
          MonthlyNewsItem(
            isUp: false,
            title: '미 연준의 금리 인상 우려로 인한 글로벌 기술주 약세',
            source: '(2026.02.19, 경제뉴스)',
          ),
          MonthlyNewsItem(
            isUp: true,
            title:
            '글로벌 빅테크 기업의 데이터센터 증설 발표에 급등. 차세대 메모리 공급 확대 기대감 반영, 장 초반 대비 거래량 급증하며 상승 탄력 확대.',
            source: '(2026.02.21, 파이낸스리포트)',
          ),
        ],
      ),
      ChartRange.week: _mk(
        [74.8, 75.9, 73.2, 75.1, 74.0, 72.9, 72.5],
        ['월', '화', '수', '목', '금', '토', '일'],
        '72,500원',
        '+0.4%',
        true,
        Sentiment.positive,
        const ['(더미)'],
        const ['더미'],
        const StockStats(open: '72,300', high: '75,900', low: '72,500'),
        const [],
      ),
      ChartRange.month: _mk(
        [70.0, 72.0, 71.5, 73.0, 72.5],
        ['1주차', '2주차', '3주차', '4주차', '5주차'],
        '72,500원',
        '+8.1%',
        true,
        Sentiment.positive,
        const ['(더미)'],
        const ['더미'],
        const StockStats(open: '70,100', high: '75,980', low: '69,800'),
        const [],
      ),
    });
  }

  static StockDetailData _mk(
      List<double> series,
      List<String> labels,
      String price,
      String change,
      bool isUp,
      Sentiment sentiment,
      List<String> summary,
      List<String> tags,
      StockStats stats,
      List<MonthlyNewsItem> monthlyNews,
      ) {
    String maxLbl = '', minLbl = '';
    if (series.isNotEmpty) {
      final mx = series.reduce(max), mn = series.reduce(min);
      maxLbl = '최고 ${_won(mx)}원';
      minLbl = '최저 ${_won(mn)}원';
    }

    return StockDetailData(
      price,
      change,
      isUp,
      sentiment,
      labels,
      series,
      maxLbl,
      minLbl,
      summary,
      tags,
      stats,
      monthlyNews,
    );
  }

  static String _won(double v) {
    final s = (v * 1000).round().toString();
    return s
        .split('')
        .reversed
        .toList()
        .asMap()
        .entries
        .map((e) => e.value + (e.key > 0 && e.key % 3 == 0 ? ',' : ''))
        .toList()
        .reversed
        .join('');
  }
}

class StockDetailData {
  final String priceText, changeText, maxLabel, minLabel;
  final bool isUp;
  final Sentiment sentiment;
  final List<String> xLabels, aiSummary, tags;
  final List<double> series;
  final StockStats stats;
  final List<MonthlyNewsItem> monthlyNews;

  final StockStats stats;
  final List<MonthlyNewsItem> monthlyNews;

  StockDetailData(
      this.priceText,
      this.changeText,
      this.isUp,
      this.sentiment,
      this.xLabels,
      this.series,
      this.maxLabel,
      this.minLabel,
      this.aiSummary,
      this.tags,
      this.stats,
      this.monthlyNews,
      );

  String tooltipFor(int i) => '${(series[i] * 1000).round()}원';
}

class StockStats {
  final String open;
  final String high;
  final String low;
  const StockStats({required this.open, required this.high, required this.low});
}

class MonthlyNewsItem {
  final bool isUp;
  final String title;
  final String source;
  const MonthlyNewsItem({required this.isUp, required this.title, required this.source});
}

/* ==================== UI 컴포넌트 ==================== */

class _OverviewItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _OverviewItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPriceSection extends StatelessWidget {
  final String stockName, priceText, changeText;
  final bool isUp;
  final bool isFlat;
  final Sentiment sentiment;

  const _HeaderPriceSection({
    required this.stockName,
    required this.priceText,
    required this.changeText,
    required this.isUp,
    this.isFlat = false,
    required this.sentiment,
  });

  @override
  Widget build(BuildContext context) {
    final color = isFlat ? Colors.grey : (isUp ? Colors.red : Colors.blue);
    final arrow = isFlat ? '─' : (isUp ? '▲' : '▼');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stockName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                priceText,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$arrow $changeText',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 36),
          child: _SentimentBadge(sentiment: sentiment),
        ),
      ],
    );
  }
}

class _SentimentBadge extends StatelessWidget {
  final Sentiment sentiment;
  const _SentimentBadge({required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;
    final Color accent;
    switch (sentiment) {
      case Sentiment.positive:
        icon = Icons.wb_sunny;
        label = 'AI 긍정';
        accent = const Color(0xFF22C55E);
      case Sentiment.neutral:
        icon = Icons.remove_circle_outline;
        label = 'AI 보합';
        accent = Colors.grey;
      case Sentiment.negative:
        icon = Icons.cloud;
        label = 'AI 부정';
        accent = const Color(0xFF64748B);
    }

    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _RangeSelector extends StatelessWidget {
  final ChartRange range;
  final ValueChanged<ChartRange> onChanged;
  const _RangeSelector({required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFEDEFF2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip('1일', ChartRange.day),
        const SizedBox(width: 6),
        _chip('1주', ChartRange.week),
        const SizedBox(width: 6),
        _chip('1달', ChartRange.month),
      ],
    ),
  );

  Widget _chip(String text, ChartRange r) {
    final sel = range == r;
    return GestureDetector(
      onTap: () => onChanged(r),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? Colors.white : const Color(0xFFEDEFF2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? const Color(0xFFCBD5E1) : Colors.transparent,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: sel ? Colors.black : Colors.grey,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.black : Colors.grey),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String text;
  const _TagChip({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFF22C55E),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/* ==================== ✅ 추가 UI: 시가/최고/최저 + 월간 급변 뉴스 ==================== */

class _StatsCard extends StatelessWidget {
  final StockStats stats;
  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    Widget row(String k, String v) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('$v원', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.1)),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          row('시가', stats.open),
          row('최고', stats.high),
          row('최저', stats.low),
        ],
      ),
    );
  }
}

class _MonthlyNewsCard extends StatelessWidget {
  final List<MonthlyNewsItem> items;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  const _MonthlyNewsCard({
    required this.items,
    required this.expanded,
    required this.onExpandedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final downs = items.where((e) => !e.isUp).toList();
    final ups = items.where((e) => e.isUp).toList();

    MonthlyNewsItem? preview;
    String previewPrefix = '';
    if (downs.isNotEmpty) {
      preview = downs.first;
      previewPrefix = '하락영향';
    } else if (ups.isNotEmpty) {
      preview = ups.first;
      previewPrefix = '상승영향';
    }

    // ✅ 펼침은 더 크게(세로)
    final constraints = expanded ? const BoxConstraints(minHeight: 280) : const BoxConstraints();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      constraints: constraints,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('월간 급변 뉴스', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onExpandedChanged(!expanded),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 22,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),

          if (!expanded) ...[
            const SizedBox(height: 6),
            if (preview == null)
              Text('월간 급변 뉴스가 없습니다.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: preview.isUp ? Colors.red : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$previewPrefix · ${preview.title}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, height: 1.25, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preview.source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],

          if (expanded) ...[
            const SizedBox(height: 10),
            if (downs.isNotEmpty) ...[
              const _GroupTitleInline(label: '하락영향', color: Colors.blue),
              const SizedBox(height: 6),
              ...downs.map((e) => _NewsLineExpanded(item: e)),
              const SizedBox(height: 12),
            ],
            if (ups.isNotEmpty) ...[
              const _GroupTitleInline(label: '상승영향', color: Colors.red),
              const SizedBox(height: 6),
              ...ups.map((e) => _NewsLineExpanded(item: e)),
            ],
            if (downs.isEmpty && ups.isEmpty)
              Text('월간 급변 뉴스가 없습니다.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }
}

class _GroupTitleInline extends StatelessWidget {
  final String label;
  final Color color;
  const _GroupTitleInline({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

class _NewsLineExpanded extends StatelessWidget {
  final MonthlyNewsItem item;
  const _NewsLineExpanded({required this.item});

  @override
  Widget build(BuildContext context) {
    final dotColor = item.isUp ? Colors.red : Colors.blue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, softWrap: true, style: const TextStyle(fontSize: 12, height: 1.35, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(item.source, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ==================== 차트 ==================== */

class LineChartInteractive extends StatefulWidget {
  final List<double> points;
  final List<XAxisLabelSpec> xAxisLabels;
  final String maxLabel, minLabel;
  final TooltipInfo Function(int) tooltipData;

  const LineChartInteractive({
    super.key,
    required this.points,
    required this.xAxisLabels,
    required this.maxLabel,
    required this.minLabel,
    required this.tooltipData,
  });

  @override
  State<LineChartInteractive> createState() => _LineChartInteractiveState();
}

class _LineChartInteractiveState extends State<LineChartInteractive> {
  int? _idx;
  Offset? _pos;
  Timer? _timer;
  final GlobalKey _chartStackKey = GlobalKey();
  double _chartGlobalLeft = 0.0;

  static const _pad = EdgeInsets.fromLTRB(10, 28, 10, 40);
  static const _scale = 0.72;
  static const _lift = 10.0;
  static const _xLabelBandHeight = 20.0;
  static const _screenTooltipPadding = 6.0;
  static const _tapTooltipDuration = Duration(seconds: 5);
  static const _dragTooltipDuration = Duration(seconds: 2);

  bool _isValidPoint(int i) {
    if (i < 0 || i >= widget.points.length) return false;
    return widget.points[i].isFinite;
  }

  List<int> _validIndices() {
    final out = <int>[];
    for (int i = 0; i < widget.points.length; i++) {
      if (_isValidPoint(i)) out.add(i);
    }
    return out;
  }

  _ChartGeometry? _buildChartGeometry(Size sz) {
    final n = widget.points.length;
    if (n == 0) return null;

    final valid = _validIndices();
    if (valid.isEmpty) return null;

    final rect = Rect.fromLTWH(
      _pad.left,
      _pad.top,
      sz.width - _pad.horizontal,
      sz.height - _pad.vertical,
    );

    if (n == 1 || valid.length == 1) {
      final idx = valid.first;
      final dx = n == 1 ? 0.0 : rect.width / (n - 1);
      final x = n == 1 ? rect.left + rect.width / 2 : rect.left + dx * idx;
      final y = rect.top + rect.height / 2;
      return _ChartGeometry(rect: rect, pointPositions: {idx: Offset(x, y)});
    }

    final validValues = valid.map((i) => widget.points[i]).toList();
    final mn = validValues.reduce(min);
    final mx = validValues.reduce(max);
    final span = max(mx - mn, 1e-6);
    final dx = rect.width / (n - 1);
    final h = rect.height * _scale;
    final top = max(0.0, (rect.height - h) / 2 - _lift);

    final pointPositions = <int, Offset>{};
    for (final i in valid) {
      final x = rect.left + dx * i;
      final y = rect.top + top + (1 - (widget.points[i] - mn) / span) * h;
      pointPositions[i] = Offset(x, y);
    }

    return _ChartGeometry(rect: rect, pointPositions: pointPositions);
  }

  void _selectNearestPoint(
    Offset localPosition,
    Size sz, {
    required Duration? hideAfter,
    required bool clearWhenOutside,
    required bool clampOutside,
  }) {
    final geometry = _buildChartGeometry(sz);
    if (geometry == null) {
      _clear();
      return;
    }

    if (!geometry.rect.contains(localPosition) && clearWhenOutside) {
      _clear();
      return;
    }

    final probe = clampOutside
        ? Offset(
            localPosition.dx
                .clamp(geometry.rect.left, geometry.rect.right)
                .toDouble(),
            localPosition.dy
                .clamp(geometry.rect.top, geometry.rect.bottom)
                .toDouble(),
          )
        : localPosition;

    final idx = geometry.nearestIndex(probe);
    if (idx == null) {
      _clear();
      return;
    }

    final point = geometry.pointPositions[idx];
    if (point == null) {
      _clear();
      return;
    }
    _show(idx, point, hideAfter: hideAfter);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LineChartInteractive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points.length != widget.points.length) {
      _resetSelection();
      return;
    }
    if (_idx != null &&
        (_idx! < 0 || _idx! >= widget.points.length || !_isValidPoint(_idx!))) {
      _resetSelection();
    }
  }

  void _onTap(TapDownDetails d, Size sz) {
    _selectNearestPoint(
      d.localPosition,
      sz,
      hideAfter: _tapTooltipDuration,
      clearWhenOutside: true,
      clampOutside: false,
    );
  }

  void _onHorizontalDragStart(DragStartDetails d, Size sz) {
    _selectNearestPoint(
      d.localPosition,
      sz,
      hideAfter: null,
      clearWhenOutside: false,
      clampOutside: true,
    );
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d, Size sz) {
    _selectNearestPoint(
      d.localPosition,
      sz,
      hideAfter: null,
      clearWhenOutside: false,
      clampOutside: true,
    );
  }

  void _onHorizontalDragEnd() {
    if (_idx == null || _pos == null) return;
    _timer?.cancel();
    _timer = Timer(_dragTooltipDuration, _clear);
  }

  void _show(int i, Offset p, {required Duration? hideAfter}) {
    setState(() {
      _idx = i;
      _pos = p;
    });
    _timer?.cancel();
    if (hideAfter != null) {
      _timer = Timer(hideAfter, _clear);
    }
  }

  void _clear() {
    setState(() {
      _idx = null;
      _pos = null;
    });
    _timer?.cancel();
  }

  void _resetSelection() {
    _timer?.cancel();
    _idx = null;
    _pos = null;
  }

  void _scheduleChartGlobalOffsetMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _chartStackKey.currentContext;
      if (context == null) return;
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      final nextLeft = renderObject.localToGlobal(Offset.zero).dx;
      if ((nextLeft - _chartGlobalLeft).abs() > 0.5) {
        setState(() => _chartGlobalLeft = nextLeft);
      }
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      _scheduleChartGlobalOffsetMeasure();
      final sz = Size(c.maxWidth, c.maxHeight);
      final viewportWidth = MediaQuery.sizeOf(context).width;
      final tooltipIdx = _idx;
      final hasValidTooltip =
          tooltipIdx != null &&
          _pos != null &&
          tooltipIdx >= 0 &&
          tooltipIdx < widget.points.length &&
          widget.points[tooltipIdx].isFinite;
      final tooltipInfo = hasValidTooltip
          ? widget.tooltipData(tooltipIdx)
          : null;
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (d) => _onTap(d, sz),
        onHorizontalDragStart: (d) => _onHorizontalDragStart(d, sz),
        onHorizontalDragUpdate: (d) => _onHorizontalDragUpdate(d, sz),
        onHorizontalDragEnd: (_) => _onHorizontalDragEnd(),
        onHorizontalDragCancel: _onHorizontalDragEnd,
        child: Stack(
          key: _chartStackKey,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Padding(
                padding: _pad,
                child: CustomPaint(painter: _Painter(widget.points)),
              ),
            ),
            if (_validIndices().length >= 2) ..._labels(sz),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _xLabelBandHeight,
              child: _xLabels(sz),
            ),
            if (hasValidTooltip && tooltipInfo != null)
              _Tooltip(
                anchor: _pos!,
                headerText: tooltipInfo.headerText,
                priceText: tooltipInfo.priceText,
                viewportWidth: viewportWidth,
                chartGlobalLeft: _chartGlobalLeft,
                screenPadding: _screenTooltipPadding,
              ),
          ],
        ),
      );
    },
  );

  List<Widget> _labels(Size sz) {
    final valid = _validIndices();
    if (valid.length < 2) return const [];
    final geometry = _buildChartGeometry(sz);
    if (geometry == null) return const [];

    int maxI = valid.first, minI = valid.first;
    for (final i in valid.skip(1)) {
      if (widget.points[i] > widget.points[maxI]) maxI = i;
      if (widget.points[i] < widget.points[minI]) minI = i;
    }

    final maxPos = geometry.pointPositions[maxI];
    final minPos = geometry.pointPositions[minI];
    if (maxPos == null || minPos == null) return const [];

    const style = TextStyle(
      fontSize: 11,
      color: Color(0xFF3B82F6),
      fontWeight: FontWeight.w600,
    );
    final maxPainter = TextPainter(
      text: TextSpan(text: widget.maxLabel, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final minPainter = TextPainter(
      text: TextSpan(text: widget.minLabel, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final graphRect = geometry.rect;
    final maxLeftLimit = max(
      graphRect.left,
      graphRect.right - maxPainter.width,
    );
    final minLeftLimit = max(
      graphRect.left,
      graphRect.right - minPainter.width,
    );
    final maxTopLimit = max(
      graphRect.top,
      graphRect.bottom - maxPainter.height,
    );
    final maxTopLowerBound = max(0.0, graphRect.top - maxPainter.height - 6);
    final minTopLimit = max(
      graphRect.top,
      graphRect.bottom - minPainter.height,
    );

    final maxLeft = (maxPos.dx - maxPainter.width / 2)
        .clamp(graphRect.left, maxLeftLimit)
        .toDouble();
    final maxTop = (maxPos.dy - maxPainter.height - 8)
        .clamp(maxTopLowerBound, maxTopLimit)
        .toDouble();
    final minLeft = (minPos.dx - minPainter.width / 2)
        .clamp(graphRect.left, minLeftLimit)
        .toDouble();
    final minTop = (minPos.dy + 4).clamp(graphRect.top, minTopLimit).toDouble();

    return [
      Positioned(
        left: maxLeft,
        top: maxTop,
        child: Text(widget.maxLabel, style: style),
      ),
      Positioned(
        left: minLeft,
        top: minTop,
        child: Text(widget.minLabel, style: style),
      ),
    ];
  }

  Widget _xLabels(Size sz) {
    if (widget.xAxisLabels.isEmpty || widget.points.isEmpty) {
      return const SizedBox();
    }
    final geometry = _buildChartGeometry(sz);
    if (geometry == null) return const SizedBox();

    const style = TextStyle(fontSize: 10, color: Colors.grey);
    final rect = geometry.rect;
    final n = widget.points.length;
    final dx = n <= 1 ? 0.0 : rect.width / (n - 1);

    final widgets = <Widget>[];
    for (final spec in widget.xAxisLabels) {
      if (spec.pointIndex < 0 || spec.pointIndex >= n) continue;
      final x = n == 1
          ? rect.left + rect.width / 2
          : rect.left + dx * spec.pointIndex;
      final painter = TextPainter(
        text: TextSpan(text: spec.text, style: style),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final maxLeft = max(0.0, sz.width - painter.width);
      final left = (x - painter.width / 2).clamp(0.0, maxLeft);
      widgets.add(
        Positioned(
          left: left.toDouble(),
          bottom: 0,
          child: Text(spec.text, style: style),
        ),
      );
    }
    return SizedBox.expand(child: Stack(children: widgets));
  }
}

class _Painter extends CustomPainter {
  final List<double> points;
  _Painter(this.points);

  @override
  void paint(Canvas canvas, Size sz) {
    if (points.isEmpty) return;

    final axis = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, sz.height), Offset(sz.width, sz.height), axis);

    final valid = <int>[];
    for (int i = 0; i < points.length; i++) {
      if (points[i].isFinite) valid.add(i);
    }
    if (valid.isEmpty) return;

    if (points.length == 1 || valid.length == 1) {
      final idx = valid.first;
      final dx = points.length == 1 ? 0.0 : sz.width / (points.length - 1);
      final x = points.length == 1 ? sz.width / 2 : dx * idx;
      canvas.drawCircle(
        Offset(x, sz.height / 2),
        6.0,
        Paint()..color = const Color(0xFF1D4ED8),
      );
      return;
    }

    final validValues = valid.map((i) => points[i]).toList();
    final mn = validValues.reduce(min), mx = validValues.reduce(max);
    final span = max(mx - mn, 1e-6);
    final dx = sz.width / (points.length - 1);
    final h = sz.height * 0.72;
    final top = max(0.0, (sz.height - h) / 2 - 10);

    Offset pt(int i) => Offset(dx * i, top + (1 - (points[i] - mn) / span) * h);

    final line = Paint()
      ..color = const Color(0xFF1D4ED8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final path = Path();
    bool started = false;
    for (int i = 0; i < points.length; i++) {
      if (!points[i].isFinite) {
        started = false;
        continue;
      }
      final p = pt(i);
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_Painter old) => old.points != points;
}

class _Tooltip extends StatelessWidget {
  final Offset anchor;
  final String headerText;
  final String priceText;
  final double viewportWidth;
  final double chartGlobalLeft;
  final double screenPadding;
  const _Tooltip({
    required this.anchor,
    required this.headerText,
    required this.priceText,
    required this.viewportWidth,
    required this.chartGlobalLeft,
    required this.screenPadding,
  });

  @override
  Widget build(BuildContext context) {
    const tail = 7.0;
    final hasHeader = headerText.isNotEmpty;
    final w = hasHeader ? 132.0 : 96.0;
    final h = hasHeader ? 46.0 : 28.0;
    final showBelow = anchor.dy - h - tail - 8 < 6;
    final localLeft = anchor.dx - w / 2;
    final globalLeft = chartGlobalLeft + localLeft;
    final maxGlobalLeft = max(screenPadding, viewportWidth - w - screenPadding);
    final clampedGlobalLeft = globalLeft
        .clamp(screenPadding, maxGlobalLeft)
        .toDouble();
    final left = clampedGlobalLeft - chartGlobalLeft;
    final top = showBelow ? anchor.dy + 8 : max(6.0, anchor.dy - h - tail - 8);
    final tailX = anchor.dx - left;

    return Positioned(
      left: left,
      top: top,
      child: CustomPaint(
        painter: _TooltipPainter(tailX, w, h, tail, tailOnTop: showBelow),
        child: SizedBox(
          width: w,
          height: h + tail,
          child: Padding(
            padding: showBelow
                ? const EdgeInsets.fromLTRB(8, tail + 6, 8, 6)
                : const EdgeInsets.fromLTRB(8, 6, 8, tail),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasHeader)
                  Text(
                    headerText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (hasHeader) const SizedBox(height: 2),
                Text(
                  priceText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TooltipPainter extends CustomPainter {
  final double tailX, w, h, tail;
  final bool tailOnTop;
  _TooltipPainter(
    this.tailX,
    this.w,
    this.h,
    this.tail, {
    required this.tailOnTop,
  });

  @override
  void paint(Canvas canvas, Size sz) {
    final paint = Paint()..color = Colors.black.withOpacity(0.75);
    final boxTop = tailOnTop ? tail : 0.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, boxTop, w, h),
        const Radius.circular(10),
      ),
      paint,
    );

    final path = Path();
    if (tailOnTop) {
      path
        ..moveTo(tailX - 7, tail)
        ..lineTo(tailX, 0)
        ..lineTo(tailX + 7, tail)
        ..close();
    } else {
      path
        ..moveTo(tailX - 7, h)
        ..lineTo(tailX, h + tail)
        ..lineTo(tailX + 7, h)
        ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TooltipPainter old) =>
      old.tailX != tailX ||
      old.w != w ||
      old.h != h ||
      old.tail != tail ||
      old.tailOnTop != tailOnTop;
}

class _ChartGeometry {
  final Rect rect;
  final Map<int, Offset> pointPositions;

  const _ChartGeometry({required this.rect, required this.pointPositions});

  int? nearestIndex(Offset target) {
    if (pointPositions.isEmpty) return null;
    int? nearest;
    double bestDistanceSquared = double.infinity;
    pointPositions.forEach((idx, point) {
      final dx = point.dx - target.dx;
      final dy = point.dy - target.dy;
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared < bestDistanceSquared) {
        bestDistanceSquared = distanceSquared;
        nearest = idx;
      }
    });
    return nearest;
  }
}

