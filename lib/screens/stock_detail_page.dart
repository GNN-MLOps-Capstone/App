// lib/screens/stock_detail_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

enum ChartRange { day, week, month }
enum Sentiment { positive, negative }

class StockDetailPage extends StatefulWidget {
  final String stockName;
  const StockDetailPage({super.key, required this.stockName});

  @override
  State<StockDetailPage> createState() => _StockDetailPageState();
}

class _StockDetailPageState extends State<StockDetailPage> {
  ChartRange _range = ChartRange.day;

  // ✅ 월간 급변 뉴스 펼침 상태
  bool _newsExpanded = false;

  // ✅ API 연동 시 수정 필요: dummy() → fromApi()로 변경
  late final vm = StockDetailViewModel.dummy(widget.stockName);

  void _onBottomTap(int index) {
    if (index == 3) return; // 주식(현재)

    const labels = ['홈', '관심', '뉴스', '주식'];

    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/news');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${labels[index]} 화면은 아직 준비 중입니다.'),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = vm.dataFor(_range);

    // ✅✅ 핵심: 접힘/펼침 레이아웃을 "완전히 다르게" 그려서
    // 펼쳤을 때 가로(전체폭)로도 커지게 만들기
    Widget statsAndNewsSection() {
      // 접힘(ROW): 왼쪽 stats + 오른쪽 뉴스(같은 높이)
      Widget collapsedRow() {
        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 118,
              child: _StatsCard(stats: data.stats),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MonthlyNewsCard(
                items: data.monthlyNews,
                expanded: false,
                onExpandedChanged: (v) => setState(() => _newsExpanded = v),
              ),
            ),
          ],
        );
        return IntrinsicHeight(child: row); // ✅ 두 카드 높이 맞춤
      }

      // 펼침(FULL WIDTH): 뉴스 카드가 전체 폭으로 렌더
      Widget expandedFullWidth() {
        return _MonthlyNewsCard(
          items: data.monthlyNews,
          expanded: true,
          onExpandedChanged: (v) => setState(() => _newsExpanded = v),
        );
      }

      return Column(
        children: [
          // ✅ 접힘 상태에서는 Row를 그대로 보여줌
          if (!_newsExpanded) collapsedRow(),

          // ✅ 펼침 상태에서는 "전체폭 뉴스 카드"를 보여줌
          if (_newsExpanded) expandedFullWidth(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: _buildAppBar(),
      bottomNavigationBar: BottomNavBar(
        initialIndex: 3,
        onIndexChanged: _onBottomTap,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderPriceSection(
                stockName: widget.stockName,
                priceText: data.priceText,
                changeText: data.changeText,
                isUp: data.isUp,
                sentiment: data.sentiment,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('가격 추이', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  _RangeSelector(range: _range, onChanged: (r) => setState(() => _range = r)),
                ],
              ),
              const SizedBox(height: 12),

              // ✅ 차트 카드
              Container(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                decoration: _cardDeco(),
                child: SizedBox(
                  height: 210,
                  child: LineChartInteractive(
                    points: data.series,
                    xLabels: data.xLabels,
                    maxLabel: data.maxLabel,
                    minLabel: data.minLabel,
                    tooltipText: data.tooltipFor,
                  ),
                ),
              ),

              // ✅✅ 시가/최고/최저 + 월간 급변 뉴스
              const SizedBox(height: 14),
              statsAndNewsSection(),

              const SizedBox(height: 18),

              // ✅ AI 요약 카드
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDeco(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AI 요약', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    ...data.aiSummary.map((line) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  ', style: TextStyle(fontSize: 14)),
                          Expanded(child: Text(line, style: const TextStyle(fontSize: 14, height: 1.3))),
                        ],
                      ),
                    )),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: data.tags.map((t) => _TagChip(text: t)).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    leading: const BackButton(color: Colors.black),
    title: const Text('검색', style: TextStyle(color: Colors.black)),
    actions: [
      IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black), onPressed: () {}),
      IconButton(icon: const Icon(Icons.settings, color: Colors.black), onPressed: () {}),
    ],
  );
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
              Text(stockName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(priceText, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
              const SizedBox(height: 6),
              Text('$arrow $changeText', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.only(top: 36), child: _SentimentBadge(sentiment: sentiment)),
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
    final accent = isPos ? const Color(0xFF22C55E) : const Color(0xFF64748B);

    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: accent.withOpacity(0.15), shape: BoxShape.circle),
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
    decoration: BoxDecoration(color: const Color(0xFFEDEFF2), borderRadius: BorderRadius.circular(12)),
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
          border: Border.all(color: sel ? const Color(0xFFCBD5E1) : Colors.transparent),
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
    decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(18)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTap(TapDownDetails d, Size sz) {
    final rect = Rect.fromLTWH(_pad.left, _pad.top, sz.width - _pad.horizontal, sz.height - _pad.vertical);
    if (!rect.contains(d.localPosition)) return _clear();

    final n = widget.points.length;
    if (n == 0) return;
    if (n == 1) return _show(0, Offset(rect.left + rect.width / 2, rect.top + rect.height / 2));

    final dx = rect.width / (n - 1);
    final idx = ((d.localPosition.dx - rect.left) / dx).round().clamp(0, n - 1);

    final mn = widget.points.reduce(min), mx = widget.points.reduce(max);
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

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
    final sz = Size(c.maxWidth, c.maxHeight);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (d) => _onTap(d, sz),
      child: Stack(
        children: [
          Positioned.fill(child: Padding(padding: _pad, child: CustomPaint(painter: _Painter(widget.points)))),
          if (widget.points.length >= 2) ..._labels(sz),
          Positioned(left: 0, right: 0, bottom: 0, child: _xLabels()),
          if (_idx != null && _pos != null) _Tooltip(anchor: _pos!, text: widget.tooltipText(_idx!), maxW: sz.width),
        ],
      ),
    );
  });

  List<Widget> _labels(Size sz) {
    final n = widget.points.length;
    final rect = Rect.fromLTWH(_pad.left, _pad.top, sz.width - _pad.horizontal, sz.height - _pad.vertical);
    final dx = rect.width / (n - 1);

    final mn = widget.points.reduce(min), mx = widget.points.reduce(max);
    final span = max(mx - mn, 1e-6);
    final h = rect.height * _scale;
    final top = max(0.0, (rect.height - h) / 2 - _lift);

    int maxI = 0, minI = 0;
    for (int i = 1; i < n; i++) {
      if (widget.points[i] > widget.points[maxI]) maxI = i;
      if (widget.points[i] < widget.points[minI]) minI = i;
    }

    final maxX = rect.left + dx * maxI;
    final maxY = rect.top + top + (1 - (widget.points[maxI] - mn) / span) * h;
    final minX = rect.left + dx * minI;
    final minY = rect.top + top + (1 - (widget.points[minI] - mn) / span) * h;

    const style = TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600);
    return [
      Positioned(left: maxX - 35, top: maxY - 20, child: Text(widget.maxLabel, style: style)),
      Positioned(left: minX - 35, top: minY + 10, child: Text(widget.minLabel, style: style)),
    ];
  }

  Widget _xLabels() {
    if (widget.xLabels.isEmpty) return const SizedBox();
    const style = TextStyle(fontSize: 10, color: Colors.grey);
    if (widget.xLabels.length == 1) {
      return Center(child: Padding(padding: const EdgeInsets.all(8), child: Text(widget.xLabels[0], style: style)));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: widget.xLabels.map((t) => Text(t, style: style)).toList(),
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

    final axis = Paint()..color = const Color(0xFFCBD5E1)..strokeWidth = 2;
    canvas.drawLine(Offset(0, sz.height), Offset(sz.width, sz.height), axis);

    if (points.length == 1) {
      canvas.drawCircle(Offset(sz.width / 2, sz.height / 2), 6, Paint()..color = const Color(0xFF1D4ED8));
      return;
    }

    final mn = points.reduce(min), mx = points.reduce(max);
    final span = max(mx - mn, 1e-6);
    final dx = sz.width / (points.length - 1);
    final h = sz.height * 0.72;
    final top = max(0.0, (sz.height - h) / 2 - 10);

    Offset pt(int i) => Offset(dx * i, top + (1 - (points[i] - mn) / span) * h);

    final line = Paint()..color = const Color(0xFF1D4ED8)..strokeWidth = 3..style = PaintingStyle.stroke;
    final dot = Paint()..color = const Color(0xFF1D4ED8);

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    canvas.drawPath(path, line);

    for (int i = 0; i < points.length; i++) {
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
  const _Tooltip({required this.anchor, required this.text, required this.maxW});

  @override
  Widget build(BuildContext context) {
    const w = 78.0, h = 28.0, tail = 7.0;
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
              child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
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
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(10)), paint);
    final path = Path()
      ..moveTo(tailX - 7, h)
      ..lineTo(tailX, h + tail)
      ..lineTo(tailX + 7, h)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TooltipPainter old) => old.tailX != tailX || old.w != w || old.h != h || old.tail != tail;
}

