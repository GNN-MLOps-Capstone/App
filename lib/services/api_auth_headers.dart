import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();

Future<Map<String, String>> getAuthHeaders() async {
  final token = await _storage.read(key: 'access_token');
  if (token == null || token.trim().isEmpty) {
    throw Exception(
      '액세스 토큰이 없습니다. 다시 로그인해주세요. 로그인 직후에도 반복되면 GOOGLE_CLIENT_ID가 서버 검증용 Google OAuth Web Client ID와 일치하는지 확인하세요.',
    );
  }
  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };
}

Future<String?> getAccessToken() async {
  return _storage.read(key: 'access_token');
}
