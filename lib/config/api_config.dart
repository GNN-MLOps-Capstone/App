import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 앱 전역 API 주소 설정
///
/// 우선순위:
///   1) --dart-define 으로 주입된 API_BASE_URL (배포 빌드 시)
///   2) .env.local 의 API_BASE_URL (개발 시 개인 설정)
///   3) 플랫폼별 localhost 자동 선택 (개발 기본값)
///
/// 배포 빌드 예시 (로컬 서버 IP 지정):
///   flutter build apk --dart-define=API_BASE_URL=http://192.168.0.10:8000
///
/// 클라우드 배포 시:
///   flutter build apk --dart-define=API_BASE_URL=https://your-domain.com
class ApiConfig {
  ApiConfig._();

  static const String _defineBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _defineWsBaseUrl = String.fromEnvironment(
    'API_WS_BASE_URL',
  );

  /// 명시적으로 설정된 URL (dart-define 또는 .env.local)
  static String? get configuredBaseUrl {
    final fromDefine = _normalizeHttpUrl(_defineBaseUrl);
    if (fromDefine != null) return fromDefine;
    return _normalizeHttpUrl(dotenv.env['API_BASE_URL']);
  }

  static String? get configuredWsBaseUrl {
    final fromDefine = _normalizeWsUrl(_defineWsBaseUrl);
    if (fromDefine != null) return fromDefine;
    return _normalizeWsUrl(dotenv.env['API_WS_BASE_URL']);
  }

  static String get baseUrl => configuredBaseUrl ?? _defaultBaseUrl;

  static String get wsBaseUrl {
    final configured = configuredWsBaseUrl;
    if (configured != null) return configured;
    return _deriveWsUrl(baseUrl);
  }

  static String get _defaultBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  static String _deriveWsUrl(String httpUrl) {
    final uri = Uri.parse(httpUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return _stripTrailingSlash(uri.replace(scheme: wsScheme).toString());
  }

  static String? _normalizeHttpUrl(String? raw) {
    final cleaned = _normalizeRaw(raw);
    if (cleaned == null) return null;
    final uri = Uri.tryParse(cleaned);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return cleaned;
  }

  static String? _normalizeWsUrl(String? raw) {
    final cleaned = _normalizeRaw(raw);
    if (cleaned == null) return null;
    final uri = Uri.tryParse(cleaned);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'ws' && uri.scheme != 'wss') return null;
    return cleaned;
  }

  static String? _normalizeRaw(String? raw) {
    if (raw == null) return null;
    final value = _stripTrailingSlash(raw.trim());
    // .env.example / 설정 템플릿의 기본 센티넬 값으로, 실제 URL이 설정되지
    // 않은 상태를 의미하므로 null로 처리한다.
    if (value.isEmpty || value == 'https://placeholder.api.com') return null;
    return value;
  }

  static String _stripTrailingSlash(String value) {
    return value.replaceFirst(RegExp(r'/+$'), '');
  }
}