/* ==================== ✅ stock_page.dart와 동일한 하단바 ==================== */

class BottomNavBar extends StatefulWidget {
  final int initialIndex;
  final ValueChanged<int> onIndexChanged;

  const BottomNavBar({
    super.key,
    required this.initialIndex,
    required this.onIndexChanged,
  });

  @override
  State<BottomNavBar> createState() => BottomNavBarState();
}

class BottomNavBarState extends State<BottomNavBar> {
  late int selectedIndex;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
  }

  void _onTap(int index) {
    setState(() => selectedIndex = index);
    widget.onIndexChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    final Color activeColor = const Color(0xFF22C55E);
    final Color inactiveColor = Colors.grey.shade400;

    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomNavItem(
            icon: Icons.home,
            label: '홈',
            isActive: selectedIndex == 0,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => _onTap(0),
          ),
          _BottomNavItem(
            icon: Icons.favorite_border,
            label: '관심',
            isActive: selectedIndex == 1,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => _onTap(1),
          ),
          _BottomNavItem(
            icon: Icons.article_outlined,
            label: '뉴스',
            isActive: selectedIndex == 2,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => _onTap(2),
          ),
          _BottomNavItem(
            icon: Icons.candlestick_chart,
            label: '주식',
            isActive: selectedIndex == 3,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => _onTap(3),
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: isActive ? activeColor : inactiveColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: isActive ? activeColor : inactiveColor),
          ),
        ],
      ),
    );
  }
}