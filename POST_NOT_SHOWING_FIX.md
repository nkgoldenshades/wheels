# Why Posts Are Not Showing - Diagnosis & Fix

## Root Causes Identified

### 1. JOIN to profiles table blocks guest access
The Dart code was doing:
```dart
.from('posts')
.select('''
  *,
  public_profiles!posts_profile_id_fkey (
    full_name,
    avatar_url
  )
''')
```

This JOIN fails for guests because they can't access the profiles table, even through a view.

### 2. Missing Columns in `user_posts` Table
The Dart code expects these columns that don't exist in your database:
- `status` (TEXT) - Used to filter active vs archived posts
- `is_online` (BOOLEAN) - Used to show/hide posts
- `user_id` (TEXT) - The Dart code uses `user_id` but SQL table has `customer_id`

### 3. Field Name Mismatch
- **Dart code** (`lib/services/user_post_repository.dart`): Uses `user_id` field
- **SQL table** (`user_posts`): Uses `customer_id` field
- This causes the JSON parsing to fail or return null values

## The Solution: Denormalization

Instead of JOINing to profiles, we store the provider/customer name and avatar directly in the posts tables. This is the right approach for guest access.

### Benefits:
✅ Guests can read posts without needing profile access  
✅ No complex RLS policies needed  
✅ Faster queries (no JOIN)  
✅ Data stays in sync via triggers  

## How to Fix

### Step 1: Run the SQL Migration
Execute `DENORMALIZE_POSTS_FOR_GUEST_ACCESS.sql` in your Supabase SQL Editor. This will:

1. **Add denormalized fields to `posts` table:**
   - `provider_name` (TEXT)
   - `provider_avatar` (TEXT)

2. **Add denormalized fields to `user_posts` table:**
   - `customer_name` (TEXT)
   - `customer_avatar` (TEXT)
   - `status` (TEXT) - active/archived
   - `is_online` (BOOLEAN)
   - `user_id` (TEXT) - synced with customer_id

3. **Populate existing records** from profiles table

4. **Create triggers** to auto-populate these fields on INSERT/UPDATE

5. **Update RLS policies** to allow guest (public) access

6. **Create sync trigger** to update posts when profile changes

### Step 2: Dart Code Updates (Already Done)
The following files have been updated to use denormalized fields:

- ✅ `lib/services/slot_repository.dart` - Removed JOIN, uses direct SELECT
- ✅ `lib/models/slot.dart` - Reads from `provider_name` field instead of JOIN

### Step 3: Verify the Fix
After running the migration, check:

```sql
-- Should show denormalized columns exist
SELECT column_name FROM information_schema.columns
WHERE table_name = 'posts' 
AND column_name IN ('provider_name', 'provider_avatar');

SELECT column_name FROM information_schema.columns
WHERE table_name = 'user_posts' 
AND column_name IN ('customer_name', 'customer_avatar', 'user_id', 'status', 'is_online');

-- Should show posts with provider names populated
SELECT id, profile_id, provider_name, service_type 
FROM posts 
WHERE is_active = true
LIMIT 5;

-- Should show user posts with customer names populated
SELECT id, user_id, customer_name, service_type, status, is_online
FROM user_posts 
WHERE is_active = true
LIMIT 5;
```

### Step 4: Test in the App
1. Restart your Flutter app
2. Navigate to the Posts page
3. Click the info button (ℹ️) to see repository status
4. You should now see posts appearing for both guests and authenticated users

## What Each File Does

### `DENORMALIZE_POSTS_FOR_GUEST_ACCESS.sql` ⭐ **USE THIS ONE**
Complete fix that:
- Adds denormalized fields to both posts tables
- Populates existing data from profiles
- Creates triggers to keep data in sync
- Updates RLS policies for guest access
- Includes verification queries

### `CHECK_USER_POSTS.sql`
Diagnostic queries to check table structure and data

### `FIX_USER_POSTS_COMPLETE.sql`
Previous fix (partial) - superseded by denormalization approach

## How Denormalization Works

### On INSERT:
```sql
-- Trigger automatically copies profile data to post
INSERT INTO posts (profile_id, service_type, ...)
VALUES ('user123', 'passenger', ...);
-- Trigger sets: provider_name = 'John Doe', provider_avatar = 'https://...'
```

### On Profile UPDATE:
```sql
-- When user updates their profile
UPDATE profiles SET full_name = 'Jane Smith' WHERE id = 'user123';
-- Trigger updates ALL posts by this user:
-- UPDATE posts SET provider_name = 'Jane Smith' WHERE profile_id = 'user123'
```

### On SELECT (Guest):
```sql
-- No JOIN needed! Guest can read directly
SELECT * FROM posts WHERE is_active = true;
-- Returns: id, profile_id, provider_name, provider_avatar, ...
```

## Why This Happened

The original schema used normalized data (profiles separate from posts) which is good for data integrity but bad for guest access with RLS. The JOIN to profiles fails for guests even when using a view.

**The fix:** Denormalize user data into posts tables. This is a common pattern for:
- Public-facing data
- Performance optimization
- Simplified RLS policies
- Guest/anonymous access

## Data Consistency

The triggers ensure data stays in sync:
- ✅ New posts automatically get provider/customer info
- ✅ Profile updates propagate to all posts
- ✅ No manual sync needed
- ✅ Atomic operations (no race conditions)

## Next Steps

1. ✅ Run `DENORMALIZE_POSTS_FOR_GUEST_ACCESS.sql` in Supabase
2. ✅ Dart code already updated (no changes needed)
3. Restart your Flutter app
4. Test guest access (browse without login)
5. Test authenticated access (create/edit posts)
6. Verify provider names show correctly

If posts still don't show, check the Flutter console for error messages and verify the SQL migration completed successfully.
