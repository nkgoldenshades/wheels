# 🌐 Current Issue: Web CORS Error

## The Error You're Seeing

```
❌ Failed to check profile: ClientException: Failed to fetch
❌ Failed to sync slot to Supabase: ClientException: Failed to fetch
```

## Root Cause

You're running the Flutter app on **web** (browser), and browsers block requests to Supabase due to **CORS (Cross-Origin Resource Sharing)** restrictions.

### What is CORS?

CORS is a browser security feature that blocks web apps from making requests to different domains unless explicitly allowed.

**Your situation:**
- Your Flutter web app runs on: `http://localhost:XXXX`
- Supabase API is at: `https://uklltpopjovbhplbvltr.supabase.co`
- Browser blocks the request because domains don't match

## Quick Fix: Run on Mobile/Desktop

**The easiest solution is to NOT use web:**

```bash
# Check available devices
flutter devices

# Run on Android emulator/device
flutter run -d android

# Run on iOS simulator/device
flutter run -d ios

# Run on Windows
flutter run -d windows

# Run on macOS
flutter run -d macos

# Run on Linux
flutter run -d linux
```

**Why this works:**
- ✅ Mobile/desktop apps don't have CORS restrictions
- ✅ Better performance
- ✅ Full native features
- ✅ No browser limitations

## Alternative: Configure CORS in Supabase

If you must use web, configure CORS:

### Step 1: Add Allowed Origins

1. Go to **Supabase Dashboard**
2. Click **Settings** → **API**
3. Scroll to **CORS Configuration**
4. Add these origins:
   ```
   http://localhost:*
   http://127.0.0.1:*
   ```

### Step 2: Restart Your App

After configuring CORS, restart your Flutter web app:
```bash
flutter run -d chrome
```

## Development Workaround: Disable CORS in Chrome

**⚠️ WARNING: Only for development, NOT production!**

Run Chrome with CORS disabled:

**Windows:**
```bash
chrome.exe --user-data-dir="C:/Chrome dev session" --disable-web-security
```

**macOS:**
```bash
open -n -a /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --args --user-data-dir="/tmp/chrome_dev_test" --disable-web-security
```

**Linux:**
```bash
google-chrome --user-data-dir="/tmp/chrome_dev_test" --disable-web-security
```

Then run Flutter:
```bash
flutter run -d chrome
```

## How to Verify CORS is the Issue

1. Open browser DevTools (F12)
2. Go to **Console** tab
3. Look for error like:
   ```
   Access to fetch at 'https://...supabase.co/...' from origin 'http://localhost:...' 
   has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present
   ```

If you see this, it's definitely CORS.

## What I Added

### 1. Web Warning in Console ✅

When you run on web, you'll now see:

```
⚠️ ═══════════════════════════════════════════════════════
⚠️ WARNING: Running on WEB - CORS issues may occur!
⚠️ If you see "Failed to fetch" errors:
⚠️   1. Run on mobile/desktop instead: flutter run -d android
⚠️   2. Or configure CORS in Supabase Dashboard
⚠️   3. See FIX_SUPABASE_CORS_FOR_WEB.md for details
⚠️ ═══════════════════════════════════════════════════════
```

### 2. Documentation ✅

Created `FIX_SUPABASE_CORS_FOR_WEB.md` with detailed solutions.

## Recommended Next Steps

### Option 1: Use Mobile/Desktop (Recommended)

```bash
# If you have Android Studio installed
flutter run -d android

# Or Windows
flutter run -d windows
```

This will work immediately with no CORS issues.

### Option 2: Configure CORS for Web

1. Go to Supabase Dashboard
2. Configure CORS to allow `localhost`
3. Restart Flutter web app

### Option 3: Use Chrome with CORS Disabled (Quick Test)

1. Close all Chrome windows
2. Run Chrome with `--disable-web-security` flag
3. Run `flutter run -d chrome`

## Summary

**Problem:** Web browser blocks Supabase requests (CORS)  
**Best Solution:** Run on mobile/desktop instead of web  
**Alternative:** Configure CORS in Supabase Dashboard  
**Quick Test:** Use Chrome with CORS disabled (dev only)

**Command to fix immediately:**
```bash
flutter run -d android
# or
flutter run -d windows
```

---

**Status:** ⚠️ CORS issue on web  
**Action Required:** Run on mobile/desktop OR configure CORS  
**Files:** See `FIX_SUPABASE_CORS_FOR_WEB.md` for detailed solutions
