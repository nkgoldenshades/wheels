# Debug: Posts Not Showing

## Problem
Posts are stored in the database but not showing in the app.

## Root Causes

### 1. Query Was Filtering by Current User Only ❌
**Before:**
```dart
.eq('profile_id', currentUser.id)  // Only YOUR posts
```

**After:** ✅
```dart
// Removed the profile_id filter - loads ALL posts
```

### 2. RLS Policy Might Be Blocking SELECT
If RLS is too restrictive, it blocks viewing other users' posts.

## Solutions Applied

### Code Fix ✅
Updated `lib/services/slot_repository.dart`:
- Removed `.eq('profile_id', currentUser.id)` filter
- Now loads ALL active posts from ALL users
- This populates the feed with posts from other providers

### RLS Fix (Run in Supabase)
Run this SQL in Supabase Dashboard → SQL Editor:

```sql
-- Allow ALL users to view ALL active posts
DROP POLICY IF EXISTS "Users can view active posts" ON posts;

CREATE POLICY "Users can view active posts" 
ON posts 
FOR SELECT 
USING (
  is_active = true 
  OR auth.uid() = profile_id
);
```

This allows:
- ✅ Everyone can view active posts (is_active = true)
- ✅ Users can view their own inactive posts

## Verification Steps

### 1. Check Database
Go to Supabase → Table Editor → posts table:
- Verify posts exist
- Check `is_active = true`
- Check `profile_id` matches user IDs

### 2. Check RLS Policies
Go to Supabase → Authentication → Policies → posts table:
- Verify "Users can view active posts" policy exists
- Check the USING clause allows `is_active = true`

### 3. Test Query Manually
In Supabase SQL Editor:
```sql
-- Test if you can see posts
SELECT id, profile_id, service_type, is_active, created_at 
FROM posts 
WHERE is_active = true
ORDER BY created_at DESC;
```

### 4. Check App Logs
Look for these debug messages:
```
✅ Loaded X slots from Supabase (all users)
📊 Provider posts: X
```

## Common Issues

### Issue 1: RLS Blocking SELECT
**Symptom:** Query returns 0 rows even though posts exist
**Solution:** Run the RLS SQL above

### Issue 2: No Posts in Database
**Symptom:** Database table is empty
**Solution:** Create a post through the app

### Issue 3: Posts Are Inactive
**Symptom:** Posts exist but `is_active = false`
**Solution:** Update posts:
```sql
UPDATE posts SET is_active = true WHERE id = 'your-post-id';
```

### Issue 4: Vehicle Not Online
**Symptom:** Posts exist but vehicle is offline
**Solution:** The feed filters by online vehicles. Check:
```dart
_vehicleRepository.isOnline(e.vehicle.id)
```

### Issue 5: Wrong Repository
**Symptom:** Looking at wrong tab
**Solution:** 
- "Provider Posts" tab = SlotRepository (all users' posts)
- "User Posts" tab = CustomerSlotRepository (user requests)

## Quick Test

### Create Test Post
1. Add a vehicle
2. Create a post with that vehicle
3. Check Supabase → posts table
4. Verify `is_active = true`
5. Restart app
6. Check "Provider Posts" tab

### Check Logs
Add this to your app:
```dart
debugPrint('=== POSTS DEBUG ===');
debugPrint('Total posts loaded: ${SlotRepository.instance.allSlots.length}');
debugPrint('Online vehicles: ${VehicleRepository.instance.allVehicles.where((v) => VehicleRepository.instance.isOnline(v.id)).length}');
```

## Expected Behavior

### After Fix
1. App loads ALL active posts from database
2. Feed shows posts from ALL users (not just you)
3. Posts are filtered by:
   - `is_active = true`
   - Vehicle is online
   - Service type matches filters

### Feed Logic
- **Provider Posts Tab**: Shows posts from ALL providers (SlotRepository)
- **User Posts Tab**: Shows requests from other users (CustomerSlotRepository)

## Still Not Working?

### Check These
1. ✅ RLS policy applied in Supabase
2. ✅ Posts exist with `is_active = true`
3. ✅ Vehicles are marked as online
4. ✅ App restarted after code changes
5. ✅ User is logged in (auth.uid() exists)

### Get More Info
Add debug logging:
```dart
final response = await supabase
    .from('posts')
    .select()
    .eq('is_active', true);
    
debugPrint('Raw response: $response');
debugPrint('Response length: ${(response as List).length}');
```

### Test RLS Directly
In Supabase SQL Editor, run as authenticated user:
```sql
-- This simulates what the app sees
SELECT * FROM posts WHERE is_active = true;
```

If this returns 0 rows but posts exist, RLS is blocking it.
