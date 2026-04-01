# JWT Claims Testing Instructions

## Why We Need This Test

We need to verify what claims are in the Firebase JWT that Supabase receives. This will tell us whether to use:
- `auth.jwt() ->> 'sub'` (if Firebase UID is in 'sub' claim)
- `auth.jwt() ->> 'user_id'` (if Firebase UID is in 'user_id' claim)
- Something else

## Step 1: Run SQL Function in Supabase

1. Open Supabase Dashboard → SQL Editor
2. Run the contents of `test_jwt_claims.sql`:

```sql
CREATE OR REPLACE FUNCTION get_jwt_claims() 
RETURNS jsonb 
LANGUAGE sql 
SECURITY DEFINER 
AS $$
  SELECT auth.jwt();
$$;

GRANT EXECUTE ON FUNCTION get_jwt_claims() TO authenticated;
GRANT EXECUTE ON FUNCTION get_jwt_claims() TO anon;
```

## Step 2: Test in Flutter App

1. Run your Flutter app
2. Go to Login screen
3. Login with your test account
4. Check the debug console/logs

## Step 3: Look for Output

You should see output like this:

```
🔍 Testing JWT claims...
🔑 Firebase UID: GbsFkKmcHCQFJ0ceVoBWz2punch1
🔑 Firebase Token (first 50 chars): eyJhbGciOiJSUzI1NiIsImtpZCI6IjFkYzBmMTcyZGE3YjYzY...
📦 JWT Claims received by Supabase:
{sub: GbsFkKmcHCQFJ0ceVoBWz2punch1, email: test@example.com, ...}
✅ Found "sub" claim: GbsFkKmcHCQFJ0ceVoBWz2punch1
```

## Step 4: Interpret Results

### Case A: "sub" claim exists ✅
```
✅ Found "sub" claim: GbsFkKmcHCQFJ0ceVoBWz2punch1
```

**Action:** Use `auth.jwt() ->> 'sub'` in RLS policies
**File to run:** `secure_firebase_jwt_rls.sql` (already created)

### Case B: "user_id" claim exists ⚠️
```
⚠️ Found "user_id" instead of "sub": GbsFkKmcHCQFJ0ceVoBWz2punch1
```

**Action:** Use `auth.jwt() ->> 'user_id'` in RLS policies
**File to run:** I'll create a new one with user_id

### Case C: No user identifier ❌
```
❌ No user identifier found in JWT!
Available keys: [iss, aud, exp, iat]
```

**Action:** Firebase JWT not being passed correctly
**Fix:** Check Supabase.initialize() has accessToken callback

### Case D: JWT is null ❌
```
❌ JWT claims is null or not a Map
```

**Action:** Supabase not receiving JWT at all
**Fix:** Verify Firebase Auth is working and accessToken callback is correct

## Step 5: Share Results

After running the test, share the console output here so I can:
1. Confirm which claim contains the Firebase UID
2. Update the RLS policies to use the correct claim
3. Ensure everything works properly

## Files Modified

- `lib/services/auth_repository.dart` - Added `testJWTClaims()` function
- `lib/screens/auth/login_screen.dart` - Calls test after login
- `test_jwt_claims.sql` - SQL function to get JWT claims

## After Testing

Once we confirm the correct claim, you can remove the test code:
1. Remove `await AuthRepository.instance.testJWTClaims();` from login_screen.dart
2. Remove `testJWTClaims()` function from auth_repository.dart
3. Keep the SQL function (harmless to leave it)
