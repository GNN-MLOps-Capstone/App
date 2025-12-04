# 보안 가이드라인: OneSignal REST API 사용

## 🚨 즉시 조치 필요 사항

### 현재 보안 위험
- 클라이언트에 OneSignal REST API Key가 노출됨
- `included_segments: ['All']`로 모든 사용자에게 무제한 알림 전송 가능
- 누구나 인증 없이 모든 사용자에게 알림 발송 가능

## ✅ 올바른 아키텍처

### 서버사이드 구현 (필수)

```javascript
// 예시: Node.js 서버
app.post('/api/notifications/send', async (req, res) => {
  const { title, message, targetUserId } = req.body;

  // 서버에서만 REST API Key 사용
  const response = await fetch('https://onesignal.com/api/v1/notifications', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Basic ${process.env.ONESIGNAL_REST_API_KEY}`
    },
    body: JSON.stringify({
      app_id: process.env.ONESIGNAL_APP_ID,
      contents: { en: message },
      headings: { en: title },
      include_player_ids: targetUserId ? [targetUserId] : undefined,
      // All 세그먼트 사용 금지
    })
  });
});
```

### 클라이언트 구현 (권장)

```dart
class PushNotificationService {
  // 서버 API를 통해서만 푸시 발송
  Future<bool> sendPushNotification({
    required String title,
    required String message,
    String? targetUserId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://your-server.com/api/notifications/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${userToken}', // 사용자 인증 필요
        },
        body: jsonEncode({
          'title': title,
          'message': message,
          'targetUserId': targetUserId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('서버 푸시 발송 실패: $e');
      return false;
    }
  }
}
```

## 📋 구현 목록

### 1. 서버 API 엔드포인트 구현
- `/api/notifications/send` - 일반 푸시 발송
- `/api/notifications/stock-alert` - 주식 가격 알림
- `/api/notifications/trade` - 거래 체결 알림
- `/api/notifications/news` - 뉴스 알림

### 2. 인증 및 권한 부여
- JWT 토큰 기반 사용자 인증
- 사용자 본인에게만 알림 발송 권한
- 관리자만 브로드캐스트 권한

### 3. 환경 변수 관리
- 서버: `ONESIGNAL_REST_API_KEY` (비밀)
- 클라이언트: `ONESIGNAL_APP_ID` (공개)

### 4. 보안 조치
- API Rate Limiting
- 사용자별 발송 제한
- 로깅 및 모니터링

## 🔧 즉시 해야 할 일

1. **OneSignal REST API Key 재발급**
   - 현재 노출된 키 즉시 폐기
   - 새로운 키 생성 (서버용으로만 사용)

2. **서버 API 구축**
   - 백엔드 API 엔드포인트 생성
   - 인증 시스템 구현

3. **클라이언트 코드 수정**
   - REST API 호출 제거
   - 서버 API 호출로 변경

4. **테스트 환경 분리**
   - 개발/테스트/운영 환경 분리
   - 각 환경별 App ID 관리

## 📞 도움말

이 보안 이슈에 대해 추가적인 구현이 필요하면 언제든지 문의하세요.
서버 개발 지원이 필요한 경우 협의 가능합니다.