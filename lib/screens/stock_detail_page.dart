// lib/screens/stock_detail_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'widgets/bottom_nav_bar.dart';
import 'stock_page.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

import '../services/stock_api_service.dart';

Widget _svgIcon(String name, {double size = 28, IconData fallback = Icons.image_outlined}) {
  return SvgPicture.asset(
    'assets/images/$name.svg',
    width: size, height: size,
    placeholderBuilder: (_) => Icon(fallback, color: _kGreen, size: size * 0.8),
  );
}

enum ChartRange { realtime, day, week, month }
enum Sentiment  { veryGood, good, neutral, bad, veryBad }

const _kGreen = Color(0xFF45C99C);
const _kRed   = Color(0xFFE63E3E); // ✅ 수정 2: 빨강 색상
const _kBlue  = Color(0xFF1E3CD6); // ✅ 수정 2: 파랑 색상
const _kBg    = Color(0xFFF2F5F6);
const _kTabBg = Color(0xFFE9ECF2);
const _kGrid  = Color(0xFFD3D3D3);
const _kTipBg = Color(0xFF83848B);

Widget _sentimentIcon(Sentiment s, {double size = 52}) {
  const paths  = ['급등.svg', '상승.svg', '보합.svg', '하락.svg', '급락.svg'];
  const icons  = [Icons.wb_sunny, Icons.wb_sunny_outlined, Icons.remove_circle_outline, Icons.cloud, Icons.thunderstorm_outlined];
  const colors = [Color(0xFFF59E0B), _kGreen, Colors.grey, Color(0xFF94A3B8), Color(0xFF64748B)];
  return SvgPicture.asset(
    'assets/images/${paths[s.index]}',
    width: size, height: size,
    placeholderBuilder: (_) => Container(
      width: size, height: size,
      decoration: BoxDecoration(color: colors[s.index].withOpacity(0.12), shape: BoxShape.circle),
      child: Icon(icons[s.index], color: colors[s.index], size: size * 0.55),
    ),
  );
}

List<String> _realtimeXLabels() {
  final now    = TimeOfDay.now();
  final labels = <String>[];
  for (int h = 9; h <= 15; h += 2) {
    if (h < now.hour || (h == now.hour && now.minute > 0)) {
      labels.add('${h.toString().padLeft(2, '0')}:00');
    } else if (h == now.hour) {
      labels.add('${h.toString().padLeft(2, '0')}:00');
      break;
    }
  }
  return labels.isEmpty ? ['09:00'] : labels;
}

// ════════════════════════════════════════════════
//  페이지
// ════════════════════════════════════════════════
class StockDetailPage extends StatefulWidget {
  final String stockName;
  final String stockCode;
  const StockDetailPage({super.key, required this.stockName, required this.stockCode});

  @override
  State<StockDetailPage> createState() => _StockDetailPageState();
}

class _StockDetailPageState extends State<StockDetailPage> {
  ChartRange _range = ChartRange.realtime;
  static final RegExp _stockCodePattern = RegExp(r'^[A-Za-z0-9]{6}$');

  bool _newsExpanded = false;

  bool    _loading = true;
  String? _error;

  StockOverview?                             _overview;
  final Map<ChartRange, StockSeries>         _seriesCache    = {};
  StockRealtimeConnection?                   _wsConnection;
  StockRealtimePrice?                        _realtimePrice;
  Timer?                                     _seriesRefreshTimer;
  final Map<ChartRange, Future<StockSeries>> _seriesInFlight = {};
  int _rangeChangeSeq = 0;

  static const Duration _daySeriesRefreshInterval   = Duration(seconds: 30);
  static const Duration _otherSeriesRefreshInterval = Duration(minutes: 5);
  static const Duration _seriesWarningSnackInterval = Duration(seconds: 60);
  static const String   _seriesWarningMessage =
      '시세 그래프 최신 갱신에 실패했습니다. (서버 502 가능)';
  String?   _seriesSyncWarning;
  DateTime? _lastSeriesWarnAt;

  static final _wonFormat          = NumberFormat('#,###');
  static final DateFormat _tooltipDayFormat  = DateFormat('MM/dd HH:mm');
  static final DateFormat _tooltipDateFormat = DateFormat('yyyy/MM/dd');

