// lib/screens/setting_page.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  // ---------------------------
  // ✅ 프로필 정보 (GoogleSignIn 기반)
  // ---------------------------
  String _nickname = '닉네임';
  String _email = 'email@gmail.com';
  String? _photoUrl; // ✅ 추가: 구글 프로필 이미지 URL

  // ---------------------------
  // ✅ 알림 토글 상태 (UI만)
  // ---------------------------
  bool _riskAlert = true;
  bool _goodNewsAlert = true;
  bool _favoriteAlert = true;

  bool get _allPush => _riskAlert && _goodNewsAlert && _favoriteAlert;

  // ---------------------------
  // ✅ 야간 방해 금지 (일단 UI만)
  // ---------------------------
  String _dndTimeRangeLabel = '23:00 ~ 07:00';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      final account = await googleSignIn.signInSilently();

      if (!mounted) return;

      if (account != null) {
        setState(() {
          _nickname =
          (account.displayName ?? '').isEmpty ? '사용자' : account.displayName!;
          _email = account.email.isEmpty ? 'email@gmail.com' : account.email;
          _photoUrl = account.photoUrl; // ✅ 핵심
        });
      }
    } catch (_) {}
  }

  Future<void> _logout(BuildContext context) async {
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      await googleSignIn.signOut();
      // ✅ 계정 선택 다시 뜨게 하고 싶으면 disconnect까지 (추천)
      try {
        await googleSignIn.disconnect();
      } catch (_) {}
    } catch (e) {
      debugPrint('로그아웃 중 에러: $e');
    }

    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
          (route) => false,
    );
  }

  void _toggleAllPush(bool value) {
    setState(() {
      _riskAlert = value;
      _goodNewsAlert = value;
      _favoriteAlert = value;
    });
  }

  void _toggleRisk(bool value) => setState(() => _riskAlert = value);
  void _toggleGoodNews(bool value) => setState(() => _goodNewsAlert = value);
  void _toggleFavorite(bool value) => setState(() => _favoriteAlert = value);

  Future<void> _openDndDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('야간 방해 금지 모드'),
        content: const Text('추후 시간 설정 UI/알림 기능과 연결될 예정입니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _openResetDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        title: Column(
          children: const [
            Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 40),
            SizedBox(height: 10),
            Text('정보 초기화', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '서비스를 탈퇴하면\n모든 관심 종목과 알림 설정이\n영구적으로 삭제되며 복구할 수 없습니다.\n정말 탈퇴하시겠습니까?',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.35),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                backgroundColor: Colors.grey.shade200,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('취소'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: const Text('탈퇴하기'),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      setState(() {
        _riskAlert = false;
        _goodNewsAlert = false;
        _favoriteAlert = false;
        _dndTimeRangeLabel = '23:00 ~ 07:00';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('설정이 초기화되었습니다. (추후 즐겨찾기/데이터 삭제와 연동 예정)'),
          duration: Duration(milliseconds: 1200),
        ),
      );
    }
  }

  // ✅✅✅ "Made by KT Capstone" 눌렀을 때 팀 소개 모달 (+ Disclaimer)
  Future<void> _openAboutDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        final maxH = MediaQuery.of(context).size.height * 0.78;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF34D399), Color(0xFF22C55E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            children: [
                              Image.asset(
                                '/Users/hyegyoung/AndroidStudioProjects/StockApp/App/lib/screens/Capston.png',
                                // 'assets/images/Capston.png',
                                height: 70,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox(height: 70),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'About Our Team & Stack',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: Container(
                            width: double.infinity,
                            color: Colors.white,
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.group_outlined, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Our Team',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  _teamRow('이수호', 'Product Manager', '백혜경', 'Frontend'),
                                  const SizedBox(height: 8),
                                  _teamRow('신동빈', 'data engineer', '이상진', 'Backend'),
                                  const SizedBox(height: 8),
                                  _teamRow('최윤형', 'Data/Design', '하성우', 'Data'),

                                  const SizedBox(height: 14),
                                  Divider(color: Colors.grey.shade300, height: 1),
                                  const SizedBox(height: 14),

                                  Row(
                                    children: const [
                                      Icon(Icons.code, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Tech Stack',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: const [
                                      _ChipTag('Python'),
                                      _ChipTag('Docker'),
                                      _ChipTag('Flutter'),
                                      _ChipTag('Firebase'),
                                      _ChipTag('OneSignal'),
                                    ],
                                  ),

                                  const SizedBox(height: 14),
                                  Divider(color: Colors.grey.shade300, height: 1),
                                  const SizedBox(height: 14),

                                  // Disclaimer (제목 왼쪽 / 내용 중앙)
                                  Row(
                                    children: const [
                                      Icon(Icons.warning_amber_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Disclaimer',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  Center(
                                    child: const Text(
                                      '본 앱은 상업적 목적이 아닌 학습 및 프로젝트 목적으로\n'
                                          '제작된 비영리 애플리케이션입니다.\n'
                                          '일부 콘텐츠는 공개 자료를 참고하였으며,\n'
                                          '출처가 명확하지 않은 자료가 포함될 수 있습니다.\n'
                                          '본 앱에서 제공되는 정보는 투자 참고용이며,\n'
                                          '실제 투자 판단에 대한 책임은 사용자 본인에게 있습니다.\n'
                                          '상업적 이용을 의도하지 않으며,\n'
                                          '문제 발생 시 즉시 수정 또는 삭제하겠습니다.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.55,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  right: 10,
                  top: 10,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _teamRow(String name1, String role1, String name2, String role2) {
    return Row(
      children: [
        Expanded(child: _teamCell(name1, role1)),
        const SizedBox(width: 10),
        Expanded(child: _teamCell(name2, role2)),
      ],
    );
  }

  Widget _teamCell(String name, String role) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          name,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '($role)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF3F4F6);
    const green = Color(0xFF22C55E);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 바
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      '설정',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/push_test');
                    },
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_none_outlined, size: 26, color: Colors.black87),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: green, shape: BoxShape.circle),
                            child: const Text(
                              '2',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.settings, size: 26, color: green),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 내 프로필
              const Text('내 프로필', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: green,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // ✅ 프로필 이미지: Google photoUrl 있으면 표시, 없으면 기본
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty)
                          ? NetworkImage(_photoUrl!)
                          : null,
                      child: (_photoUrl == null || _photoUrl!.isEmpty)
                          ? const Text(
                        'G',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      )
                          : null,
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nickname,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // ✅ 간격 줄임 (기존 4 → 2)
                          const SizedBox(height: 2),

                          Text(
                            _email,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12, // ✅ 살짝 더 작게
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 10),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _logout(context),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.18),
                                foregroundColor: Colors.white,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 알림 설정
              const Text('알림 설정', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _CardSection(
                child: Column(
                  children: [
                    _SwitchRow(title: '앱 전체 푸시 알림', value: _allPush, onChanged: _toggleAllPush),
                    const Divider(height: 1),
                    _SwitchRow(title: '리스크 알림', value: _riskAlert, onChanged: _toggleRisk),
                    const Divider(height: 1),
                    _SwitchRow(title: '호재 알림', value: _goodNewsAlert, onChanged: _toggleGoodNews),
                    const Divider(height: 1),
                    _SwitchRow(title: '관심 종목 알림', value: _favoriteAlert, onChanged: _toggleFavorite),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 야간 방해 금지 모드
              _CardSection(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '야간 방해 금지 모드',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    GestureDetector(
                      onTap: _openDndDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          _dndTimeRangeLabel,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 정보 초기화
              _CardSection(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openResetDialog,
                  child: Row(
                    children: const [
                      Icon(Icons.warning_rounded, color: Color(0xFFEF4444)),
                      SizedBox(width: 8),
                      Text(
                        '정보 초기화',
                        style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 26),

              // About 모달
              Center(
                child: TextButton(
                  onPressed: _openAboutDialog,
                  child: const Text(
                    'Made by KT Capstone',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------
// ✅ 공용 UI 컴포넌트들
// ---------------------------
class _CardSection extends StatelessWidget {
  final Widget child;
  const _CardSection({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF22C55E);
    return Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        Switch(
          value: value,
          activeColor: green,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ChipTag extends StatelessWidget {
  final String text;
  const _ChipTag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}