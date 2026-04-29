# 2주차 Frontend 단위 테스트 리포트

**기간:** 2026.04.09 ~ 04.15  
**작성일:** 2026.04.15  
**브랜치:** `test/week2-unit-tests`  
**실행 결과:** ✅ 61 / 61 통과 (실패 0)  
**실행 시간:** ~0.00s

---

## 테스트 범위 요약

| 날짜 | 항목 | 테스트 파일 | 테스트 수 | 결과 |
|------|------|------------|-----------|------|
| 4/9~10 | 유저 인증 API 통신 레이어 | `user_api_service_test.dart` | 19 | ✅ 전체 통과 |
| 4/9~10 | 관심종목 API 통신 레이어 | `watchlist_service_test.dart` | 17 | ✅ 전체 통과 |
| 4/11 | 푸시 알림 수신 및 처리 | `notification_service_test.dart` | 19 | ✅ 전체 통과 |
| 4/12~13 | API 인증 헤더 생성 | `api_auth_headers_test.dart` | 6 | ✅ 전체 통과 |

---

## 상세 결과

### 1. 유저 인증 API — `user_api_service_test.dart` (19개)

#### 모델 파싱
| # | 테스트명 | 결과 |
|---|---------|------|
| 1 | AuthResponse.fromJson — 정상 JSON 파싱 | ✅ |
| 2 | AuthResponse.fromJson — token_type 누락 시 기본값 Bearer | ✅ |
| 3 | UserResponse.fromJson — 정상 JSON 파싱 | ✅ |
| 4 | UserResponse.fromJson — img_url null 허용 | ✅ |
| 5 | UserResponse.fromJson — id 누락 시 기본값 0 | ✅ |
| 6 | SettingResponse.fromJson — 정상 JSON 파싱 | ✅ |
| 7 | SettingResponse.fromJson — 필드 누락 시 기본값 false | ✅ |

#### API 통신
| # | 테스트명 | 결과 |
|---|---------|------|
| 8 | checkHealth — 서버 200 응답 시 true 반환 | ✅ |
| 9 | checkHealth — 서버 500 응답 시 false 반환 | ✅ |
| 10 | checkHealth — 네트워크 오류 시 false 반환 | ✅ |
| 11 | getProfile — 정상 응답 파싱 | ✅ |
| 12 | getProfile — 404 응답 시 UserApiException(404) 발생 | ✅ |
| 13 | getProfile — 500 응답 시 UserApiException 발생 | ✅ |
| 14 | getSettings — 정상 응답 파싱 | ✅ |
| 15 | getSettings — 404 응답 시 UserApiException(404) 발생 | ✅ |
| 16 | updateSettings — 정상 응답 시 변경된 설정 반환 | ✅ |
| 17 | updateSettings — 500 응답 시 UserApiException 발생 | ✅ |
| 18 | deleteUser — 204 응답 시 true 반환 | ✅ |
| 19 | deleteUser — 200 응답 시 false 반환 (204가 아님) | ✅ |

---

### 2. 관심종목 API — `watchlist_service_test.dart` (17개)

#### 종목 코드 변환
| # | 테스트명 | 결과 |
|---|---------|------|
| 1 | toStockCode — 6자리 코드는 그대로 반환 | ✅ |
| 2 | toStockCode — ISIN 코드(KR 시작, 12자리)를 6자리로 변환 | ✅ |
| 3 | toStockCode — KR로 시작하지 않는 코드는 그대로 반환 | ✅ |

#### API 통신
| # | 테스트명 | 결과 |
|---|---------|------|
| 4 | getWatchlist — 정상 응답 파싱 | ✅ |
| 5 | getWatchlist — 빈 배열 응답 처리 | ✅ |
| 6 | getWatchlist — 500 응답 시 예외 발생 | ✅ |
| 7 | addStock — 201 응답 시 true 반환 | ✅ |
| 8 | addStock — 200 응답 시 true 반환 | ✅ |
| 9 | addStock — 네트워크 오류 시 false 반환 | ✅ |
| 10 | addStock — ISIN 코드를 6자리로 변환하여 전송 | ✅ |
| 11 | deleteStock — 200 응답 시 true 반환 | ✅ |
| 12 | deleteStock — 204 응답 시 true 반환 | ✅ |
| 13 | deleteStock — 네트워크 오류 시 false 반환 | ✅ |
| 14 | getBriefing — 정상 응답 파싱 | ✅ |
| 15 | getBriefing — 500 응답 시 예외 발생 | ✅ |
| 16 | getStockDetail — 정상 응답 파싱 | ✅ |
| 17 | getStockDetail — 500 응답 시 예외 발생 | ✅ |

