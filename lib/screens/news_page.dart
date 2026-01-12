// lib/screens/news_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

import 'main_page.dart'; // BottomNavBar 사용

// CSV 한 줄을 담는 모델
class NewsItem {
  final String title;
  final String summary;
  final String press;     // 신문사
  final String sentiment; // 긍정 / 부정 / 중립 등

  NewsItem({
    required this.title,
    required this.summary,
    required this.press,
    required this.sentiment,
  });
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late Future<List<NewsItem>> _futureNews;

  @override
  void initState() {
    super.initState();
    _futureNews = _loadNewsFromCsv();
  }

  Future<List<NewsItem>> _loadNewsFromCsv() async {
    final csvString = await rootBundle.loadString('lib/dummy_data.csv');

    final rows = const CsvToListConverter(eol: '\n').convert(csvString);
    if (rows.isEmpty) return [];

    final headers = rows.first.map((e) => e.toString().trim()).toList();

    int idxTitle = headers.indexOf('title');
    int idxSummary = headers.indexOf('summary');
    int idxPress = headers.indexOf('신문사');
    int idxPn = headers.indexOf('pn');

    // 헤더 이름이 다를 경우 대비
    // 헤더 유효성 검사
    if (idxTitle == -1 || idxSummary == -1 || idxPress == -1 || idxPn == -1) {
      debugPrint('CSV 헤더 형식이 올바르지 않습니다: $headers');
      return []; // 또는 throw 에러
    }

    final List<NewsItem> items = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      String getValue(int index) {
        if (index < 0 || index >= row.length) return '';
        final v = row[index];
        return v?.toString() ?? '';
      }

      items.add(
        NewsItem(
          title: getValue(idxTitle),
          summary: getValue(idxSummary),
          press: getValue(idxPress),
          sentiment: getValue(idxPn),
        ),
      );
    }

    return items;
  }

  @override
  void _onBottomTap(BuildContext context, int index) {
    if (index == 2) return; // 이미 뉴스 페이지

    const labels = ['홈', '관심', '뉴스', '주식'];

    if (index == 0) {
      // 홈
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // 아직 안 만든 탭은 안내만
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${labels[index]} 화면은 아직 준비 중입니다.'),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '실시간 뉴스',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // 검색창
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: '원하는 종목을 검색해 보세요',
                    border: InputBorder.none,
                    icon: Icon(Icons.search),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 뉴스 리스트
              Expanded(
                child: FutureBuilder<List<NewsItem>>(
                  future: _futureNews,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          '뉴스를 불러오는 중 오류가 발생했어요.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Center(
                        child: Text('표시할 뉴스가 없습니다.'),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final news = items[index];
                        return _NewsCard(item: news);
                      },
                    );
                  },
                ),
              ),

              // 하단 네비게이션
              BottomNavBar(
                initialIndex: 2,
                onIndexChanged: (i) => _onBottomTap(context, i),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================== 뉴스 카드 위젯 =================
class _NewsCard extends StatelessWidget {
  final NewsItem item;

  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),

          // 요약
          Text(
            item.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),

          // 태그(신문사 + 감성)
          Row(
            children: [
              _TagChip(
                label: item.press,
                background: const Color(0xFFE5F4FF),
                textColor: const Color(0xFF1D4ED8),
              ),
              const SizedBox(width: 8),
              _SentimentChip(sentiment: item.sentiment),
            ],
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;

  const _TagChip({
    required this.label,
    required this.background,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

class _SentimentChip extends StatelessWidget {
  final String sentiment;

  const _SentimentChip({required this.sentiment});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;

    if (sentiment.contains('긍')) {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF16A34A);
    } else if (sentiment.contains('부정')) {
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFFB91C1C);
    } else {
      bg = const Color(0xFFE5E7EB);
      text = const Color(0xFF4B5563);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        sentiment,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: text,
        ),
      ),
    );
  }
}