@echo off
REM Firebase 환경 변수 설정 스크립트 (Windows)
REM 이 스크립트는 빌드 시점에 환경 변수를 읽어서 google-services.json 파일을 생성합니다.

setlocal enabledelayedexpansion

REM 스크립트 실행 디렉토리 이동
cd /d "%~dp0\.."

REM .env 파일이 있는지 확인
if not exist .env (
    echo Error: .env 파일을 찾을 수 없습니다. .env.example 파일을 복사하여 설정하세요.
    exit /b 1
)

REM .env 파일에서 환경 변수 로드
for /f "tokens=1,2 delims==" %%a in ('type .env ^| findstr /v "^#"') do (
    set %%a=%%b
)

REM 필수 환경 변수가 있는지 확인
set missing_vars=0

if "%FIREBASE_PROJECT_NUMBER%"=="" (
    echo Error: FIREBASE_PROJECT_NUMBER가 설정되지 않았습니다.
    set missing_vars=1
)

if "%FIREBASE_PROJECT_ID%"=="" (
    echo Error: FIREBASE_PROJECT_ID가 설정되지 않았습니다.
    set missing_vars=1
)

if "%FIREBASE_STORAGE_BUCKET%"=="" (
    echo Error: FIREBASE_STORAGE_BUCKET가 설정되지 않았습니다.
    set missing_vars=1
)

if "%FIREBASE_MOBILESDK_APP_ID%"=="" (
    echo Error: FIREBASE_MOBILESDK_APP_ID가 설정되지 않았습니다.
    set missing_vars=1
)

if "%FIREBASE_API_KEY%"=="" (
    echo Error: FIREBASE_API_KEY가 설정되지 않았습니다.
    set missing_vars=1
)

if "%FIREBASE_CLIENT_ID%"=="" (
    echo Error: FIREBASE_CLIENT_ID가 설정되지 않았습니다.
    set missing_vars=1
)

if "%FIREBASE_IOS_CLIENT_ID%"=="" (
    echo Error: FIREBASE_IOS_CLIENT_ID가 설정되지 않았습니다.
    set missing_vars=1
)

if %missing_vars%==1 (
    exit /b 1
)

REM google-services.json 파일 생성
(
echo {
echo   "project_info": {
echo     "project_number": "%FIREBASE_PROJECT_NUMBER%",
echo     "project_id": "%FIREBASE_PROJECT_ID%",
echo     "storage_bucket": "%FIREBASE_STORAGE_BUCKET%"
echo   },
echo   "client": [
echo     {
echo       "client_info": {
echo         "mobilesdk_app_id": "%FIREBASE_MOBILESDK_APP_ID%",
echo         "android_client_info": {
echo           "package_name": "kim.gwanwoo.bikemarket.new"
echo         }
echo       },
echo       "oauth_client": [
echo         {
echo           "client_id": "%FIREBASE_CLIENT_ID%",
echo           "client_type": 3
echo         }
echo       ],
echo       "api_key": [
echo         {
echo           "current_key": "%FIREBASE_API_KEY%"
echo         }
echo       ],
echo       "services": {
echo         "appinvite_service": {
echo           "other_platform_oauth_client": [
echo             {
echo               "client_id": "%FIREBASE_CLIENT_ID%",
echo               "client_type": 3
echo             },
echo             {
echo               "client_id": "%FIREBASE_IOS_CLIENT_ID%",
echo               "client_type": 2,
echo               "ios_info": {
echo                 "bundle_id": "kim.gwanwoo.bikemarket.new"
echo               }
echo             }
echo           ]
echo         }
echo       }
echo     }
echo   ],
echo   "configuration_version": "1"
echo }
) > android\app\google-services.json

echo ✅ google-services.json 파일이 성공적으로 생성되었습니다.