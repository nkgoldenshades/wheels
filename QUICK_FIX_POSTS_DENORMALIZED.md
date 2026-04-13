# Quick Fix: Posts Not Showing (Denormalized Solution)

## The Problem
Posts weren't showing because the query was doing a JOIN to `profiles` table:
```sql
SELECT *, public_profiles!posts_profile_id_fkey (full_name, avatar_url) FROM posts
```
This fails for guests due to RLS restrictions on the profiles table.

## The Solution
**Denormalize user data** - store provider/customer names directly in posts tables.

## Steps to Fix

### 1. Run SQL Migration
Execute `DENORMALIZE_POSTS_FOR_GUEST_ACCESS.sql` in Supabase SQL Editor

This adds:
- `provider_name` and `provider_avatar` to `posts` table
- `customer_name` and `customer_avatar` to `user_posts` table
- `status`, `is_online`, `user_id` to `user_posts` table
- Triggers to keep data in sync
- Guest-friendly RLS policies

### 2. Code Changes (Already Done ✅)
- `lib/services/slot_repository.dart` - Removed JOIN, uses `.select('*')`
- `lib/models/slot.dart` - Reads from `provider_name` field

### 3. Restart App
```bash
flutter run
```

## How It Works

### Before (with JOIN - fails for guests):
```dart
.from('posts')
.select('''
  *,
  public_profiles!posts_profile_id_fkey (full_name, avatar_url)
''')
```

### After (denormalized - works for everyone):
```dart
.from('posts')
.select('*')  // provider_name is already in the row!
```

## Benefits
✅ Guests can browse posts without login  
✅ No complex RLS policies  
✅ Faster queries (no JOIN)  
✅ Auto-synced via triggers  

## Verification

After running the SQL:
```sql
-- Check columns exist
SELECT column_name FROM information_schema.columns
WHERE table_name = 'posts' AND column_name = 'provider_name';

-- Check data populated
SELECT id, provider_name, service_type FROM posts LIMIT 5;
```

## What Gets Denormalized

### posts table:
- `provider_name` - copied from profiles.full_name
- `provider_avatar` - copied from profiles.avatar_url

### user_posts table:
- `customer_name` - copied from profiles.full_name
- `customer_avatar` - copied from profiles.avatar_url

### Triggers keep it in sync:
- When creating a post → auto-fills name/avatar
- When updating profile → updates all posts by that user

## That's It!
Run the SQL, restart the app, and posts should appear for everyone (guests + authenticated users).
