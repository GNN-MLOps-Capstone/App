import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'notification_service.dart';

class OneSignalService {
  final Set<String> _savedNotificationIds = <String>{};
  static final OneSignalService _instance = OneSignalService._internal();
  factory OneSignalService() => _instance;
  OneSignalService._internal();

  bool _isInitialized = false;

  // OneSignal 초기화
  Future<void> initializeOneSignal() async {
    if (_isInitialized) return;

    try {
      // .env 파일에서 App ID 가져오기
      String? app_id = dotenv.env['ONESIGNAL_APP_ID']?.trim();

      // 플레이스홀더 값 확인 (.env.example과 일치)
      const placeholderAppId = 'your_onesignal_app_id_here';

      if (app_id == null || app_id.isEmpty || app_id == placeholderAppId) {
        if (kDebugMode) {
          print('OneSignal App ID가 설정되지 않음: ${app_id ?? "null"}');
          print('.env 파일에 실제 OneSignal App ID를 설정해주세요.');
        }
        return; // 플레이스홀더인 경우 초기화하지 않음
      }

      if (kDebugMode) {
        print('OneSignal App ID 설정됨: $app_id');
      }

      // OneSignal 초기화
      OneSignal.initialize(app_id);

      OneSignal.Notifications.addForegroundWillDisplayListener((event) async {
        if (kDebugMode) print('🔔 알림 수신 감지: ${event.notification.title}');
        await _saveNotificationToDb(event.notification);
      });

      // 푸시 알림 권한 요청
      await OneSignal.Notifications.requestPermission(true);

      // 알림 클릭 리스너
      OneSignal.Notifications.addClickListener((event) async {
        await _saveNotificationToDb(event.notification);
        if (kDebugMode) {
          print('알림 클릭: ${event.notification.title}');
        }

        // 알림 클릭 처리 로직
        _handleNotificationClick(event);
      });

      _isInitialized = true;

      if (kDebugMode) {
        print('OneSignal이 성공적으로 초기화되었습니다.');
      }

    } catch (e) {
      if (kDebugMode) {
        print('OneSignal 초기화 오류: $e');
      }
    }
  }

  Future<void> _saveNotificationToDb(OSNotification notification) async {
    final notificationId = notification.notificationId;
    if (notificationId.isEmpty || _savedNotificationIds.contains(notificationId)) {
      if (kDebugMode) print('이미 처리된 알림입니다 (ID: $notificationId)');
      return;
    }
    try {
      final createdId = await NotificationApiService.createNotification(
        NotificationCreateRequest(
          notificationId: notification.notificationId,
          type: notification.additionalData?['type'] ?? 'general',
          title: notification.title ?? '',
          body: notification.body ?? '',
          stockName: notification.additionalData?['stock_name'],
          sentimentScore: notification.additionalData?['sentiment_score'] != null 
              ? double.tryParse(notification.additionalData!['sentiment_score'].toString()) 
              : null,
        ),
      );

      if (createdId != null) {
        _savedNotificationIds.add(notificationId); // 성공 리스트에 추가
        if (kDebugMode) print('✅ 알림 DB 저장 완료 (서버 ID: $createdId)');
      } else {
        // [실패 처리] 반환값이 null이면 예외 발생
        throw Exception('서버 응답이 null입니다.');
      }
    } catch (e) {
      if (kDebugMode) print('❌ 알림 DB 저장 실패: $e');
    }
  } 

  // 알림 클릭 처리
  void _handleNotificationClick(OSNotificationClickEvent event) {
    // 추가 데이터가 있는 경우 처리
    if (event.notification.additionalData != null) {
      var data = event.notification.additionalData!;

      // 예시: 특정 페이지로 이동
      if (data.containsKey('target_screen')) {
        String? targetScreen = data['target_screen'] as String?;
        if (kDebugMode) {
          print('이동할 화면: $targetScreen');
        }
      }

      // 예시: 상세 아이템 ID로 이동
      if (data.containsKey('product_id')) {
        String? productId = data['product_id'] as String?;
        if (kDebugMode) {
          print('상세 상품 ID: $productId');
        }
      }
    }
  }

  // 사용자 ID 설정 (로그인 시)
  Future<void> setUserId(String userId) async {
    try {
      await OneSignal.login(userId);

      if (kDebugMode) {
        print('OneSignal 사용자 ID 설정: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OneSignal 사용자 ID 설정 오류: $e');
      }
    }
  }

  // 사용자 로그아웃
  Future<void> logout() async {
    try {
      await OneSignal.logout();

      if (kDebugMode) {
        print('OneSignal 로그아웃 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OneSignal 로그아웃 오류: $e');
      }
    }
  }

  // 태그 설정 (개인화된 알림을 위함)
  Future<void> setTag(String key, String value) async {
    try {
      await OneSignal.User.addTagWithKey(key, value);

      if (kDebugMode) {
        print('태그 설정: $key = $value');
      }
    } catch (e) {
      if (kDebugMode) {
        print('태그 설정 오류: $e');
      }
    }
  }

  // 태그 삭제
  Future<void> deleteTag(String key) async {
    try {
      await OneSignal.User.removeTag(key);

      if (kDebugMode) {
        print('태그 삭제: $key');
      }
    } catch (e) {
      if (kDebugMode) {
        print('태그 삭제 오류: $e');
      }
    }
  }

  // 푸시 토큰 가져오기 (Player ID 사용)
  Future<String?> getPushToken() async {
    try {
      var subscription = OneSignal.User.pushSubscription;
      // Player ID (UUID)를 반환
      return subscription.id;
    } catch (e) {
      if (kDebugMode) {
        print('푸시 토큰 가져오기 오류: $e');
      }
      return null;
    }
  }

  // 알림 수신 동의 상태 확인
  Future<bool> isNotificationSubscribed() async {
    try {
      var subscription = OneSignal.User.pushSubscription;
      var optedIn = subscription.optedIn;
      var token = subscription.token;

      if (kDebugMode) {
        print('🔔 Notification status:');
        print('   - Opted in: $optedIn');
        print('   - Token: $token');
        print('   - ID: ${subscription.id}');
      }

      return optedIn ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('알림 구독 상태 확인 오류: $e');
      }
      return false;
    }
  }

  // 포그라운드 알림 비활성화
  void disableForegroundNotifications() {
    OneSignal.Notifications.clearAll();
  }

  static Future<void> syncDnd(bool isDnd) async {
    await OneSignal.User.addTagWithKey("is_dnd", isDnd ? "true" : "false");
  }
}