// lib/screens/news_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'news_page.dart';
import '../services/news_api_service.dart' show NewsApiService, StockSummary;

class NewsDetailPage extends StatefulWidget {
  final NewsItem item;
  const NewsDetailPage({super.key, required this.item});

  @override
  State<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  bool get _isPositive => widget.item.stockUp;
  bool _summaryExpanded = false;

  String? _aiSummary;
  bool _aiLoading = true;

  // 더미 키워드 (API 연결 후 교체)
  final List<String> _keywords = ['HBM3E', 'AI반도체', '엔비디아', '3분기양산', 'HBM수요증가'];

  final ScrollController _keywordScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAiSummary();
  }

  @override
  void dispose() {
    _keywordScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAiSummary() async {
    if (widget.item.stockName == null) {
      setState(() => _aiLoading = false);
      return;
    }
    try {
      final result = await NewsApiService.getStockSummary(widget.item.stockName!);
      if (mounted) {
        setState(() {
          _aiSummary = result.summary;
          _aiLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiSummary = null;
          _aiLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    final fullText = _aiSummary ?? '';
    final shortSummary = fullText.length > 60
        ? '${fullText.substring(0, 60)}...'
        : fullText;

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
                    icon: const Icon(Icons.arrow_back, size: 26, color: Colors.black),
                  ),
                  const Spacer(),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_none, size: 28, color: Colors.black),
                      Positioned(
                        right: -2, top: -2,
                        child: Container(
                          width: 15, height: 15,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                              color: Color(0xFF0EC272), shape: BoxShape.circle),
                          child: const Text('2',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.settings, size: 26, color: Colors.black),
                ],
              ),
            ),

            // ── 본문 ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [

                  // 1. 종목 태그
                  if (item.stockName != null && item.stockChange != null) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3E3E3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                text: '${item.stockName}  ',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
                              ),
                              TextSpan(
                                text: item.stockChange,
                                style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w500,
                                  color: item.stockUp ? const Color(0xFFE63E3E) : const Color(0xFF1E3CD6),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 2. 제목
                  Text(
                    item.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.4),
                  ),
                  const SizedBox(height: 8),

                  // 3. 날짜
                  if (item.pubDate != null)
                    Text(
                      item.pubDate!.length >= 16
                          ? item.pubDate!.replaceAll('T', ' ').substring(0, 16)
                          : item.pubDate!.replaceAll('T', ' '),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF606060)),
                    ),
                  const SizedBox(height: 14),

                  // 4. AI 감성 판단
                  Row(
                    children: [
                      const Text(
                        'AI가 이 뉴스를 ',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _isPositive ? '긍정적' : '부정적',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _isPositive ? const Color(0xFFFF0000) : const Color(0xFF2445EF),
                        ),
                      ),
                      const Text(
                        '으로 판단했어요.',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 더보기 버튼 - 카드 바로 위 오른쪽
                  if (!_aiLoading && _aiSummary != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _summaryExpanded = !_summaryExpanded),
                          child: Text(
                            _summaryExpanded ? '접기' : '더보기',
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

                  // 5. AI 요약 카드
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F5F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD3D3D3)),
                    ),
                    child: _aiLoading
                        ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                        : _aiSummary == null
                        ? const Text(
                      'AI 요약을 불러올 수 없습니다.',
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
                            _summaryExpanded ? fullText : shortSummary,
                            style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                    controller: _keywordScrollController,
                    thumbVisibility: true,
                    thickness: 4,
                    radius: const Radius.circular(2),
                    child: ScrollConfiguration(
                      behavior: _CustomScrollBehavior(),
                      child: SingleChildScrollView(
                        controller: _keywordScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Row(
                          children: _keywords.map((kw) => Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E5E5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              kw,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 8. 본문
                  Text(
                    item.summary, // 본문 부분 일단 summary 사용. 나중에 뉴스 본문 api로 교체하면 될듯.
                    style: const TextStyle(fontSize: 15, height: 1.8, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 스크롤바 색상 커스텀
class _CustomScrollBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
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