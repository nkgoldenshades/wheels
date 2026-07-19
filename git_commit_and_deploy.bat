@echo off
echo ========================================
echo  Git Commit and Deploy VaultWheels
echo ========================================
echo.

echo Step 1: Git Status
echo.
git status
echo.

set /p commit_message="Enter commit message (or press Enter for default): "

if "%commit_message%"=="" (
    set commit_message=Legal documents added - Ready for production deployment
)

echo.
echo Step 2: Adding all files to git...
git add .

echo.
echo Step 3: Committing with message: "%commit_message%"
git commit -m "%commit_message%"

echo.
echo Step 4: Pushing to remote repository...
git push origin main

if %errorlevel% neq 0 (
    echo.
    echo ⚠️ Git push failed. Common reasons:
    echo   - Not on main branch (try: git branch)
    echo   - No remote set up (try: git remote -v)
    echo   - Need to set upstream (try: git push -u origin main)
    echo.
    echo Continuing with deployment anyway...
    echo.
)

echo.
echo ========================================
echo  ✅ Git Commit Complete!
echo ========================================
echo.
echo Now deploying to Firebase...
echo.
pause

call deploy_vaultwheels.bat
