# Fix Supabase CORS for Flutter Web

## The Problem

When running Flutter app on **web**, you get:
```
❌ Failed to fetch: ClientException
```

This is a **CORS (Cross-Origin Resource Sharing)** error. Browsers block requests to Supabase unless CORS is configured.

## Solution 1: Run on Mobile/Desktop (Recommended)

Web has CORS restrictions. Run on a real platform instead:

```bash
# Check available devices
flutter devices

# Run on Android
flutter run -d android

# Run on iOS  
flutter run -d ios

# Run on Windows
flutter run -d windows

# Run on macOS
flutter run -d macos
```

**Why this is better:**
- ✅ No CORS issues
- ✅ Better performance
- ✅ Full native features
- ✅ No browser restrictions

## Solution 2: Configure CORS in Supabase (For Web Development)

If you must use web, configure CORS:

### Step 1: Add Allowed Origins in Supabase

1. Go to **Supabase Dashboard**
2. Click **Settings** → **API**
3. Scroll to **CORS Configuration**
4. Add your web app origins:
   ```
   http://localhost:*
   http://127.0.0.1:*
   https://your-domain.com
   ```

### Step 2: Update Supabase Client Configuration

In your Flutter web app, ensure Supabase client is configured for web:

```dart
await Supabase.initialize(
  url: SupabaseConfig.url,
  anonKey: SupabaseConfig.anonKey,
  authOptions: FlutterAuthClientOptions(
    authFlowType: AuthFlowType.pkce, // Use PKCE for web
  ),
);
```

### Step 3: Use Chrome with CORS Disabled (Development Only)

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

Then run your Flutter web app:
```bash
flutter run -d chrome
```

## Solution 3: Use Flutter Web with Proxy (Advanced)

Create a proxy server to bypass CORS:

1. Create `proxy.js`:
```javascript
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();

app.use('/api', createProxyMiddleware({
  target: 'https://uklltpopjovbhplbvltr.supabase.co',
  changeOrigin: true,
  pathRewrite: {
    '^/api': '',
  },
}));

app.listen(3000, () => {
  console.log('Proxy server running on http://localhost:3000');
});
```

2. Update Supabase URL in Flutter:
```dart
url: 'http://localhost:3000/api',
```

## Recommended Approach

### For Development
1. **Use mobile emulator or desktop** - No CORS issues
2. **Or use Chrome with CORS disabled** - Quick but insecure

### For Production
1. **Deploy as mobile app** (Android/iOS) - Best user experience
2. **Or configure CORS properly** in Supabase Dashboard
3. **Never disable CORS in production** - Security risk

## Current Error Explained

```
❌ Failed to check profile: ClientException: Failed to fetch
```

**What's happening:**
1. Flutter web app tries to fetch from Supabase
2. Browser blocks the request (CORS policy)
3. Supabase never receives the request
4. App gets "Failed to fetch" error

**Why it happens:**
- Browser security prevents cross-origin requests
- Supabase URL is different from your app's URL
- CORS headers not configured to allow your app

**How to fix:**
- Run on mobile/desktop (no CORS restrictions)
- Or configure CORS in Supabase Dashboard

## Quick Test

To verify CORS is the issue, check browser console:

1. Open browser DevTools (F12)
2. Go to Console tab
3. Look for error:
   ```
   Access to fetch at 'https://...supabase.co/...' from origin 'http://localhost:...' 
   has been blocked by CORS policy
   ```

If you see this, it's definitely CORS.

## Summary

**Problem:** CORS blocks Supabase requests on web  
**Best Solution:** Run on mobile/desktop instead of web  
**Alternative:** Configure CORS in Supabase Dashboard  
**Quick Fix:** Use Chrome with CORS disabled (dev only)

---

**Recommendation:** Use `flutter run -d android` or `flutter run -d windows` instead of web for development.