  @override
  void initState() {
    super.initState();
    if (!_isStockCodeValid) {
      _loading = false;
      _error   = '유효하지 않은 종목코드입니다.\n(${widget.stockCode})';
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

  void _onBottomTap(int index) {
    if (index == 3) return;
    const routes = ['/home', '/watchlist', '/news'];
    Navigator.pushNamedAndRemoveUntil(context, routes[index], (route) => false);
  }

  Future<void> _loadData() async {
    if (!_isStockCodeValid) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '유효하지 않은 종목코드입니다.\n(${widget.stockCode})'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final overview = await StockApiService.getOverview(widget.stockCode);
      try {
        await _fetchSeries(_range);
      } catch (e) {
        debugPrint('[상세] 초기 시리즈 로드 실패: $e');
        _setSeriesWarning(_seriesWarningMessage, showSnackBar: true);
      }
      if (!mounted) return;
      setState(() { _overview = overview; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '데이터를 불러올 수 없습니다.\n$e'; _loading = false; });
    }
  }

  Future<StockSeries> _fetchSeries(ChartRange range) async => _requestSeries(range);

  Future<StockSeries> _requestSeries(ChartRange range, {bool forceRefresh = false}) {
    if (!forceRefresh && _seriesCache.containsKey(range)) return Future.value(_seriesCache[range]!);
    final inFlight = _seriesInFlight[range];
    if (inFlight != null) return inFlight;

    late final Future<StockSeries> future;
    future = (() async {
      final series = await StockApiService.getSeries(
        widget.stockCode, range: _rangeToString(range), forceRefresh: forceRefresh,
      );
      _seriesCache[range] = series;
      _clearSeriesWarning();
      debugPrint('[상세] series loaded range=${_rangeToString(range)} points=${series.points.length} force=$forceRefresh');
      return series;
    })();

    _seriesInFlight[range] = future;
    unawaited(future.then<void>(
          (_)                               { if (identical(_seriesInFlight[range], future)) _seriesInFlight.remove(range); },
      onError: (Object e, StackTrace s) { if (identical(_seriesInFlight[range], future)) _seriesInFlight.remove(range); },
    ));
    return future;
  }

  Future<void> _onRangeChanged(ChartRange newRange) async {
    if (!_isStockCodeValid) return;
    if (newRange == _range) { unawaited(_refreshRange(newRange)); return; }
    final seq = ++_rangeChangeSeq;
    setState(() => _range = newRange);
    _startSeriesAutoRefresh();
    final hasCache = _seriesCache.containsKey(newRange);
    if (!hasCache) setState(() => _loading = true);
    try {
      await _requestSeries(newRange);
    } catch (e) {
      debugPrint('Series 로드 실패(${_rangeToString(newRange)}): $e');
      _setSeriesWarning(_seriesWarningMessage, showSnackBar: true);
    } finally {
      if (mounted && seq == _rangeChangeSeq && _range == newRange && !hasCache) {
        setState(() => _loading = false);
      }
    }
    if (!mounted || seq != _rangeChangeSeq || _range != newRange) return;
    unawaited(_refreshRange(newRange));
  }

  void _connectWebSocket() {
    if (!_isStockCodeValid) return;
    _wsConnection = StockApiService.connectRealtime(widget.stockCode);
    _wsConnection!.stream.listen(
          (price) { if (price.price <= 0) return; if (mounted) setState(() => _realtimePrice = price); },
      onError: (e) => debugPrint('[상세] WS 에러: $e'),
    );
  }

  void _startSeriesAutoRefresh() {
    _seriesRefreshTimer?.cancel();
    final interval = (_range == ChartRange.realtime || _range == ChartRange.day)
        ? _daySeriesRefreshInterval : _otherSeriesRefreshInterval;
    _seriesRefreshTimer = Timer.periodic(interval, (_) => unawaited(_refreshRange(_range)));
  }

  void _stopSeriesAutoRefresh() { _seriesRefreshTimer?.cancel(); _seriesRefreshTimer = null; }

  void _clearSeriesWarning() {
    if (!mounted || _seriesSyncWarning == null) return;
    setState(() => _seriesSyncWarning = null);
  }

  void _setSeriesWarning(String message, {bool showSnackBar = false}) {
    if (!mounted) return;
    final now        = DateTime.now();
    final shouldShow = showSnackBar && (_lastSeriesWarnAt == null ||
        now.difference(_lastSeriesWarnAt!) >= _seriesWarningSnackInterval);
    if (_seriesSyncWarning != message || shouldShow) {
      setState(() { _seriesSyncWarning = message; if (shouldShow) _lastSeriesWarnAt = now; });
    }
    if (shouldShow) {
      final m = ScaffoldMessenger.maybeOf(context);
      m?.hideCurrentSnackBar();
      m?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _refreshRange(ChartRange range) async {
    if (!mounted || !_isStockCodeValid) return;
    try {
      final latest = await _requestSeries(range, forceRefresh: true);
      if (!mounted) return;
      if (_range == range) setState(() {});
      debugPrint('[상세] series refresh requested=${_rangeToString(range)} applied=${_rangeToString(_range)} points=${latest.points.length}');
    } catch (e) {
      debugPrint('[상세] 시리즈 자동 갱신 실패 (${_rangeToString(range)}): $e');
      _setSeriesWarning(_seriesWarningMessage, showSnackBar: true);
    }
  }

  String _rangeToString(ChartRange r) {
    switch (r) {
      case ChartRange.realtime: return '1d';
      case ChartRange.day:      return '1d';
      case ChartRange.week:     return '1w';
      case ChartRange.month:    return '1m';
    }
  }

  bool   get _isStockCodeValid  => _stockCodePattern.hasMatch(widget.stockCode);
  int    get _currentPrice      => _realtimePrice?.price      ?? _overview?.lastPrice  ?? 0;
  double get _currentChange     => _realtimePrice?.change     ?? _overview?.change     ?? 0;
  double get _currentChangeRate => _realtimePrice?.changeRate ?? _overview?.changeRate ?? 0;
  bool   get _isUp   => _currentChange > 0;
  bool   get _isFlat => _currentChange == 0;
  int    get _currentOpen  => _realtimePrice?.open  ?? _overview?.open  ?? 0;
  int    get _currentHigh  => _realtimePrice?.high  ?? _overview?.high  ?? 0;
  int    get _currentLow   => _realtimePrice?.low   ?? _overview?.low   ?? 0;

  Sentiment get _sentiment {
    final r = _currentChangeRate;
    if (r >  3) return Sentiment.veryGood;
    if (r >  0) return Sentiment.good;
    if (r == 0) return Sentiment.neutral;
    if (r > -3) return Sentiment.bad;
    return Sentiment.veryBad;
  }

  _PreparedChartData _prepareChartData(StockSeries series) {
    if (_range == ChartRange.realtime || _range == ChartRange.day) {
      return _buildDayTimelineChart(series);
    }
    return _PreparedChartData(
      points:     series.points.map((p) => p.c.toDouble()).toList(),
      pointTimes: series.points.map((p) => DateTime.fromMillisecondsSinceEpoch(p.t)).toList(),
    );
  }

  _PreparedChartData _buildDayTimelineChart(StockSeries series) {
    if (series.points.isEmpty) return const _PreparedChartData(points: [], pointTimes: []);

    final sorted   = [...series.points]..sort((a, b) => a.t.compareTo(b.t));
    final anchor   = DateTime.fromMillisecondsSinceEpoch(sorted.last.t);
    final dayStart = DateTime(anchor.year, anchor.month, anchor.day, 9, 0);
    final dayEnd   = DateTime(anchor.year, anchor.month, anchor.day, 15, 30);

    final filtered = sorted.where((p) {
      final dt = DateTime.fromMillisecondsSinceEpoch(p.t);
      return dt.year  == dayStart.year  &&
          dt.month == dayStart.month &&
          dt.day   == dayStart.day   &&
          !dt.isBefore(dayStart)     &&
          !dt.isAfter(dayEnd);
    }).toList();

    final src = filtered.isNotEmpty ? filtered : sorted;
    return _PreparedChartData(
      points:     src.map((p) => p.c.toDouble()).toList(),
      pointTimes: src.map((p) => DateTime.fromMillisecondsSinceEpoch(p.t)).toList(),
    );
  }

  String _formatTooltipText(int idx, List<double> pts, List<DateTime?> times) {
    return '${_wonFormat.format(pts[idx].round())}원';
  }

  List<String> _xLabelsFor(ChartRange r, List<DateTime?> times) {
    if (times.isEmpty) return [];
    final n = times.length;
    final count = n < 4 ? n : 4;
    if (count <= 1) {
      final dt = times.first;
      return dt == null ? [] : [_fmtAxisTime(r, dt)];
    }
    final labels = <String>[];
    for (int i = 0; i < count; i++) {
      final idx = (i * (n - 1) ~/ (count - 1)).clamp(0, n - 1);
      final dt = times[idx];
      if (dt != null) labels.add(_fmtAxisTime(r, dt));
    }
    return labels;
  }

  String _fmtAxisTime(ChartRange r, DateTime dt) {
    if (r == ChartRange.realtime || r == ChartRange.day) {
      return '${dt.hour.toString().padLeft(2,"0")}:${dt.minute.toString().padLeft(2,"0")}';
    }
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('검색', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.black),
              onPressed: () {},
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.settings, color: Colors.black),
              onPressed: () {
                if (!_isStockCodeValid) { Navigator.maybePop(context); return; }
                _seriesCache.clear(); _seriesInFlight.clear(); _rangeChangeSeq++;
                _loadData(); _startSeriesAutoRefresh();
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        initialIndex: 3,
        onIndexChanged: _onBottomTap,
      ),
      body: SafeArea(
        child: _loading && _overview == null
            ? const Center(child: CircularProgressIndicator(color: _kGreen))
            : _error != null && _overview == null
            ? _buildError()
            : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    final invalid = !_isStockCodeValid;
    return Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.grey),
        const SizedBox(height: 16),
        Text(_error ?? '알 수 없는 오류', textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: invalid ? () => Navigator.maybePop(context) : _loadData,
          child: Text(invalid ? '뒤로가기' : '재시도'),
        ),
      ]),
    ));
  }

  Widget _buildContent() {
    final series = _seriesCache[_range];
    List<double>    chartPts = [];
    List<DateTime?> times    = [];

    if (series != null && series.points.isNotEmpty) {
      final p = _prepareChartData(series);
      chartPts = p.points; times = p.pointTimes;
    }

    final finite  = chartPts.where((v) => v.isFinite).toList();
    final allZero = finite.isNotEmpty && finite.every((v) => v == 0);
    if (allZero) { chartPts = []; times = []; finite.clear(); }

    final maxLabel = finite.length >= 2 ? '최고 ${_wonFormat.format(finite.reduce(max).round())}원' : '';
    final minLabel = finite.length >= 2 ? '최저 ${_wonFormat.format(finite.reduce(min).round())}원' : '';

    // ✅ 수정 1,2,3: 주식명/가격/변동 글씨 크기 및 색상, SVG 화살표 적용
    final changeColor = _isFlat ? Colors.grey : (_isUp ? _kRed : _kBlue);
    final changeAmountText = '${_isUp ? "+" : "-"}${_wonFormat.format(_currentChange.abs().round())}원';
    final changeRateText   = '${_isUp ? "+" : ""}${_currentChangeRate.toStringAsFixed(1)}%  ($changeAmountText)';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SearchBar(),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ✅ 수정 1: 주식명 fontSize 25
            Text(widget.stockName,
                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            // ✅ 수정 1: 가격 fontSize 35
            Text('${_wonFormat.format(_currentPrice)}원',
                style: const TextStyle(fontSize: 35, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            // ✅ 수정 1,2,3: 변동 fontSize 15, 색상 변경, SVG 화살표
            if (_isFlat)
              Text('보합', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey))
            else
              Row(children: [
                // ✅ 수정 3: 상승/하락 SVG 화살표
                SvgPicture.asset(
                  _isUp
                      ? 'assets/images/up_arrow.svg'
                      : 'assets/images/down_arrow.svg',
                  width: 10, height: 10,
                  colorFilter: ColorFilter.mode(changeColor, BlendMode.srcIn),
                  placeholderBuilder: (_) => Icon(
                    _isUp ? Icons.arrow_upward : Icons.arrow_downward,
                    color: changeColor, size: 14,
                  ),
                ),
                const SizedBox(width: 3),
                Text(changeRateText,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: changeColor)),
              ]),
          ])),
          _sentimentIcon(_sentiment),
        ]),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerRight,
            child: _RangeTab(range: _range, onChanged: _onRangeChanged)),
        const SizedBox(height: 6),
        if (_seriesSyncWarning != null) ...[
          Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFB45309)),
            const SizedBox(width: 4),
            Expanded(child: Text(_seriesSyncWarning!,
                style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)))),
          ]),
          const SizedBox(height: 4),
        ],
        _ChartBox(
          isLoading: _loading && series == null,
          chartPts: chartPts, times: times,
          maxLabel: maxLabel, minLabel: minLabel,
          xLabels: _xLabelsFor(_range, times),
          tooltipFor: (idx) => _formatTooltipText(idx, chartPts, times),
        ),
        const SizedBox(height: 10),
        _StatsRow(
          open: _wonFormat.format(_currentOpen),
          high: _wonFormat.format(_currentHigh),
          low:  _wonFormat.format(_currentLow),
        ),
        const SizedBox(height: 12),
        _AiSummaryCard(lines: const [
          'HBM3E 공급 계약 체결로 인해 AI 반도체 시장 내 기대감이 높아지고 있으며, 특히 엔비디아와의 협력이 강화되면서 2026년 상반기 대규모 납품이 예정되어 있다.',
          '이에 따라 단기적인 주가 조정 가능성은 존재하지만, 중장기적으로는 견고한 펀더멘털을 바탕으로 안정적인 성장 흐름이 이어질 것으로 전망된다.',
        ]),
        const SizedBox(height: 12),
        _BreakingNewsCard(
          items: const [
            BreakingNewsItem(isUp: false, title: '미 연준의 금리 인상 우려로 인한 글로벌 기술주 약세',  source: '(2026.02.19, 경제뉴스)'),
            BreakingNewsItem(isUp: false, title: '美 반도체 장비 수출 규제 강화 가능성 제기',         source: '(2026.02.19, 글로벌경제)'),
            BreakingNewsItem(isUp: true,  title: 'AI 서버 투자 확대... HBM 수요 급증 전망',         source: '(2026.02.19, 산업뉴스)'),
            BreakingNewsItem(isUp: true,  title: '삼성전자, 차세대 메모리 양산 계획 발표',           source: '(2026.02.19, 전자신문)'),
          ],
          expanded: _newsExpanded,
          onToggle: () => setState(() => _newsExpanded = !_newsExpanded),
        ),
        const SizedBox(height: 14),
        _KeywordCard(stockName: widget.stockName, tags: const [
          TagItem(label: 'HBM3E',    relevance: 0.93, rank: 1),
          TagItem(label: 'AI반도체', relevance: 0.76, rank: 2),
          TagItem(label: '엔비디아', relevance: 0.56, rank: 3),
          TagItem(label: 'GPU',      relevance: 0.36, rank: 4),
          TagItem(label: '삼성전자', relevance: 0.28, rank: 5),
          TagItem(label: 'TSMC',     relevance: 0.21, rank: 6),
          TagItem(label: '파운드리', relevance: 0.15, rank: 7),
          TagItem(label: 'DDR5',     relevance: 0.10, rank: 8),
        ]),
        const SizedBox(height: 12),
        _RelatedSection(stockName: widget.stockName, related: const [
          RelatedStock(name: 'SK 하이닉스',  logoText: 'SK',  logoColor: Color(0xFFEA3323)),
          RelatedStock(name: '이수페타시스', logoText: 'ISU', logoColor: Color(0xFF005BAC)),
          RelatedStock(name: '엔비디아',     logoText: 'N',   logoColor: Color(0xFF76B900)),
        ]),
      ]),
    );
  }
}

