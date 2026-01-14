import 'package:flutter/material.dart';
import 'main_page.dart'; // BottomNavBar 재사용 (원하면 빼도 됨)

class NewsDetailScreen extends StatelessWidget {
  const NewsDetailScreen({super.key});

  // ✅ 뉴스 제목, 내용
  static const String kPlaceholderTitle = '뉴스 제목';
  static const String kPlaceholderContent = '뉴스 내용';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ 상단: 뒤로가기(요구한 "작다 크다" 아이콘 역할)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '실시간 뉴스',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ✅ 상세 카드(지금은 더미 텍스트)
              Container(
                width: double.infinity,
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
                  children: const [
                    // ============================
                    // ✅ [수정 포인트] 제목 텍스트
                    // ============================
                    Text(
                      kPlaceholderTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 10),

                    // ============================
                    // ✅ [수정 포인트] 내용 텍스트
                    // ============================
                    Text(
                      kPlaceholderContent,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // 하단바
              const BottomNavBar(initialIndex: 2),
            ],
          ),
        ),
      ),
    );
  }
}