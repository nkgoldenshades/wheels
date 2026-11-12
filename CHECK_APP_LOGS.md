# Check App Debug Logs

## What to Look For

Run your app and check the debug console for these messages:

### 1. Vehicle Loading
```
✅ Loaded X vehicles from Supabase
```
- If you see 0 → RLS blocking or query failing
- If you see 5+ → Vehicles loaded successfully

### 2. Posts Loading
```
✅ Loaded X slots from Supabase (all users)
```
- If you see 0 → RLS blocking or no posts
- If you see 5+ → Posts loaded successfully

### 3. Filtering Debug
```
=== FILTERING DEBUG ===
Current user ID: GbsFkKmcHCQFJ0ceVoBWz2punch1
Total provider slots: X
  - Slot post_1: vehicle=veh_1, userId=..., online=true
📊 Provider posts mapped: X
```

### 4. Error Messages
Look for any errors like:
```
❌ Failed to load from Supabase: ...
⚠️ Failed to load vehicles from Supabase, trying local: ...
```

## Quick Diagnostic Queries

Run these in Supabase SQL Editor:

### Check if RLS is blocking
```sql
-- This simulates what the app sees
SELECT * FROM vehicles 
WHERE is_active = true;
```

If this returns 0 rows but vehicles exist, RLS is blocking.

### Check auth.uid()
```sql
-- Check what user ID Supabase sees
SELECT auth.uid();
```

This should return: `GbsFkKmcHCQFJ0ceVoBWz2punch1`

If it returns NULL, authentication isn't working.

### Test RLS policy
```sql
-- Temporarily disable RLS to test
ALTER TABLE vehicles DISABLE ROW LEVEL SECURITY;

-- Try query again
SELECT * FROM vehicles WHERE is_active = true;

-- Re-enable RLS
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
```

## Common Issues

### Issue 1: RLS Blocking
**Symptom:** Query returns 0 rows with RLS enabled, but returns rows with RLS disabled
**Fix:** Update RLS policy to allow SELECT for all users

### Issue 2: Auth Not Working
**Symptom:** `auth.uid()` returns NULL
**Fix:** Check Firebase authentication is working

### Issue 3: Column Mismatch
**Symptom:** Error about column not existing
**Fix:** Verify `is_active` column exists in vehicles table

### Issue 4: Wrong User ID
**Symptom:** Vehicles exist but for different profile_id
**Fix:** Check if profile_id in vehicles matches current user

## Share These Logs

Please share:
1. The "Loaded X vehicles" message
2. The "Loaded X slots" message  
3. Any error messages
4. Result of `SELECT auth.uid();` in Supabase

This will help me identify the exact issue!
