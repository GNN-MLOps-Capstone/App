@echo off
REM Firebase Setup Script for Windows
REM This script sets up Firebase configuration from environment variables

echo 🔧 Setting up Firebase configuration...

REM Check if .env.local exists
if not exist ".env.local" (
    echo ❌ Error: .env.local file not found!
    echo Please copy .env.example to .env.local and fill in your Firebase credentials.
    exit /b 1
)

REM Check if required variables are set (basic check)
findstr /C:"FIREBASE_PROJECT_NUMBER=" .env.local >nul
if errorlevel 1 (
    echo ❌ Error: FIREBASE_PROJECT_NUMBER is not set in .env.local
    exit /b 1
)

echo ✅ Environment file found

REM Clean up existing generated files
echo 🧹 Cleaning up existing generated files...
if exist "android\app\src\google-services.json" del "android\app\src\google-services.json"

REM Run Gradle task to generate google-services.json
echo 🏗️  Generating google-services.json...
cd android
call gradlew.bat app:generateGoogleServicesJson

if errorlevel 1 (
    echo ❌ Error: Failed to generate google-services.json
    exit /b 1
) else (
    echo ✅ Firebase configuration setup complete!
    echo 🚀 You can now run flutter run to start the app
)