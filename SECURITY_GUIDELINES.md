# 보안 가이드라인: OneSignal REST API 사용

## 🎯 현재 상태: 팀 내부 프로젝트 전용

### 현재 구현
- 팀 내부 프로젝트용으로 클라이언트에서 직접 OneSignal REST API 호출
- 구독된 사용자에게만 알림 발송 (전체 사용자 브로드캐스트 방지)
- 주식 가격 급락 등 긴급 알림 기능 구현

## ⚠️ 실제 배포 시 필요한 변경사항

### 서버사이드 구현 (권장)
실제 앱스토어 배포 시에는 반드시 서버사이드로 전환해야 합니다:

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
    })
  });
});
```

### 배포용 클라이언트 구현
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
          'Authorization': 'Bearer ${userToken}',
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

## 🔒 현재 팀 내부용 보안 조치

1. **API Key 관리**
   - 새로운 REST API Key 사용 (기존 키 폐기됨)
   - .env.local 파일에만 저장
   - Git에 커밋되지 않음

2. **타겟 제한**
   - 'Subscribed Users' 세그먼트로만 발송
   - 'All' 세그먼트 사용 금지

3. **팀 내부 공유**
   - API Key는 신뢰할 수 있는 팀원에게만 공유
   - 외부 유출 방지

## 📋 구현 기능

- ✅ 관심 종목 가격 급락 알림
- ✅ 개인 사용자 알림
- ✅ 데이터 포함 알림
- ✅ 알림 클릭 시 화면 이동

## 🚀 테스트 시나리오

### 주식 가격 급락 알림
```dart
// 예시 코드
await pushService.sendStockPriceAlert(
  stockName: '삼성전자',
  stockCode: '005930',
  currentPrice: 75000, // 현재가
  targetPrice: 80000, // 목표가
  alertType: 'lower', // 하락 경보
);
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