# Issues Found & Fixes Needed

## Issue 1: End Time Not Editable (Stays on Default)

**Location:** `lib/screens/add_flow/create_post_screen.dart` line 191

**Bug:**
```dart
final current = isStart ? _startTime! : _endTime!;  // ← BUG: crashes if _endTime is null
```

**Problem:** When clicking to edit end time, if `_endTime` is null, the `!` (bang operator) crashes because null is force-unwrapped.

**Fix:**
```dart
final current = isStart 
    ? (_startTime ?? DateTime.now().add(const Duration(hours: 1)))
    : (_endTime ?? _startTime ?? DateTime.now().add(const Duration(hours: 9)));
```

**Status:** NEED TO FIX

---

## Issue 2: Currency Showing in Dollars Instead of INR

**Location:** Multiple places

**Problem:** Currency defaults to USD instead of INR for users

**Root cause:** Need to check:
1. `AppPreferences.currencyCode.value` initialization
2. User's currency setting in profile

**Check:**
- Open Settings/Currency Selector
- Make sure currency is set to INR
- Refresh app

**Default:** Should be INR for India users (set in `app_preferences.dart` line 42)

**Status:** May be user setting issue, OR need to fix default currency for India

---

## Summary

| Issue | Fix | Complexity |
|-------|-----|-----------|
| End time editable | Fix null safety in _selectTime | LOW |
| Currency shows USD | Check user preferences + default | LOW |

Both are simple fixes. Should I apply them now?
