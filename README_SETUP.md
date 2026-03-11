# Firebase 설정 가이드

이 가이드는 Firebase 자격 증명을 안전하게 관리하는 방법을 설명합니다.

## 개요

보안 강화를 위해 Firebase 자격 증명을 하드코딩하지 않고 환경 변수를 통해 관리합니다.

## 설정 단계

### 1. 환경 변수 설정

1. `.env.example` 파일을 복사하여 `.env.local` 파일을 생성합니다:
   ```bash
   cp .env.example .env.local
   ```

2. `.env.local` 파일에 Firebase 정보를 입력합니다 (실제 값으로 교체):
   ```env
   # Firebase Configuration - 실제 값으로 교체하세요
   FIREBASE_PROJECT_NUMBER=your_firebase_project_number_here
   FIREBASE_PROJECT_ID=your_firebase_project_id_here
   FIREBASE_STORAGE_BUCKET=your_firebase_storage_bucket_here
   FIREBASE_MOBILESDK_APP_ID=your_firebase_mobilesdk_app_id_here
   FIREBASE_API_KEY=your_firebase_api_key_here
   FIREBASE_CLIENT_ID=your_firebase_client_id_here
   FIREBASE_IOS_CLIENT_ID=your_firebase_ios_client_id_here
   FIREBASE_CLIENT_ID_ANDROID_CERT2=your_firebase_android_client_id_cert2_here
   FIREBASE_CLIENT_ID_WEB=your_firebase_web_client_id_here

   # OneSignal Configuration
   ONESIGNAL_APP_ID=your_onesignal_app_id_here
   ONESIGNAL_REST_API_KEY=your_onesignal_rest_api_key_here

   # API Configuration
   # Android 에뮬레이터: http://10.0.2.2:8000
   # iOS 시뮬레이터/데스크톱: http://localhost:8000
   # 실기기: http://<개발PC의로컬IP>:8000
   API_BASE_URL=http://10.0.2.2:8000
   # 선택값 (미설정 시 API_BASE_URL로부터 자동 변환)
   # API_WS_BASE_URL=ws://10.0.2.2:8000
   ```

**⚠️ 중요:** `.env.local` 파일에는 실제 자격 증명 값을 입력하세요. 이 파일은 .gitignore에 포함되어 Git에 커밋되지 않습니다.

### 2. Firebase 설정 스크립트 실행

빌드 전에 Firebase 설정 스크립트를 실행하여 google-services.json 파일을 생성합니다:

```bash
# Linux/Mac
chmod +x scripts/setup-firebase.sh
./scripts/setup-firebase.sh

# Windows
scripts\setup-firebase.bat
# 또는 Git Bash 사용
./scripts/setup-firebase.sh
```

### 3. 빌드 실행

#### 개발 (로컬 서버 자동 연결)

`.env.local`에 `API_BASE_URL`을 설정하지 않아도 플랫폼별로 자동 선택됩니다:

```bash
./scripts/setup-firebase.sh
flutter run
```

#### 배포 빌드 (서버 주소 지정)

`--dart-define=API_BASE_URL`로 API 서버 주소를 앱에 내장합니다.
사용자는 아무 설정 없이 앱을 실행하면 해당 서버로 자동 연결됩니다:

```bash
# 로컬 네트워크 서버 (같은 Wi-Fi 내 시연 등)
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.0.10:8000

# 클라우드 배포 서버
flutter build apk --release --dart-define=API_BASE_URL=https://your-domain.com
```

#### API URL 우선순위

| 순위 | 소스 | 용도 |
|------|------|------|
| 1 | `--dart-define=API_BASE_URL=...` | 배포 빌드 시 서버 주소 내장 |
| 2 | `.env.local`의 `API_BASE_URL` | 개발 시 개인 설정 |
| 3 | 플랫폼별 localhost | 개발 기본값 (Android: 10.0.2.2, 그 외: localhost) |

## CI/CD 환경에서의 사용

CI/CD 파이프라인에서는 다음 순서로 실행하세요:

1. 환경 변수 설정 (.env.local 파일)
2. `./scripts/setup-firebase.sh` 스크립트 실행
3. Flutter 빌드 실행

## 보안 주의사항

- ⚠️ `.env.local` 파일은 절대 Git에 커밋하지 마세요 (이미 .gitignore에 포함되어 있습니다)

## 파일 구조

```
Frontend/
├── .env.local             # 실제 환경 변수 (Git 미포함)
├── .env.example          # 환경 변수 템플릿
├── android/app/
│   └── google-services.json  # 생성되는 Firebase 설정 파일 (Git 미포함)
└── scripts/
    ├── setup-firebase.sh     # Firebase 설정 스크립트 (Linux/Mac)
    └── setup-firebase.bat    # Firebase 설정 스크립트 (Windows)
```

## 문제 해결

### 스크립트 실행 오류
- `.env.local` 파일이 있는지 확인
- 환경 변수가 올바르게 설정되었는지 확인
- 스크립트 실행 권한이 있는지 확인 (Linux/Mac)

### 빌드 오류
- `google-services.json` 파일이 생성되었는지 확인
- Firebase 프로젝트 설정이 올바른지 확인
