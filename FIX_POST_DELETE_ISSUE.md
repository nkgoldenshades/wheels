# Fix Post Deletion Not Reflecting in Supabase

## Problem
When you delete posts in the app, they disappear locally but don't get deleted from Supabase database.

## Root Causes Found

### 1. ❌ Silent Error Swallowing
The delete methods were catching errors but not re-throwing them:
```dart
// OLD CODE (BAD)
try {
  await supabase.from('posts').delete().eq('id', slotId);
} catch (e) {
  debugPrint('Failed to delete');
  // Error swallowed - no rethrow!
}
```

### 2. ❌ Missing User Ownership Check
Deletes weren't verifying the user owns the post:
```dart
// OLD CODE (BAD)
await supabase.from('posts').delete().eq('id', slotId);
// Anyone could delete any post!
```

### 3. ❌ Possible RLS Policy Issues
Supabase Row Level Security might not allow deletes.

## What I Fixed

### ✅ 1. Enhanced Delete Methods
**Files Modified:**
- `lib/services/slot_repository.dart`
- `lib/services/customer_slot_repository.dart`
- `lib/services/user_post_repository.dart`

**Changes:**
```dart
// NEW CODE (GOOD)
Future<void> _deleteSlotFromSupabase(String slotId) async {
  try {
    // Check authentication
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not authenticated - cannot delete post');
    }
    
    debugPrint('🗑️ Deleting slot from Supabase: $slotId');
    debugPrint('🔑 User ID: ${user.uid}');
    
    // Delete with ownership check
    final response = await supabase
        .from('posts')
        .delete()
        .eq('id', slotId)
        .eq('provider_id', user.uid); // Ensure user owns the post

    debugPrint('✅ Slot deleted from Supabase: $slotId');
    debugPrint('📊 Delete response: $response');
  } catch (e) {
    debugPrint('❌ Failed to delete slot from Supabase: $e');
    rethrow; // Now errors are visible!
  }
}
```

### ✅ 2. Added Detailed Logging
Now you'll see in the console:
- 🗑️ When delete starts
- 🔑 Which user is deleting
- ✅ When delete succeeds
- ❌ When delete fails (with error details)

### ✅ 3. Created RLS Policy Fix Script
**File:** `FIX_DELETE_RLS_POLICIES.sql`

## How to Fix

### Step 1: Update Your App Code
The code is already fixed! Just hot restart:
```bash
# Press R (capital R) in terminal
# Or stop and restart:
flutter run -d chrome --web-renderer html
```

### Step 2: Fix Supabase RLS Policies
1. Open **Supabase Dashboard**
2. Go to **SQL Editor**
3. Copy and paste `FIX_DELETE_RLS_POLICIES.sql`
4. Click **Run**

This will:
- ✅ Create proper DELETE policies
- ✅ Ensure users can only delete their own posts
- ✅ Show you current policy status

### Step 3: Test Delete
1. Try deleting a post in your app
2. Check the **browser console** (F12)
3. Look for these messages:
   ```
   🗑️ Deleting slot from Supabase: abc123
   🔑 User ID: xyz789
   ✅ Slot deleted from Supabase: abc123
   ```

### Step 4: Verify in Supabase
1. Go to **Supabase Dashboard**
2. Click **Table Editor**
3. Open `posts` or `user_posts` table
4. Verify the post is gone

## Troubleshooting

### Issue 1: "Not authenticated" Error
**Symptom:** Console shows "Not authenticated - cannot delete post"
**Cause:** User not logged in
**Fix:**
1. Make sure you're logged in
2. Check Firebase Auth status
3. Try logging out and back in

### Issue 2: Delete Fails Silently
**Symptom:** No error, but post still in Supabase
**Cause:** RLS policy blocking delete
**Fix:**
1. Run `FIX_DELETE_RLS_POLICIES.sql` in Supabase
2. Check Supabase logs (Dashboard → Logs)
3. Look for "permission denied" errors

### Issue 3: "Foreign key constraint" Error
**Symptom:** Error mentions "violates foreign key constraint"
**Cause:** Post has active bookings or related records
**Fix:**
- The app already checks for active bookings
- If you see this error, there might be orphaned records
- Check Supabase for related records:
  ```sql
  SELECT * FROM bookings WHERE slot_id = 'YOUR_POST_ID';
  ```

### Issue 4: Post Deleted Locally But Not in Supabase
**Symptom:** Post disappears from app but reappears after refresh
**Cause:** Supabase delete failed but error was swallowed (old code)
**Fix:**
- ✅ Already fixed with new code
- Hot restart the app
- Try deleting again
- Check console for error details

## Verify the Fix

### Test Checklist
- [ ] Hot restart the app
- [ ] Run `FIX_DELETE_RLS_POLICIES.sql` in Supabase
- [ ] Try deleting a post
- [ ] Check browser console for logs
- [ ] Verify post is gone from Supabase Table Editor
- [ ] Refresh app - post should stay deleted

### Expected Console Output
```
🗑️ Deleting slot from Supabase: abc-123-def
🔑 User ID: firebase-uid-xyz
✅ Slot deleted from Supabase: abc-123-def
📊 Delete response: null
```

### If You See Errors
```
❌ Failed to delete slot from Supabase: [Error details here]
```
Share the error details so I can help further!

## Common Error Messages

### "permission denied for table posts"
**Cause:** RLS policy not allowing delete
**Fix:** Run `FIX_DELETE_RLS_POLICIES.sql`

### "JWT expired"
**Cause:** Firebase token expired
**Fix:** Log out and log back in

### "violates foreign key constraint"
**Cause:** Post has dependent records
**Fix:** Delete or update dependent records first

### "No rows deleted"
**Cause:** Post doesn't exist or doesn't belong to user
**Fix:** Verify post ID and ownership

## Additional Debugging

### Check RLS Policies
In Supabase SQL Editor:
```sql
SELECT * FROM pg_policies WHERE tablename = 'posts';
```

### Check User Ownership
```sql
SELECT id, provider_id, (auth.jwt() ->> 'sub') as current_user
FROM posts
WHERE id = 'YOUR_POST_ID';
```

### Check Active Bookings
```sql
SELECT * FROM bookings 
WHERE slot_id = 'YOUR_POST_ID' 
AND status IN ('pending', 'confirmed');
```

## Summary

### What Was Wrong
1. ❌ Errors were silently swallowed
2. ❌ No user ownership verification
3. ❌ Possibly missing RLS policies

### What's Fixed
1. ✅ Errors now throw and show in console
2. ✅ User ownership checked before delete
3. ✅ Detailed logging added
4. ✅ SQL script to fix RLS policies

### Next Steps
1. **Hot restart** your app
2. **Run** `FIX_DELETE_RLS_POLICIES.sql` in Supabase
3. **Test** deleting a post
4. **Check** console and Supabase to verify

The delete should now work properly and reflect in Supabase! 🎉
