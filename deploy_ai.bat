@echo off
echo 🚀 Deploying Firebase AI Functions...

REM Check if we're in the right directory
if not exist "functions\package.json" (
    echo ❌ Error: Run this script from your project root directory
    exit /b 1
)

REM Install dependencies
echo 📦 Installing dependencies...
cd functions
call npm install

REM Deploy functions
echo 🚀 Deploying Firebase Functions...
cd ..
call firebase deploy --only functions

if %errorlevel% equ 0 (
    echo ✅ Deployment successful!
    echo 🎉 Your AI is now ready with natural responses!
    echo.
    echo Next steps:
    echo 1. Test the AI chat in your app
    echo 2. You should get natural, conversational responses
    echo 3. Check Firebase Console ^> Functions for logs
) else (
    echo ❌ Deployment failed!
    echo Check the error messages above and try again
)

pause