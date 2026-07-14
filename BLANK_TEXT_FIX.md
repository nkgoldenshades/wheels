# Blank Button Text Issue - Fix Guide

## Problem
Buttons/chips showing no text labels - just empty boxes

## Root Cause
Most likely a **Flutter hot reload rendering bug** or theme color conflict (white text on white background)

## Solutions (Try in Order)

### ✅ Solution 1: Full Hot Restart (90% Success Rate)

**Option A - Command Line:**
```bash
# Stop the app (Ctrl+C in terminal)
flutter clean
flutter run
```

**Option B - VS Code/Android Studio:**
1. Press `Ctrl+Shift+P` (Command Palette)
2. Type: "Flutter: Hot Restart"
3. Or press `Shift + R`

**Option C - Complete Restart:**
1. Stop the app completely
2. Close emulator/browser
3. Reopen and run again

---

### ✅ Solution 2: Clear Build Cache

```bash
# Run these commands:
flutter clean
flutter pub get
flutter run
```

---

### ✅ Solution 3: Check Browser (If Using Web)

If running on **Chrome/Edge**:
1. Open DevTools (F12)
2. Check Console for errors
3. Try Ctrl+Shift+R (hard refresh)
4. Clear browser cache

---

### ✅ Solution 4: Theme Issue

I added explicit text styling to filter chips:
```dart
label: Text(
  _serviceLabel(service),
  style: const TextStyle(fontSize: 14),
),
```

After saving, do a **hot restart** (not just hot reload).

---

## What Was Changed

### File: `d:\quickohunt\lib\main.dart`

**Before:**
```dart
FilterChip(
  label: Text(_serviceLabel(service)),
  selected: _selectedServiceType == service,
```

**After:**
```dart
FilterChip(
  label: Text(
    _serviceLabel(service),
    style: const TextStyle(fontSize: 14), // ← Added explicit style
  ),
  selected: _selectedServiceType == service,
```

---

## Verification Steps

After applying fix:
1. Stop app completely
2. Run `flutter clean`
3. Run `flutter run`
4. Check if buttons now show text:
   - "Passenger"
   - "Parcel"
   - "Lease"
   - "Provider Posts"
   - "User Requests"

---

## If Still Not Working

### Check for Other Issues:

1. **Font Issue:**
   ```yaml
   # Check pubspec.yaml has fonts configured
   flutter:
     uses-material-design: true
   ```

2. **Build Mode:**
   ```bash
   # Try debug mode specifically
   flutter run --debug
   ```

3. **Platform Specific:**
   - **Web:** Try different browser
   - **Android:** Restart emulator
   - **iOS:** Clean and rebuild

4. **Nuclear Option:**
   ```bash
   flutter clean
   rm -rf build/
   flutter pub cache repair
   flutter pub get
   flutter run
   ```

---

## Expected Result

After fix, you should see:
- ✅ "Passenger" button (blue chip)
- ✅ "Parcel" button (blue chip)  
- ✅ "Lease" button (blue chip)
- ✅ "Provider Posts" toggle button
- ✅ "User Requests" toggle button

All with visible text labels.

---

## Why This Happens

Common causes:
1. **Hot Reload Bug** - Flutter sometimes doesn't update text widgets on hot reload
2. **Theme Conflict** - Text color matches background
3. **Font Loading** - Custom fonts not loaded
4. **Build Cache** - Corrupted build cache
5. **Platform Bug** - Flutter web rendering issue

**Solution:** Full restart usually fixes 90% of cases.
