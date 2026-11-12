# Vehicle & Post Status Synchronization

## The Problem
Posts can become visible even when their vehicle is inactive, creating inconsistency.

## Two Different Statuses

### 1. `is_active` (Soft Delete)
- **Purpose**: Whether the vehicle/post exists in the system
- **Values**: `true` (active) or `false` (deleted/archived)
- **Usage**: Permanent removal without deleting data
- **Filter**: App queries use `.eq('is_active', true)`

### 2. `is_online` (Availability Toggle)
- **Purpose**: Whether the vehicle is currently available for bookings
- **Values**: `true` (online) or `false` (offline)
- **Usage**: Temporary on/off toggle by user
- **Filter**: App uses `isOnline(vehicleId)` method

## Current Behavior

### Without Sync ❌
1. User creates vehicle → `is_active = true`
2. User creates posts for vehicle → `is_active = true`
3. User deactivates vehicle → vehicle `is_active = false`
4. Posts still have `is_active = true` ❌
5. Posts show in feed but vehicle is gone ❌

### With Sync ✅
1. User creates vehicle → `is_active = true`
2. User creates posts for vehicle → `is_active = true`
3. User deactivates vehicle → vehicle `is_active = false`
4. **Trigger automatically sets** posts `is_active = false` ✅
5. Posts hidden from feed ✅

## Solution: Database Trigger

### What It Does
Automatically syncs post status when vehicle status changes:
- Vehicle activated → All its posts activated
- Vehicle deactivated → All its posts deactivated
- Vehicle deleted → All its posts deactivated

### How It Works
```sql
-- When vehicle.is_active changes
UPDATE posts
SET is_active = NEW.is_active
WHERE vehicle_id = NEW.id;
```

### Installation
Run `vehicle_post_sync_trigger.sql` in Supabase SQL Editor

## Implementation Details

### Trigger 1: Status Sync
**Trigger:** `vehicle_status_sync_trigger`
**Event:** `AFTER UPDATE ON vehicles`
**Condition:** `is_active` changed
**Action:** Update all posts for that vehicle

```sql
CREATE TRIGGER vehicle_status_sync_trigger
  AFTER UPDATE ON vehicles
  FOR EACH ROW
  WHEN (OLD.is_active IS DISTINCT FROM NEW.is_active)
  EXECUTE FUNCTION sync_vehicle_status_to_posts();
```

### Trigger 2: Delete Protection
**Trigger:** `vehicle_delete_deactivate_posts`
**Event:** `BEFORE DELETE ON vehicles`
**Action:** Deactivate all posts (don't delete them)

```sql
CREATE TRIGGER vehicle_delete_deactivate_posts
  BEFORE DELETE ON vehicles
  FOR EACH ROW
  EXECUTE FUNCTION deactivate_posts_on_vehicle_delete();
```

## Testing

### Test Case 1: Deactivate Vehicle
```sql
-- 1. Check current status
SELECT p.id, p.is_active as post_active, v.is_active as vehicle_active
FROM posts p
JOIN vehicles v ON p.vehicle_id = v.id
WHERE v.id = 'test-vehicle-id';

-- 2. Deactivate vehicle
UPDATE vehicles SET is_active = false WHERE id = 'test-vehicle-id';

-- 3. Verify posts were deactivated
SELECT p.id, p.is_active as post_active, v.is_active as vehicle_active
FROM posts p
JOIN vehicles v ON p.vehicle_id = v.id
WHERE v.id = 'test-vehicle-id';

-- Expected: All posts should have is_active = false
```

### Test Case 2: Reactivate Vehicle
```sql
-- 1. Reactivate vehicle
UPDATE vehicles SET is_active = true WHERE id = 'test-vehicle-id';

-- 2. Verify posts were reactivated
SELECT p.id, p.is_active as post_active, v.is_active as vehicle_active
FROM posts p
JOIN vehicles v ON p.vehicle_id = v.id
WHERE v.id = 'test-vehicle-id';

-- Expected: All posts should have is_active = true
```

## Initial Sync

### Fix Existing Data
Run this once to sync all existing posts:
```sql
UPDATE posts p
SET 
  is_active = v.is_active,
  updated_at = NOW()
FROM vehicles v
WHERE p.vehicle_id = v.id
  AND p.is_active != v.is_active;
```

### Verify Sync
```sql
-- Check for mismatches
SELECT 
  p.id as post_id,
  p.is_active as post_active,
  v.id as vehicle_id,
  v.is_active as vehicle_active,
  CASE 
    WHEN p.is_active = v.is_active THEN '✅ Synced'
    ELSE '❌ Mismatch'
  END as status
FROM posts p
JOIN vehicles v ON p.vehicle_id = v.id
ORDER BY status DESC;
```

## App-Side Considerations

### Current Query (Correct)
```dart
// Vehicles query
.from('vehicles')
.select()
.eq('is_active', true)  // ✅ Only active vehicles

// Posts query
.from('posts')
.select()
.eq('is_active', true)  // ✅ Only active posts
```

### No App Changes Needed
The trigger handles everything automatically. The app just needs to:
1. Query with `is_active = true` filter (already doing this)
2. Update vehicle `is_active` when needed
3. Trigger handles the rest

## Benefits

### 1. Data Consistency
- Posts always match their vehicle's status
- No orphaned posts
- No manual sync needed

### 2. Automatic Cleanup
- Deactivate vehicle → Posts hidden automatically
- Delete vehicle → Posts archived automatically
- Reactivate vehicle → Posts visible again

### 3. History Preservation
- Deleted vehicles don't delete posts
- Posts are deactivated, not deleted
- Can reactivate later if needed

## Edge Cases Handled

### Case 1: Vehicle Deleted
- Trigger deactivates posts (doesn't delete)
- Posts preserved for history/analytics
- Can't be reactivated (vehicle gone)

### Case 2: Bulk Updates
- Trigger fires for each vehicle
- All posts updated automatically
- Atomic operation (all or nothing)

### Case 3: Concurrent Updates
- PostgreSQL handles locking
- No race conditions
- Consistent state guaranteed

## Monitoring

### Check Sync Status
```sql
-- Count synced vs mismatched
SELECT 
  CASE 
    WHEN p.is_active = v.is_active THEN 'Synced'
    ELSE 'Mismatch'
  END as sync_status,
  COUNT(*) as count
FROM posts p
JOIN vehicles v ON p.vehicle_id = v.id
GROUP BY sync_status;

-- Expected: All should be 'Synced'
```

### View Trigger Logs
```sql
-- PostgreSQL logs trigger notices
-- Check server logs for:
-- NOTICE: Vehicle xyz is_active changed to false. Updated 3 posts.
```

## Rollback (If Needed)

### Remove Triggers
```sql
DROP TRIGGER IF EXISTS vehicle_status_sync_trigger ON vehicles;
DROP TRIGGER IF EXISTS vehicle_delete_deactivate_posts ON vehicles;
DROP FUNCTION IF EXISTS sync_vehicle_status_to_posts();
DROP FUNCTION IF EXISTS deactivate_posts_on_vehicle_delete();
```

## Summary

**Before:** Manual sync required, posts could be orphaned
**After:** Automatic sync, always consistent

**Setup:** Run one SQL file
**Maintenance:** None - fully automatic
**Impact:** Zero app changes needed

The trigger ensures that posts always reflect their vehicle's status, maintaining data consistency without any app-side logic! 🎉
