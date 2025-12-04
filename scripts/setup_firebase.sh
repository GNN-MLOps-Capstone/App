#!/bin/bash

# Firebase 환경 변수 설정 스크립트
# 이 스크립트는 빌드 시점에 환경 변수를 읽어서 google-services.json 파일을 생성합니다.

set -e

# 스크립트 실행 디렉토리 이동
cd "$(dirname "$0")/.."

# .env 파일이 있는지 확인
if [ ! -f .env ]; then
    echo "Error: .env 파일을 찾을 수 없습니다. .env.example 파일을 복사하여 설정하세요."
    exit 1
fi

# .env 파일에서 환경 변수 로드
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# 필수 환경 변수가 있는지 확인
required_vars=(
    "FIREBASE_PROJECT_NUMBER"
    "FIREBASE_PROJECT_ID"
    "FIREBASE_STORAGE_BUCKET"
    "FIREBASE_MOBILESDK_APP_ID"
    "FIREBASE_API_KEY"
    "FIREBASE_CLIENT_ID"
    "FIREBASE_IOS_CLIENT_ID"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
    echo "Error: 다음 환경 변수가 설정되지 않았습니다:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    exit 1
fi

# google-services.json 파일 생성
cat > android/app/google-services.json << EOF
{
  "project_info": {
    "project_number": "$FIREBASE_PROJECT_NUMBER",
    "project_id": "$FIREBASE_PROJECT_ID",
    "storage_bucket": "$FIREBASE_STORAGE_BUCKET"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "$FIREBASE_MOBILESDK_APP_ID",
        "android_client_info": {
          "package_name": "kim.gwanwoo.bikemarket.new"
        }
      },
      "oauth_client": [
        {
          "client_id": "$FIREBASE_CLIENT_ID",
          "client_type": 3
        }
      ],
      "api_key": [
        {
          "current_key": "$FIREBASE_API_KEY"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": [
            {
              "client_id": "$FIREBASE_CLIENT_ID",
              "client_type": 3
            },
            {
              "client_id": "$FIREBASE_IOS_CLIENT_ID",
              "client_type": 2,
              "ios_info": {
                "bundle_id": "kim.gwanwoo.bikemarket.new"
              }
            }
          ]
        }
      }
    }
  ],
  "configuration_version": "1"
}
EOF

echo "✅ google-services.json 파일이 성공적으로 생성되었습니다."