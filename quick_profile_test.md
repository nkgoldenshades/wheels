# 🧪 Quick Profile Test

## 1. Test Your Profiles Table in Supabase

Run this in your Supabase SQL Editor:

```sql
-- Check if profiles table exists
SELECT * FROM information_schema.tables WHERE table_name = 'profiles';

-- Check RLS policies
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'profiles';

-- Test JWT (should show your Firebase UID when logged in)
SELECT auth.jwt()->>'sub' as firebase_uid;
```

## 2. Test Profile Repository in Flutter

Add this to your `main()` function after initialization:

```dart
// Test profile connection
try {
  print('🧪 Testing profiles...');
  
  final currentUser = AuthRepository.instance.currentUser;
  if (currentUser != null) {
    print('✅ User: ${currentUser.id}');
    
    // This will create profile if doesn't exist
    await ProfileRepository.instance.init();
    
    // Test update
    await ProfileRepository.instance.update(
      profileName: 'Test User',
      phone: '+1234567890',
    );
    
    print('✅ Profile test passed!');
  } else {
    print('❌ No user logged in');
  }
} catch (e) {
  print('❌ Profile test failed: $e');
}
```

## 3. Expected Results

**If working correctly:**
- ✅ Profile created/loaded from Supabase
- ✅ Updates saved to database
- ✅ RLS security working

**If failing:**
- ❌ Check Firebase authentication
- ❌ Check Supabase JWT token
- ❌ Check RLS policies

## 4. Next Steps

Once profiles work, we'll test:
1. Vehicles table
2. Slots table  
3. Bookings table
