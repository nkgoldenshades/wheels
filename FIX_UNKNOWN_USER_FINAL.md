# Fix "Unknown User" Issue - Final Solution

## Current Status

✅ **Code is correct** - Both `vehicle_repository.dart` and `customer_vehicle_repository.dart` use:
```dart
profiles!vehicles_new_profile_id_fkey (
  full_name,
  profile_photo_url
)
```

❌ **Error shows old FK name** - The error message shows:
```
Searched for a foreign key relationship... using the hint 'vehicles_profile_id_fkey'
```

This means the app is running **cached/old code**.

---

## Solution: Rebuild the Flutter App

The Dart code has the correct FK name, but the running app has old code cached.

### Step 1: Stop the App Completely
```bash
# Stop all Flutter processes
flutter clean
```

### Step 2: Rebuild and Run
```bash
# Get dependencies
flutter pub get

# Run the app (this will do a full rebuild)
flutter run
```

### Step 3: If Still Not Working - Hot Restart
If you're already running the app:
1. Press `R` (capital R) in the terminal to **Hot Restart**
2. Or press the "Hot Restart" button in your IDE

**Note:** Hot Reload (lowercase `r`) is NOT enough - you need Hot Restart (capital `R`)

---

## Verify the Fix

After rebuilding, check the Flutter console logs:

### ✅ Success Looks Like:
```
🔍 VehicleRepository: Query completed, processing 2 vehicles
✅ Loaded 2 vehicles from Supabase
🔍 First vehicle: id=xxx, userName=John Doe, name=Toyota Camry
```

### ❌ Still Broken Looks Like:
```
❌ Failed to load from Supabase: PostgrestException... vehicles_profile_id_fkey
```

---

## If Rebuild Doesn't Fix It

If you still see the error after a full rebuild, then the issue is in the database:

### Run This SQL to Verify FK Name:
```sql
-- Check the actual FK constraint name
SELECT constraint_name
FROM information_schema.table_constraints
WHERE table_name = 'vehicles'
  AND constraint_type = 'FOREIGN KEY';
```

**Expected Result:** `vehicles_new_profile_id_fkey`

### If FK Name is Wrong in Database:

Run this SQL to fix it:

```sql
-- Drop old FK if it exists
ALTER TABLE vehicles 
DROP CONSTRAINT IF EXISTS vehicles_profile_id_fkey;

-- Add correct FK
ALTER TABLE vehicles
ADD CONSTRAINT vehicles_new_profile_id_fkey
FOREIGN KEY (profile_id)
REFERENCES profiles(id)
ON DELETE CASCADE;
```

---

## Alternative: Simplify the Query (No FK Hint)

If the FK name keeps causing issues, you can remove the FK hint and let PostgREST auto-detect:

### Update `vehicle_repository.dart`:
```dart
final response = await _supabase
    .from('vehicles')
    .select('''
      *,
      profiles (
        full_name,
        profile_photo_url
      )
    ''')  // ✅ No FK hint - PostgREST will auto-detect
    .order('created_at', ascending: false);
```

This works because:
- PostgREST automatically finds the FK relationship
- `vehicles.profile_id` → `profiles.id` is the only FK between these tables
- No need to specify the constraint name

---

## Summary

1. **Most Likely:** App is using cached code → **Run `flutter clean` then `flutter run`**
2. **If that fails:** FK name is wrong in database → **Run the SQL fix above**
3. **If still fails:** Remove FK hint from query → **Use `profiles (...)` instead of `profiles!vehicles_new_profile_id_fkey (...)`**

---

## Next Steps

After fixing, you should see:
- ✅ Vehicles load successfully (count > 0)
- ✅ "Unknown User" replaced with actual user names
- ✅ Vehicle names show correctly

If you still see "Unknown User" after vehicles load successfully, then the issue is:
- Profiles table doesn't have `full_name` populated
- Or the join is not working (check SQL diagnostic)
