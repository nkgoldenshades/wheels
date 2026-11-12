@echo off
REM Flutter Web Runner Script for Windows
REM Runs the app with HTML renderer to avoid CDN network issues

echo 🚀 Starting Flutter Web App with HTML Renderer...
echo 📝 This avoids Google CDN network issues
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Flutter is not installed or not in PATH
    exit /b 1
)

REM Run with HTML renderer
echo ▶️  Running: flutter run -d chrome --web-renderer html
echo.

flutter run -d chrome --web-renderer html
