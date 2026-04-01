# Security Solution: Firebase Auth + Supabase RLS

## The Problem

You asked: "Will disabling RLS be a security risk?"

**YES - it's a MAJOR security risk!**

Without RLS:
- Anyone with your Supabase anon key can access ALL data
- Malicious users could delete bookings, modify prices, steal user info
- No database-level protection

## The Secure Solution

Use **Firebase JWT validation** with **Supabase RLS policies**.

### How It Works

```
1. User logs in with Firebase Auth
   ↓
2. Firebase generates JWT token with user ID in 'sub' claim
   ↓
3. Flutter app passes JWT to Supabase via accessToken callback
   ↓
4. Supabase validates JWT signature
   ↓
5. RLS policies use auth.jwt() ->> 'sub' to extract Firebase UID
   ↓
6. Only authenticated users can access their own data
```

### Implementation Steps

#### Step 1: Update Flutter App (lib/main.dart)

Replace the Supabase initialization with:

```dart
await Supabase.initialize(
  url: SupabaseConfig.url,
  anonKey: SupabaseConfig.anonKey,
  // CRITICAL: Pass Firebase JWT for security
  accessToken: () async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    
    try {
      final token = await user.getIdToken(true);
      if (kDebugMode) {
        print('🔑 Firebase UID: ${user.uid}');
      }
      return token;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to get Firebase token: $e');
      return null;
    }
  },
);
```

#### Step 2: Run secure_firebase_jwt_rls.sql in Supabase

This SQL script:
1. Converts all user ID columns to TEXT
2. Creates RLS policies using `auth.jwt() ->> 'sub'`
3. Maintains security while working with Firebase UIDs

### Key Difference from Before

**OLD (BROKEN):**
```sql
-- This doesn't work because auth.uid() returns Supabase UUID, not Firebase UID
CREATE POLICY "bookings_insert" ON bookings
  FOR INSERT WITH CHECK ((auth.uid())::text = user_id);
```

**NEW (SECURE):**
```sql
-- This works because auth.jwt() ->> 'sub' extracts Firebase UID from JWT
CREATE POLICY "bookings_insert" ON bookings
  FOR INSERT WITH CHECK ((auth.jwt() ->> 'sub') = user_id);
```

### Security Benefits

✅ Only authenticated Firebase users can access data
✅ Users can only modify their own records
✅ JWT signature validation prevents forgery
✅ Database-level security (not just app-level)
✅ Works with Firebase UID strings (TEXT type)

### What NOT To Do

❌ Don't disable RLS entirely
❌ Don't use permissive policies (USING true) for write operations
❌ Don't use auth.uid() (returns Supabase UUID, not Firebase UID)
❌ Don't remove accessToken callback from Flutter app

### Files to Use

1. **secure_firebase_jwt_rls.sql** - Run this in Supabase SQL Editor
2. **lib/main.dart** - Update Supabase.initialize() with accessToken callback

### Testing

After applying:
1. Restart Flutter app
2. Log in with Firebase
3. Try creating a booking
4. Check debug logs for "🔑 Firebase UID: ..."
5. Booking should succeed with OTP generated

### Why This Works

Firebase JWT contains:
```json
{
  "sub": "GbsFkKmcHCQFJ0ceVoBWz2punch1",  // Firebase UID
  "email": "user@example.com",
  "iat": 1234567890,
  ...
}
```

Supabase RLS can extract the `sub` claim:
```sql
auth.jwt() ->> 'sub'  -- Returns "GbsFkKmcHCQFJ0ceVoBWz2punch1"
```

This matches your TEXT user_id columns!

## Summary

**Don't disable RLS** - use `secure_firebase_jwt_rls.sql` instead. It provides proper security while working with Firebase Auth.
