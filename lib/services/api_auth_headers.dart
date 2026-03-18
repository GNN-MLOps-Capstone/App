import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();

Future<Map<String, String>> getAuthHeaders() async {
  final token = await _storage.read(key: 'access_token');
  return {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

Future<String?> getAccessToken() async {
  return _storage.read(key: 'access_token');
}
