# 📦 Migrate User Posts to Supabase

## Current Status

**Before:** User posts stored in memory only (lost on app restart)
**After:** User posts stored in Supabase database (persistent)

## What's Ready

✅ `user_posts` table exists in Supabase (from `FRESH_PROJECT_SCHEMA.sql`)
✅ `lib/services/user_post_repository.dart` created with Supabase integration
✅ RLS policies configured (users can only modify their own posts)

## Migration Steps

### Step 1: Add Import to main.dart

Add this line to the imports section (around line 40):

```dart
import 'services/user_post_repository.dart';
```

### Step 2: Initialize Repository in main.dart

Find this section (around line 88-95):

```dart
await AuthRepository.instance.init();
await AppPreferences.instance.init();
await ProfileRepository.instance.init();
await VehicleRepository.instance.init();
await SlotRepository.instance.init();
await SeatLayoutRepository.instance.init();
await BookingRepository.instance.init();
await PassengerRepository.instance.init();
```

Add this line at the end:

```dart
await UserPostRepository.instance.init();
```

### Step 3: Remove Old UserPost Classes from main.dart

Find and DELETE these classes from main.dart (they're now in the new repository file):

1. `enum UserPostStatus` (around line 820)
2. `class UserPost` (around line 822)
3. `class UserPostRepository` (around line 831)

Keep these classes (they use the repository):
- `CreateUserPostPage`
- `EditUserPostPage`

### Step 4: Update Imports in Files Using UserPost

Any file that uses `UserPost` or `UserPostRepository` needs to import the new file:

```dart
import 'package:your_app/services/user_post_repository.dart';
```

## What Changes for Users

### Before Migration
- Create post → Stored in memory
- Close app → Posts lost
- Reopen app → No posts

### After Migration
- Create post → Stored in Supabase ✅
- Close app → Posts persist ✅
- Reopen app → Posts load from database ✅

## Testing After Migration

### Test 1: Create Post
1. Run app
2. Create a new user post
3. Check console for: `✅ User post created in Supabase: [id]`
4. Check Supabase Table Editor → `user_posts` table
5. Verify row appears

### Test 2: Persistence
1. Create a post
2. Close app completely
3. Reopen app
4. Check console for: `✅ Loaded X user posts from Supabase`
5. Verify post still appears

### Test 3: Update Post
1. Edit an existing post
2. Check console for: `✅ User post updated in Supabase: [id]`
3. Verify changes in Supabase Table Editor

### Test 4: Archive Post
1. Archive a post
2. Check console for: `✅ User post archived in Supabase: [id]`
3. Verify `status` = `archived` in database

### Test 5: RLS Security
In Supabase SQL Editor:

```sql
-- Should only see your own posts
SELECT * FROM user_posts WHERE user_id = auth.uid()::text;

-- Should fail (can't insert for another user)
INSERT INTO user_posts (user_id, service_type, slot_type, start_time, end_time, budget, persons)
VALUES ('fake_user_id', 'passenger', 'from_to', NOW(), NOW(), 100, 1);
```

## New Repository Methods

### Load Posts
```dart
await UserPostRepository.instance.loadPosts();
```

### Create Post
```dart
final post = UserPost(
  id: uuid.v4(),
  userId: currentUser.id,
  serviceType: ServiceType.passenger,
  slotType: SlotType.fromTo,
  startTime: DateTime.now(),
  endTime: DateTime.now().add(Duration(hours: 2)),
  budget: 100.0,
  persons: 1,
  createdAt: DateTime.now(),
  status: UserPostStatus.active,
);

await UserPostRepository.instance.add(post);
```

### Update Post
```dart
final updated = post.copyWith(budget: 150.0);
await UserPostRepository.instance.update(updated);
```

### Archive Post
```dart
await UserPostRepository.instance.archive(postId);
```

### Restore Post
```dart
await UserPostRepository.instance.restore(postId);
```

### Toggle Online Status
```dart
await UserPostRepository.instance.toggleOnline(postId);
```

### Delete Post
```dart
await UserPostRepository.instance.delete(postId);
```

## Database Schema

The `user_posts` table in Supabase:

```sql
CREATE TABLE user_posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  service_type TEXT NOT NULL,
  slot_type TEXT CHECK (slot_type IN ('from_to', 'base_radius')),
  from_location TEXT,
  to_location TEXT,
  base_location TEXT,
  radius NUMERIC,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  budget NUMERIC NOT NULL,
  persons INTEGER NOT NULL,
  notes TEXT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'archived')),
  is_online BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## RLS Policies

```sql
-- Everyone can view active posts (marketplace)
CREATE POLICY "posts_select_active" ON user_posts 
  FOR SELECT USING (status = 'active');

-- Users can view their own posts (any status)
CREATE POLICY "posts_select_own" ON user_posts 
  FOR SELECT USING (auth.uid()::text = user_id);

-- Users can only insert their own posts
CREATE POLICY "posts_insert_self" ON user_posts 
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

-- Users can only update their own posts
CREATE POLICY "posts_update_self" ON user_posts 
  FOR UPDATE USING (auth.uid()::text = user_id);

-- Users can only delete their own posts
CREATE POLICY "posts_delete_self" ON user_posts 
  FOR DELETE USING (auth.uid()::text = user_id);
```

## Benefits

✅ **Persistence** - Posts survive app restarts
✅ **Security** - RLS ensures users can only modify their own posts
✅ **Sync** - Posts accessible from multiple devices
✅ **Backup** - Data stored in cloud database
✅ **Scalability** - Can handle thousands of posts
✅ **Real-time** - Can add Supabase subscriptions later

## Troubleshooting

### Issue: "Failed to create user post"
**Cause:** RLS policy blocking insert
**Fix:** Verify `auth.uid()` matches `user_id` in insert

### Issue: "Failed to load user posts"
**Cause:** User not logged in or token not passed
**Fix:** Ensure user is logged in and Firebase token is being passed

### Issue: Posts not appearing after creation
**Cause:** Local state not updated
**Fix:** Check console for success message, reload posts if needed

### Issue: Can see other users' posts
**Cause:** RLS policy misconfigured
**Fix:** Verify RLS policies in Supabase dashboard

## Time Estimate

- Code changes: 5 minutes
- Testing: 5 minutes
- **Total: 10 minutes**

## Next Steps

After migrating user posts, consider migrating:
1. Vehicles → Already using Supabase? (check `vehicle_repository.dart`)
2. Slots → Already using Supabase? (check `slot_repository.dart`)
3. Events → Already using Supabase? (check `event_repository.dart`)
4. Bookings → Already using Supabase? (check `booking_repository.dart`)

---

**Ready to migrate? Follow Steps 1-4 above!**
