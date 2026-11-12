@echo off
REM Fix Firebase Web Error Script for Windows

echo 🔥 Fixing Firebase Web Error...

REM Step 1: Clean everything
echo 📦 Cleaning Flutter project...
flutter clean

REM Step 2: Remove lock file
echo 🗑️  Removing pubspec.lock...
if exist pubspec.lock del pubspec.lock

REM Step 3: Get packages
echo 📥 Getting packages...
flutter pub get

REM Step 4: Upgrade Firebase packages
echo ⬆️  Upgrading Firebase packages...
flutter pub upgrade firebase_core firebase_auth cloud_functions

REM Step 5: Done
echo ✅ Done! Now update your Firebase config in web/index.html
echo.
echo Next steps:
echo 1. Open web/index.html
echo 2. Replace YOUR_API_KEY, YOUR_PROJECT_ID, etc. with your actual Firebase config
echo 3. Run: flutter run -d chrome
echo.
echo 🚀 Ready to test!
pause
