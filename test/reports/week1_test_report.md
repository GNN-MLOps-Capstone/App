# Frontend 단위 테스트 보고서 — 1주차

**기간:** 2026.04.02 ~ 2026.04.08  
**작성일:** 2026.04.08  
**담당:** 이수호
**결과:** ✅ 전체 통과 (39 / 39)

---

## 1. 환경 셋업

| 항목 | 내용 |
|------|------|
| 테스트 프레임워크 | `flutter_test` (Flutter SDK 내장) |
| 모킹 라이브러리 | `mockito ^5.4.4` |
| 코드 생성 도구 | `build_runner ^2.4.9` |
| HTTP 모킹 | `package:http/testing.dart` (`MockClient` + `http.runWithClient`) |
| 플랫폼 채널 모킹 | `TestDefaultBinaryMessengerBinding` (FlutterSecureStorage) |
| Dotenv 초기화 | `dotenv.loadFromString(isOptional: true)` |

### 주요 셋업 이슈 및 해결

| 이슈 | 원인 | 해결 |
|------|------|------|
| `dotenv.env` 접근 시 `NotInitializedError` | 테스트 환경에서 `.env.local` 미로드 | `dotenv.loadFromString(isOptional: true)` 로 빈 초기화 |
| 한글 포함 mock 응답 `ArgumentError` | `http.Response(String, ...)` 생성자가 Latin-1 인코딩 사용 | `http.Response.bytes(utf8.encode(...), ...)` 로 교체 |
| `FlutterSecureStorage` 플랫폼 채널 오류 | 테스트 VM에서 네이티브 플러그인 미등록 | `setMockMethodCallHandler` 로 채널 직접 모킹 |

---

## 2. 테스트 파일 구조

```
test/
└── unit/
    ├── models/
    │   ├── watchlist_models_test.dart
    │   └── news_models_test.dart
    └── services/
        ├── news_api_service_test.dart
        └── stock_api_service_test.dart
```

---

## 3. 테스트 결과 상세

### 3-1. 모델 파싱 테스트

#### WatchlistStock / WatchlistBriefing (`watchlist_models_test.dart`)

| # | 테스트명 | 결과 |
|---|---------|------|
| 1 | WatchlistStock.fromJson — 정상 JSON 파싱 | ✅ |
| 2 | WatchlistStock.fromJson — 필드 누락 시 기본값 적용 | ✅ |
| 3 | WatchlistStock.fromJson — price가 double로 오는 경우 int 변환 | ✅ |
| 4 | WatchlistStock.fromJson — changeRate가 int로 오는 경우 double 변환 | ✅ |
| 5 | WatchlistBriefing.fromJson — 정상 JSON 파싱 | ✅ |
| 6 | WatchlistBriefing.fromJson — 필드 누락 시 기본값 적용 | ✅ |

**소계: 6 / 6**

#### NewsRecommendationItem / NewsRecommendationPage / NewsDetailItem (`news_models_test.dart`)

| # | 테스트명 | 결과 |
|---|---------|------|
| 1 | NewsRecommendationItem.fromJson — 정상 JSON 파싱 | ✅ |
| 2 | NewsRecommendationItem.fromJson — 필드 누락 시 기본값 적용 | ✅ |
| 3 | NewsRecommendationItem.fromJson — pub_date 잘못된 형식이면 null | ✅ |
| 4 | NewsRecommendationPage.fromJson — 정상 JSON 파싱 및 items 리스트 변환 | ✅ |
| 5 | NewsRecommendationPage.fromJson — items 빈 배열 처리 | ✅ |
| 6 | NewsRecommendationPage.fromJson — 필드 누락 시 기본값 적용 | ✅ |
| 7 | NewsDetailItem.fromJson — 정상 JSON 파싱 | ✅ |
| 8 | NewsDetailItem.fromJson — stock_name 공백만 있는 related_stocks 필터링 | ✅ |
| 9 | NewsDetailItem.fromRecommendationItem — stockName 있을 때 relatedStocks 생성 | ✅ |
| 10 | NewsDetailItem.fromRecommendationItem — stockName null이면 relatedStocks 비어있음 | ✅ |

**소계: 10 / 10**

---

### 3-2. API 통신 레이어 테스트

#### NewsApiService (`news_api_service_test.dart`)

| # | 테스트명 | 결과 |
|---|---------|------|
| 1 | checkHealth — 서버 200 응답 시 true 반환 | ✅ |
| 2 | checkHealth — 서버 500 응답 시 false 반환 | ✅ |
| 3 | checkHealth — 네트워크 오류 시 false 반환 | ✅ |
| 4 | getRecommendations — 정상 응답 파싱 | ✅ |
| 5 | getRecommendations — 401 응답 시 NewsApiException 발생 | ✅ |
| 6 | getRecommendations — 500 응답 시 NewsApiException 발생 | ✅ |
| 7 | getRecommendations — 타임아웃 시 NewsApiException 발생 | ✅ |
| 8 | getRecommendations — 토큰 없으면 NewsApiException 발생 | ✅ |
| 9 | getNewsDetail — 정상 응답 파싱 | ✅ |
| 10 | getNewsDetail — 404 응답 시 NewsApiException(404) 발생 | ✅ |

**소계: 10 / 10**

#### StockApiService (`stock_api_service_test.dart`)

| # | 테스트명 | 결과 |
|---|---------|------|
| 1 | checkHealth — 서버 200 응답 시 true 반환 | ✅ |
| 2 | checkHealth — 서버 500 응답 시 false 반환 | ✅ |
| 3 | checkHealth — 네트워크 오류 시 false 반환 | ✅ |
| 4 | getAiTrends — 정상 응답 파싱 | ✅ |
| 5 | getAiTrends — 500 응답 시 StockApiException 발생 | ✅ |
| 6 | getAiTrends — 타임아웃 시 StockApiException 발생 | ✅ |
| 7 | getAiTrends — 토큰 없으면 StockApiException 발생 | ✅ |
| 8 | getStockWeather — stockId로 정상 응답 시 weather 반환 | ✅ |
| 9 | getStockWeather — stockName으로 정상 응답 시 weather 반환 | ✅ |
| 10 | getStockWeather — stockId, stockName 둘 다 없으면 StockApiException(400) 발생 | ✅ |
| 11 | getStockWeather — 404 응답 시 StockApiException 발생 | ✅ |
| 12 | getOverview — 정상 응답 파싱 | ✅ |
| 13 | getOverview — 500 응답 시 StockApiException 발생 | ✅ |

**소계: 13 / 13**

---

## 4. 전체 집계

| 분류 | 테스트 파일 | 전체 | 통과 | 실패 |
|------|-----------|------|------|------|
| 모델 | watchlist_models_test.dart | 6 | 6 | 0 |
| 모델 | news_models_test.dart | 10 | 10 | 0 |
| 서비스 | news_api_service_test.dart | 10 | 10 | 0 |
| 서비스 | stock_api_service_test.dart | 13 | 13 | 0 |
| **합계** | | **39** | **39** | **0** |

---