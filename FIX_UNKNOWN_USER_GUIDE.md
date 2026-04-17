# Fix "Unknown User" Issue - Complete Guide

## ✅ What We Fixed

### 1. Created `vehicles_public` View with User Information
- View joins `vehicles` table with `profiles` table
- Exposes `user_name` column (from `profiles.full_name`)
- Protects sensitive data (RC, insurance, national ID)

### 2. Updated Flutter to Use `vehicles_public` View
- ✅ `lib/services/vehicle_repository.dart` - Uses `vehicles_public` for loading
- ✅ `lib/services/customer_vehicle_repository.dart` - Uses `vehicles_public` for loading
- ✅ `lib/models/vehicle.dart` - Reads `user_name` from JSON

### 3. Added Debug Logging
- Vehicle loading now logs raw Supabase response
- `Vehicle.fromJson()` logs all user name fields it receives
- Helps diagnose if view is returning correct data

---

## 🔧 How to Test

### Step 1: Verify View in Supabase
Run this query in Supabase SQL Editor:

```sql
SELECT 
  id,
  vehicle_name,
  user_name,  -- Should show actual names, not NULL
  profile_id
FROM vehicles_public 
LIMIT 5;
```

**Expected Result:**
- `user_name` column should show actual user names (e.g., "John Doe")
- If `user_name` is NULL, the view is not working correctly

### Step 2: Full Restart Flutter App
**CRITICAL:** Hot reload will NOT work! You must do a full restart:

1. **Stop the app completely** (not just hot reload)
2. **Close the app** on your device/emulator
3. **Run again:** `flutter run`

### Step 3: Check Debug Logs
Look for these logs in your Flutter console:

```
🔍 Raw Supabase response (first vehicle): {id: xxx, vehicle_name: xxx, user_name: John Doe, ...}
🔍 Vehicle.fromJson: id=xxx, user_name=John Doe, userName=null, full_name=null, operator_name=null → final=John Doe
✅ Loaded 5 vehicles from Supabase
🔍 First vehicle: id=xxx, userName=John Doe, name=My Car
```

**What to look for:**
- ✅ `user_name` should have a value in raw response
- ✅ `Vehicle.fromJson` should show `user_name=John Doe` (not null)
- ✅ Final userName should be the actual name (not "Unknown User")

---

## 🐛 Troubleshooting

### Issue 1: View Returns NULL for `user_name`

**Cause:** View is not joining with profiles table correctly

**Fix:** Re-run the view creation script:

```sql
-- Drop and recreate view
DROP VIEW IF EXISTS vehicles_public;

CREATE OR REPLACE VIEW vehicles_public AS
SELECT 
  v.id,
  v.profile_id,
  v.vehicle_type,
  v.vehicle_name,
  v.seating_capacity,
  v.vehicle_photo_url,
  v.gallery_images,
  v.video_url,
  v.created_at,
  v.updated_at,
  v.is_online,
  v.vehicle_owner,
  v.total_trips,
  v.total_reviews,
  v.active_posts_count,
  v.is_verified,
  v.verified_at,
  v.operator_name,
  v.operator_phone,
  v.operator_profile_photo_url,
  v.registration_number,
  v.is_active,
  
  -- ✅ JOIN WITH PROFILES
  p.full_name as user_name,
  p.profile_photo_url as user_avatar,
  
  CASE 
    WHEN v.profile_id = (auth.jwt() ->> 'sub'::text) THEN true
    ELSE false
  END AS is_owner
  
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id

WHERE 
  v.is_active = true OR v.profile_id = (auth.jwt() ->> 'sub'::text);
```

### Issue 2: Still Shows "Unknown User" After Restart

**Possible Causes:**

1. **View not returning data**
   - Check: Run SQL query in Step 1 above
   - Fix: Recreate view

2. **Profiles table missing `full_name`**
   - Check: `SELECT id, full_name FROM profiles LIMIT 5;`
   - Fix: Ensure users have `full_name` populated

3. **Flutter still using old code**
   - Check: Look for debug logs in console
   - Fix: Do a clean rebuild: `flutter clean && flutter pub get && flutter run`

4. **RLS blocking view access**
   - Check: Run query as authenticated user in Supabase
   - Fix: Views inherit RLS from underlying tables (should work automatically)

### Issue 3: Debug Logs Not Showing

**Cause:** App not restarted properly

**Fix:**
1. Stop app completely
2. Run: `flutter clean`
3. Run: `flutter pub get`
4. Run: `flutter run`

---

## 📊 Expected Behavior After Fix

### Before Fix:
```
Common Feed:
┌─────────────────────┐
│ Unknown User        │  ❌ Wrong
│ Unknown Vehicle     │
│ ₹500/day           │
└─────────────────────┘
```

### After Fix:
```
Common Feed:
┌─────────────────────┐
│ John Doe           │  ✅ Correct
│ Honda City         │
│ ₹500/day           │
└─────────────────────┘
```

---

## 🔍 Debug Commands

### Check if view exists:
```sql
SELECT * FROM information_schema.views 
WHERE table_name = 'vehicles_public';
```

### Check view definition:
```sql
SELECT pg_get_viewdef('vehicles_public', true);
```

### Test view with sample data:
```sql
SELECT 
  v.id,
  v.vehicle_name,
  v.profile_id,
  p.full_name,
  (SELECT user_name FROM vehicles_public WHERE id = v.id) as view_user_name
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
LIMIT 3;
```

This will show:
- What's in `vehicles` table
- What's in `profiles` table
- What the view returns

---

## 📝 Summary

**What Changed:**
1. ✅ Created `vehicles_public` view with `user_name` column
2. ✅ Updated Flutter to read from `vehicles_public` view
3. ✅ Added debug logging to diagnose issues
4. ✅ `Vehicle.fromJson()` tries multiple sources for user name

**Next Steps:**
1. ✅ Verify view returns data (SQL query)
2. ✅ Full restart Flutter app (not hot reload)
3. ✅ Check debug logs in console
4. ✅ Should see actual user names instead of "Unknown User"

**If Still Not Working:**
- Share the debug logs from Flutter console
- Share the SQL query result from Step 1
- We'll diagnose from there
