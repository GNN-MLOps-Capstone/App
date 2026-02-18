// lib/screens/stock_detail_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/stock_api_service.dart';

enum ChartRange { day, week, month }
enum Sentiment { positive, negative }

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
  bool _isRefreshingSeries = false;
  static const Duration _seriesRefreshInterval = Duration(minutes: 5);

  // 천 단위 콤마 포맷
  static final _wonFormat = NumberFormat('#,###');

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
    if (_seriesCache.containsKey(range)) return _seriesCache[range]!;
    final rangeStr = _rangeToString(range);
    final series = await StockApiService.getSeries(widget.stockCode, range: rangeStr);
    _seriesCache[range] = series;
    return series;
  }

  /// Range 변경 시
  Future<void> _onRangeChanged(ChartRange newRange) async {
    if (!_isStockCodeValid) return;
    setState(() => _range = newRange);
    if (!_seriesCache.containsKey(newRange)) {
      setState(() => _loading = true);
      try {
        await _fetchSeries(newRange);
      } catch (e) {
        debugPrint('Series 로드 실패: $e');
      }
      if (mounted) setState(() => _loading = false);
    }
    unawaited(_refreshVisibleSeries());
  }

  /// 실시간 WebSocket 연결
  void _connectWebSocket() {
    if (!_isStockCodeValid) return;
    _wsConnection = StockApiService.connectRealtime(widget.stockCode);
    _wsConnection!.stream.listen(
      (price) {
        // 비정상 실시간 틱(0원)은 overview 값을 덮어쓰지 않도록 무시
        if (price.price <= 0) return;
        if (mounted) {
          setState(() => _realtimePrice = price);
        }
      },
      onError: (e) => debugPrint('[상세] WS 에러: $e'),
    );
  }

  void _startSeriesAutoRefresh() {
    _seriesRefreshTimer?.cancel();
    _seriesRefreshTimer = Timer.periodic(_seriesRefreshInterval, (_) {
      unawaited(_refreshVisibleSeries());
    });
  }

  void _stopSeriesAutoRefresh() {
    _seriesRefreshTimer?.cancel();
    _seriesRefreshTimer = null;
  }

  Future<void> _refreshVisibleSeries() async {
    if (!mounted || _isRefreshingSeries || !_isStockCodeValid) return;

    _isRefreshingSeries = true;
    try {
      final rangeStr = _rangeToString(_range);
      final latest = await StockApiService.getSeries(
        widget.stockCode,
        range: rangeStr,
        forceRefresh: true,
      );
      _seriesCache[_range] = latest;
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint('[상세] 시리즈 자동 갱신 실패 (${_rangeToString(_range)}): $e');
    } finally {
      _isRefreshingSeries = false;
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

  bool get _isUp => _currentChange >= 0;

  int get _currentOpen => _realtimePrice?.open ?? _overview?.open ?? 0;
  int get _currentHigh => _realtimePrice?.high ?? _overview?.high ?? 0;
  int get _currentLow => _realtimePrice?.low ?? _overview?.low ?? 0;
  int get _currentVolume => _realtimePrice?.volume ?? _overview?.volume ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: _buildAppBar(),
      bottomNavigationBar: _buildBottomNav(),
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
            Text(_error ?? '알 수 없는 오류', textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: invalidCode ? () => Navigator.maybePop(context) : _loadData,
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
    List<String> xLabels = [];

    if (series != null && series.points.isNotEmpty) {
      final prepared = _prepareChartData(series);
      chartPoints = prepared.points;
      xLabels = prepared.xLabels;
    }

    final finitePoints = chartPoints.where((v) => v.isFinite).toList();
    final allZero = finitePoints.isNotEmpty && finitePoints.every((v) => v == 0);
    if (allZero) {
      chartPoints = [];
      xLabels = [];
      finitePoints.clear();
    }

    final maxLabel = finitePoints.length >= 2
        ? '최고 ${_wonFormat.format(finitePoints.reduce(max).round())}원'
        : '';
    final minLabel = finitePoints.length >= 2
        ? '최저 ${_wonFormat.format(finitePoints.reduce(min).round())}원'
        : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 종목명 + 가격 헤더 ──
          _HeaderPriceSection(
            stockName: widget.stockName,
            priceText: '${_wonFormat.format(_currentPrice)}원',
            changeText: '${_currentChangeRate >= 0 ? "+" : ""}${_currentChangeRate.toStringAsFixed(2)}%',
            isUp: _isUp,
            sentiment: _isUp ? Sentiment.positive : Sentiment.negative,
          ),

          const SizedBox(height: 14),

          // ── 시세 정보 요약 카드 ──
          _buildOverviewCard(),

          const SizedBox(height: 14),

          // ── 차트 범위 선택 ──
          Row(
            children: [
              const Text('가격 추이',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              _RangeSelector(
                range: _range,
                onChanged: _onRangeChanged,
              ),
            ],
          ),
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
                            child: Text('장 마감 또는 데이터가 없습니다',
                                style: TextStyle(color: Colors.grey)))
                        : LineChartInteractive(
                            points: chartPoints,
                            xLabels: xLabels,
                            maxLabel: maxLabel,
                            minLabel: minLabel,
                            tooltipText: (idx) =>
                                '${_wonFormat.format(chartPoints[idx].round())}원',
                          ),
                  ),
          ),

          const SizedBox(height: 18),

          // ── AI 요약 (추후 API 연동 가능) ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI 요약',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                ..._buildAiSummary().map((line) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  ',
                              style: TextStyle(fontSize: 14)),
                          Expanded(
                              child: Text(line,
                                  style: const TextStyle(
                                      fontSize: 14, height: 1.3))),
                        ],
                      ),
                    )),
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
          _OverviewItem(label: '시가', value: '${_wonFormat.format(_currentOpen)}원'),
          _OverviewItem(label: '고가', value: '${_wonFormat.format(_currentHigh)}원',
              valueColor: Colors.red),
          _OverviewItem(label: '저가', value: '${_wonFormat.format(_currentLow)}원',
              valueColor: Colors.blue),
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
      xLabels: _buildXLabels(series),
    );
  }

  _PreparedChartData _buildDayTimelineChart(StockSeries series) {
    if (series.points.isEmpty) {
      return _PreparedChartData(points: const [], xLabels: const []);
    }

    const startHour = 8;
    const endHour = 20;
    const intervalMinutes = 5;
    const totalMinutes = (endHour - startHour) * 60;
    const slotCount = (totalMinutes ~/ intervalMinutes) + 1; // 08:00~20:00

    final sorted = [...series.points]..sort((a, b) => a.t.compareTo(b.t));
    final anchorDt = DateTime.fromMillisecondsSinceEpoch(sorted.last.t);
    final dayStart = DateTime(anchorDt.year, anchorDt.month, anchorDt.day, startHour);
    final dayEnd = DateTime(anchorDt.year, anchorDt.month, anchorDt.day, endHour);

    final points = List<double>.filled(slotCount, double.nan);

    for (final p in sorted) {
      final dt = DateTime.fromMillisecondsSinceEpoch(p.t);
      if (dt.year != dayStart.year || dt.month != dayStart.month || dt.day != dayStart.day) {
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
    if (now.year == dayStart.year && now.month == dayStart.month && now.day == dayStart.day) {
      final nowMinutes = now.difference(dayStart).inMinutes;
      final nowIdx = nowMinutes ~/ intervalMinutes;
      final startClear = (nowIdx + 1).clamp(0, slotCount);
      for (int i = startClear; i < slotCount; i++) {
        points[i] = double.nan;
      }
    }

    return _PreparedChartData(
      points: points,
      xLabels: const ['08:00', '10:00', '12:00', '14:00', '16:00', '18:00', '20:00'],
    );
  }

  /// X축 라벨 생성 (5~7개로 균등 분할)
  List<String> _buildXLabels(StockSeries series) {
    if (series.points.isEmpty) return [];

    final points = series.points;
    final n = points.length;

    // 표시할 라벨 수 (최대 7개)
    final labelCount = min(7, n);
    if (labelCount <= 1) {
      final dt = DateTime.fromMillisecondsSinceEpoch(points[0].t);
      return [_formatTime(dt)];
    }

    final labels = <String>[];
    for (int i = 0; i < labelCount; i++) {
      // 균등 분할 인덱스
      final idx = (i * (n - 1)) ~/ (labelCount - 1);
      final dt = DateTime.fromMillisecondsSinceEpoch(points[idx].t);
      labels.add(_formatTime(dt));
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
      '전일 대비 ${_currentChange >= 0 ? "상승" : "하락"} (${_currentChangeRate >= 0 ? "+" : ""}${_currentChangeRate.toStringAsFixed(2)}%)',
      '거래량 ${_wonFormat.format(_currentVolume)}주로 시장 참여가 ${_currentVolume > 100000 ? "활발" : "보통"}합니다.',
    ];
  }

  /// AI 태그 (현재는 더미)
  List<String> _buildAiTags() {
    final tags = <String>[];
    if (_isUp) {
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
        title:
            const Text('종목 상세', style: TextStyle(color: Colors.black)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: () {
                if (!_isStockCodeValid) {
                  Navigator.maybePop(context);
                  return;
                }
                _seriesCache.clear();
                _loadData();
                _startSeriesAutoRefresh();
              }),
          IconButton(
              icon:
                  const Icon(Icons.notifications_none, color: Colors.black),
              onPressed: () {}),
        ],
      );

  BottomNavigationBar _buildBottomNav() => BottomNavigationBar(
        currentIndex: 3,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          if (i == 3) return;
          if (i == 0) {
            Navigator.pushReplacementNamed(context, '/home');
          } else if (i == 2) {
            Navigator.pushReplacementNamed(context, '/news');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('아직 구현되지 않았습니다.')));
          }
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: '홈'),
          BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border), label: '관심'),
          BottomNavigationBarItem(
              icon: Icon(Icons.article_outlined), label: '뉴스'),
          BottomNavigationBarItem(
              icon: Icon(Icons.show_chart), label: '주식'),
        ],
      );
}

