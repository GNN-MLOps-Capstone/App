import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock/services/user_api_service.dart';

void _mockSecureStorage({String? token = 'test_token'}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (MethodCall call) async {
      if (call.method == 'read') return token;
      if (call.method == 'write') return null;
      return null;
    },
  );
}

http.Response _jsonResponse(Object body, int statusCode) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.Response.bytes(bytes, statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
  });

  // ── AuthResponse.fromJson ────────────────────────────────────
  group('AuthResponse.fromJson', () {
    test('정상 JSON 파싱', () {
      final json = {
        'access_token': 'token_abc',
        'token_type': 'Bearer',
        'user': {
          'id': 1,
          'google_id': 'google_123',
          'email': 'test@test.com',
          'nickname': '홍길동',
          'img_url': 'https://example.com/img.jpg',
        },
      };
      final auth = AuthResponse.fromJson(json);

      expect(auth.accessToken, 'token_abc');
      expect(auth.tokenType, 'Bearer');
      expect(auth.user.nickname, '홍길동');
      expect(auth.user.email, 'test@test.com');
    });

    test('token_type 누락 시 기본값 Bearer', () {
      final json = {
        'access_token': 'token_abc',
        'user': {
          'id': 1,
          'google_id': 'g',
          'email': 'e@e.com',
          'nickname': '홍',
        },
      };
      final auth = AuthResponse.fromJson(json);
      expect(auth.tokenType, 'Bearer');
    });
  });

  // ── UserResponse.fromJson ────────────────────────────────────
  group('UserResponse.fromJson', () {
    test('정상 JSON 파싱', () {
      final json = {
        'id': 42,
        'google_id': 'google_abc',
        'email': 'user@test.com',
        'nickname': '테스트유저',
        'img_url': 'https://example.com/photo.jpg',
      };
      final user = UserResponse.fromJson(json);

      expect(user.id, 42);
      expect(user.googleId, 'google_abc');
      expect(user.email, 'user@test.com');
      expect(user.nickname, '테스트유저');
      expect(user.imgUrl, 'https://example.com/photo.jpg');
    });

    test('img_url null 허용', () {
      final json = {
        'id': 1,
        'google_id': 'g',
        'email': 'e@e.com',
        'nickname': '닉네임',
      };
      final user = UserResponse.fromJson(json);
      expect(user.imgUrl, isNull);
    });

    test('id 누락 시 기본값 0', () {
      final json = {
        'google_id': 'g',
        'email': 'e@e.com',
        'nickname': '닉',
      };
      final user = UserResponse.fromJson(json);
      expect(user.id, 0);
    });
  });

  // ── SettingResponse.fromJson ─────────────────────────────────
  group('SettingResponse.fromJson', () {
    test('정상 JSON 파싱', () {
      final json = {
        'push': true,
        'risk_only': false,
        'positive_only': true,
        'interest_only': false,
        'night_push_prohibit': true,
        'dnd_start': '22:00',
        'dnd_finish': '08:00',
      };
      final setting = SettingResponse.fromJson(json);

      expect(setting.push, true);
      expect(setting.riskOnly, false);
      expect(setting.positiveOnly, true);
      expect(setting.nightPushProhibit, true);
      expect(setting.dndStart, '22:00');
      expect(setting.dndFinish, '08:00');
    });

    test('필드 누락 시 기본값 false', () {
      final setting = SettingResponse.fromJson({});

      expect(setting.push, false);
      expect(setting.riskOnly, false);
      expect(setting.positiveOnly, false);
      expect(setting.interestOnly, false);
      expect(setting.nightPushProhibit, false);
      expect(setting.dndStart, isNull);
      expect(setting.dndFinish, isNull);
    });
  });

  // ── UserApiService.checkHealth ───────────────────────────────
  group('UserApiService.checkHealth', () {
    test('서버 200 응답 시 true 반환', () async {
      final client = MockClient((_) async => http.Response('ok', 200));
      final result = await http.runWithClient(
        () => UserApiService.checkHealth(),
        () => client,
      );
      expect(result, true);
    });

    test('서버 500 응답 시 false 반환', () async {
      final client = MockClient((_) async => http.Response('error', 500));
      final result = await http.runWithClient(
        () => UserApiService.checkHealth(),
        () => client,
      );
      expect(result, false);
    });

    test('네트워크 오류 시 false 반환', () async {
      final client = MockClient((_) async => throw Exception('connection refused'));
      final result = await http.runWithClient(
        () => UserApiService.checkHealth(),
        () => client,
      );
      expect(result, false);
    });
  });

  // ── UserApiService.getProfile ────────────────────────────────
  group('UserApiService.getProfile', () {
    test('정상 응답 파싱', () async {
      _mockSecureStorage();
      final body = {
        'id': 1,
        'google_id': 'google_abc',
        'email': 'user@test.com',
        'nickname': '홍길동',
      };
      final client = MockClient((_) async => _jsonResponse(body, 200));

      final user = await http.runWithClient(
        () => UserApiService.getProfile(),
        () => client,
      );

      expect(user.nickname, '홍길동');
      expect(user.email, 'user@test.com');
    });

    test('404 응답 시 UserApiException(404) 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('not found', 404));

      expect(
        () => http.runWithClient(
          () => UserApiService.getProfile(),
          () => client,
        ),
        throwsA(isA<UserApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('500 응답 시 UserApiException 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('error', 500));

      expect(
        () => http.runWithClient(
          () => UserApiService.getProfile(),
          () => client,
        ),
        throwsA(isA<UserApiException>()),
      );
    });
  });

  // ── UserApiService.getSettings ───────────────────────────────
  group('UserApiService.getSettings', () {
    test('정상 응답 파싱', () async {
      _mockSecureStorage();
      final body = {
        'push': true,
        'risk_only': false,
        'positive_only': false,
        'interest_only': true,
        'night_push_prohibit': false,
      };
      final client = MockClient((_) async => _jsonResponse(body, 200));

      final setting = await http.runWithClient(
        () => UserApiService.getSettings(),
        () => client,
      );

      expect(setting.push, true);
      expect(setting.interestOnly, true);
    });

    test('404 응답 시 UserApiException(404) 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('not found', 404));

      expect(
        () => http.runWithClient(
          () => UserApiService.getSettings(),
          () => client,
        ),
        throwsA(isA<UserApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });

  // ── UserApiService.updateSettings ───────────────────────────
  group('UserApiService.updateSettings', () {
    test('정상 응답 시 변경된 설정 반환', () async {
      _mockSecureStorage();
      final body = {
        'push': false,
        'risk_only': true,
        'positive_only': false,
        'interest_only': false,
        'night_push_prohibit': false,
      };
      final client = MockClient((_) async => _jsonResponse(body, 200));

      final setting = await http.runWithClient(
        () => UserApiService.updateSettings({'push': false, 'risk_only': true}),
        () => client,
      );

      expect(setting.push, false);
      expect(setting.riskOnly, true);
    });

    test('500 응답 시 UserApiException 발생', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('error', 500));

      expect(
        () => http.runWithClient(
          () => UserApiService.updateSettings({'push': false}),
          () => client,
        ),
        throwsA(isA<UserApiException>()),
      );
    });
  });

  // ── UserApiService.deleteUser ────────────────────────────────
  group('UserApiService.deleteUser', () {
    test('204 응답 시 true 반환', () async {
      _mockSecureStorage();
      final client = MockClient((_) async => http.Response('', 204));

      final result = await http.runWithClient(
        () => UserApiService.deleteUser(),
        () => client,
      );

      expect(result, true);
    });

    test('204가 아닌 응답 시 UserApiException 발생', () async {
      _mockSecureStorage();
      final client = MockClient(
        (_) async => http.Response('already deleted', 200),
      );

      expect(
        () =>
            http.runWithClient(() => UserApiService.deleteUser(), () => client),
        throwsA(
          isA<UserApiException>()
              .having((e) => e.statusCode, 'statusCode', 200)
              .having(
                (e) => e.message,
                'message',
                allOf(
                  contains('회원 탈퇴 요청에 실패했습니다'),
                  contains('already deleted'),
                ),
              ),
        ),
      );
    });
  });
}
