# ⚠️ Critical: Verify Column Names Match Between View and Flutter

## 🎯 The Issue

For this to work, the column names must match **exactly** between:
1. Your Supabase `vehicles_public` view
2. Flutter's `Vehicle.fromJson()` method

## 🔍 Current State

### Flutter Code (✅ Updated):
```dart
// lib/models/vehicle.dart
final userName = json['profile_name'] ??  // ✅ Reads profile_name
                 json['user_name'] ??     // Fallback
                 ...
```

### Your View (❓ Need to Verify):
You said you changed to `profile_name` and `profile_avatar`, but we need to confirm this is actually in your view.

---

## ✅ Step 1: Verify Your View Has Correct Column Names

Run this in Supabase SQL Editor:

```sql
-- Check what columns your view actually has
SELECT 
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'vehicles_public'
  AND column_name LIKE '%name%' OR column_name LIKE '%avatar%'
ORDER BY column_name;
```

**Expected Output (what you said you have):**
```
| column_name    | data_type |
|----------------|-----------|
| profile_avatar | text      |
| profile_name   | text      |  ✅ This is what Flutter expects
| vehicle_name   | text      |
```

**If you see `user_name` instead:**
```
| column_name    | data_type |
|----------------|-----------|
| user_avatar    | text      |
| user_name      | text      |  ❌ Flutter won't find this first
| vehicle_name   | text      |
```

---

## ✅ Step 2: Verify View Returns Data

```sql
-- Test if profile_name has actual values
SELECT 
  id,
  vehicle_name,
  profile_name,   -- ✅ Should show "John Doe", not NULL
  profile_id
FROM vehicles_public 
LIMIT 5;
```

**Expected:**
- `profile_name` column exists ✅
- `profile_name` has values like "John Doe" ✅
- NOT NULL ✅

**If `profile_name` is NULL:**
- Check profiles table: `SELECT id, full_name FROM profiles LIMIT 5;`
- If `full_name` is NULL, users need to set their names

---

## ✅ Step 3: Verify View Definition

```sql
-- See the exact SQL that creates your view
SELECT pg_get_viewdef('vehicles_public', true);
```

**Look for this line:**
```sql
p.full_name AS profile_name  -- ✅ Correct
```

**NOT this:**
```sql
p.full_name AS user_name  -- ❌ Wrong, Flutter expects profile_name
```

---

## 🔧 If Column Names Don't Match

### Scenario A: View has `user_name` but Flutter expects `profile_name`

**Option 1: Update View (Recommended)**
```sql
DROP VIEW IF EXISTS vehicles_public CASCADE;

CREATE OR REPLACE VIEW vehicles_public AS
SELECT 
  v.*,
  p.full_name AS profile_name,        -- ✅ Match Flutter
  p.profile_photo_url AS profile_avatar,  -- ✅ Match Flutter
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

**Option 2: Update Flutter (Alternative)**
```dart
// Change Flutter to read user_name first
final userName = json['user_name'] ??      // Read user_name
                 json['profile_name'] ??   // Fallback
                 ...
```

---

### Scenario B: View has `profile_name` (What you said)

**✅ Already correct!** Just verify with Step 1 above.

---

## 📊 Verification Checklist

Run through this to ensure everything matches:

### Backend (Supabase):
- [ ] View exists: `SELECT * FROM vehicles_public LIMIT 1;`
- [ ] View has `profile_name` column (not `user_name`)
- [ ] View has `profile_avatar` column (not `user_avatar`)
- [ ] `profile_name` returns actual names (not NULL)
- [ ] View joins with profiles: `p.full_name AS profile_name`

### Frontend (Flutter):
- [ ] `Vehicle.fromJson()` reads `json['profile_name']` first
- [ ] Debug logging shows: `profile_name=John Doe`
- [ ] App fully restarted (not hot reload)

### Result:
- [ ] Common Feed shows actual names (not "Unknown User")

---

## 🎯 The Golden Rule

**Column name in view MUST match what Flutter reads:**

```
Supabase View          Flutter Code
─────────────────      ─────────────────
profile_name      →    json['profile_name']  ✅ Match!
user_name         →    json['user_name']     ✅ Match!

profile_name      →    json['user_name']     ❌ No match!
user_name         →    json['profile_name']  ❌ No match!
```

---

## 🔍 Quick Test Command

Run this to see what your view actually has:

```sql
-- Show first row with all name/avatar columns
SELECT 
  id,
  profile_name,   -- Does this column exist?
  profile_avatar, -- Does this column exist?
  vehicle_name,
  profile_id
FROM vehicles_public 
LIMIT 1;
```

**If you get an error like "column profile_name does not exist":**
- Your view has `user_name`, not `profile_name`
- Either update view OR update Flutter to match

**If query works and shows data:**
- ✅ View is correct
- ✅ Flutter is correct
- ✅ Just restart Flutter app

---

## 💡 Summary

1. **Run Step 1** to see what columns your view actually has
2. **Verify** it matches what Flutter expects (`profile_name`)
3. **If mismatch** → Update view OR update Flutter
4. **Restart Flutter** completely
5. **Check debug logs** to confirm data is being read

The debug logs will tell you exactly what's happening! 🔍