// ════════════════════════════════════════════════
//  내부 데이터 클래스
// ════════════════════════════════════════════════
class _PreparedChartData {
  final List<double>    points;
  final List<DateTime?> pointTimes;
  const _PreparedChartData({required this.points, required this.pointTimes});
}

// ════════════════════════════════════════════════
//  UI 컴포넌트
// ════════════════════════════════════════════════
class _SearchBar extends StatefulWidget {
  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  static final RegExp _shortCodePattern = RegExp(r'^[0-9A-Z]{6}$');
  static final RegExp _isuCdPattern = RegExp(r'^KR[0-9A-Z]{10}$');
  List<StockItem> _allStocks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCsv();
  }

  Future<void> _loadCsv() async {
    try {
      final raw = await rootBundle.loadString('lib/screens/name.csv');
      final normalizedRaw = raw.replaceFirst('\uFEFF', '');
      final lines = const LineSplitter().convert(normalizedRaw);
      final parsed = <StockItem>[];
      for (int i = 0; i < lines.length; i++) {
        final t = lines[i].trim();
        if (t.isEmpty) continue;
        final lower = t.toLowerCase();
        if (i == 0 && lower.contains('name') && lower.contains('isu_cd')) continue;
        final cols = t.split(',');
        if (cols.length < 3) continue;
        final name = cols[0].trim();
        final isuCd = cols[2].trim();
        final explicitCode = cols.length >= 4 ? cols[3].trim().toUpperCase() : '';
        final code = _shortCodePattern.hasMatch(explicitCode)
            ? explicitCode : _toShortCode(isuCd);
        if (name.isEmpty || code == null) continue;
        parsed.add(StockItem(name: name, code: code));
      }
      if (!mounted) return;
      setState(() { _allStocks = parsed; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String? _toShortCode(String isuCd) {
    final n = isuCd.trim().toUpperCase();
    if (_shortCodePattern.hasMatch(n)) return n;
    if (_isuCdPattern.hasMatch(n)) return n.substring(3, 9);
    return null;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockSearchPage(
          allStocks: _allStocks,
          loading: _loading,
        ),
      ),
    ),
    child: Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0F3),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        Icon(Icons.search, color: Colors.grey.shade500, size: 20),
        const SizedBox(width: 8),
        const Text('종목을 검색하세요',
            style: TextStyle(color: Colors.black87, fontSize: 15)),
      ]),
    ),
  );
}

