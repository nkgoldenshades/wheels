# Actual Fix: Vehicles Not Loading

## Root Cause Confirmed

Based on your database check:
- ✅ 5 vehicles exist with `is_active = true`
- ✅ 5 posts exist with `is_active = true`
- ❌ 0 vehicles loaded in app
- ❌ 0 SlotEntry objects created (need vehicle + post)

## Why Vehicles Aren't Loading

### Possible Causes:

1. **RLS Policy Blocking SELECT**
   - Current policy might require `profile_id = auth.uid()`
   - But feed needs ALL vehicles, not just current user's

2. **Query Error (Silent Failure)**
   - Query might be failing but falling back to local storage
   - Local storage is empty

3. **Vehicle Table Column Mismatch**
   - App expects certain columns that don't exist
   - `fromJson()` fails silently

## The Fix

### Step 1: Check RLS Policy for Vehicles

Run this in Supabase:
```sql
-- Check current policy
SELECT * FROM pg_policies WHERE tablename = 'vehicles';

-- Drop restrictive policy
DROP POLICY IF EXISTS "Users can view their own vehicles" ON vehicles;
DROP POLICY IF EXISTS "Users can view own vehicles" ON vehicles;

-- Create permissive policy (allow viewing ALL vehicles)
CREATE POLICY "Users can view all vehicles" 
ON vehicles 
FOR SELECT 
USING (true);  -- Allow everyone to view all vehicles
```

### Step 2: Verify Vehicles Load

Add debug logging to see what's happening:

In `lib/services/vehicle_repository.dart`, update `_loadVehicles()`:

```dart
Future<void> _loadVehicles() async {
  try {
    debugPrint('🔍 Loading vehicles from Supabase...');
    
    final response = await _supabase
        .from('vehicles')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);

    debugPrint('📦 Raw response: ${response.length} vehicles');
    
    _vehicles.value = (response as List)
        .map((json) {
          debugPrint('  - Vehicle: ${json['id']}, profile: ${json['profile_id']}');
          return Vehicle.fromJson(json as Map<String, dynamic>);
        })
        .toList();

    debugPrint('✅ Loaded ${_vehicles.value.length} vehicles from Supabase');
  } catch (e) {
    debugPrint('❌ Failed to load from Supabase: $e');
    debugPrint('Stack trace: ${StackTrace.current}');
    // Fallback to local storage
    await _loadVehiclesLocal();
  }
}
```

### Step 3: Check Vehicle Model Mapping

The issue might be in `Vehicle.fromJson()`. Check if all required fields exist:

```sql
-- Check what columns exist in vehicles table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'vehicles' 
  AND table_schema = 'public'
ORDER BY ordinal_position;
```

Compare with what `Vehicle.fromJson()` expects.

### Step 4: Test Query Directly

Run this in Supabase SQL Editor:
```sql
-- Test the exact query the app uses
SELECT * 
FROM vehicles 
WHERE is_active = true 
ORDER BY created_at DESC;
```

Expected: Should return 5 vehicles

If it returns 0, the issue is:
- RLS policy blocking
- `is_active` is actually false (check again)

If it returns 5, the issue is:
- App not receiving data
- `fromJson()` failing
- RLS policy blocking app's auth token

## Quick Test

### Option 1: Temporarily Disable RLS
```sql
ALTER TABLE vehicles DISABLE ROW LEVEL SECURITY;
```

Restart app and check if vehicles load.

If they do → RLS policy is the issue
If they don't → Query or mapping issue

### Option 2: Check Auth Token
The app might not be sending the correct auth token.

In `lib/services/vehicle_repository.dart`:
```dart
Future<void> _loadVehicles() async {
  try {
    // Check if user is authenticated
    final session = _supabase.auth.currentSession;
    debugPrint('🔐 Auth session: ${session != null ? "Active" : "None"}');
    debugPrint('🔐 User ID: ${session?.user.id}');
    
    final response = await _supabase
        .from('vehicles')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);
    
    // ... rest of code
  }
}
```

## Expected Logs After Fix

```
🔍 Loading vehicles from Supabase...
🔐 Auth session: Active
🔐 User ID: GbsFkKmcHCQFJ0ceVoBWz2punch1
📦 Raw response: 5 vehicles
  - Vehicle: veh_1, profile: GbsFkKmcHCQFJ0ceVoBWz2punch1
  - Vehicle: veh_2, profile: GbsFkKmcHCQFJ0ceVoBWz2punch1
  ...
✅ Loaded 5 vehicles from Supabase
✅ Loaded 5 slots from Supabase (all users)
Total provider slots: 5
📊 Provider posts mapped: 5
```

## Summary

The issue is NOT verification filtering in the UI.
The issue is vehicles aren't loading at all.

Most likely cause: **RLS policy blocking SELECT on vehicles table**

Fix: Update RLS policy to allow viewing all vehicles (not just own vehicles)