class _PreparedChartData {
  final List<double> points;
  final List<String> xLabels;

  const _PreparedChartData({
    required this.points,
    required this.xLabels,
  });
}

BoxDecoration _cardDeco() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    );

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
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87,
              )),
        ],
      ),
    );
  }
}

class _HeaderPriceSection extends StatelessWidget {
  final String stockName, priceText, changeText;
  final bool isUp;
  final Sentiment sentiment;

  const _HeaderPriceSection({
    required this.stockName,
    required this.priceText,
    required this.changeText,
    required this.isUp,
    required this.sentiment,
  });

  @override
  Widget build(BuildContext context) {
    final color = isUp ? Colors.red : Colors.blue;
    final arrow = isUp ? '▲' : '▼';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stockName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(priceText,
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2)),
              const SizedBox(height: 6),
              Text('$arrow $changeText',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ),
        Padding(
            padding: const EdgeInsets.only(top: 36),
            child: _SentimentBadge(sentiment: sentiment)),
      ],
    );
  }
}

class _SentimentBadge extends StatelessWidget {
  final Sentiment sentiment;
  const _SentimentBadge({required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final isPos = sentiment == Sentiment.positive;
    final icon = isPos ? Icons.wb_sunny : Icons.cloud;
    final label = isPos ? 'AI 긍정' : 'AI 부정';
    final accent =
        isPos ? const Color(0xFF22C55E) : const Color(0xFF64748B);

    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: accent.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, color: accent, size: 20),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
            borderRadius: BorderRadius.circular(12)),
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
              color: sel ? const Color(0xFFCBD5E1) : Colors.transparent),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.black : Colors.grey)),
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
            borderRadius: BorderRadius.circular(18)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      );
}