class _RangeTab extends StatelessWidget {
  final ChartRange range; final ValueChanged<ChartRange> onChanged;
  const _RangeTab({required this.range, required this.onChanged});
  static const _items = [
    (ChartRange.realtime,'실시간'),(ChartRange.day,'1일'),
    (ChartRange.week,'1주'),(ChartRange.month,'1개월'),
  ];
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: _kTabBg, borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: _items.map((e) {
      final sel = range == e.$1;
      return GestureDetector(
        onTap: () => onChanged(e.$1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(e.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: sel ? Colors.black : Colors.grey.shade500)),
        ),
      );
    }).toList()),
  );
}

class _ChartBox extends StatelessWidget {
  final bool isLoading; final List<double> chartPts; final List<DateTime?> times;
  final String maxLabel, minLabel; final List<String> xLabels;
  final String Function(int) tooltipFor;
  const _ChartBox({required this.isLoading, required this.chartPts, required this.times,
    required this.maxLabel, required this.minLabel, required this.xLabels, required this.tooltipFor});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
    decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB))),
    child: SizedBox(height: 200,
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: _kGreen))
            : chartPts.isEmpty
            ? const Center(child: Text('장 마감 또는 데이터가 없습니다', style: TextStyle(color: Colors.grey)))
            : ClipRect(
            child: _SmoothChart(pts: chartPts, maxLabel: maxLabel, minLabel: minLabel,
                xLabels: xLabels, tooltipFor: tooltipFor))),
  );
}

