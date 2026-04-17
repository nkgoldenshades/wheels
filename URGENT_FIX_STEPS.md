# 🚨 URGENT: Fix "Empty JWT" Error and Enable Guest Browsing

## Current Problem
- Error: `Empty JWT is sent in Authorization header (PGRST301)`
- Guests cannot browse posts/vehicles
- RLS policies block `anon` role (guests)
- Only `authenticated` role can access data

## Root Cause
Your RLS policies are set to `TO authenticated` which blocks guests. Firebase JWT users are also being blocked because Supabase doesn't recognize them as `authenticated` role.

## ✅ SOLUTION (3 Steps)

### Step 1: Run SQL Script in Supabase (CRITICAL)
1. Open Supabase Dashboard → SQL Editor
2. Copy the entire content of `COMPLETE_RLS_FIX_FOR_FIREBASE.sql`
3. Paste and click "Run"
4. Verify output shows policies created successfully

**What this does:**
- ✅ Drops the blocking trigger `validate_posts_profile_matches_vehicle`
- ✅ Creates `is_firebase_authenticated()` function to check Firebase JWT
- ✅ Updates posts RLS policies to `TO public` (allows guests + authenticated)
- ✅ Updates vehicles RLS policies to `TO public`
- ✅ Guests can browse (SELECT), only Firebase users can create/update/delete

### Step 2: Verify RLS Policies
After running the SQL, check that these policies exist:

**Posts table:**
- `public_view_active_posts` - SELECT for everyone
- `firebase_users_insert_own_posts` - INSERT for Firebase users only
- `firebase_users_update_own_posts` - UPDATE for Firebase users only
- `firebase_users_delete_own_posts` - DELETE for Firebase users only

**Vehicles table:**
- `public_view_online_vehicles` - SELECT for everyone
- `firebase_users_insert_vehicles` - INSERT for Firebase users only
- `firebase_users_update_own_vehicles` - UPDATE for Firebase users only
- `firebase_users_delete_own_vehicles` - DELETE for Firebase users only

### Step 3: Test the App
1. **As Guest (not logged in):**
   - ✅ Should see posts in feed
   - ✅ Should see vehicles
   - ❌ Cannot create posts/vehicles (expected)

2. **As Logged-in User:**
   - ✅ Should see posts in feed
   - ✅ Should see vehicles
   - ✅ Can create posts with own vehicles
   - ✅ Can create vehicles
   - ✅ Can update/delete own posts/vehicles

## 🔍 Debugging

### Check JWT Claims (Optional)
If you want to see what Supabase receives from Firebase JWT:

1. Add this SQL function in Supabase:
```sql
CREATE OR REPLACE FUNCTION get_jwt_claims()
RETURNS json AS $$
BEGIN
  RETURN current_setting('request.jwt.claims', true)::json;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

2. In your Flutter app, call it after login:
```dart
final claims = await Supabase.instance.client.rpc('get_jwt_claims');
print('JWT Claims: $claims');
```

3. Check if `sub` field exists (should be Firebase UID)

### Common Issues

**Issue: Still getting "Empty JWT" error**
- Make sure you ran the SQL script completely
- Check that policies show `TO public` not `TO authenticated`
- Restart your Flutter app

**Issue: Posts not showing in feed**
- Check `posts` table has `is_active = true`
- Check `posts` have valid `vehicle_id` that exists in `vehicles` table
- Check `vehicles` have `is_online = true`

**Issue: Cannot create posts**
- Make sure you're logged in with Firebase
- Check that vehicle's `profile_id` matches your Firebase UID
- Check that profile exists in `profiles` table

## 📋 Verification Checklist

After running the SQL script:

- [ ] No more "Empty JWT" errors in console
- [ ] Guests can see posts in feed
- [ ] Guests can see vehicles
- [ ] Logged-in users can create posts
- [ ] Logged-in users can create vehicles
- [ ] Vehicle ownership check works (can only use own vehicles)

## 🎯 Expected Behavior After Fix

### Guest Users (anon role)
- ✅ Browse all active posts
- ✅ Browse all online vehicles
- ✅ View post details
- ✅ View vehicle details
- ❌ Cannot create/edit/delete anything

### Logged-in Users (Firebase JWT with sub claim)
- ✅ Everything guests can do
- ✅ Create posts with their own vehicles
- ✅ Create vehicles
- ✅ Edit their own posts/vehicles
- ✅ Delete their own posts/vehicles
- ❌ Cannot edit/delete other users' content

## 🚀 Next Steps After This Fix

Once this is working:

1. **Add more posts** - Create test posts to populate the feed
2. **Test vehicle ownership** - Try creating posts with different vehicles
3. **Test guest browsing** - Open app in incognito/guest mode
4. **Check profile sync** - Verify Firebase users sync to `profiles` table

---

**Need Help?**
- Check Supabase logs: Dashboard → Logs → Postgres Logs
- Check Flutter console for detailed error messages
- Verify Firebase user is logged in: `FirebaseAuth.instance.currentUser`
