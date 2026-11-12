# 🎯 Action Plan: Verify and Fix "Unknown User"

## ⚠️ Critical Understanding

For this to work, **column names must match exactly**:

```
Supabase View Column  →  Flutter Code
────────────────────     ─────────────
profile_name         →   json['profile_name']  ✅
```

---

## 📋 Step-by-Step Action Plan

### Step 1: Verify What Your View Actually Has

Run this in Supabase SQL Editor:

```sql
-- Quick check: What columns exist?
SELECT 
  column_name
FROM information_schema.columns
WHERE table_name = 'vehicles_public'
  AND column_name IN ('profile_name', 'user_name')
ORDER BY column_name;
```

**Possible Results:**

#### Result A: Shows `profile_name`
```
| column_name  |
|--------------|
| profile_name |  ✅
```
→ **Action:** ✅ View is correct, go to Step 2

#### Result B: Shows `user_name`
```
| column_name |
|-------------|
| user_name   |  ⚠️
```
→ **Action:** ⚠️ View has wrong column name, go to Step 1b

#### Result C: Shows both
```
| column_name  |
|--------------|
| profile_name |
| user_name    |
```
→ **Action:** ✅ Both exist (redundant but works), go to Step 2

#### Result D: Shows neither
```
(empty result)
```
→ **Action:** ❌ View is broken, go to Step 1b

---

### Step 1b: Fix View (Only if Result B or D above)

If your view has `user_name` instead of `profile_name`, recreate it:

```sql
DROP VIEW IF EXISTS vehicles_public CASCADE;

CREATE OR REPLACE VIEW vehicles_public AS
SELECT 
  v.*,
  p.full_name AS profile_name,           -- ✅ Match Flutter
  p.profile_photo_url AS profile_avatar, -- ✅ Match Flutter
  CASE 
    WHEN v.profile_id = (auth.jwt() ->> 'sub'::text) THEN true
    ELSE false
  END AS is_owner
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
WHERE 
  v.is_active = true OR v.profile_id = (auth.jwt() ->> 'sub'::text);

GRANT SELECT ON vehicles_public TO anon, authenticated;
```

Then verify:
```sql
SELECT profile_name FROM vehicles_public LIMIT 1;
```

Should return a name (not error, not NULL).

---

### Step 2: Verify View Returns Data

```sql
SELECT 
  id,
  vehicle_name,
  profile_name,  -- Should show actual names
  profile_id
FROM vehicles_public 
LIMIT 5;
```

**Expected:**
```
| id   | vehicle_name | profile_name | profile_id |
|------|-------------|-------------|-----------|
| v123 | Honda City  | John Doe    | u456      |
| v124 | Yamaha R15  | Jane Smith  | u457      |
```

**If `profile_name` is NULL:**

Check profiles table:
```sql
SELECT 
  id, 
  full_name,
  email
FROM profiles 
WHERE id IN (
  SELECT DISTINCT profile_id FROM vehicles LIMIT 5
);
```

If `full_name` is NULL:
- Users need to set their names in profiles
- OR use `operator_name` as fallback

---

### Step 3: Verify Flutter Code

Check that `lib/models/vehicle.dart` has:

```dart
final userName = json['profile_name'] ??  // ✅ First priority
                 json['user_name'] ??     // Fallback
                 json['userName'] ?? 
                 json['full_name'] ??
                 json['operator_name'] ??
                 'Unknown User';
```

✅ Already updated in previous fix.

---

### Step 4: Full Restart Flutter

**CRITICAL:** Hot reload will NOT work!

```bash
# Stop app completely
flutter clean
flutter pub get
flutter run
```

---

### Step 5: Check Debug Logs

Look for these logs in Flutter console:

```
🔍 Raw Supabase response (first vehicle): {id: xxx, profile_name: John Doe, ...}
🔍 Vehicle.fromJson: id=xxx, profile_name=John Doe, ... → final=John Doe
✅ Loaded 5 vehicles from Supabase
🔍 First vehicle: id=xxx, userName=John Doe, name=Honda City
```

**Interpretation:**

✅ `profile_name=John Doe` → Working correctly!
❌ `profile_name=null` → View not returning data, go back to Step 2
❌ No logs → App not restarted, go back to Step 4

---

### Step 6: Verify Result

Check Common Feed in your app:

**Expected:**
```
┌─────────────────────┐
│ John Doe           │  ✅ Real name
│ Honda City         │  ✅ Real vehicle
│ ₹500/day           │
└─────────────────────┘
```

**If still "Unknown User":**
- Check debug logs from Step 5
- Share logs for further diagnosis

---

## 🔍 Quick Diagnostic Script

Run this to get a complete picture:

```sql
-- File: QUICK_VERIFY_VIEW_COLUMNS.sql
-- (Already created, just run it)
```

This will tell you:
- ✅ Which columns exist (profile_name vs user_name)
- ✅ Sample values
- ✅ View definition

---

## 📊 Troubleshooting Matrix

| Symptom | Cause | Fix |
|---------|-------|-----|
| SQL error: "column profile_name does not exist" | View has `user_name` not `profile_name` | Run Step 1b |
| `profile_name` is NULL in SQL | Profiles missing `full_name` | Update profiles table |
| Debug logs show `profile_name=null` | View not joining correctly | Recreate view (Step 1b) |
| Debug logs show `profile_name=John Doe` but still "Unknown User" | Flutter cache | `flutter clean` |
| No debug logs | App not restarted | Full restart (Step 4) |

---

## ✅ Success Criteria

All of these must be true:

- [ ] SQL: `SELECT profile_name FROM vehicles_public LIMIT 1;` returns a name
- [ ] SQL: `profile_name` is NOT NULL
- [ ] Flutter: Debug logs show `profile_name=John Doe`
- [ ] Flutter: App fully restarted (not hot reload)
- [ ] UI: Common Feed shows actual names

If all checked → **Fixed!** 🎉

---

## 📁 Files to Use

1. **`QUICK_VERIFY_VIEW_COLUMNS.sql`** - Run this first to diagnose
2. **`VERIFY_COLUMN_NAMES_MATCH.md`** - Detailed explanation
3. **`FINAL_FIX_PROFILE_NAME.md`** - Complete guide

---

## 🎯 TL;DR

1. Run `QUICK_VERIFY_VIEW_COLUMNS.sql` to see what you have
2. If view has `profile_name` → Just restart Flutter
3. If view has `user_name` → Recreate view with `profile_name`
4. Verify with debug logs
5. Done! ✅
