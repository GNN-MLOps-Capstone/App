import 'package:flutter/material.dart';
import 'main_page.dart';
import 'onboarding_stock_page.dart';
import '../services/onboarding_api_service.dart';

class OnboardingThemePage extends StatefulWidget {
  final String userName;

  const OnboardingThemePage({super.key, required this.userName});

  @override
  State<OnboardingThemePage> createState() => _OnboardingThemePageState();
}

class _OnboardingThemePageState extends State<OnboardingThemePage> {
  List<OnboardingTheme> _mainThemes = [];
  List<String> _etcCategories = [];
  bool _isLoading = true;
  String? _errorMessage;

  final Set<String> _selected = {};
  bool _isEtcExpanded = false;

  bool get _hasEtcSelected => _etcCategories.any(_selected.contains);
  bool get canProceed => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  Future<void> _loadThemes() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final themes = await OnboardingApiService.getThemes();
      if (!mounted) return;
      setState(() {
        _mainThemes = themes.where((t) => t.name != '기타').toList();
        final etc = themes.firstWhere(
          (t) => t.name == '기타',
          orElse: () => OnboardingTheme(id: -1, name: '기타', displayOrder: 99, categories: []),
        );
        _etcCategories = etc.categories;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Map<String, List<String>> _buildThemeCategoryMap() {
    return {for (final t in _mainThemes) t.name: t.categories};
  }

  Future<void> _onNext() async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingStockPage(
          userName: widget.userName,
          selectedThemes: Set.from(_selected),
          themeCategoryMap: _buildThemeCategoryMap(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, size: 24, color: Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            value: 1 / 3,
                            backgroundColor: Color(0xFFE0E0E0),
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C37A)),
                            minHeight: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    '관심 있는 투자 테마를\n선택하세요',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1개 이상 선택해주세요',
                    style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C37A)))
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, color: Color(0xFFE53935), size: 40),
                                const SizedBox(height: 12),
                                const Text('테마를 불러오지 못했어요', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                                const SizedBox(height: 8),
                                Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)), textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadThemes,
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C37A), foregroundColor: Colors.white),
                                  child: const Text('다시 시도'),
                                ),
                              ],
                            ),
                          ),
                        )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _mainThemes.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                              itemBuilder: (context, index) {
                                final theme = _mainThemes[index].name;
                                final isSelected = _selected.contains(theme);
                                final borderRadius = index == 0
                                    ? const BorderRadius.vertical(top: Radius.circular(12))
                                    : BorderRadius.zero;
                                return _ThemeRow(
                                  label: theme,
                                  isSelected: isSelected,
                                  borderRadius: borderRadius,
                                  onTap: () => setState(() {
                                    isSelected ? _selected.remove(theme) : _selected.add(theme);
                                  }),
                                );
                              },
                            ),

                            if (_etcCategories.isNotEmpty) ...[
                              const Divider(height: 1, color: Color(0xFFEEEEEE)),
                              InkWell(
                                onTap: () => setState(() => _isEtcExpanded = !_isEtcExpanded),
                                borderRadius: _isEtcExpanded
                                    ? BorderRadius.zero
                                    : const BorderRadius.vertical(bottom: Radius.circular(12)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                  decoration: BoxDecoration(
                                    color: _hasEtcSelected ? const Color(0xFFE8F8F1) : Colors.transparent,
                                    borderRadius: _isEtcExpanded
                                        ? BorderRadius.zero
                                        : const BorderRadius.vertical(bottom: Radius.circular(12)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '기타',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: _hasEtcSelected
                                                ? const Color(0xFF00C37A)
                                                : const Color(0xFF1A1A1A),
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        _isEtcExpanded ? Icons.expand_less : Icons.expand_more,
                                        color: const Color(0xFF9E9E9E),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_isEtcExpanded)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF9F9F9),
                                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                                  ),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _etcCategories.map((category) {
                                      final isSelected = _selected.contains(category);
                                      return GestureDetector(
                                        onTap: () => setState(() {
                                          isSelected
                                              ? _selected.remove(category)
                                              : _selected.add(category);
                                        }),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: isSelected ? const Color(0xFFE8F8F1) : Colors.white,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFF00C37A)
                                                  : const Color(0xFFE0E0E0),
                                            ),
                                          ),
                                          child: Text(
                                            category,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: isSelected
                                                  ? const Color(0xFF00C37A)
                                                  : const Color(0xFF555555),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canProceed ? _onNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBDBDBD),
                    disabledBackgroundColor: const Color(0xFFBDBDBD),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ).copyWith(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                      (states) => canProceed ? const Color(0xFF00C37A) : const Color(0xFFBDBDBD),
                    ),
                  ),
                  child: const Text(
                    '다음',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  final String label;
  final bool isSelected;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  const _ThemeRow({
    required this.label,
    required this.isSelected,
    required this.borderRadius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F8F1) : Colors.transparent,
          borderRadius: borderRadius,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? const Color(0xFF00C37A) : const Color(0xFF1A1A1A),
                ),
              ),
            ),
            if (isSelected) const Icon(Icons.check, color: Color(0xFF00C37A), size: 20),
          ],
        ),
      ),
    );
  }
}
