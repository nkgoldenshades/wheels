# Debug White Screen Issue

## What I Fixed

Added a custom `ErrorWidget.builder` in `MyApp` that will now show error details instead of a white screen.

## How to Debug

### 1. Check Browser Console (F12)
Open Chrome DevTools and look for:
- Red error messages
- Stack traces
- Failed network requests
- CORS errors

### 2. Common Causes of White Screen

#### A. Device Info Service Error
If you see errors related to `device_info_service.dart`:
- The new device info collection might be failing
- **Quick Fix**: Comment out the device info calls temporarily:

In `lib/services/auth_repository.dart`, comment out these lines:
```dart
// Record device session (fire-and-forget, non-blocking)
// unawaited(DeviceInfoService.instance.recordLoginSession(user.id));
```

#### B. Supabase Connection Error
If you see "Failed to connect to Supabase":
- Check if `CREATE_DEVICE_SESSIONS_TABLE.sql` was run
- The app might be trying to insert into a non-existent table
- **Quick Fix**: Run the SQL file in Supabase dashboard

#### C. Firebase/Supabase Init Error
If initialization fails:
- Check `lib/firebase_options.dart` has correct keys
- Check `lib/config/supabase_config.dart` has correct URL/key
- **Quick Fix**: The app should handle this gracefully now

### 3. Hot Restart
After the fix, do a **full restart** (not hot reload):
```bash
# Stop the app (Ctrl+C)
flutter run -d chrome --web-renderer html
```

Or press `R` (capital R) in the terminal for hot restart.

### 4. Check Specific Errors

#### Error: "Could not find summary for library"
**Status**: ✅ FIXED - This was the `(_, _)` syntax error in `vehicle_list_screen.dart`

#### Error: "Bad state: No element"
**Cause**: Trying to access empty list/collection
**Fix**: Check if any repository is trying to access data before it's loaded

#### Error: "Null check operator used on null value"
**Cause**: Using `!` on a null value
**Fix**: Check splash screen and main screen for null safety issues

### 5. Enable Verbose Logging

The app already has debug prints. Check terminal output for:
```
⏳ Initializing Firebase...
✅ Firebase initialized
⏳ Initializing AuthRepository...
✅ AuthRepository initialized
🚀 Starting app...
```

If you don't see these, initialization failed.

### 6. Test Without Device Info

If device info is causing issues, temporarily disable it:

**File**: `lib/services/auth_repository.dart`

Comment out both occurrences:
```dart
// In signUpWithEmail:
// unawaited(DeviceInfoService.instance.recordLoginSession(user.id));

// In signInWithEmail:
// unawaited(DeviceInfoService.instance.recordLoginSession(user.id));
```

Then hot restart.

### 7. Check Network Tab

In Chrome DevTools → Network tab, look for:
- Failed requests (red)
- 404 errors (missing endpoints)
- CORS errors (blocked by browser)
- Timeout errors

### 8. Minimal Test

Create a minimal test to isolate the issue:

**File**: `lib/main_test.dart`
```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Test App Works!'),
        ),
      ),
    );
  }
}
```

Run with:
```bash
flutter run -d chrome --web-renderer html -t lib/main_test.dart
```

If this works, the issue is in your main app initialization.

## Expected Behavior Now

Instead of white screen, you should see:
- ❌ **Before**: Blank white screen
- ✅ **After**: Error message with details and "Restart App" button

## Next Steps

1. **Hot restart** the app (press `R` in terminal)
2. **Check what error appears** (should show details now)
3. **Share the error message** so I can fix the root cause

## Quick Fixes Summary

| Issue | Quick Fix |
|-------|-----------|
| White screen | ✅ Added error widget - restart app |
| Device info error | Comment out `DeviceInfoService` calls |
| Supabase table missing | Run `CREATE_DEVICE_SESSIONS_TABLE.sql` |
| Syntax error | ✅ Fixed `(_, _)` → `(_, __)` |
| Init timeout | Already has timeout protection |

## Still White Screen?

If you still see white screen after restart:
1. Clear browser cache (Ctrl+Shift+Delete)
2. Close all Chrome windows
3. Run: `flutter clean && flutter pub get`
4. Run: `flutter run -d chrome --web-renderer html`

## Get More Help

Share the output from:
1. Browser console (F12 → Console tab)
2. Terminal output (where you ran `flutter run`)
3. Network tab (F12 → Network tab) - any red/failed requests
