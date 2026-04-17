# Fix: vehicles_public View Missing user_name Column

## 🔍 Problem Found

Looking at your Supabase screenshot, the `vehicles_public` view is missing the `user_name` column. This is why Flutter shows "Unknown User".

The view currently has:
- ✅ `profile_id`
- ✅ `vehicle_type`
- ✅ `vehicle_name`
- ✅ `seating_capacity`
- ❌ `user_name` (MISSING!)

## 🔧 Solution (2 Steps)

### Step 1: Check Current View Columns

Run this in Supabase SQL Editor:

```sql
-- See all columns in vehicles_public
SELECT 
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'vehicles_public'
ORDER BY column_name;
```

**Look for:** `user_name` column
- If it exists → Skip to Step 2
- If it doesn't exist → Continue below

---

### Step 2: Recreate View with user_name Column

Run this in Supabase SQL Editor:

```sql
-- Drop old view
DROP VIEW IF EXISTS vehicles_public CASCADE;

-- Create new view with user_name
CREATE OR REPLACE VIEW vehicles_public AS
SELECT 
  v.*,  -- All columns from vehicles table
  
  -- ✅ ADD USER INFORMATION
  p.full_name AS user_name,
  p.profile_photo_url AS user_avatar,
  
  -- Ownership flag
  CASE 
    WHEN v.profile_id = (auth.jwt() ->> 'sub'::text) THEN true
    ELSE false
  END AS is_owner
  
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id

WHERE 
  v.is_active = true OR v.profile_id = (auth.jwt() ->> 'sub'::text);

-- Grant access
GRANT SELECT ON vehicles_public TO anon, authenticated;
```

---

### Step 3: Verify user_name Column Exists

```sql
-- Check if user_name column is now in the view
SELECT 
  column_name
FROM information_schema.columns
WHERE table_name = 'vehicles_public'
  AND column_name = 'user_name';
```

**Expected:** 1 row with `column_name = 'user_name'`

---

### Step 4: Test View Returns Data

```sql
-- Test the view
SELECT 
  id,
  vehicle_name,
  user_name,  -- Should show actual names now!
  profile_id
FROM vehicles_public 
LIMIT 5;
```

**Expected:**
- `user_name` should show actual names (e.g., "John Doe")
- If `user_name` is NULL, check Step 5 below

---

### Step 5: Check if Profiles Have Names

```sql
-- Check if users have full_name set
SELECT 
  id,
  full_name,
  email
FROM profiles 
WHERE id IN (
  SELECT DISTINCT profile_id FROM vehicles LIMIT 5
);
```

**If `full_name` is NULL:**
- Users need to set their names in the profiles table
- Or you can use `operator_name` as fallback

---

### Step 6: Restart Flutter App

**CRITICAL:** Must do full restart (not hot reload)

```bash
flutter clean
flutter pub get
flutter run
```

---

## 🎯 Expected Result

After recreating the view and restarting Flutter:

### Before:
```
Common Feed:
┌─────────────────────┐
│ Unknown User       │  ❌
│ Unknown Vehicle    │
└─────────────────────┘
```

### After:
```
Common Feed:
┌─────────────────────┐
│ John Doe           │  ✅
│ Honda City         │
└─────────────────────┘
```

---

## 🐛 Troubleshooting

### Issue 1: user_name still NULL after recreating view

**Check profiles table:**
```sql
SELECT id, full_name FROM profiles LIMIT 5;
```

**If full_name is NULL:**
- Users haven't set their names
- Update profiles: `UPDATE profiles SET full_name = 'John Doe' WHERE id = 'user_id';`

---

### Issue 2: View doesn't have user_name column after Step 2

**Check view definition:**
```sql
SELECT pg_get_viewdef('vehicles_public', true);
```

**Look for:** `p.full_name AS user_name`
- If missing → Re-run Step 2
- If present → Check if profiles table exists

---

### Issue 3: Still shows "Unknown User" in Flutter

**Possible causes:**
1. Flutter cache → Run `flutter clean`
2. View not updated → Re-run Step 2
3. Profiles missing names → Run Step 5

---

## 📊 Quick Verification Checklist

- [ ] Step 1: `user_name` column exists in view schema
- [ ] Step 4: SQL query shows `user_name` with values (not NULL)
- [ ] Step 5: Profiles have `full_name` populated
- [ ] Step 6: Flutter app fully restarted (not hot reload)
- [ ] Result: Common Feed shows actual names

If all checked ✅ → **Fixed!**

---

## 📁 Files to Use

1. **`CHECK_VEHICLES_PUBLIC_COLUMNS.sql`** - Check current columns
2. **`RECREATE_VEHICLES_PUBLIC_WITH_USER_NAME.sql`** - Full recreation script
3. **`README_UNKNOWN_USER_FIX.md`** - Flutter restart guide

---

## 💡 Key Points

1. The view MUST have `user_name` column (from `profiles.full_name`)
2. The view MUST join with `profiles` table
3. Flutter MUST be fully restarted (not hot reload)
4. Profiles MUST have `full_name` populated

All 4 must be true for this to work! ✅
