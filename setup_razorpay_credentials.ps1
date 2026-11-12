# Razorpay Credentials Setup Script for Firebase Functions (PowerShell)
# Run this once to configure your Razorpay credentials

Write-Host "🔧 Setting up Razorpay credentials in Firebase..." -ForegroundColor Cyan
Write-Host ""

Set-Location firebase_functions

# Set Razorpay credentials
Write-Host "📝 Setting RAZORPAY_KEY_ID..." -ForegroundColor Yellow
firebase functions:config:set razorpay.key_id="rzp_test_TyygacttLXjp96"

Write-Host "📝 Setting RAZORPAY_KEY_SECRET..." -ForegroundColor Yellow
firebase functions:config:set razorpay.key_secret="nUsRlMW4Ubw6MnB6OREhdeK9"

Write-Host ""
Write-Host "✅ Credentials set successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Verify configuration:" -ForegroundColor Cyan
firebase functions:config:get

Write-Host ""
Write-Host "🚀 Next steps:" -ForegroundColor Cyan
Write-Host "1. Deploy functions: firebase deploy --only functions" -ForegroundColor White
Write-Host "2. Test payment flow in your Flutter app" -ForegroundColor White
Write-Host "3. Check logs: firebase functions:log" -ForegroundColor White
Write-Host ""
