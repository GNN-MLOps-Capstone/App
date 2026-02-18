import 'package:flutter/material.dart';

enum AlarmTag { highRisk, risk, keyword }

class AlarmItem {
  final String id;
  final AlarmTag tag;
  final String title;
  final String body;
  final String timeLabel; // 예: "방금 전", "3시간 전"
  bool isRead;

  AlarmItem({
    required this.id,
    required this.tag,
    required this.title,
    required this.body,
    required this.timeLabel,
    this.isRead = false,
  });
}

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  // ✅ 더미 데이터 (원하면 나중에 API로 교체)
  final List<AlarmItem> _items = [
    AlarmItem(
      id: '1',
      tag: AlarmTag.highRisk,
      title: '삼성전자 급락 리스크 감지',
      body: '최근 3일간 부정적 뉴스 급증 (15건) 및 주가 -5.2% 하락, 실적 발표 전 변동성 증가 예상',
      timeLabel: '방금 전',
      isRead: false,
    ),
    AlarmItem(
      id: '2',
      tag: AlarmTag.keyword,
      title: '카카오 규제 이슈 발생',
      body: '공정거래위원회 조사 착수, 관련 키워드 “규제”, “조사” 급증 중',
      timeLabel: '3시간 전',
      isRead: false,
    ),
    AlarmItem(
      id: '3',
      tag: AlarmTag.risk,
      title: 'NAVER 감성 지수 하락',
      body: 'AI 서비스 관련 부정적 여론 증가, 감성 지수 70→45로 하락',
      timeLabel: '1일 전',
      isRead: true,
    ),
    AlarmItem(
      id: '4',
      tag: AlarmTag.keyword,
      title: '삼성전자 “반도체” 키워드 급등',
      body: '관련 기사/언급량이 급증했습니다. 단기 이슈로 변동성 주의',
      timeLabel: '2일 전',
      isRead: true,
    ),
    AlarmItem(
      id: '5',
      tag: AlarmTag.risk,
      title: 'LG에너지솔루션 변동성 확대',
      body: '최근 거래량 급증과 함께 변동성이 커지고 있습니다.',
      timeLabel: '3일 전',
      isRead: false,
    ),
  ];

  int get _totalCount => _items.length;
  int get _unreadCount => _items.where((e) => !e.isRead).length;

  // 긴급/리스크 탭 카운트 = HighRisk + Risk
  int get _riskTabCount =>
      _items.where((e) => e.tag == AlarmTag.highRisk || e.tag == AlarmTag.risk).length;

  // 키워드 탭 카운트
  int get _keywordTabCount => _items.where((e) => e.tag == AlarmTag.keyword).length;

  void _markAllRead() {
    setState(() {
      for (final it in _items) {
        it.isRead = true;
      }
    });
  }

  Future<void> _openDetailAndMarkRead(AlarmItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlarmDetailPage(item: item),
      ),
    );

    // ✅ 4) 읽지 않은 알람 클릭 후 돌아오면 읽음 처리
    if (!mounted) return;
    if (!item.isRead) {
      setState(() {
        item.isRead = true;
      });
    }
  }

  List<AlarmItem> _filteredItems(int tabIndex) {
    // 탭 순서: 0 전체, 1 읽지 않음, 2 긴급/리스크, 3 키워드
    switch (tabIndex) {
      case 1:
        return _items.where((e) => !e.isRead).toList();
      case 2:
        return _items
            .where((e) => e.tag == AlarmTag.highRisk || e.tag == AlarmTag.risk)
            .toList();
      case 3:
        return _items.where((e) => e.tag == AlarmTag.keyword).toList();
      default:
        return _items;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            '알림',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800),
          ),
          actions: [
            // (옵션) 톱니 버튼 자리
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.settings_outlined, color: Colors.black54),
              tooltip: '설정',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TextButton.icon(
                onPressed: _unreadCount == 0 ? null : _markAllRead, // ✅ 읽을 게 없으면 비활성화
                icon: const Icon(Icons.check, size: 18),
                label: const Text('모두 읽음'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black87,
                  disabledForegroundColor: Colors.black26,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              alignment: Alignment.centerLeft,
              color: Colors.white,
              child: TabBar(
                isScrollable: true,
                labelColor: Colors.black87,
                unselectedLabelColor: Colors.black45,
                indicatorColor: Colors.black87,
                indicatorWeight: 2.6,
                tabs: [
                  Tab(text: '전체 ($_totalCount)'),
                  Tab(text: '읽지 않음 ($_unreadCount)'),
                  Tab(text: '🚨 긴급/리스크 ($_riskTabCount)'),
                  Tab(text: '키워드 ($_keywordTabCount)'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: List.generate(4, (tabIndex) {
            final list = _filteredItems(tabIndex);

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final item = list[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AlarmCard(
                    item: item,
                    onTap: () => _openDetailAndMarkRead(item),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  final AlarmItem item;
  final VoidCallback onTap;

  const _AlarmCard({required this.item, required this.onTap});

  bool get _isUnread => !item.isRead;

  // 1) 읽지 않음: 빨강(리스크) / 파랑(이슈)
  Color get _bgColor {
    if (!_isUnread) return Colors.white;

    if (item.tag == AlarmTag.highRisk || item.tag == AlarmTag.risk) {
      return const Color(0xFFFDECEC); // 연한 빨강 배경
    }
    // keyword(이슈)
    return const Color(0xFFEAF3FF); // 연한 파랑 배경
  }

  Color get _borderColor {
    if (item.isRead) return const Color(0xFFE5E7EB);
    if (item.tag == AlarmTag.highRisk || item.tag == AlarmTag.risk) {
      return const Color(0xFFF6B6B6);
    }
    return const Color(0xFFB9D8FF);
  }

  // 아이콘(좌측)
  Widget _leadingIcon() {
    // 5) 읽지 않음 표시 파란 점 (읽음이면 없음)
    return SizedBox(
      width: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (_isUnread)
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF2F80ED), // 파란 점
                shape: BoxShape.circle,
              ),
            )
          else
            const SizedBox(width: 10),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  // 제목 앞 작은 이모지
  String get _emoji {
    switch (item.tag) {
      case AlarmTag.highRisk:
      case AlarmTag.risk:
        return '🧨';
      case AlarmTag.keyword:
        return '📌';
    }
  }

  // 배지(높은 리스크/리스크/키워드)
  Widget _badge() {
    switch (item.tag) {
      case AlarmTag.highRisk:
        return _Chip(
          text: '높은 리스크',
          fg: Colors.white,
          bg: const Color(0xFFEF4444),
        );
      case AlarmTag.risk:
        return _Chip(
          text: '리스크',
          fg: const Color(0xFFEF4444),
          bg: const Color(0xFFFDE2E2),
        );
      case AlarmTag.keyword:
        return _Chip(
          text: '키워드',
          fg: const Color(0xFF2F80ED),
          bg: const Color(0xFFDCEBFF),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _leadingIcon(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목줄
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(_emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _badge(),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 본문
                  Text(
                    item.body,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // 시간
                  Text(
                    item.timeLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
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

class _Chip extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;

  const _Chip({required this.text, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class AlarmDetailPage extends StatelessWidget {
  final AlarmItem item;
  const AlarmDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '알림',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        // 3) 빈 화면 + 연결 예정
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '“추후 연결 예정”',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}