/* ==================== 차트 ==================== */

class LineChartInteractive extends StatefulWidget {
  final List<double> points;
  final List<String> xLabels;
  final String maxLabel, minLabel;
  final String Function(int) tooltipText;

  const LineChartInteractive({
    super.key,
    required this.points,
    required this.xLabels,
    required this.maxLabel,
    required this.minLabel,
    required this.tooltipText,
  });

  @override
  State<LineChartInteractive> createState() => _LineChartInteractiveState();
}

class _LineChartInteractiveState extends State<LineChartInteractive> {
  int? _idx;
  Offset? _pos;
  Timer? _timer;

  static const _pad = EdgeInsets.fromLTRB(10, 28, 10, 40);
  static const _scale = 0.72;
  static const _lift = 10.0;

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

  int? _nearestValidIndex(int idx) {
    if (_isValidPoint(idx)) return idx;
    for (int d = 1; d < widget.points.length; d++) {
      final left = idx - d;
      if (_isValidPoint(left)) return left;
      final right = idx + d;
      if (_isValidPoint(right)) return right;
    }
    return null;
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
    if (_idx != null && (_idx! < 0 || _idx! >= widget.points.length || !_isValidPoint(_idx!))) {
      _resetSelection();
    }
  }

  void _onTap(TapDownDetails d, Size sz) {
    final rect = Rect.fromLTWH(
        _pad.left, _pad.top, sz.width - _pad.horizontal, sz.height - _pad.vertical);
    if (!rect.contains(d.localPosition)) return _clear();

    final n = widget.points.length;
    if (n == 0) return;
    final valid = _validIndices();
    if (valid.isEmpty) return _clear();

    if (n == 1) {
      if (!_isValidPoint(0)) return _clear();
      return _show(0, Offset(rect.left + rect.width / 2, rect.top + rect.height / 2));
    }

    final dx = rect.width / (n - 1);
    final rawIdx = ((d.localPosition.dx - rect.left) / dx).round().clamp(0, n - 1);
    final idx = _nearestValidIndex(rawIdx);
    if (idx == null) return _clear();

    final validValues = valid.map((i) => widget.points[i]).toList();
    final mn = validValues.reduce(min), mx = validValues.reduce(max);
    final span = max(mx - mn, 1e-6);
    final h = rect.height * _scale;
    final top = max(0.0, (rect.height - h) / 2 - _lift);

    final x = rect.left + dx * idx;
    final y = rect.top + top + (1 - (widget.points[idx] - mn) / span) * h;

    _show(idx, Offset(x, y));
  }

