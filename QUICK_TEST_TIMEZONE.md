# 🧪 Quick Test Guide - Timezone Fix

## What Was Fixed

Changed timezone conversion from `.toLocal()` to `.toUtc()` when storing times to Supabase.

---

## Test Steps

### 1️⃣ Restart the App
```bash
# Stop the app completely
# Then restart:
flutter run
```

### 2️⃣ Create a Test Post

1. **Login** to the app
2. **Go to** "Create Post" or "Add Vehicle Post"
3. **Select a specific time:** 
   - Example: **9:30 AM** (your current local time)
4. **Fill in** other required fields
5. **Submit** the post

### 3️⃣ Check Console Logs

Look for these logs in your console:

```
⏰ TIME DEBUG - START ⏰
slot.startTime: 2026-04-15 09:30:00.000
slot.startTime.isUtc: false
startTime ISO: 2026-04-15T09:30:00.000
⏰ TIME DEBUG - END ⏰
📤 Inserting: start_time=2026-04-15T04:00:00.000Z  ← Should be UTC!
✅ Slot synced to Supabase
```

**Expected:** `start_time` should be ~5.5 hours earlier than your input (IST → UTC conversion)

### 4️⃣ Verify in Supabase

1. **Open** Supabase Dashboard
2. **Go to** Table Editor → `posts` table
3. **Find** your newly created post
4. **Check** the `start_time` column:
   - Should show **UTC time** (5.5 hours earlier than IST)
   - Example: If you entered 9:30 AM IST, it should show ~4:00 AM UTC

### 5️⃣ Verify in App Display

1. **Refresh** the app (pull down on posts list)
2. **Find** your post in the feed
3. **Check** the displayed time:
   - Should show **9:30 AM** (same as you entered)
   - NOT 2:30 PM or any other wrong time

---

## ✅ Success Criteria

| Check | Expected Result |
|-------|----------------|
| Console log shows UTC conversion | `start_time=2026-04-15T04:00:00.000Z` (UTC) |
| Supabase stores UTC | ~4:00 AM UTC for 9:30 AM IST input |
| App displays local time | 9:30 AM (same as input) |
| Post expires at correct time | Disappears after end time passes |

---

## ❌ If Something's Wrong

### Problem: Time still shows wrong in app
**Solution:** Make sure you restarted the app completely (not hot reload)

### Problem: Console doesn't show UTC conversion
**Solution:** Check that the changes were saved:
```bash
git diff lib/services/slot_repository.dart
# Should show: .toUtc().toIso8601String()
```

### Problem: Supabase shows wrong time
**Solution:** Delete old posts and create a new one after the fix

---

## 📝 Example Test Case

```
Input Time:     9:30 AM IST (April 15, 2026)
                ↓
Console Log:    start_time=2026-04-15T04:00:00.000Z
                ↓
Supabase:       2026-04-15 04:00:00+00 (UTC)
                ↓
App Display:    9:30 AM (April 15, 2026)
```

**Result:** ✅ Times match correctly!

---

## 🐛 Debug Commands

If you need to debug further:

```bash
# Check current changes
git status

# View the exact changes
git diff lib/services/slot_repository.dart
git diff lib/services/customer_slot_repository.dart

# Run with verbose logging
flutter run -v
```

---

**Status:** Ready to test! 🚀

**Next:** Create a post and verify the times match correctly.
