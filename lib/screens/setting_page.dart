// lib/screens/setting_page.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/user_api_service.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  String _nickname = '닉네임';
  String _email = 'email@gmail.com';
  String? _photoUrl;

  bool _riskAlert = true;
  bool _goodNewsAlert = true;
  bool _favoriteAlert = true;

  bool get _allPush => _riskAlert && _goodNewsAlert && _favoriteAlert;

  String _dndTimeRangeLabel = '23:00 ~ 07:00';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadServerSettings();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userProfile = await UserApiService.getProfile();
      if (!mounted) return;
      setState(() {
        _nickname = userProfile.nickname;
        _email = userProfile.email;
        _photoUrl = userProfile.imgUrl;
      });
    } catch (e) {
      debugPrint('서버 프로필 로드 실패: $e');
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      final account = await googleSignIn.signInSilently();
      if (account != null && mounted) {
        setState(() {
          _nickname = (account.displayName ?? '').isEmpty ? '사용자' : account.displayName!;
          _email = account.email.isEmpty ? 'email@gmail.com' : account.email;
          _photoUrl = account.photoUrl;
        });
      }
    }
  }

  Future<void> _loadServerSettings() async {
    try {
      final settings = await UserApiService.getSettings();
      if (!mounted) return;
      setState(() {
        _riskAlert = settings.riskOnly;
        _goodNewsAlert = settings.positiveOnly;
        _favoriteAlert = settings.interestOnly;
        final rawStart = settings.dndStart ?? '23:00:00';
        final rawFinish = settings.dndFinish ?? '07:00:00';
        final start = rawStart.length >= 5 ? rawStart.substring(0, 5) : '23:00';
        final finish = rawFinish.length >= 5 ? rawFinish.substring(0, 5) : '07:00';
        _dndTimeRangeLabel = '$start ~ $finish';
      });
    } catch (e) {
      debugPrint('서버 설정 로드 실패: $e');
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      await googleSignIn.signOut();
      try {
        await googleSignIn.disconnect();
      } catch (_) {}
    } catch (e) {
      debugPrint('로그아웃 중 에러: $e');
    }
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _toggleAllPush(bool value) {
    setState(() {
      _riskAlert = value;
      _goodNewsAlert = value;
      _favoriteAlert = value;
    });
    UserApiService.updateSettings({
      'push': value,
      'risk_only': value,
      'positive_only': value,
      'interest_only': value,
    });
  }

  void _toggleRisk(bool value) {
    setState(() => _riskAlert = value);
    UserApiService.updateSettings({'risk_only': value, 'push': _allPush});
  }

  void _toggleGoodNews(bool value) {
    setState(() => _goodNewsAlert = value);
    UserApiService.updateSettings({'positive_only': value, 'push': _allPush});
  }

  void _toggleFavorite(bool value) {
    setState(() => _favoriteAlert = value);
    UserApiService.updateSettings({'interest_only': value, 'push': _allPush});
  }

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
        backgroundColor: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        title: const Text(
          '초기화 전 반드시 확인해주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: const Text(
          '서비스를 초기화하면 모든 관심 종목과 알림 설정이\n영구적으로 삭제되며 복구할 수 없습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.5, color: Colors.black87),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD3D3D3),
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('취소',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EC272),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('초기화',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      // TODO: API 연결 후 실제 초기화 API 호출로 교체
      // await UserApiService.deleteUser();
      if (!mounted) return;
      setState(() {
        _riskAlert = false;
        _goodNewsAlert = false;
        _favoriteAlert = false;
        _dndTimeRangeLabel = '23:00 ~ 07:00';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('설정이 초기화되었습니다.'),
          duration: Duration(milliseconds: 1200),
        ),
      );
    }
  }

  Future<void> _openAboutDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        final maxH = MediaQuery.of(context).size.height * 0.95;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
          const EdgeInsets.only(left: 18, right: 18, top: 20, bottom: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 28, 18, 22),
                      decoration:
                      const BoxDecoration(color: Color(0xFF0EC272)),
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/Capston.png',
                            height: 75,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                            const SizedBox(height: 75),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'About Our Team & Stack',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Our Team',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _teamRow('이수호', 'Product Manager', '백혜경', 'Frontend'),
                          const SizedBox(height: 8),
                          _teamRow('신동빈', 'Data engineer', '이상진', 'Backend'),
                          const SizedBox(height: 8),
                          _teamRow('최윤형', 'Data/Design', '하성우', 'Data'),
                          const SizedBox(height: 14),
                          Divider(color: Colors.grey.shade300, height: 1),
                          const SizedBox(height: 14),
                          const Text('Tech Stack',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          const Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
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
                          const Text('Disclaimer',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          const Text(
                            '본 앱은 상업적 목적이 아닌 학습 및 프로젝트 목적으로\n제작된 비영리 애플리케이션입니다.',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.6,
                                color: Colors.black),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '일부 콘텐츠는 공개 자료를 참고하였으며,\n출처가 명확하지 않은 자료가 포함될 수 있습니다.',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.6,
                                color: Colors.black),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '본 앱에서 제공되는 정보는 투자 참고용이며,\n실제 투자 판단에 대한 책임은 사용자 본인에게 있습니다.',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.6,
                                color: Colors.black),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '상업적 이용을 의도하지 않으며,\n문제 발생 시 즉시 수정 또는 삭제하겠습니다.',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.6,
                                color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
      children: [
        Text(name,
            style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '($role)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF2F5F6);
    const green = Color(0xFF0EC272);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back,
                        size: 28, color: Colors.black),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('설정',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/push_test'),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_none,
                            size: 30, color: Colors.black),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 16,
                            height: 16,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                                color: green, shape: BoxShape.circle),
                            child: const Text('2',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.settings,
                        size: 30, color: Colors.black),
                  ),
                ],
              ),

              const SizedBox(height: 22),
              const Text('내 프로필',
                  style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),

              _CardSection(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      backgroundImage: (_photoUrl != null &&
                          _photoUrl!.isNotEmpty)
                          ? NetworkImage(_photoUrl!)
                          : null,
                      child: (_photoUrl == null || _photoUrl!.isEmpty)
                          ? const Text('G',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87))
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nickname,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _email,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => _logout(context),
                  child: Text(
                    '로그아웃',
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              const Text('알림 설정',
                  style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),

              _CardSection(
                child: Column(
                  children: [
                    _SwitchRow(
                        title: '앱 전체 푸시 알림',
                        value: _allPush,
                        onChanged: _toggleAllPush),
                    const Divider(height: 1, color: Color(0xFFD3D3D3)),
                    _SwitchRow(
                        title: '리스크 알림',
                        value: _riskAlert,
                        onChanged: _toggleRisk),
                    _SwitchRow(
                        title: '호재 알림',
                        value: _goodNewsAlert,
                        onChanged: _toggleGoodNews),
                    _SwitchRow(
                        title: '관심 종목 알림',
                        value: _favoriteAlert,
                        onChanged: _toggleFavorite),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _CardSection(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('야간 방해 금지 모드',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                        ),
                        GestureDetector(
                          onTap: _openDndDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _dndTimeRangeLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFD3D3D3)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _openResetDialog,
                      child: const Row(
                        children: [
                          Text(
                            '정보 초기화',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 42),

              Center(
                child: TextButton(
                  onPressed: _openAboutDialog,
                  child: const Text(
                    'Made by KT Capstone',
                    style: TextStyle(
                      color: green,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                      decorationColor: green,
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

class _CardSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _CardSection({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
    const green = Color(0xFF0EC272);
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          SizedBox(
            width: 46,
            height: 26,
            child: FittedBox(
              fit: BoxFit.fill,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.white,
                activeTrackColor: green,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFE5E7EB),
                trackOutlineColor:
                WidgetStateProperty.all(Colors.transparent),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipTag extends StatelessWidget {
  final String text;
  const _ChipTag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0EC272),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12),
      ),
    );
  }
}