  void _show(int i, Offset p) {
    setState(() {
      _idx = i;
      _pos = p;
    });
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 5), _clear);
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

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
        final sz = Size(c.maxWidth, c.maxHeight);
        final tooltipIdx = _idx;
        final hasValidTooltip = tooltipIdx != null &&
            _pos != null &&
            tooltipIdx >= 0 &&
            tooltipIdx < widget.points.length &&
            widget.points[tooltipIdx].isFinite;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (d) => _onTap(d, sz),
          child: Stack(
            children: [
              Positioned.fill(
                  child: Padding(
                      padding: _pad,
                      child:
                          CustomPaint(painter: _Painter(widget.points)))),
              if (_validIndices().length >= 2) ..._labels(sz),
              Positioned(
                  left: 0, right: 0, bottom: 0, child: _xLabels()),
              if (hasValidTooltip)
                _Tooltip(
                    anchor: _pos!,
                    text: widget.tooltipText(tooltipIdx),
                    maxW: sz.width),
            ],
          ),
        );
      });

  List<Widget> _labels(Size sz) {
    final n = widget.points.length;
    final valid = _validIndices();
    if (valid.length < 2) return const [];
    final rect = Rect.fromLTWH(_pad.left, _pad.top, sz.width - _pad.horizontal, sz.height - _pad.vertical);
    final dx = rect.width / (n - 1);

    final validValues = valid.map((i) => widget.points[i]).toList();
    final mn = validValues.reduce(min), mx = validValues.reduce(max);
    final span = max(mx - mn, 1e-6);
    final h = rect.height * _scale;
    final top = max(0.0, (rect.height - h) / 2 - _lift);

    int maxI = valid.first, minI = valid.first;
    for (final i in valid.skip(1)) {
      if (widget.points[i] > widget.points[maxI]) maxI = i;
      if (widget.points[i] < widget.points[minI]) minI = i;
    }

    final maxX = rect.left + dx * maxI;
    final maxY = rect.top + top + (1 - (widget.points[maxI] - mn) / span) * h;
    final minX = rect.left + dx * minI;
    final minY = rect.top + top + (1 - (widget.points[minI] - mn) / span) * h;

    const style = TextStyle(
        fontSize: 11,
        color: Color(0xFF3B82F6),
        fontWeight: FontWeight.w600);
    return [
      Positioned(
          left: maxX - 35,
          top: maxY - 20,
          child: Text(widget.maxLabel, style: style)),
      Positioned(
          left: minX - 35,
          top: minY + 10,
          child: Text(widget.minLabel, style: style)),
    ];
  }

  Widget _xLabels() {
    if (widget.xLabels.isEmpty) return const SizedBox();
    const style = TextStyle(fontSize: 10, color: Colors.grey);
    if (widget.xLabels.length == 1) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(widget.xLabels[0], style: style)));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children:
            widget.xLabels.map((t) => Text(t, style: style)).toList(),
      ),
    );
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
    canvas.drawLine(
        Offset(0, sz.height), Offset(sz.width, sz.height), axis);

    final valid = <int>[];
    for (int i = 0; i < points.length; i++) {
      if (points[i].isFinite) valid.add(i);
    }
    if (valid.isEmpty) return;

    if (points.length == 1 || valid.length == 1) {
      final idx = valid.first;
      final dx = points.length == 1 ? 0.0 : sz.width / (points.length - 1);
      final x = points.length == 1 ? sz.width / 2 : dx * idx;
      canvas.drawCircle(Offset(x, sz.height / 2), 6, Paint()..color = const Color(0xFF1D4ED8));
      return;
    }

    final validValues = valid.map((i) => points[i]).toList();
    final mn = validValues.reduce(min), mx = validValues.reduce(max);
    final span = max(mx - mn, 1e-6);
    final dx = sz.width / (points.length - 1);
    final h = sz.height * 0.72;
    final top = max(0.0, (sz.height - h) / 2 - 10);

    Offset pt(int i) =>
        Offset(dx * i, top + (1 - (points[i] - mn) / span) * h);

    final line = Paint()
      ..color = const Color(0xFF1D4ED8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = const Color(0xFF1D4ED8);

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

    for (final i in valid) {
      canvas.drawCircle(pt(i), 5, dot);
    }
  }

  @override
  bool shouldRepaint(_Painter old) => old.points != points;
}