---

### 3. 알림 수신 및 처리 — `notification_service_test.dart` (19개)

#### 모델 파싱
| # | 테스트명 | 결과 |
|---|---------|------|
| 1 | NotificationResponse.fromJson — 정상 JSON 파싱 | ✅ |
| 2 | NotificationResponse.fromJson — body null 허용 | ✅ |
| 3 | NotificationResponse.fromJson — read/star 누락 시 기본값 false | ✅ |
| 4 | NotificationCreateRequest.toJson — 모든 필드 직렬화 | ✅ |
| 5 | NotificationCreateRequest.toJson — 선택 필드 null 허용 | ✅ |

#### API 통신
| # | 테스트명 | 결과 |
|---|---------|------|
| 6 | getNotifications — 정상 응답 파싱 | ✅ |
| 7 | getNotifications — 빈 배열 응답 처리 | ✅ |
| 8 | getNotifications — 500 응답 시 예외 발생 | ✅ |
| 9 | markAsRead — 단건 읽음 처리 후 unread_count 반환 | ✅ |
| 10 | markAsRead — 전체 읽음 처리(id null) 후 unread_count 0 반환 | ✅ |
| 11 | markAsRead — 500 응답 시 예외 발생 | ✅ |
| 12 | toggleImportant — 200 응답 시 star 상태 반환 (true) | ✅ |
| 13 | toggleImportant — 200 응답 시 star 상태 반환 (false) | ✅ |
| 14 | toggleImportant — 비정상 응답 시 false 반환 | ✅ |
| 15 | deleteNotification — 200 응답 시 true 반환 | ✅ |
| 16 | deleteNotification — 404 응답 시 false 반환 | ✅ |
| 17 | deleteNotification — 네트워크 오류 시 false 반환 | ✅ |
| 18 | createNotification — 201 응답 시 생성된 id 반환 | ✅ |
| 19 | createNotification — 비정상 응답 시 null 반환 | ✅ |

---

### 4. API 인증 헤더 생성 — `api_auth_headers_test.dart` (6개)

| # | 테스트명 | 결과 |
|---|---------|------|
| 1 | getAuthHeaders — 유효한 토큰이 있을 때 Authorization 헤더 반환 | ✅ |
| 2 | getAuthHeaders — 토큰이 null이면 예외 발생 | ✅ |
| 3 | getAuthHeaders — 토큰이 공백만 있으면 예외 발생 | ✅ |
| 4 | getAuthHeaders — 토큰이 빈 문자열이면 예외 발생 | ✅ |
| 5 | getAccessToken — 토큰이 있을 때 토큰 문자열 반환 | ✅ |
| 6 | getAccessToken — 토큰이 없을 때 null 반환 | ✅ |

---

## 테스트 환경

- **Flutter:** flutter_test
- **HTTP 모킹:** `package:http/testing.dart` (MockClient + http.runWithClient)
- **스토리지 모킹:** MethodChannel mock (flutter_secure_storage)
- **서버 의존성:** 없음 (완전 오프라인 실행 가능)

---

## 미테스트 항목

| 항목 | 사유 |
|------|------|
| `UserApiService.login` | OneSignal SDK 네이티브 초기화 필요 — 단위 테스트 환경에서 플랫폼 채널 모킹 범위 초과 |
| `PushNotificationService.sendPushNotification` | OneSignal REST API 외부 호출 및 토큰 의존 — 5주차 연동 통합 테스트에서 처리 예정 |

---

## 1·2주차 누적 현황

| 주차 | 테스트 수 | 통과 | 실패 |
|------|-----------|------|------|
| 1주차 | 37 | 37 | 0 |
| 2주차 | 61 | 61 | 0 |
| **누계** | **98** | **98** | **0** |
