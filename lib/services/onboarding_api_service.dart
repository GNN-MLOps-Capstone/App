import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'api_auth_headers.dart';

class OnboardingTheme {
  final int id;
  final String name;
  final int displayOrder;
  final List<String> categories;

  OnboardingTheme({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.categories,
  });

  factory OnboardingTheme.fromJson(Map<String, dynamic> json) {
    return OnboardingTheme(
      id: json['id'] as int,
      name: json['name'] as String,
      displayOrder: json['display_order'] as int,
      categories: (json['categories'] as List).cast<String>(),
    );
  }
}

class OnboardingKeyword {
  final int id;
  final String word;
  final int count;

  OnboardingKeyword({required this.id, required this.word, required this.count});

  factory OnboardingKeyword.fromJson(Map<String, dynamic> json) {
    return OnboardingKeyword(
      id: json['id'] as int,
      word: json['word'] as String,
      count: json['count'] as int,
    );
  }
}

class OnboardingApiService {
  static String get _baseUrl => ApiConfig.baseUrl;

  static Future<List<OnboardingTheme>> getThemes() async {
    final uri = Uri.parse('$_baseUrl/api/onboarding/themes');
    final res = await http
        .get(uri, headers: await getAuthHeaders())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list
          .cast<Map<String, dynamic>>()
          .map(OnboardingTheme.fromJson)
          .toList();
    }
    throw Exception('Failed to load onboarding themes: ${res.statusCode}');
  }

  static Future<List<OnboardingKeyword>> getTopKeywords({String? q}) async {
    final uri = Uri.parse('$_baseUrl/api/onboarding/keywords').replace(
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'limit': '20',
      },
    );
    final res = await http
        .get(uri, headers: await getAuthHeaders())
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list
          .cast<Map<String, dynamic>>()
          .map(OnboardingKeyword.fromJson)
          .toList();
    }
    throw Exception('Failed to load keywords: ${res.statusCode}');
  }

  static Future<void> saveSelectedKeywords(List<String> keywords) async {
    if (keywords.isEmpty) return;
    final uri = Uri.parse('$_baseUrl/api/onboarding/keywords');
    final res = await http
        .post(
          uri,
          headers: {
            ...await getAuthHeaders(),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'keywords': keywords
                .map((w) => {'original_keyword': w})
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Failed to save keywords: ${res.statusCode}');
    }
  }
}
