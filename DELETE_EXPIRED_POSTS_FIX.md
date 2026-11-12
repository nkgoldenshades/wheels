# Allow Deletion of Expired Posts - FIXED ✅

## Problem

Users cannot delete expired posts even after `end_time` has passed because the system waits for `deadline_time` (end_time + 2 hours).

**Example:**
- Post expires: June 12, 8:51 PM
- Deadline time: June 12, 10:51 PM (2 hours later)
- User tries to delete at 9:00 PM → ❌ BLOCKED
- User must wait until 10:51 PM → ✅ ALLOWED

## Solution

Changed logic to allow deletion **immediately after post expires** (end_time passes):

### Old Logic:
```
Post expired → Wait 2 hours for deadline → Then allow deletion
```

### New Logic:
```
Post expired → Auto-cancel all bookings → Allow deletion immediately
```

## Changes Made

### File: `allow_delete_expired_posts.sql`

**Key Changes:**

1. **Check if post expired:**
   ```sql
   IF v_end_time < NOW() THEN
     -- Post expired, auto-cancel bookings
     UPDATE bookings SET status = 'expired'
     -- Allow deletion
   END IF
   ```

2. **Only block deletion if post NOT expired AND has active bookings:**
   ```sql
   IF v_end_time >= NOW() THEN
     -- Post still active, check bookings
     IF has_active_bookings THEN
       RETURN error
     END IF
   END IF
   ```

## Implementation Steps

### Step 1: Run SQL in Supabase
1. Open Supabase SQL Editor
2. Copy entire content from `allow_delete_expired_posts.sql`
3. Click "Run"
4. Verify: "Success. No rows returned"

### Step 2: Test Deletion
1. Find an expired post (end_time < now)
2. Try to delete it
3. Should succeed immediately (no 2-hour wait)

## Behavior After Fix

| Scenario | Old | New |
|----------|-----|-----|
| Post active + no bookings | ✅ Can delete | ✅ Can delete |
| Post active + has bookings | ❌ Cannot delete | ❌ Cannot delete |
| Post expired + has bookings | ❌ Wait 2 hours | ✅ Delete immediately |
| Post expired + no bookings | ✅ Can delete | ✅ Can delete |

## Safety Features Still Active

✅ **Cannot delete active posts with bookings** - Protection remains
✅ **Ownership check** - Only post owner can delete
✅ **Auto-expire bookings** - When post expires, all bookings auto-cancel
✅ **Graceful handling** - All bookings marked as 'expired' before deletion

## Testing Checklist

- [ ] Run SQL migration in Supabase
- [ ] Try to delete an expired post (should succeed immediately)
- [ ] Try to delete an active post with bookings (should be blocked)
- [ ] Verify bookings auto-expire when post expires
- [ ] Check error messages are clear

## Related Files

- `allow_delete_expired_posts.sql` - New migration (run this)
- `PREVENT_DELETE_ACTIVE_BOOKINGS.sql` - Old version (replaced)
- `lib/services/slot_repository.dart` - Dart code (no changes needed)
