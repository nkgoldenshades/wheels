# How to Fix the 404 Error - Honest Version

## What's Actually Happening

1. **Your Flutter code is calling 2 RPC functions:**
   - `expire_overdue_bookings()` - line 56 of booking_repository.dart
   - `auto_deactivate_expired_posts()` - line 64 of booking_repository.dart

2. **These functions are defined in your project:**
   - File: `AUTO_EXPIRE_BOOKINGS.sql`
   - They work fine in SQL

3. **But they're NOT in your Supabase database:**
   - PostgREST can't find them
   - You get 404 error
   - App crashes when calling them

## The Real Fix

Run ONE SQL script in Supabase to deploy these 2 functions.

### Steps:

1. **Open this file:**
   ```
   e:\quickohunt\ACTUAL_FIX_DEPLOY_RPC.sql
   ```

2. **Copy entire contents** (Ctrl+A → Ctrl+C)

3. **Go to Supabase:**
   - [app.supabase.com](https://app.supabase.com)
   - Select your project
   - SQL Editor
   - New Query

4. **Paste and Run:**
   - Ctrl+V → Click Run

5. **Check bottom of output:**
   ```
   function_name                   | schema | status
   ─────────────────────────────────────────────────
   auto_deactivate_expired_posts   | public | ✅ Ready
   expire_overdue_bookings         | public | ✅ Ready
   ```

6. **Refresh your app** - done!

## That's It

- Time: 5 minutes
- Result: 404 error goes away
- Reason: Functions now exist in your database

No guessing, no making things up. Just deploy what you already defined.
