@echo off
echo ========================================
echo  Cleaning and Restarting Flutter App
echo ========================================
echo.

echo Step 1: Cleaning Flutter build cache...
flutter clean
if %errorlevel% neq 0 (
    echo ERROR: Flutter clean failed
    pause
    exit /b 1
)
echo ✅ Clean complete
echo.

echo Step 2: Removing build directory...
if exist build rmdir /s /q build
echo ✅ Build directory removed
echo.

echo Step 3: Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Flutter pub get failed
    pause
    exit /b 1
)
echo ✅ Dependencies updated
echo.

echo Step 4: Starting app with HTML renderer...
echo.
echo ========================================
echo  App is starting...
echo  Press Ctrl+C to stop
echo ========================================
echo.

flutter run -d chrome --web-renderer html

pause