class _Tooltip extends StatelessWidget {
  final Offset anchor;
  final String text;
  final double maxW;
  const _Tooltip(
      {required this.anchor, required this.text, required this.maxW});

  @override
  Widget build(BuildContext context) {
    const w = 90.0, h = 28.0, tail = 7.0;
    final left = (anchor.dx - w / 2).clamp(6.0, maxW - w - 6);
    final top = max(6.0, anchor.dy - h - tail - 8);
    final tailX = (anchor.dx - left).clamp(12.0, w - 12);

    return Positioned(
      left: left,
      top: top,
      child: CustomPaint(
        painter: _TooltipPainter(tailX, w, h, tail),
        child: SizedBox(
          width: w,
          height: h + tail,
          child: Padding(
            padding: const EdgeInsets.only(bottom: tail),
            child: Center(
              child: Text(text,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}

class _TooltipPainter extends CustomPainter {
  final double tailX, w, h, tail;
  _TooltipPainter(this.tailX, this.w, this.h, this.tail);

  @override
  void paint(Canvas canvas, Size sz) {
    final paint = Paint()..color = Colors.black.withOpacity(0.75);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, w, h), const Radius.circular(10)),
        paint);
    final path = Path()
      ..moveTo(tailX - 7, h)
      ..lineTo(tailX, h + tail)
      ..lineTo(tailX + 7, h)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TooltipPainter old) =>
      old.tailX != tailX || old.w != w || old.h != h || old.tail != tail;
}
