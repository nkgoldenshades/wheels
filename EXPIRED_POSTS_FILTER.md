# Expired Posts Filter

## What Was Added

Added automatic filtering to hide posts that have already started (expired posts) from the common feed.

## How It Works

### Filter Logic
```dart
final now = DateTime.now();

// Filter out posts where start time has passed
.where((e) => e.slot.startTime.isAfter(now))
```

### Where It's Applied

1. **Provider Posts Tab** (Offers)
   - Shows only future posts from providers
   - Hides posts where `startTime` is in the past
   - Location: `lib/main.dart` line ~3808

2. **User Posts Tab** (Requests)
   - Shows only future requests from users
   - Hides posts where `startTime` is in the past
   - Location: `lib/main.dart` line ~3783

## Benefits

✅ **No Confusion** - Users only see bookable trips
✅ **Clean Feed** - Old posts automatically hidden
✅ **No Data Loss** - Posts still exist in database
✅ **Provider History** - Providers can still see their past posts in "My Posts"
✅ **Instant** - No backend processing needed

## What Users See

### Common Feed (Browse Posts)
- ✅ Only shows posts with future start times
- ❌ Hides posts that have already started
- ❌ Hides posts that have ended

### My Posts (Provider's Own Posts)
- ✅ Shows ALL posts (past and future)
- Providers can see their history
- Can manage completed trips

## Example

**Current Time:** January 15, 2026 10:00 AM

**Posts in Database:**
1. Trip A - Start: January 14, 2026 (YESTERDAY) → ❌ Hidden from feed
2. Trip B - Start: January 15, 2026 08:00 AM (2 hours ago) → ❌ Hidden from feed
3. Trip C - Start: January 15, 2026 02:00 PM (4 hours from now) → ✅ Shown in feed
4. Trip D - Start: January 20, 2026 (5 days from now) → ✅ Shown in feed

## Technical Details

### Filter Order
1. **Expiry Filter** - Remove past posts
2. **Online Status Filter** - For authenticated users only
3. **Privacy Filter** - Hide own posts from user posts tab
4. **Search Filter** - Location search
5. **Date Range Filter** - User-selected date range
6. **Price Filter** - User-selected price range
7. **Capacity Filter** - User-selected capacity

### Performance
- Filtering happens in memory (fast)
- No database queries needed
- Runs on every feed refresh
- Minimal performance impact

## Alternative Approach (Not Implemented)

If you want to permanently delete expired posts from the database, you can:

1. Create a Supabase Edge Function
2. Schedule it to run daily
3. Delete posts where `start_time < NOW()`

```sql
-- Example SQL for auto-deletion (NOT IMPLEMENTED)
DELETE FROM posts 
WHERE start_time < NOW() - INTERVAL '1 day';
```

## Testing

To test the filter:

1. Create a post with start time in the past
2. Check common feed - post should NOT appear
3. Check "My Posts" - post SHOULD appear (if you're the provider)
4. Create a post with future start time
5. Check common feed - post SHOULD appear

## Notes

- Posts are filtered by `startTime`, not `endTime`
- Once a trip starts, it's hidden from the feed
- Users can't book trips that have already started
- Providers can still see and manage all their posts
