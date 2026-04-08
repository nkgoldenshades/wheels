# 🧪 Test Backend Connection

## Quick Test

Run your app and check the console output:

```bash
flutter run -d chrome
```

## Expected Console Output:

```
🚀 Starting app...
⏳ Initializing Firebase...
✅ Firebase initialized
⏳ Initializing AuthRepository...
✅ AuthRepository initialized
🔧 Starting background initialization...
⏳ Starting Supabase...
✅ Supabase initialized
🔗 Supabase connection configured
📍 URL: https://uklltpopjovbhplbvltr.supabase.co
🔑 Auth: Firebase JWT → Supabase RLS

🧪 Starting Backend Connection Tests...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📡 Test 1: Supabase Connection
   URL: https://uklltpopjovbhplbvltr.supabase.co
   ✅ Supabase client initialized

🔑 Test 2: Firebase JWT
   ⚠️  No user logged in (expected on first launch)

🔒 Test 3: RLS Policies
   ⚠️  Skipping (no user logged in)

📊 Test 4: Table Access
   ✅ profiles - accessible
   ✅ vehicles - accessible
   ✅ slots - accessible
   ✅ bookings - accessible
   ✅ reviews - accessible
   ✅ user_posts - accessible
   ✅ user_post_acceptances - accessible

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 Backend Connection Tests Complete!
```

## After Login:

Once you log in, you should see:

```
🔑 Test 2: Firebase JWT
   User ID: abc123xyz
   Email: user@example.com
   ✅ Firebase user authenticated

🔒 Test 3: RLS Policies
   ✅ Can read own profile
   ✅ Can read vehicles (0 found)
   ✅ Can read slots (0 found)
```

## Manual Test Steps:

### 1. Test Profile Creation
1. Sign up with email/password
2. Check console for: `✅ Profile created successfully`
3. Go to Supabase Dashboard → Table Editor → profiles
4. Should see your profile row ✅

### 2. Test Vehicle Creation
1. Go to "My Vehicles" tab
2. Add a new vehicle
3. Check console for: `✅ Provider vehicle created in Supabase`
4. Go to Supabase Dashboard → Table Editor → vehicles
5. Should see your vehicle row ✅

### 3. Test Slot Creation
1. Go to "Posts" tab
2. Create a new slot/post
3. Check console for: `✅ Slot synced to Supabase`
4. Go to Supabase Dashboard → Table Editor → slots
5. Should see your slot row ✅

### 4. Test Booking Creation
1. Browse available slots
2. Book a slot
3. Check console for: `✅ Booking created`
4. Go to Supabase Dashboard → Table Editor → bookings
5. Should see your booking row ✅

## Troubleshooting:

### ❌ "Table not found"
**Fix:** Run the database schema SQL in Supabase SQL Editor
```sql
-- Run: fresh_database_setup.sql
```

### ❌ "RLS policy violation"
**Fix:** Check RLS policies are enabled
```sql
-- In Supabase SQL Editor:
SELECT tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'public';
```

### ❌ "JWT validation failed"
**Fix:** Configure Firebase JWT in Supabase
1. Supabase Dashboard → Authentication → Providers
2. Enable "Custom" provider
3. Add Firebase JWT configuration

### ❌ "Connection timeout"
**Fix:** Check internet connection and Supabase status
- Visit: https://status.supabase.com/

## Quick Debug Commands:

### Check Supabase Connection:
```dart
// In your app, add this to any button:
final supabase = Supabase.instance.client;
final response = await supabase.from('profiles').select().limit(1);
print('Connected: ${response.length} rows');
```

### Check Firebase Auth:
```dart
final user = FirebaseAuth.instance.currentUser;
print('User: ${user?.uid}');
print('Email: ${user?.email}');
```

### Check JWT Token:
```dart
final token = await FirebaseAuth.instance.currentUser?.getIdToken();
print('Token: ${token?.substring(0, 50)}...');
```

## Success Indicators:

✅ All 7 tables accessible
✅ Can create profile after signup
✅ Can create vehicles
✅ Can create slots
✅ Can create bookings
✅ Data persists after app restart
✅ Data visible in Supabase Dashboard

## Next Steps After Connection:

1. ✅ Backend connected
2. Test all CRUD operations
3. Test RLS policies (try accessing other users' data)
4. Test offline → online sync
5. Enable real-time subscriptions (optional)
6. Add data validation
7. Add error handling for network failures

---

**Your backend is ready to use!** 🚀