class _SmoothChart extends StatefulWidget {
  final List<double> pts; final String maxLabel, minLabel;
  final List<String> xLabels; final String Function(int) tooltipFor;
  const _SmoothChart({required this.pts, required this.maxLabel, required this.minLabel,
    required this.xLabels, required this.tooltipFor});
  @override State<_SmoothChart> createState() => _SmoothChartState();
}

class _SmoothChartState extends State<_SmoothChart> {
  int?   _idx;
  Size?  _sz;
  Timer? _hideTimer;
  static const _pad = EdgeInsets.fromLTRB(4, 28, 4, 24);

  @override
  void dispose() { _hideTimer?.cancel(); super.dispose(); }

  Offset _pt(int i, Size sz) {
    final pts    = widget.pts;
    final finite = pts.where((v) => v.isFinite).toList();
    final mn     = finite.isEmpty ? 0.0 : finite.reduce(min);
    final mx     = finite.isEmpty ? 1.0 : finite.reduce(max);
    final rw     = sz.width  - _pad.horizontal;
    final rh     = (sz.height - _pad.vertical) * 0.80;
    final topOff = (sz.height - _pad.vertical - rh) / 2;
    final val    = pts[i].isFinite ? pts[i] : mn;
    return Offset(_pad.left + rw / (pts.length - 1) * i,
        _pad.top + topOff + (1 - (val - mn) / max(mx - mn, 1e-6)) * rh);
  }

