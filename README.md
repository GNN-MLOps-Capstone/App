# stock

A new Flutter project.

## API 설정

```dotenv
API_BASE_URL=https://api.api
GOOGLE_CLIENT_ID=<서버가 검증하는 Google OAuth Web Client ID>
```

`GOOGLE_CLIENT_ID`는 서버가 Google ID 토큰을 검증할 때 사용하는 OAuth Web Client ID와 같아야 합니다. 값이 다르면 로그인 또는 보호 API 호출에서 401/403 응답이 발생할 수 있습니다.

`.env.local` 대신 실행/빌드 시 `--dart-define`으로 주입할 수도 있습니다.

```sh
flutter run \
  --dart-define=API_BASE_URL=https://api.api \
  --dart-define=GOOGLE_CLIENT_ID='<서버가 검증하는 Google OAuth Web Client ID>'

flutter build apk \
  --dart-define=API_BASE_URL=https://api.api \
  --dart-define=GOOGLE_CLIENT_ID='<서버가 검증하는 Google OAuth Web Client ID>'
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
