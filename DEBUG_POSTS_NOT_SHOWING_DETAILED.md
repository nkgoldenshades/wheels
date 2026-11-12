# Debug: Posts Not Showing - Detailed Analysis

## Current Situation
- ✅ Posts stored in Supabase database
- ❌ Posts not showing in app UI
- Log shows: `📊 Provider posts mapped: 0`

## Root Cause Analysis

### Issue 1: Vehicle Not Online
**Check:** `_vehicleRepository.isOnline(e.vehicle.id)`

**Default Behavior:**
```dart
bool isOnline(String vehicleId) {
  return _onlineStatus.value[vehicleId] ?? true; // Default to online
}
```

**Possible Problem:**
- Vehicle might be explicitly set to offline
- Check vehicle online status in database

**Solution:**
```sql
-- Check vehicle status
SELECT id, registration_number, is_online 
FROM vehicles 
WHERE profile_id = 'your-user-id';

-- Set vehicle online
UPDATE vehicles 
SET is_online = true 
WHERE id = 'your-vehicle-id';
```

### Issue 2: Posts Not Loaded from Supabase
**Check:** `SlotRepository.instance.allSlots.length`

**Possible Problems:**
1. Query filtering by wrong user ID
2. RLS policy blocking SELECT
3. Posts not loaded yet (timing issue)

**Debug Steps:**
1. Check logs for: `✅ Loaded X slots from Supabase (all users)`
2. If 0 slots loaded → RLS or query issue
3. If slots loaded but not showing → filtering issue

### Issue 3: User ID Mismatch
**Check:** `currentUser.id` vs `vehicle.userId` vs `post.profile_id`

**Possible Problems:**
- Firebase UID ≠ Supabase profile ID
- Vehicle has wrong userId
- Post has wrong profile_id

**Debug:**
```dart
debugPrint('Current user ID: ${currentUser.id}');
debugPrint('Vehicle user ID: ${vehicle.userId}');
debugPrint('Post profile ID: ${post.profile_id}');
```

## Debug Logs Added

### Location: `_filteredSlotItems()` in main.dart

```dart
debugPrint('=== FILTERING DEBUG ===');
debugPrint('Current user ID: ${currentUser.id}');
debugPrint('Show user posts: $_showUserPosts');
debugPrint('Total provider slots: ${allProviderSlots.length}');

for (var e in allProviderSlots) {
  debugPrint('  - Slot ${e.slot.id}: vehicle=${e.vehicle.id}, userId=${e.vehicle.userId}, online=${_vehicleRepository.isOnline(e.vehicle.id)}');
}
```

## What to Check in Logs

### 1. User ID
```
Current user ID: GbsFkKmcHCQFJ0ceVoBWz2punch1
```
**Action:** Copy this ID for database queries

### 2. Slots Loaded
```
✅ Loaded 5 slots from Supabase (all users)
Total provider slots: 5
```
**If 0:** RLS or query issue
**If >0:** Continue to next check

### 3. Vehicle Details
```
- Slot post_123: vehicle=veh_456, userId=GbsFkKmcHCQFJ0ceVoBWz2punch1, online=true
```
**Check:**
- Does userId match current user ID?
- Is online = true?

### 4. Final Count
```
📊 Provider posts mapped: 5
```
**If 0:** Vehicle is offline or filtered out

## Database Verification

### Check Posts
```sql
SELECT 
  id, 
  profile_id, 
  vehicle_id, 
  service_type, 
  is_active,
  created_at
FROM posts 
WHERE profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1'
ORDER BY created_at DESC;
```

**Expected:** At least 1 row with `is_active = true`

### Check Profile
```sql
SELECT 
  id, 
  full_name, 
  is_active,
  is_deleted
FROM profiles 
WHERE id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';
```

**Expected:** 
- `is_active = true`
- `is_deleted = false`

### Check Vehicles
```sql
SELECT 
  id, 
  profile_id, 
  registration_number, 
  is_verified,
  created_at
FROM vehicles 
WHERE profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';
```

**Expected:** 
- Vehicle exists
- `profile_id` matches your user ID

### Check Vehicle-Post Link
```sql
SELECT 
  p.id as post_id,
  p.vehicle_id,
  v.id as vehicle_id_check,
  v.profile_id as vehicle_owner,
  p.profile_id as post_owner
FROM posts p
LEFT JOIN vehicles v ON p.vehicle_id = v.id
WHERE p.profile_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';
```

**Expected:** 
- `vehicle_id = vehicle_id_check` (not NULL)
- `vehicle_owner = post_owner`

## Common Issues & Fixes

### Issue: Vehicle is Offline
**Symptom:** Slots loaded but filtered out
**Fix:**
```dart
// In app, go to vehicle list
// Toggle vehicle online status
// OR in database:
UPDATE vehicles SET is_online = true WHERE id = 'vehicle-id';
```

### Issue: RLS Blocking SELECT
**Symptom:** 0 slots loaded from Supabase
**Fix:** Run RLS policy from `supabase_rls_complete.sql`

### Issue: User ID Mismatch
**Symptom:** userId doesn't match currentUser.id
**Fix:**
```sql
-- Update vehicle owner
UPDATE vehicles 
SET profile_id = 'correct-user-id' 
WHERE id = 'vehicle-id';

-- Update post owner
UPDATE posts 
SET profile_id = 'correct-user-id' 
WHERE id = 'post-id';
```

### Issue: Posts Not Active
**Symptom:** Posts exist but `is_active = false`
**Fix:**
```sql
UPDATE posts 
SET is_active = true 
WHERE profile_id = 'your-user-id';
```

### Issue: Profile Not Active
**Symptom:** User profile is inactive
**Fix:**
```sql
UPDATE profiles 
SET is_active = true 
WHERE id = 'your-user-id';
```

## Testing Steps

### 1. Check Logs
Run app and look for:
```
=== FILTERING DEBUG ===
Current user ID: ...
Total provider slots: ...
```

### 2. Verify Database
Run SQL queries above to check data

### 3. Test Vehicle Online
1. Go to vehicle list
2. Check if vehicle shows as online
3. Toggle offline → online
4. Refresh posts feed

### 4. Create New Post
1. Create a fresh post
2. Check logs immediately
3. Should see in feed right away

## Expected Flow

### Correct Flow ✅
1. User creates post → Stored in DB
2. App loads posts → Query returns data
3. RLS allows SELECT → Data retrieved
4. Vehicle is online → Passes filter
5. Post shows in feed → Success!

### Broken Flow ❌
1. User creates post → Stored in DB ✅
2. App loads posts → Query returns data ✅
3. RLS allows SELECT → Data retrieved ✅
4. Vehicle is offline → Filtered out ❌
5. Post NOT in feed → Empty list

## Quick Fix Commands

### Make Everything Visible
```sql
-- Ensure posts are active
UPDATE posts SET is_active = true WHERE profile_id = 'your-user-id';

-- Ensure profile is active
UPDATE profiles SET is_active = true WHERE id = 'your-user-id';

-- Verify
SELECT 
  p.id, 
  p.service_type, 
  p.is_active as post_active,
  v.registration_number,
  prof.is_active as profile_active
FROM posts p
JOIN vehicles v ON p.vehicle_id = v.id
JOIN profiles prof ON p.profile_id = prof.id
WHERE p.profile_id = 'your-user-id';
```

## Next Steps

1. **Run the app** and check debug logs
2. **Copy the output** and share it
3. **Run database queries** to verify data
4. **Compare** user IDs between app and database
5. **Check vehicle online status**

The debug logs will tell us exactly where the filtering is happening!