  int _idxFromX(double dx, Size sz) {
    final n = widget.pts.length; if (n < 2) return 0;
    return ((dx - _pad.left) / ((sz.width - _pad.horizontal) / (n - 1)))
        .round().clamp(0, n - 1);
  }

  void _select(double dx, Size sz, {bool startHideTimer = false}) {
    final idx = _idxFromX(dx, sz);
    setState(() => _idx = idx);
    _hideTimer?.cancel();
    if (startHideTimer) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _idx = null);
      });
    }
  }

  void _clearWithDelay() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _idx = null);
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
    _sz = Size(c.maxWidth, c.maxHeight);
    final sz = _sz!;
    final pts = widget.pts; final n = pts.length;
    int maxI = 0, minI = 0;
    for (int i = 1; i < n; i++) { if (pts[i] > pts[maxI]) maxI = i; if (pts[i] < pts[minI]) minI = i; }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (d) => _select(d.localPosition.dx, sz, startHideTimer: true),
      onHorizontalDragStart:  (d) { _hideTimer?.cancel(); _select(d.localPosition.dx, sz); },
      onHorizontalDragUpdate: (d) => _select(d.localPosition.dx, sz),
      onHorizontalDragEnd:    (_) => _clearWithDelay(),
      onHorizontalDragCancel: ()  => _clearWithDelay(),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _CurvePainter(pts, _idx))),
        Positioned.fill(child: _greenTag(sz, maxI, widget.maxLabel, above: true)),
        Positioned.fill(child: _greenTag(sz, minI, widget.minLabel, above: false)),
        Positioned(left: _pad.left, right: _pad.right, bottom: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: widget.xLabels.map((t) =>
                    SizedBox(
                      width: 36,
                      child: Text(t,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        overflow: TextOverflow.clip,
                        maxLines: 1,
                      ),
                    )).toList())),
        if (_idx != null)
          _TooltipBubble(anchor: _pt(_idx!, sz), text: widget.tooltipFor(_idx!), maxW: sz.width),
      ]),
    );
  });

  Widget _greenTag(Size sz, int i, String label, {required bool above}) {
    if (label.isEmpty) return const SizedBox();
    final p = _pt(i, sz); final top = above ? p.dy - 26 : p.dy + 6;
    final left = (p.dx - 48).clamp(0.0, sz.width - 100.0);
    return Positioned(left: left, top: top,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: _kGreen, borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        ));
  }
}

class _CurvePainter extends CustomPainter {
  final List<double> pts; final int? activeIdx;
  static const _pad = EdgeInsets.fromLTRB(4, 28, 4, 24);
  _CurvePainter(this.pts, this.activeIdx);

