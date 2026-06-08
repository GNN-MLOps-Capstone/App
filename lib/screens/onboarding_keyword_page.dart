import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'main_page.dart';
import '../services/onboarding_api_service.dart';

class OnboardingKeywordPage extends StatefulWidget {
  final String userName;

  const OnboardingKeywordPage({super.key, required this.userName});

  @override
  State<OnboardingKeywordPage> createState() => _OnboardingKeywordPageState();
}

class _OnboardingKeywordPageState extends State<OnboardingKeywordPage> {
  static const _storage = FlutterSecureStorage();

  final TextEditingController _searchController = TextEditingController();

  List<OnboardingKeyword> _keywords = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _completing = false;
  int _searchGeneration = 0;

  final Set<String> _selected = {}; // keyword word

  @override
  void initState() {
    super.initState();
    _loadKeywords();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadKeywords({String? q}) async {
    final generation = ++_searchGeneration;
    setState(() => _isLoading = true);
    try {
      final result = await OnboardingApiService.getTopKeywords(q: q);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _keywords = result;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _keywords = [];
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim();
    setState(() => _isSearching = q.isNotEmpty);
    _loadKeywords(q: q.isEmpty ? null : q);
  }

  Future<void> _onComplete() async {
    setState(() => _completing = true);
    try {
      if (_selected.isNotEmpty) {
        await OnboardingApiService.saveSelectedKeywords(_selected.toList());
      }
      await _storage.write(key: 'onboarding_complete', value: 'true');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => StockHomeScreen(userName: widget.userName)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            value: 1.0,
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
                    '관심 키워드를\n선택하세요',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '뉴스에 많이 등장한 키워드예요',
                    style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
                  ),
                  const SizedBox(height: 20),
                  // 검색창
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Color(0xFF9E9E9E), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                            decoration: const InputDecoration(
                              hintText: '키워드 검색',
                              hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBDBDBD)),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_isSearching)
                          GestureDetector(
                            onTap: () => _searchController.clear(),
                            child: const Icon(Icons.close, color: Color(0xFF9E9E9E), size: 18),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // 선택된 키워드 칩
            if (_selected.isNotEmpty) ...[
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _selected.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final word = _selected.elementAt(i);
                    return GestureDetector(
                      onTap: () => setState(() => _selected.remove(word)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C37A),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(word, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 4),
                            const Icon(Icons.close, size: 14, color: Colors.white),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 키워드 목록
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C37A)))
                  : _keywords.isEmpty
                      ? Center(
                          child: Text(
                            _isSearching
                                ? '"${_searchController.text.trim()}" 검색 결과가 없어요'
                                : '키워드를 불러오지 못했어요',
                            style: const TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _keywords.map((kw) {
                              final isSelected = _selected.contains(kw.word);
                              return GestureDetector(
                                onTap: () => setState(() {
                                  isSelected ? _selected.remove(kw.word) : _selected.add(kw.word);
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFE8F8F1) : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF00C37A) : const Color(0xFFE0E0E0),
                                    ),
                                  ),
                                  child: Text(
                                    kw.word,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected ? const Color(0xFF00C37A) : const Color(0xFF333333),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
            ),

            // 완료 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _completing ? null : _onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C37A),
                    disabledBackgroundColor: const Color(0xFFBDBDBD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _completing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _selected.isEmpty ? '건너뛰기' : '완료 (${_selected.length}개)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
