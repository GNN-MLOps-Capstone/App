import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// 유저 API 서비스
/// 
/// 백엔드 API 서버와 통신하여 유저 프로필, 설정을 처리 및 관리합니다.
/// 
/// 사용하는 테이블:
///   - users
class UserApiService {
  // API 서버 주소
  // 개발 환경: localhost
  // 배포 환경: 실제 서버 주소로 변경
  static const String _baseUrl = 'http://10.0.2.2:8000';
  static const _storage = FlutterSecureStorage();

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  
  /// 로그인 시 회원 정보 db에 저장
  static Future<AuthResponse> login(UserLoginRequest request) async {
    try {
      String? onesignalId = OneSignal.User.pushSubscription.id;
    
      // 2. 기존 request에 onesignalId를 포함한 새로운 request 생성 (혹은 필드 할당)
      final updatedRequest = UserLoginRequest(
        googleId: request.googleId,
        email: request.email,
        nickname: request.nickname,
        imgUrl: request.imgUrl,
        onesignalId: onesignalId, // 추출한 ID 주입
      );

      final uri = Uri.parse('$_baseUrl/api/users/login');
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updatedRequest.toJson()),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final authData = AuthResponse.fromJson(json.decode(response.body));
        await _storage.write(key: 'access_token', value: authData.accessToken);
        
        return authData;
      } else {
        throw UserApiException(
          'failed to upload data: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is UserApiException) rethrow;
      throw UserApiException('Network error: $e', 0);
    }
  }

  /// 유저 프로필 가져오기
  static Future<UserResponse> getProfile() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/users/profile');
      
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return UserResponse.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        throw UserApiException('User not found', 404);
      } else {
        throw UserApiException(
          'Failed to load profile: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is UserApiException) rethrow;
      throw UserApiException('Network error: $e', 0);
    }
  }

  /// 설정 가져오기
  static Future<SettingResponse> getSettings() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/users/settings');
      
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return SettingResponse.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        throw UserApiException('User not found', 404);
      } else {
        throw UserApiException(
          'Failed to load settings: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is UserApiException) rethrow;
      throw UserApiException('Network error: $e', 0);
    }
  }

  /// 설정 변경시 변경된 설정 db에 저장
  static Future<SettingResponse> updateSettings(Map<String, dynamic> updateData) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/users/settings');
      
      final response = await http.patch(
        uri,
        headers: await _getHeaders(),
        body: json.encode(updateData),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return SettingResponse.fromJson(json.decode(response.body));
      } else {
        throw UserApiException(
          'Failed to update settings: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is UserApiException) rethrow;
      throw UserApiException('Network error: $e', 0);
    }
  }

  /// 회원 탈퇴시 회원 정보 삭제
  static Future<bool> deleteUser() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/users');
      
      final response = await http.delete(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 204;
    } catch (e) {
      if (e is UserApiException) rethrow;
      throw UserApiException('Network error: $e', 0);
    }
  }

  /// 서버 상태 확인
  static Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$_baseUrl/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

/// 유저 API 예외
class UserApiException implements Exception {
  final String message;
  final int statusCode;
  
  UserApiException(this.message, this.statusCode);
  
  @override
  String toString() => 'UserApiException: $message (status: $statusCode)';
}


/// API 응답을 담는 데이터 클래스입니다.
class AuthResponse {
  final String accessToken;
  final String tokenType;
  final UserResponse user;

  AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] ?? "Bearer",
      user: UserResponse.fromJson(json['user']), // 내부에 user 정보 포함
    );
  }
}

/// 유저 프로필 모델
class UserResponse {
  final String googleId;
  final String email;
  final String nickname;
  final String? imgUrl;

  UserResponse({
    required this.googleId,
    required this.email,
    required this.nickname,
    this.imgUrl,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      googleId: json['google_id'] as String,
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      imgUrl: json['img_url'] as String?, // 서버 컬럼명 img_url 반영
    );
  }
}
/// 설정 모델
/// 
/// API 응답을 담는 데이터 클래스입니다.
class SettingResponse {
  final bool push;
  final bool riskOnly;
  final bool positiveOnly;
  final bool interestOnly;
  final bool nightPushProhibit;
  final String? dndStart;
  final String? dndFinish;

  SettingResponse({
    required this.push,
    required this.riskOnly,
    required this.positiveOnly,
    required this.interestOnly,
    required this.nightPushProhibit,
    this.dndStart,
    this.dndFinish,
  });

  factory SettingResponse.fromJson(Map<String, dynamic> json)  {
    return SettingResponse(
      push: json['push'] ?? false,
      riskOnly: json['risk_only'] ?? false,
      positiveOnly: json['positive_only'] ?? false,
      interestOnly: json['interest_only'] ?? false,
      nightPushProhibit: json['night_push_prohibit'] ?? false,
      dndStart: json['dnd_start'],
      dndFinish: json['dnd_finish'],
    );
  }
}

class UserLoginRequest {
  final String googleId;
  final String email;
  final String nickname;
  final String? imgUrl;
  final String? onesignalId;

  UserLoginRequest({
    required this.googleId,
    required this.email,
    required this.nickname,
    required this.imgUrl,
    this.onesignalId,
  });

  Map<String, dynamic> toJson() => {
    'google_id': googleId,
    'email': email,
    'nickname': nickname,
    'img_url': imgUrl,
    'onesignal_id': onesignalId,
  };
}