  @override
  void paint(Canvas canvas, Size sz) {
    if (pts.length < 2) return;
    final finite = pts.where((v) => v.isFinite).toList();
    if (finite.isEmpty) return;
    final mn   = finite.reduce(min); final mx = finite.reduce(max);
    final span = max(mx - mn, 1e-6);
    final rw     = sz.width  - _pad.horizontal;
    final rh     = (sz.height - _pad.vertical) * 0.80;
    final topOff = (sz.height - _pad.vertical - rh) / 2;
    final dx     = rw / (pts.length - 1);
    Offset pt(int i) => Offset(_pad.left + dx * i,
        _pad.top + topOff + (1 - (pts[i] - mn) / span) * rh);

    final dash = Paint()..color = _kGrid..strokeWidth = 0.8;
    for (int r = 1; r <= 3; r++) {
      final y = _pad.top + topOff + rh * r / 3; double x = _pad.left;
      while (x < sz.width - _pad.right) { canvas.drawLine(Offset(x, y), Offset(x + 4, y), dash); x += 8; }
    }

    final path = Path();
    bool started = false; int? prev;
    for (int i = 0; i < pts.length; i++) {
      if (!pts[i].isFinite) { started = false; prev = null; continue; }
      if (!started) { path.moveTo(pt(i).dx, pt(i).dy); started = true; }
      else {
        final a = pt(prev!); final b = pt(i); final cx = (a.dx + b.dx) / 2;
        path.cubicTo(cx, a.dy, cx, b.dy, b.dx, b.dy);
      }
      prev = i;
    }
    if (!started) return;

    final firstValid = pts.indexWhere((v) => v.isFinite);
    final lastValid  = pts.lastIndexWhere((v) => v.isFinite);
    final bottom = _pad.top + topOff + rh;
    canvas.drawPath(
      Path.from(path)
        ..lineTo(pt(lastValid).dx,  bottom)
        ..lineTo(pt(firstValid).dx, bottom)
        ..close(),
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [_kGreen.withOpacity(0.15), _kGreen.withOpacity(0.01)],
      ).createShader(Rect.fromLTWH(0, _pad.top, sz.width, rh + topOff)),
    );

    canvas.drawPath(path, Paint()..color = _kGreen..strokeWidth = 2.2..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    int maxI = 0, minI = 0;
    for (int i = 1; i < pts.length; i++) {
      if (pts[i].isFinite && pts[i] > pts[maxI]) maxI = i;
      if (pts[i].isFinite && pts[i] < pts[minI]) minI = i;
    }
    for (final idx in [maxI, minI]) {
      if (!pts[idx].isFinite) continue;
      final p = pt(idx);
      canvas.drawCircle(p, 3, Paint()..color = _kGreen);
    }

    if (activeIdx != null && pts[activeIdx!].isFinite) {
      final p = pt(activeIdx!);
      canvas.drawCircle(p, 7, Paint()..color = _kGreen.withOpacity(0.2));
      canvas.drawCircle(p, 4, Paint()..color = _kGreen);
      canvas.drawCircle(p, 2, Paint()..color = _kGreen);
    }
  }
  @override bool shouldRepaint(_CurvePainter o) => o.activeIdx != activeIdx || o.pts != pts;
}

class _TooltipBubble extends StatelessWidget {
  final Offset anchor; final String text; final double maxW;
  const _TooltipBubble({required this.anchor, required this.text, required this.maxW});
  @override
  Widget build(BuildContext context) {
    const w = 84.0, h = 26.0, tail = 6.0;
    final left = (anchor.dx - w / 2).clamp(4.0, maxW - w - 4);
    final top  = max(4.0, anchor.dy - h - tail - 4);
    final tx   = (anchor.dx - left).clamp(10.0, w - 10.0);
    return Positioned(left: left, top: top,
        child: CustomPaint(painter: _BubblePainter(tx),
            child: SizedBox(width: w, height: h + tail,
                child: Padding(padding: const EdgeInsets.only(bottom: tail),
                    child: Center(child: Text(text,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)))))));
  }
}

class _BubblePainter extends CustomPainter {
  final double tx; _BubblePainter(this.tx);
  static const w = 84.0, h = 26.0, tail = 6.0;
  @override
  void paint(Canvas canvas, Size _) {
    final p = Paint()..color = _kTipBg;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(8)), p);
    canvas.drawPath(Path()..moveTo(tx-6,h)..lineTo(tx,h+tail)..lineTo(tx+6,h)..close(), p);
  }
  @override bool shouldRepaint(_BubblePainter o) => o.tx != tx;
}

class _StatsRow extends StatelessWidget {
  final String open, high, low;
  const _StatsRow({required this.open, required this.high, required this.low});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _s('시가', open), _s('최고', high), _s('최저', low),
    ]),
  );
  Widget _s(String k, String v) => Row(children: [
    Text('$k  ', style: const TextStyle(fontSize: 15, color: Colors.black)),
    Text(v, style: const TextStyle(fontSize: 15)),
  ]);
}

