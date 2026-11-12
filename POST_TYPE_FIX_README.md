# Fix: Customer Posts Appearing in Main Feed

## Problem
After customers create posts with payment, the posts appear in **both**:
1. Main feed (provider posts) ❌
2. "My Posts" section ✅

Customer requests should **only** appear in "My Posts", not in the main feed.

## Root Cause
The `posts` table doesn't differentiate between:
- **Provider offers** (`post_type='offer'`) — services offered by providers
- **Customer requests** (`post_type='request'`) — services requested by customers with escrow payment

## Solution

### 1. Database Migration
Run `add_post_type_column.sql` in Supabase SQL Editor to:
- Add `post_type` column
- Set all existing posts to `'offer'` (provider posts)
- Add index for performance
- Add constraint to only allow `'offer'` or `'request'`

### 2. Code Changes

**File: `lib/services/customer_slot_repository.dart`**
- Line ~338: Added `'post_type': 'request'` when saving customer posts

**File: `lib/services/slot_repository.dart`**  
- Line ~171: Added `.not('post_type', 'eq', 'request')` to exclude customer requests from main feed

## How It Works Now

### Customer Flow:
1. Customer creates post → pays with Razorpay/Stripe
2. Post saved with `post_type='request'`
3. Post appears **only** in "My Posts" (filtered by `profile_id`)
4. **Does NOT** appear in main feed

### Provider Flow:
1. Provider creates post (no payment)
2. Post saved with `post_type='offer'` (default)
3. Post appears in main feed for customers to book
4. Also appears in provider's "My Posts"

## Vehicle ID Issue

If posts show wrong vehicle IDs, check:
1. Customer has vehicles added in "My Vehicles"
2. Vehicle selection is mandatory (validation on line 390)
3. Vehicle list loads correctly for customer mode (`isUserMode=true`)

## Testing Steps

1. **Run SQL migration** in Supabase
2. **Restart Flutter app** (full restart, not hot reload)
3. **Create provider post** (should appear in main feed)
4. **Create customer post with payment** (should NOT appear in main feed)
5. **Check "My Posts"** (customer post should be there)

## Verification Queries

```sql
-- Check post types
SELECT post_type, COUNT(*) FROM posts GROUP BY post_type;

-- Check customer posts
SELECT id, profile_id, vehicle_id, post_type 
FROM posts 
WHERE post_type = 'request' 
ORDER BY created_at DESC;

-- Check provider posts in main feed
SELECT id, profile_id, vehicle_id, post_type 
FROM posts 
WHERE is_active = true 
  AND post_type != 'request' 
  AND end_time > NOW()
ORDER BY created_at DESC;
```
