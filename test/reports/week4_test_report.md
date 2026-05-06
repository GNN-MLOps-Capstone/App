# 4주차 Frontend 통합 테스트 리포트

**기간:** 2026.04.30 ~ 05.06  
**작성일:** 2026.05.06  
**브랜치:** `test/week4-unit-tests`  
**실행 결과:** ✅ 27 / 27 통과 (실패 0)  
**실행 시간:** ~3s

---

## 테스트 범위 요약

| 날짜 | 항목 | 테스트 파일 | 테스트 수 | 결과 |
|------|------|------------|-----------|------|
| 4/30~5/2 | 알림 화면 상호작용 플로우 | `alarm_integration_test.dart` | 7 | ✅ 전체 통과 |
| 4/30~5/2 | 설정 화면 알림 설정 플로우 | `setting_notification_integration_test.dart` | 8 | ✅ 전체 통과 |
| 5/3~5/5 | 화면 전환 플로우 (하단 내비게이션 포함) | `navigation_flow_integration_test.dart` | 12 | ✅ 전체 통과 |

---

## 상세 결과

### 1. 알림 화면 통합 테스트 — `alarm_integration_test.dart` (7개)

| # | 테스트명 | 결과 |
|---|---------|------|
| 1 | 탭 전환 플로우: 전체 → 중요 → 읽지 않음 → 긴급/리스크 | ✅ |
| 2 | 모두 읽음 버튼 탭 → markAsRead API 호출 → 읽지 않음 카운트 0 | ✅ |
| 3 | 미읽음 알림 탭 → 상세 페이지 이동 → 뒤로가기 → markAsRead API 호출 | ✅ |
| 4 | 이미 읽은 알림 탭 → 뒤로가기 → markAsRead API 미호출 | ✅ |
| 5 | 모두 읽음 API 실패 → 스낵바 표시 | ✅ |
| 6 | 읽지 않은 알림 없을 때 모두 읽음 버튼 탭해도 API 미호출 | ✅ |
| 7 | 탭 전환 후 전체 탭으로 돌아오면 전체 목록 복원 | ✅ |

> **Note:** 탭 레이블 형식이 `'읽지 않음 (N)'`(괄호 포함)이므로 `find.textContaining('읽지 않음 (N)')` 사용.  
> **Note:** `TextButton.icon`의 `onPressed` 속성은 ancestor 탐색으로 접근 불가 — 비활성화 검증은 탭 후 API 미호출 여부로 대체.

---

### 2. 설정 화면 알림 설정 통합 테스트 — `setting_notification_integration_test.dart` (8개)

| # | 테스트명 | 결과 |
|---|---------|------|
| 1 | 설정 로드 → 스위치 상태 반영 (risk:ON, 호재:OFF, 관심:ON) | ✅ |
| 2 | 호재 알림 스위치 ON → updateSettings PATCH 호출 → 상태 갱신 | ✅ |
| 3 | 앱 전체 푸시 스위치 ON → 리스크·호재·관심 종목 모두 ON | ✅ |
| 4 | 앱 전체 푸시 스위치 OFF → 리스크·호재·관심 종목 모두 OFF | ✅ |
| 5 | 야간 방해금지 모드 토글 성공 → "꺼짐"에서 시간 범위 텍스트로 변경 | ✅ |
| 6 | 야간 방해금지 모드 토글 API 실패 → 원래 상태로 롤백 + 스낵바 표시 | ✅ |
| 7 | 정보 초기화 다이얼로그 → 취소 클릭 → 스위치 상태 유지 | ✅ |
| 8 | 정보 초기화 다이얼로그 → 확인 클릭 → 알림 스위치 전체 OFF + 스낵바 표시 | ✅ |

> **Note:** 야간 방해금지 버튼(`'꺼짐'` 텍스트)은 `SingleChildScrollView` 내 스크롤 영역에 위치 — `tester.ensureVisible()` 후 탭.  
> **Note:** 정보 초기화 항목도 동일하게 스크롤 후 탭.  
> **Note:** OneSignal 채널(`com.onesignal.flutter`) MethodChannel 모킹 추가 — `syncDnd` 호출 시 MissingPluginException 방지.

---

### 3. 화면 전환 플로우 통합 테스트 — `navigation_flow_integration_test.dart` (12개)

#### 홈 화면 상단 아이콘 네비게이션 (2개)
| # | 테스트명 | 결과 |
|---|---------|------|
| 1 | 알림 아이콘 탭 → 알림 페이지로 이동 | ✅ |
| 2 | 설정 아이콘 탭 → 설정 페이지로 이동 | ✅ |

#### 홈 화면 더보기 네비게이션 (2개)
| # | 테스트명 | 결과 |
|---|---------|------|
| 3 | 관심종목 더보기 탭 → 관심종목 페이지로 이동 | ✅ |
| 4 | 뉴스 더보기 탭 → 뉴스 페이지로 이동 | ✅ |

#### 하단 내비게이션 탭 전환 — 홈 기준 (4개)
| # | 테스트명 | 결과 |
|---|---------|------|
| 5 | 관심종목 탭(1) → 관심종목 페이지로 전환 | ✅ |
| 6 | 뉴스 탭(2) → 뉴스 페이지로 전환 | ✅ |
| 7 | 주식 탭(3) → 주식 페이지로 전환 | ✅ |
| 8 | 홈 탭(0) → 홈 화면 유지 (route 없음) | ✅ |

#### 하단 내비게이션 탭 전환 — 설정 페이지 기준 (4개)
| # | 테스트명 | 결과 |
|---|---------|------|
| 9 | 홈 탭(0) → 홈 페이지로 전환 | ✅ |
| 10 | 관심종목 탭(1) → 관심종목 페이지로 전환 | ✅ |
| 11 | 뉴스 탭(2) → 뉴스 페이지로 전환 | ✅ |
| 12 | 주식 탭(3) → 주식 페이지로 전환 | ✅ |

> **Note:** `BottomNavBar` 내 탭 아이템은 SVG 기반 `GestureDetector` — `find.descendant(of: find.byType(BottomNavBar), matching: find.byType(GestureDetector)).at(index)`로 탭.  
> **Note:** 화면 전환 목적지는 route stub(`Scaffold + Text`)으로 단순화하여 목적지 API 의존성 제거.

---

## 테스트 환경

- **Flutter:** flutter_test (WidgetTester)
- **HTTP 모킹:** `package:http/testing.dart` (MockClient + http.runWithClient)
- **스토리지 모킹:** MethodChannel mock (flutter_secure_storage)
- **Google Sign-In 모킹:** MethodChannel mock
- **OneSignal 모킹:** MethodChannel mock (com.onesignal.flutter)
- **서버 의존성:** 없음 (완전 오프라인 실행 가능)

---

## 1~4주차 누적 현황

| 주차 | 종류 | 테스트 수 | 통과 | 실패 |
|------|------|-----------|------|------|
| 1주차 | 단위 테스트 | 37 | 37 | 0 |
| 2주차 | 단위 테스트 | 63 | 63 | 0 |
| 3주차 | 위젯 테스트 | 42 | 42 | 0 |
| 4주차 | 통합 테스트 | 27 | 27 | 0 |
| **누계** | | **169** | **169** | **0** |