class _AiSummaryCard extends StatefulWidget {
  final List<String> lines;
  const _AiSummaryCard({required this.lines});
  @override State<_AiSummaryCard> createState() => _AiSummaryCardState();
}
class _AiSummaryCardState extends State<_AiSummaryCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final text = _expanded ? widget.lines.join(' ') : widget.lines[0];
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      GestureDetector(onTap: () => setState(() => _expanded = !_expanded),
          child: Text(_expanded ? '접기' : '더보기', style: const TextStyle(fontSize: 12, color: Colors.grey))),
      const SizedBox(height: 4),
      Container(width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _svgIcon('AI요약', fallback: Icons.auto_awesome), const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.65, color: Colors.black87))),
          ])),
    ]);
  }
}

class BreakingNewsItem {
  final bool isUp; final String title, source;
  const BreakingNewsItem({required this.isUp, required this.title, required this.source});
}

class _BreakingNewsCard extends StatelessWidget {
  final List<BreakingNewsItem> items; final bool expanded; final VoidCallback onToggle;
  const _BreakingNewsCard({required this.items, required this.expanded, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    final show = expanded ? items : (items.isEmpty ? <BreakingNewsItem>[] : [items.first]);
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      GestureDetector(onTap: onToggle,
          child: Text(expanded ? '접기' : '더보기', style: const TextStyle(fontSize: 12, color: Colors.grey))),
      const SizedBox(height: 4),
      Container(width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _svgIcon('실시간급변뉴스', fallback: Icons.article_outlined), const SizedBox(width: 8),
              const Text('실시간 급변 뉴스', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            ...show.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.title, style: const TextStyle(fontSize: 15, height: 1.4)),
                  Text(e.source, style: TextStyle(fontSize: 15, color: Colors.grey.shade500)),
                ]))),
          ])),
    ]);
  }
}

class TagItem {
  final String label; final double relevance; final int rank;
  const TagItem({required this.label, required this.relevance, required this.rank});
}

class _KeywordCard extends StatefulWidget {
  final String stockName; final List<TagItem> tags;
  const _KeywordCard({required this.stockName, required this.tags});
  @override
  State<_KeywordCard> createState() => _KeywordCardState();
}

class _KeywordCardState extends State<_KeywordCard> {
  final _scrollController = ScrollController();

  static const _styles = [
    (Color(0xFF00C951), Color(0xFFFFFFFF), EdgeInsets.symmetric(horizontal: 13.0, vertical: 10.0), 14.0),
    (Color(0xFFABFACD), Color(0xFF00682E), EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),  13.0),
    (Color(0xFFD4FDE7), Color(0xFF189C5C), EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),  12.0),
    (Color(0xFFE5E5E5), Color(0xFF000000), EdgeInsets.symmetric(horizontal: 9.0,  vertical: 5.0),  11.0),
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = widget.tags.first;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RichText(text: TextSpan(
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black),
          children: [
            TextSpan(text: '${widget.stockName}는 '),
            TextSpan(text: top.label, style: const TextStyle(color: Color(0xFF0EC272), fontWeight: FontWeight.w700)),
            const TextSpan(text: '이 핵심이에요.'),
          ],
        )),
        const SizedBox(height: 14),
        Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.tags.map((t) {
                  final styleIdx = (t.rank - 1).clamp(0, 3);
                  final s = _styles[styleIdx];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: s.$3,
                    decoration: BoxDecoration(color: s.$1, borderRadius: BorderRadius.circular(30)),
                    child: Text(t.label, textAlign: TextAlign.center,
                        style: TextStyle(color: s.$2, fontSize: s.$4, fontWeight: FontWeight.w700)),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class RelatedStock {
  final String name, logoText; final Color logoColor; final String? logoUrl;
  const RelatedStock({required this.name, required this.logoText, required this.logoColor, this.logoUrl});
}

class _RelatedSection extends StatelessWidget {
  final String stockName; final List<RelatedStock> related;
  const _RelatedSection({required this.stockName, required this.related});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    RichText(text: TextSpan(
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      children: [
        const TextSpan(text: 'AI', style: TextStyle(color: Color(0xFF0EC272), fontWeight: FontWeight.w700)),
        const TextSpan(text: '가 함께 주목한 종목이에요.\n', style: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w700)),
        TextSpan(text: '$stockName와 연관성이 높은 종목을\n', style: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w700)),
        const TextSpan(text: '데이터 기반으로 ', style: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w700)),
        const TextSpan(text: '추천', style: TextStyle(color: Color(0xFF0EC272), fontWeight: FontWeight.w700)),
        const TextSpan(text: '해드려요.',style: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w700)),
      ],
    )),
    const SizedBox(height: 12),
    Row(children: related.map((r) => Expanded(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(children: [
        Text(r.logoText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: r.logoColor)),
        const SizedBox(height: 6),
        Text(r.name, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ]),
    ))).toList()),
  ]);
}

