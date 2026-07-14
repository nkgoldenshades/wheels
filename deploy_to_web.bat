@echo off
REM ============================================================================
REM QuickOHunt Web Deployment Script
REM ============================================================================
REM This script:
REM 1. Builds Flutter web app (compiled JavaScript)
REM 2. Copies to Vaultwheels-web repository
REM 3. Commits and pushes to GitHub
REM 4. App goes live on GitHub Pages
REM ============================================================================

echo.
echo ============================================
echo   QuickOHunt Web Deployment
echo ============================================
echo.

REM --- CONFIGURATION (UPDATE THESE PATHS) ---
set SOURCE_DIR=E:\quickohunt
set WEB_REPO_DIR=E:\Vaultwheels-web
REM If Vaultwheels-web is in a different location, update WEB_REPO_DIR above

echo [1/5] Checking directories...
if not exist "%SOURCE_DIR%" (
    echo ERROR: Source directory not found: %SOURCE_DIR%
    pause
    exit /b 1
)

if not exist "%WEB_REPO_DIR%" (
    echo WARNING: Web repo directory not found: %WEB_REPO_DIR%
    echo Please clone the Vaultwheels-web repository first:
    echo   git clone https://github.com/nkgoldenshades/Vaultwheels-web.git
    echo.
    set /p WEB_REPO_DIR="Enter the correct path to Vaultwheels-web folder: "
)

echo Source: %SOURCE_DIR%
echo Target: %WEB_REPO_DIR%
echo.

echo [2/5] Building Flutter web app (this may take a few minutes)...
cd /d "%SOURCE_DIR%"
call flutter clean
call flutter build web --release

if errorlevel 1 (
    echo ERROR: Flutter build failed!
    pause
    exit /b 1
)

echo.
echo [3/5] Copying build files to Vaultwheels-web repository...

REM Clear old files (except .git folder)
echo Cleaning target directory...
for /d %%D in ("%WEB_REPO_DIR%\*") do (
    if /i not "%%~nxD"==".git" (
        rd /s /q "%%D"
    )
)
for %%F in ("%WEB_REPO_DIR%\*") do (
    if /i not "%%~nxF"==".git" (
        del /q "%%F"
    )
)

REM Copy new build
echo Copying new build files...
xcopy /s /e /y "%SOURCE_DIR%\build\web\*" "%WEB_REPO_DIR%\"

if errorlevel 1 (
    echo ERROR: Failed to copy files!
    pause
    exit /b 1
)

echo.
echo [4/5] Committing to Git...
cd /d "%WEB_REPO_DIR%"

git add .

REM Check if there are changes to commit
git diff --cached --quiet
if errorlevel 1 (
    echo Changes detected, creating commit...
    git commit -m "Deploy: %date% %time%"
) else (
    echo No changes to commit.
    echo.
    echo ============================================
    echo   Deployment Complete (No Changes)
    echo ============================================
    pause
    exit /b 0
)

echo.
echo [5/5] Pushing to GitHub...
git push origin main

if errorlevel 1 (
    echo ERROR: Failed to push to GitHub!
    echo Please check your internet connection and Git credentials.
    pause
    exit /b 1
)

echo.
echo ============================================
echo   SUCCESS! Deployment Complete
echo ============================================
echo.
echo Your app is now live at:
echo https://nkgoldenshades.github.io/Vaultwheels-web/
echo.
echo Note: It may take 1-2 minutes for GitHub Pages to update.
echo.
pause
