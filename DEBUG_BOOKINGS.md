# Debug: Why Bookings Disappeared

## Possible Causes:

### 1. User ID Mismatch
- Bookings are filtered by `currentUser.id`
- If you logged out/in or switched accounts, you'll only see YOUR bookings
- **Check**: Are you logged in as the same user who created the bookings?

### 2. Supabase Query Filter
The app loads bookings using:
```dart
.or('profile_customer_id.eq.${currentUser.id},profile_provider_id.eq.${currentUser.id}')
```
This means it ONLY shows bookings where you are either:
- The customer (booked a service) OR
- The provider (offering a service)

### 3. Local Storage vs Supabase
- Primary source: Supabase (database)
- Fallback: Local storage (cache)
- If you cleared cache AND Supabase fails to load, bookings disappear

## How to Debug:

### Option 1: Check Supabase Dashboard
1. Log into your Supabase project dashboard
2. Go to **Table Editor** > **bookings** table
3. Check if bookings data exists
4. Verify `profile_customer_id` or `profile_provider_id` matches your current user's Firebase ID

### Option 2: Add Debug Logs
Add these lines in your app (in main.dart around line 195 after `_loadFromSupabase()`):

```dart
debugPrint('🔍 Current User ID: ${currentUser?.id}');
debugPrint('📊 Total bookings loaded: ${bookings.value.length}');
for (final b in bookings.value) {
  debugPrint('   - Booking ID: ${b.id}, Customer: ${b.userId}, Provider: ${b.providerId}');
}
```

### Option 3: Force Refresh
In your app, try:
1. Pull down to refresh (if you have pull-to-refresh)
2. Or restart the app completely
3. Check if bookings reappear

## Quick Fix:

If bookings are truly gone from database, you may need to:
1. Create test bookings again
2. Or restore from a backup (if you have one)

## For Launch:

**IMPORTANT**: Before going live, make sure:
- Bookings data is persistent in Supabase
- Users can see their bookings after logging out/in
- Test with 2+ accounts to verify provider AND customer views
