import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock/services/api_auth_headers.dart';

void _mockSecureStorage({String? token}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (MethodCall call) async {
      if (call.method == 'read') return token;
      return null;
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── getAuthHeaders ───────────────────────────────────────────
  group('getAuthHeaders', () {
    test('유효한 토큰이 있을 때 Authorization 헤더 반환', () async {
      _mockSecureStorage(token: 'valid_token_123');

      final headers = await getAuthHeaders();

      expect(headers['Authorization'], 'Bearer valid_token_123');
      expect(headers['Content-Type'], 'application/json');
    });

    test('토큰이 null이면 예외 발생', () async {
      _mockSecureStorage(token: null);

      expect(
        () => getAuthHeaders(),
        throwsA(isA<Exception>()),
      );
    });

    test('토큰이 공백만 있으면 예외 발생', () async {
      _mockSecureStorage(token: '   ');

      expect(
        () => getAuthHeaders(),
        throwsA(isA<Exception>()),
      );
    });

    test('토큰이 빈 문자열이면 예외 발생', () async {
      _mockSecureStorage(token: '');

      expect(
        () => getAuthHeaders(),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── getAccessToken ───────────────────────────────────────────
  group('getAccessToken', () {
    test('토큰이 있을 때 토큰 문자열 반환', () async {
      _mockSecureStorage(token: 'my_token');

      final token = await getAccessToken();

      expect(token, 'my_token');
    });

    test('토큰이 없을 때 null 반환', () async {
      _mockSecureStorage(token: null);

      final token = await getAccessToken();

      expect(token, isNull);
    });
  });
}
