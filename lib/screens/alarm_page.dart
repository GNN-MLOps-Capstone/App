import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

enum AlarmTag { highRisk, risk, keyword }

class AlarmItem {
  final String id;
  final AlarmTag tag;
  final String stockName;
  final double? sentimentScore;

  final String title;
  final String body;

  /// 알림 발생 시각(정렬/시간표시 핵심)
  final DateTime createdAt;

  final bool isRead;

  /// ✅ 즐겨찾기(= 중요 탭에 들어갈지)
  final bool isStarred;

  AlarmItem({
    required this.id,
    required this.tag,
    required this.stockName,
    required this.title,
    required this.body,
    required this.createdAt,
    this.sentimentScore,
    this.isRead = false,
    this.isStarred = false,
  });

  AlarmItem copyWith({
    AlarmTag? tag,
    String? stockName,
    double? sentimentScore,
    String? title,
    String? body,
    DateTime? createdAt,
    bool? isRead,
    bool? isStarred,
  }) {
    return AlarmItem(
      id: id,
      tag: tag ?? this.tag,
      stockName: stockName ?? this.stockName,
      sentimentScore: sentimentScore ?? this.sentimentScore,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      isStarred: isStarred ?? this.isStarred,
    );
  }

  /// 요청 규칙대로 timeLabel 생성
  String timeLabelNow(DateTime now) {
    final diff = now.difference(createdAt);
    if (diff.isNegative) return '방금 전';

    final minutes = diff.inMinutes;
    final hours = diff.inHours;
    final days = diff.inDays;

    if (minutes <= 5) return '방금 전';          // 0~5분
    if (minutes < 60) return '${minutes}분 전';   // 5분 초과~1시간 미만
    if (hours < 24) return '${hours}시간 전';     // 1시간 이상~24시간 미만(분 버림)
    return '${days}일 전';                       // 1일 이상
  }
}

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  Timer? _ticker;
  List<AlarmItem> _items = [];

  // ==============================
  // 정렬/추가 공통 유틸
  // ==============================

  void _sortByNewest() {
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<AlarmItem> _mergeAndSort(List<AlarmItem> a, List<AlarmItem> b) {
    final merged = [...a, ...b];
    merged.sort((x, y) => y.createdAt.compareTo(x.createdAt));
    return merged;
  }

  /// ✅ 새 알림 도착 시 호출하면 됨 (자동 최신순 + 맨 위)
  /// - 같은 id가 있으면 업데이트(중복 방지)
  void addOrUpdateAlarm(AlarmItem newItem) {
    setState(() {
      final idx = _items.indexWhere((e) => e.id == newItem.id);
      if (idx >= 0) {
        final old = _items[idx];
        // 기존 읽음/즐겨찾기 상태는 유지하면서 본문/시간/태그만 갱신
        _items[idx] = old.copyWith(
          tag: newItem.tag,
          stockName: newItem.stockName,
          sentimentScore: newItem.sentimentScore,
          title: newItem.title,
          body: newItem.body,
          createdAt: newItem.createdAt,
        );
      } else {
        _items.add(newItem);
      }
      _sortByNewest();
    });
  }

  void _deleteItem(String id) {
    setState(() {
      _items.removeWhere((e) => e.id == id);
    });
  }

  void _toggleStar(String id) {
    setState(() {
      final idx = _items.indexWhere((e) => e.id == id);
      if (idx < 0) return;
      final it = _items[idx];
      _items[idx] = it.copyWith(isStarred: !it.isStarred);
      // 즐겨찾기 토글해도 정렬은 최신순 유지(필요하면 여기서 고정정렬 정책 변경 가능)
      _sortByNewest();
    });
  }

  // ==============================
  // 리스크/키워드 생성 로직 (더미)
  // ==============================

  AlarmTag _tagBySentiment(double sentimentScore) {
    // TODO(임계값 튜닝 필요):
    // - sentimentScore가 X 이하이면 highRisk
    // - sentimentScore가 Y 이하이면 risk
    if (sentimentScore <= 35) return AlarmTag.highRisk; // TODO
    if (sentimentScore <= 55) return AlarmTag.risk;     // TODO
    return AlarmTag.risk; // TODO: 정책에 따라 "알림 생성 안 함"으로 바꿀 수 있음
  }

  Future<List<String>> _fetchFavoriteStocks() async {
    // TODO: 관심종목 페이지에서 가져오기 (상태관리/Firestore/로컬저장 등)
    return ['삼성전자', 'NAVER', '카카오'];
  }

  Future<List<String>> _fetchUserKeywordsFromFavorites() async {
    // TODO: 관심종목 기반 키워드 정책 결정
    final favorites = await _fetchFavoriteStocks();
    return favorites;
  }

  List<AlarmItem> _generateRiskAlarmsDummy() {
    final now = DateTime.now();
    final dummy = [
      {
        'stock': '삼성전자',
        'sent': 30.0,
        'title': '삼성전자 급락 리스크 감지',
        'body': '최근 3일간 부정적 뉴스 급증 (15건) 및 주가 -5.2% 하락, 실적 발표 전 변동성 증가 예상',
        'createdAt': now.subtract(const Duration(minutes: 3)),
        'read': false,
        'star': false,
      },
      {
        'stock': 'NAVER',
        'sent': 45.0,
        'title': 'NAVER 감성 지수 하락',
        'body': 'AI 서비스 관련 부정적 여론 증가, 감성 지수 70→45로 하락',
        'createdAt': now.subtract(const Duration(hours: 3)),
        'read': true,
        'star': false, // 더미로 중요 하나 넣어둠
      },
      {
        'stock': 'LG에너지솔루션',
        'sent': 55.0,
        'title': 'LG에너지솔루션 변동성 확대',
        'body': '최근 거래량 급증과 함께 변동성이 커지고 있습니다.',
        'createdAt': now.subtract(const Duration(days: 3, hours: 2)),
        'read': false,
        'star': false,
      },
    ];

    return dummy.map((d) {
      final s = d['sent'] as double;
      final createdAt = d['createdAt'] as DateTime;
      final stock = d['stock'] as String;

      return AlarmItem(
        id: 'risk_${stock}_${createdAt.millisecondsSinceEpoch}',
        tag: _tagBySentiment(s),
        stockName: stock,
        sentimentScore: s,
        title: d['title'] as String,
        body: d['body'] as String,
        createdAt: createdAt,
        isRead: d['read'] as bool,
        isStarred: d['star'] as bool,
      );
    }).toList();
  }

  List<AlarmItem> _generateKeywordAlarmsDummy(List<String> userKeywords) {
    final now = DateTime.now();
    final dummy = [
      {
        'stock': '카카오',
        'title': '카카오 규제 이슈 발생',
        'body': '공정거래위원회 조사 착수, 관련 키워드 “규제”, “조사” 급증 중',
        'createdAt': now.subtract(const Duration(minutes: 32)),
        'read': false,
        'star': false,
      },
      {
        'stock': '삼성전자',
        'title': '삼성전자 “반도체” 키워드 급등',
        'body': '관련 기사/언급량이 급증했습니다. 단기 이슈로 변동성 주의',
        'createdAt': now.subtract(const Duration(days: 2, minutes: 5)),
        'read': true,
        'star': false,
      },
    ];

    final List<AlarmItem> results = [];
    for (final n in dummy) {
      final text = '${n['title']} ${n['body']}';
      final matched = userKeywords.any((kw) => text.contains(kw));
      if (!matched) continue;

      final createdAt = n['createdAt'] as DateTime;
      final stock = n['stock'] as String;

      results.add(
        AlarmItem(
          id: 'kw_${stock}_${createdAt.millisecondsSinceEpoch}',
          tag: AlarmTag.keyword,
          stockName: stock,
          title: n['title'] as String,
          body: n['body'] as String,
          createdAt: createdAt,
          isRead: n['read'] as bool,
          isStarred: n['star'] as bool,
        ),
      );
    }
    return results;
  }

  // ==============================
  // 초기 로드
  // ==============================

  @override
  void initState() {
    super.initState();
    _initDummyItems();

    // timeLabel 갱신 (1분마다)
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _initDummyItems() async {
    final riskItems = _generateRiskAlarmsDummy();
    final userKeywords = await _fetchUserKeywordsFromFavorites();
    final keywordItems = _generateKeywordAlarmsDummy(userKeywords);
    if (!mounted) return;

    setState(() {
      _items = _mergeAndSort(riskItems, keywordItems);
    });
  }

  // ==============================
  // 탭 카운트/필터
  // ==============================

  int get _totalCount => _items.length;
  int get _starCount => _items.where((e) => e.isStarred).length;
  int get _unreadCount => _items.where((e) => !e.isRead).length;

  int get _riskTabCount =>
      _items.where((e) => e.tag == AlarmTag.highRisk || e.tag == AlarmTag.risk).length;

  int get _keywordTabCount => _items.where((e) => e.tag == AlarmTag.keyword).length;

  void _markAllRead() {
    setState(() {
      _items = _items.map((it) => it.isRead ? it : it.copyWith(isRead: true)).toList();
    });
  }

  Future<void> _openDetailAndMarkRead(AlarmItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlarmDetailPage(item: item),
      ),
    );

    if (!mounted) return;
    if (!item.isRead) {
      setState(() {
        final idx = _items.indexWhere((e) => e.id == item.id);
        if (idx >= 0) {
          _items[idx] = _items[idx].copyWith(isRead: true);
        }
      });
    }
  }

  /// 탭 순서:
  /// 0 전체 / 1 중요 / 2 읽지 않음 / 3 긴급/리스크 / 4 키워드
  List<AlarmItem> _filteredItems(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return _items.where((e) => e.isStarred).toList();
      case 2:
        return _items.where((e) => !e.isRead).toList();
      case 3:
        return _items
            .where((e) => e.tag == AlarmTag.highRisk || e.tag == AlarmTag.risk)
            .toList();
      case 4:
        return _items.where((e) => e.tag == AlarmTag.keyword).toList();
      default:
        return _items;
    }
  }

  // ==============================
  // UI
  // ==============================

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5, // ✅ 중요 탭 추가!
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            '알림',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TextButton.icon(
                onPressed: _unreadCount == 0 ? null : _markAllRead,
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
                  Tab(text: '중요 ($_starCount)'),
                  Tab(text: '읽지 않음 ($_unreadCount)'),
                  Tab(text: '긴급/리스크 ($_riskTabCount)'),
                  Tab(text: '키워드 ($_keywordTabCount)'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: List.generate(5, (tabIndex) {
            final list = _filteredItems(tabIndex);

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final item = list[i];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AlarmSlidableCard(
                    item: item,
                    onTap: () => _openDetailAndMarkRead(item),
                    onDelete: () => _deleteItem(item.id),
                    onToggleStar: () => _toggleStar(item.id),
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

/// ✅ 슬라이드 액션(삭제/중요) 포함 카드
class _AlarmSlidableCard extends StatelessWidget {
  final AlarmItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleStar;

  const _AlarmSlidableCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.onToggleStar,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(item.id),

      /// ✅ 오른쪽으로 슬라이드하면(=startToEnd) 왼쪽에 버튼
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.52, // 버튼 2개가 딱 들어가는 폭
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: '삭제',
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
          ),
          SlidableAction(
            onPressed: (_) => onToggleStar(),
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            icon: item.isStarred ? Icons.star : Icons.star_border,
            label: '중요',
          ),
        ],
      ),

      child: _AlarmCard(item: item, onTap: onTap),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  final AlarmItem item;
  final VoidCallback onTap;

  const _AlarmCard({required this.item, required this.onTap});

  bool get _isUnread => !item.isRead;

  Color get _bgColor {
    if (!_isUnread) return Colors.white;

    if (item.tag == AlarmTag.highRisk || item.tag == AlarmTag.risk) {
      return const Color(0xFFFDECEC);
    }
    return const Color(0xFFEAF3FF);
  }

  Color get _borderColor {
    if (item.isRead) return const Color(0xFFE5E7EB);
    if (item.tag == AlarmTag.highRisk || item.tag == AlarmTag.risk) {
      return const Color(0xFFF6B6B6);
    }
    return const Color(0xFFB9D8FF);
  }

  Widget _leadingDot() {
    return SizedBox(
      width: 26,
      child: Center(
        child: _isUnread
            ? Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Color(0xFF2F80ED),
            shape: BoxShape.circle,
          ),
        )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _badge() {
    switch (item.tag) {
      case AlarmTag.highRisk:
        return const _Chip(
          text: '높은 리스크',
          fg: Colors.white,
          bg: Color(0xFFEF4444),
        );
      case AlarmTag.risk:
        return const _Chip(
          text: '리스크',
          fg: Color(0xFFEF4444),
          bg: Color(0xFFFDE2E2),
        );
      case AlarmTag.keyword:
        return const _Chip(
          text: '키워드',
          fg: Color(0xFF2F80ED),
          bg: Color(0xFFDCEBFF),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = item.timeLabelNow(DateTime.now());

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
        padding: const EdgeInsets.fromLTRB(10, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _leadingDot(),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
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
                  Text(
                    timeLabel,
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
        centerTitle: false,
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