import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/notification_service.dart';

enum AlarmTag { highRisk, risk, keyword }

AlarmTag _tagFromType(String type) {
  switch (type) {
    case 'high_risk': return AlarmTag.highRisk;
    case 'risk':      return AlarmTag.risk;
    case 'keyword':
    default:          return AlarmTag.keyword;
  }
}

class AlarmItem {
  final int id;
  final AlarmTag tag;
  final String stockName;
  final double? sentimentScore;
  final String title;
  final String body;
  final DateTime createdAt;
  bool isRead;
  bool isStarred;

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

  factory AlarmItem.fromResponse(NotificationResponse r) {
    return AlarmItem(
      id: r.id,
      tag: _tagFromType(r.type),
      stockName: '',
      sentimentScore: null,
      title: r.title,
      body: r.body ?? '',
      createdAt: r.createdAt,
      isRead: r.read,
      isStarred: r.star,
    );
  }

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

  String timeLabelNow(DateTime now) {
    final diff = now.difference(createdAt);
    if (diff.isNegative) return '방금 전';
    final minutes = diff.inMinutes;
    final hours = diff.inHours;
    final days = diff.inDays;
    if (minutes <= 5) return '방금 전';
    if (minutes < 60) return '${minutes}분 전';
    if (hours < 24) return '${hours}시간 전';
    return '${days}일 전';
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

  void _sortByNewest() {
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<AlarmItem> _mergeAndSort(List<AlarmItem> a, List<AlarmItem> b) {
    final merged = [...a, ...b];
    merged.sort((x, y) => y.createdAt.compareTo(x.createdAt));
    return merged;
  }

  void addOrUpdateAlarm(AlarmItem newItem) {
    setState(() {
      final idx = _items.indexWhere((e) => e.id == newItem.id);
      if (idx >= 0) {
        final old = _items[idx];
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

  void _deleteItem(int id) {
    setState(() {
      _items.removeWhere((e) => e.id == id);
    });
  }

  void _toggleStar(int id) {
    setState(() {
      final idx = _items.indexWhere((e) => e.id == id);
      if (idx < 0) return;
      final it = _items[idx];
      _items[idx] = it.copyWith(isStarred: !it.isStarred);
      _sortByNewest();
    });
  }

  AlarmTag _tagBySentiment(double sentimentScore) {
    if (sentimentScore <= 35) return AlarmTag.highRisk;
    if (sentimentScore <= 55) return AlarmTag.risk;
    return AlarmTag.keyword;
  }

  Future<List<String>> _fetchFavoriteStocks() async {
    return ['삼성전자', 'NAVER', '카카오'];
  }

  Future<List<String>> _fetchUserKeywordsFromFavorites() async {
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
        'star': false,
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
        id: createdAt.millisecondsSinceEpoch,
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
        'body': '공정거래위원회 조사 착수, 관련 키워드 "규제", "조사" 급증 중',
        'createdAt': now.subtract(const Duration(minutes: 32)),
        'read': false,
        'star': false,
      },
      {
        'stock': '삼성전자',
        'title': '삼성전자 "반도체" 키워드 급등',
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
      results.add(AlarmItem(
        id: createdAt.millisecondsSinceEpoch,
        tag: AlarmTag.keyword,
        stockName: stock,
        title: n['title'] as String,
        body: n['body'] as String,
        createdAt: createdAt,
        isRead: n['read'] as bool,
        isStarred: n['star'] as bool,
      ));
    }
    return results;
  }

  @override
  void initState() {
    super.initState();
    //_initDummyItems(); // 더미데이터 사용 시 이걸로 교체
    _initFromApi(); // API 연결 시 이걸로 교체

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

  Future<void> _initFromApi() async {
    try {
      final result = await NotificationApiService.getNotifications();
      if (!mounted) return;
      setState(() {
        _items = result.map(AlarmItem.fromResponse).toList();
        _sortByNewest();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('알림을 불러오지 못했습니다: $e')),
        );
      }
    }
  }

  // ===== 더미 모드 사용 시 =====
  /*
  Future<void> _deleteItemWithApi(int id) async {
    _deleteItem(id); // 더미: 바로 로컬에서 삭제
  }
   */

// ===== API 연결 시 아래 주석 해제 =====
  // /*
  Future<void> _deleteItemWithApi(int id) async {
    try {
      final ok = await NotificationApiService.deleteNotification(id);
      if (!mounted) return;
      if (ok) {
        _deleteItem(id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림 삭제에 실패했습니다.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('deleteNotification failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알림 삭제 중 오류가 발생했습니다.')),
      );
    }
  }
  // */

// ===== 더미 모드 사용 시 =====
  /*
  Future<void> _toggleStarWithApi(int id) async {
    setState(() {
      final idx = _items.indexWhere((e) => e.id == id);
      if (idx >= 0) {
        _items[idx] = _items[idx].copyWith(isStarred: !_items[idx].isStarred);
      }
    });
  }
  */

// ===== API 연결 시 아래 주석 해제 =====
  // /*
  Future<void> _toggleStarWithApi(int id) async {
    try {
      final newValue = await NotificationApiService.toggleImportant(id);
      // API가 성공 시 bool, 실패 시 throw한다고 가정
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((e) => e.id == id);
        if (idx >= 0) {
          _items[idx] = _items[idx].copyWith(isStarred: newValue); // copyWith으로 불변 갱신
        }
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('toggleImportant failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('중요 표시 변경에 실패했습니다.')),
      );
      // 로컬 상태 변경 없음
    }
  }
// */

  int get _totalCount => _items.length;
  int get _starCount => _items.where((e) => e.isStarred).length;
  int get _unreadCount => _items.where((e) => !e.isRead).length;
  int get _riskTabCount =>
      _items.where((e) => e.tag == AlarmTag.highRisk || e.tag == AlarmTag.risk).length;
  int get _keywordCount => _items.where((e) => e.tag == AlarmTag.keyword).length;

  // ===== 더미 모드 사용 시 =====
  /*
  void _markAllRead() {
    setState(() {
      _items = _items.map((it) => it.copyWith(isRead: true)).toList();
    });
  }
  */

// ===== API 연결 시 아래 주석 해제 =====
  // /*
  void _markAllRead() async {
    try {
      await NotificationApiService.markAsRead(id: null);
      if (!mounted) return;
      setState(() {
        _items = _items.map((it) => it.copyWith(isRead: true)).toList();
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('markAsRead(all) failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모두 읽음 처리에 실패했습니다.')),
      );
    }
  } // */

  Future<void> _openDetailAndMarkRead(AlarmItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AlarmDetailPage(item: item)),
    );

    if (!mounted) return;

    final idx = _items.indexWhere((e) => e.id == item.id);
    if (idx < 0 || _items[idx].isRead) return;

    try {
      await NotificationApiService.markAsRead(id: item.id);
      if (!mounted) return;
      setState(() {
        final freshIdx = _items.indexWhere((e) => e.id == item.id);
        if (freshIdx >= 0) {
          _items[freshIdx] = _items[freshIdx].copyWith(isRead: true);
        }
      });
    } catch (e) {
      debugPrint('Failed to mark as read: $e');
    }
  }


  /// 탭 순서: 0 전체 / 1 중요 / 2 읽지 않음 / 3 긴급/리스크
  List<AlarmItem> _filteredItems(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return _items.where((e) => e.isStarred).toList();
      case 2:
        return _items.where((e) => !e.isRead).toList();
      case 3:
      // ✅ 3번 수정: tag가 명시적으로 highRisk/risk인 것만 포함
        return _items
            .where((e) => e.tag == AlarmTag.highRisk || e.tag == AlarmTag.risk)
            .toList();
      case 4:
        return _items.where((e) => e.tag == AlarmTag.keyword).toList();
      default:
        return _items;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
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
                tabAlignment: TabAlignment.start,
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                labelColor: Colors.black87,
                unselectedLabelColor: Colors.black45,
                indicatorColor: Colors.black87,
                indicatorWeight: 2.6,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: [
                  Tab(text: '전체 ($_totalCount)'),
                  Tab(text: '중요 ($_starCount)'),
                  Tab(text: '읽지 않음 ($_unreadCount)'),
                  Tab(text: '긴급/리스크 ($_riskTabCount)'),
                  Tab(text: '키워드 ($_keywordCount)'),
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
                    onDelete: () => _deleteItemWithApi(item.id),
                    onToggleStar: () => _toggleStarWithApi(item.id),
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
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.52,
        children: [
          CustomSlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: const Color(0xFF83848B),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
            child: SvgPicture.asset(
              'assets/images/delete.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
          CustomSlidableAction(
            onPressed: (_) => onToggleStar(),
            backgroundColor: const Color(0xFF0EC272),
            child: SvgPicture.asset(
              'assets/images/favorites.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
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

  // ✅ 2번 수정: 읽음 여부와 무관하게 tag 기준으로만 배경색 결정
  Color get _bgColor {
    if (item.tag == AlarmTag.highRisk || item.tag == AlarmTag.risk) {
      return const Color(0xFFD6FCEB); // 리스크는 항상 초록
    }
    return Colors.white;
  }

  // ✅ 2번 수정: 테두리도 동일하게 tag 기준
  Color get _borderColor {
    if (item.tag == AlarmTag.highRisk || item.tag == AlarmTag.risk) {
      return const Color(0xFF0EC272);
    }
    return const Color(0xFFE5E7EB);
  }

  Widget _leadingDot() {
    return SizedBox(
      width: 26,
      child: Padding(
        padding: const EdgeInsets.only(top: 30), // ← 숫자 조절로 위치 변경
        child: Align(
          alignment: Alignment.topCenter,
          child: _isUnread
              ? Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF0EC272),
              shape: BoxShape.circle,
            ),
          )
              : const SizedBox.shrink(),
        ),
      ),
    );
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
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
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
                      ),
                      const SizedBox(width: 8),
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

  Color get _tagColor {
    switch (item.tag) {
      case AlarmTag.highRisk: return const Color(0xFFFF4D4D);
      case AlarmTag.risk:     return const Color(0xFFFF9500);
      case AlarmTag.keyword:  return const Color(0xFF0EC272);
    }
  }

  String get _tagLabel {
    switch (item.tag) {
      case AlarmTag.highRisk: return '긴급';
      case AlarmTag.risk:     return '긴급';
      case AlarmTag.keyword:  return '키워드';
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = item.timeLabelNow(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '알림 상세',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 태그 + 시간
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _tagColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _tagLabel,
                    style: TextStyle(
                      color: _tagColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  timeLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // 제목
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
                height: 1.35,
              ),
            ),
            if (item.stockName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.stockName,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 18),
            const Divider(color: Color(0xFFE5E7EB), height: 1),
            const SizedBox(height: 18),
            // 본문
            Text(
              item.body,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}