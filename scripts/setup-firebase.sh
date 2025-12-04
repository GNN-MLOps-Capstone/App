#!/bin/bash

# Firebase Setup Script
# This script sets up Firebase configuration from environment variables

echo "🔧 Setting up Firebase configuration..."

# Check if .env.local exists
if [ ! -f ".env.local" ]; then
    echo "❌ Error: .env.local file not found!"
    echo "Please copy .env.example to .env.local and fill in your Firebase credentials."
    exit 1
fi

# Load environment variables
source .env.local

# Check if required variables are set
required_vars=(
    "FIREBASE_PROJECT_NUMBER"
    "FIREBASE_PROJECT_ID"
    "FIREBASE_STORAGE_BUCKET"
    "FIREBASE_MOBILESDK_APP_ID"
    "FIREBASE_API_KEY"
    "FIREBASE_CLIENT_ID"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Error: $var is not set in .env.local"
        exit 1
    fi
done

echo "✅ All required environment variables are set"

# Clean up existing generated files
echo "🧹 Cleaning up existing generated files..."
rm -f android/app/src/google-services.json

# Run Gradle task to generate google-services.json
echo "🏗️  Generating google-services.json..."
cd android
./gradlew app:generateGoogleServicesJson

if [ $? -eq 0 ]; then
    echo "✅ Firebase configuration setup complete!"
    echo "🚀 You can now run flutter run to start the app"
else
    echo "❌ Error: Failed to generate google-services.json"
    exit 1
fi