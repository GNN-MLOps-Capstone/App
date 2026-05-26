// lib/screens/news_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/news_models.dart';
import '../services/news_api_service.dart';
import '../services/notification_service.dart';

class NewsDetailPage extends StatefulWidget {
  final int newsId;
  final NewsRecommendationItem? initialItem;

  const NewsDetailPage({super.key, required this.newsId, this.initialItem});

  @override
  State<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  final ScrollController _keywordScrollController = ScrollController();

  NewsDetailItem? _detail;
  bool _loading = true;
  bool _summaryExpanded = false;
  String? _errorMessage;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialItem?.isPlaceholder == true) {
      _detail = NewsDetailItem.fromRecommendationItem(widget.initialItem!);
      _loading = false;
      return;
    }
    _loadDetail();
    _loadUnreadCount();
  }

  @override
  void dispose() {
    _keywordScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final detail = await NewsApiService.getNewsDetail(widget.newsId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _detail = widget.initialItem != null
            ? NewsDetailItem.fromRecommendationItem(widget.initialItem!)
            : _detail;
        _loading = false;
        _errorMessage = _detail == null ? '뉴스 상세를 불러오지 못했습니다.' : null;
      });
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await NotificationApiService.getUnreadNotificationCount();
      if (!mounted) return;
      setState(() {
        _unreadCount = count;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ 알림 개수 로드 실패: $e');
      debugPrint(stackTrace.toString());
    }
  }

  Color _sentimentColor(String? sentiment) {
    switch (sentiment) {
      case '긍정':
        return const Color(0xFFE63E3E);
      case '부정':
        return const Color(0xFF2445EF);
      default:
        return Colors.black87;
    }
  }

  String _sentimentLabel(String? sentiment) {
    switch (sentiment) {
      case '긍정':
        return '긍정적';
      case '부정':
        return '부정적';
      case '중립':
        return '중립적';
      default:
        return '';
    }
  }

  String _formatPubDate(DateTime? pubDate) {
    if (pubDate == null) return '';
    final year = pubDate.year.toString().padLeft(4, '0');
    final month = pubDate.month.toString().padLeft(2, '0');
    final day = pubDate.day.toString().padLeft(2, '0');
    final hour = pubDate.hour.toString().padLeft(2, '0');
    final minute = pubDate.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F6),
      body: SafeArea(
        child: Column(
          children: [
            // ── 상단 바 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 26,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/alarm').then((_) {
                            _loadUnreadCount(); // 알림방 갔다 오면 갱신
                          });
                        },
                        icon: const Icon(
                          Icons.notifications_none,
                          size: 28,
                          color: Colors.black,
                        ),
                      ),
                      if (_unreadCount > 0)
                        Positioned(
                          right: 6,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EC272),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _unreadCount > 99 ? '99+' : '$_unreadCount',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                    icon: const Icon(
                        Icons.settings,
                        size: 26,
                        color: Colors.black87
                    ),
                  ),
                ],
              ),
            ),

            // ── 본문 ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF606060),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _loadDetail,
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : detail == null
                  ? const SizedBox.shrink()
                  : _NewsDetailContent(
                      detail: detail,
                      summaryExpanded: _summaryExpanded,
                      onToggleSummary: () {
                        setState(() => _summaryExpanded = !_summaryExpanded);
                      },
                      keywordScrollController: _keywordScrollController,
                      sentimentColor: _sentimentColor(detail.sentiment),
                      sentimentLabel: _sentimentLabel(detail.sentiment),
                      formattedDate: _formatPubDate(detail.pubDate),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsDetailContent extends StatelessWidget {
  final NewsDetailItem detail;
  final bool summaryExpanded;
  final VoidCallback onToggleSummary;
  final ScrollController keywordScrollController;
  final Color sentimentColor;
  final String sentimentLabel;
  final String formattedDate;

  const _NewsDetailContent({
    required this.detail,
    required this.summaryExpanded,
    required this.onToggleSummary,
    required this.keywordScrollController,
    required this.sentimentColor,
    required this.sentimentLabel,
    required this.formattedDate,
  });

  @override
  Widget build(BuildContext context) {
    final summaryText = detail.summary.trim();
    final bodyText = detail.body.trim().isEmpty
        ? summaryText
        : detail.body.trim();
    final trimmedStockName = detail.stockName?.trim();
    final stockItems = detail.relatedStocks.isNotEmpty
        ? detail.relatedStocks
        : trimmedStockName?.isNotEmpty == true
        ? [
            NewsDetailStockItem(
              stockId: '',
              stockName: trimmedStockName!,
              stockChange: detail.stockChange,
              stockUp: detail.stockUp,
            ),
          ]
        : const <NewsDetailStockItem>[];
    final shortSummary = summaryText.length > 90
        ? '${summaryText.substring(0, 90)}...'
        : summaryText;
    final hasKeywords = detail.keywords.isNotEmpty;
    final hasSentiment = sentimentLabel.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // 1. 종목 태그
        if (stockItems.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stockItems.map((stock) {
              final stockChange = stock.stockChange;
              final stockColor = stock.stockUp == true
                  ? const Color(0xFFE63E3E)
                  : stock.stockUp == false
                  ? const Color(0xFF1E3CD6)
                  : Colors.grey;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3E3E3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: stock.stockName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      if (stockChange != null && stockChange.isNotEmpty)
                        TextSpan(
                          text: '  $stockChange',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: stockColor,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          detail.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),

        // 3. 날짜
        if (formattedDate.isNotEmpty)
          Text(
            formattedDate,
            style: const TextStyle(fontSize: 12, color: Color(0xFF606060)),
          ),
        const SizedBox(height: 14),

        // 4. AI 감성 판단
        if (hasSentiment) ...[
          Row(
            children: [
              const Text(
                'AI가 이 뉴스를 ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              Text(
                sentimentLabel,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: sentimentColor,
                ),
              ),
              const Text(
                '으로 판단했어요.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // 더보기 버튼 - 카드 바로 위 오른쪽
        if (summaryText.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: onToggleSummary,
                child: Text(
                  summaryExpanded ? '접기' : '더보기',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF83848B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],

        // 5. AI 요약 카드
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F5F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD3D3D3)),
          ),
          child: summaryText.isEmpty
              ? const Text(
                  'AI 요약이 아직 준비되지 않았습니다.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF606060)),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SvgPicture.asset(
                      'assets/images/AI요약.svg',
                      width: 20,
                      height: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        summaryExpanded ? summaryText : shortSummary,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        if (hasKeywords) ...[
          const SizedBox(height: 20),

          // 6. AI 핵심 정리 텍스트
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'AI',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0EC272),
                  ),
                ),
                const TextSpan(
                  text: '가 이 뉴스의 핵심을 정리했어요.\n지금 이슈의 ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const TextSpan(
                  text: '중심 키워드',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0EC272),
                  ),
                ),
                const TextSpan(
                  text: '예요.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 7. 키워드 가로 스크롤
          Scrollbar(
            controller: keywordScrollController,
            thumbVisibility: true,
            thickness: 4,
            radius: const Radius.circular(2),
            child: ScrollConfiguration(
              behavior: _CustomScrollBehavior(),
              child: SingleChildScrollView(
                controller: keywordScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 15),
                child: Row(
                  children: detail.keywords
                      .map(
                        (keyword) => Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E5E5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            keyword,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),

        // 8. 본문
        Text(
          bodyText,
          style: const TextStyle(
            fontSize: 15,
            height: 1.8,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

// 스크롤바 색상 커스텀
class _CustomScrollBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: const ScrollbarThemeData(
          thumbColor: WidgetStatePropertyAll(Color(0xFF83848B)),
        ),
      ),
      child: child,
    );
  }
}
