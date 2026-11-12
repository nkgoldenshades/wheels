# Decision Log: auto_deactivate_expired_posts RPC Function

**Date:** July 23, 2026  
**Issue:** 404 error on `auto_deactivate_expired_posts` RPC call  
**Status:** RESOLVED - Function call REMOVED (not deployed)

---

## What Happened

1. **Code had RPC call** in `booking_repository.dart` to `auto_deactivate_expired_posts()`
2. **Function was never deployed** to Supabase (existed in SQL file but not in database)
3. **404 error occurred** when Flutter tried to call it
4. **Code silently caught the error** with try-catch, so app didn't crash

---

## Why This Function Wasn't Critical

The function's purpose: Auto-mark expired posts in the database as "ended"

**The reality:**
- This is a **frontend display concern**, not backend logic
- Posts are already filtered in queries using `WHERE end_time > NOW()`
- Filtering expired posts is handled at the query level, not via RPC
- Not critical for data integrity or bookings

---

## Decision Made

**REMOVED the RPC call entirely** from `booking_repository.dart`

**Why:**
- Function was non-essential
- Caused 404 errors
- Could be handled frontend-side if needed
- Keeping only the critical function: `expire_overdue_bookings()` which marks bookings as expired

---

## What Was Changed

**File:** `lib/services/booking_repository.dart`

**Removed:**
```dart
// Deactivate posts whose end_time has passed
try {
  final r2 = await supabase.rpc('auto_deactivate_expired_posts');
  if (r2 != null) {
    final count = (r2 as Map<String, dynamic>)['deactivated_posts'] ?? 0;
    if (count > 0) {
      debugPrint('📴 Auto-deactivated $count expired post(s)');
    }
  }
} catch (_) {
  // RPC not deployed — silently skip
}
```

**Result:** No more 404 errors, cleaner code

---

## Expired Posts in Feed

**Q: Do expired posts show in the feed after end_time?**

**A:** ✅ **NO - Already handled by queries!**

**Your queries already filter expired posts:**

```dart
// slot_repository.dart line 177
.gt('end_time', nowUtc)

// customer_slot_repository.dart line 132
.gt('end_time', DateTime.now().toUtc().toIso8601String())
```

This means:
- Posts are only shown if `end_time > NOW()`
- When end_time passes, posts automatically disappear from feed
- No need for backend RPC function to deactivate posts
- Everything works as expected ✅

---

## Lesson Learned

**Don't deploy RPC functions that are:**
- Frontend display concerns only
- Already handled by query filters
- Non-critical to business logic

**Do deploy RPC functions that are:**
- Critical to bookings/payments (like `expire_overdue_bookings`)
- Required for data integrity
- Part of the core system

---

## Files Affected

- ✅ `lib/services/booking_repository.dart` - Removed unnecessary RPC call
- ❌ `DEPLOY_MISSING_AUTO_DEACTIVATE.sql` - Not needed (can be deleted)
- ❌ `ACTUAL_FIX_DEPLOY_RPC.sql` - Not needed (can be deleted)

---

**Status:** ✅ RESOLVED - No 404 errors, app works cleanly
