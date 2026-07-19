@echo off
echo ========================================
echo  VaultWheels Deployment Script
echo ========================================
echo.

echo Step 1: Building Flutter Web App...
echo.
call flutter build web --release

if %errorlevel% neq 0 (
    echo.
    echo ❌ Build failed! Please fix errors above.
    pause
    exit /b 1
)

echo.
echo ✅ Build successful!
echo.

echo Step 2: Deploying to Firebase Hosting...
echo.
call firebase deploy --only hosting

if %errorlevel% neq 0 (
    echo.
    echo ❌ Deploy failed! Check Firebase configuration.
    pause
    exit /b 1
)

echo.
echo ========================================
echo  ✅ Deployment Complete!
echo ========================================
echo.
echo Your app is now live at:
echo   https://quickohunt-app.web.app
echo   https://quickohunt-app.firebaseapp.com
echo.
echo 📋 Next Steps:
echo   1. Open Firebase Console
echo   2. Go to Hosting section
echo   3. Click "Add custom domain"
echo   4. Enter: vaultwheels.vervestrideai.com
echo   5. Follow DNS setup instructions
echo.
echo Firebase Console:
echo   https://console.firebase.google.com/project/quickohunt-app/hosting
echo.
pause
