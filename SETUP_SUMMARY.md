# Firebase + Supabase Setup - Complete Guide

## Your Architecture (Confirmed Correct ✅)

```
Firebase Auth (authentication)
    ↓
Flutter App (sends JWT manually)
    ↓
Supabase (validates JWT, uses RLS)
    ↓
PostgreSQL Database
```

## Two Manual Steps Required

### Step 1: Supabase Dashboard Setup (One-time)

**Purpose:** Tell Supabase to trust Firebase JWTs

**Location:** Supabase Dashboard → Authentication → Providers → Firebase

**What it does:**
- Supabase fetches Firebase's public OIDC keys
- Stores them in your project config
- Now Supabase knows what valid Firebase JWTs look like

**Result:** Your Supabase project now accepts Firebase JWTs ✅

### Step 2: Flutter Code Setup (One-time)

**Purpose:** Send Firebase JWT with every Supabase request

**Code:**
```dart
await Supabase.initialize(
  url: 'https://xxxx.supabase.co',
  anonKey: 'your-anon-key',
  accessToken: () async {
    return await FirebaseAuth
        .instance
        .currentUser
        ?.getIdToken(true);
  },
);
```

**What it does:**
- Before each Supabase request, gets fresh Firebase JWT
- Automatically includes JWT in request headers
- Supabase receives JWT and validates it

**Result:** Every request includes Firebase JWT ✅

## How JWT Works

### JWT Lifecycle
```
User logs in → Firebase generates JWT (expires in 1 hour)
    ↓
Flutter calls getIdToken(true) → Gets fresh JWT
    ↓
Supabase receives JWT → Validates signature
    ↓
Extracts 'sub' claim → Gets Firebase UID
    ↓
RLS policies check → auth.jwt() ->> 'sub'
    ↓
Allows/denies database operation
```

### JWT Contents
```json
{
  "sub": "GbsFkKmcHCQFJ0ceVoBWz2punch1",  // Firebase UID (never changes)
  "email": "user@example.com",
  "iat": 1234567890,
  "exp": 1234571490  // Expires in 1 hour
}
```

## RLS Security

### How RLS Uses JWT
```sql
-- Extract Firebase UID from JWT
auth.jwt() ->> 'sub'  -- Returns "GbsFkKmcHCQFJ0ceVoBWz2punch1"

-- Example policy
CREATE POLICY "users_own_bookings" ON bookings
  FOR SELECT USING (
    (auth.jwt() ->> 'sub') = user_id
  );
```

### What Each Component Does

| Component | Purpose |
|-----------|---------|
| Supabase URL | Identifies your project |
| Anon Key | Public key to access project |
| Firebase JWT | Proves who the user is |
| RLS Policies | Controls what data user can access |

## Security Layers

1. **Firebase Auth** - User must log in
2. **JWT Validation** - Supabase verifies JWT signature
3. **RLS Policies** - Database checks user permissions
4. **Firebase Functions** - Business logic validation

## Key Points

✅ **auth.users table stays empty** - That's normal with Firebase Auth
✅ **JWT auto-refreshes** - getIdToken(true) handles it
✅ **'sub' claim never changes** - Same Firebase UID forever
✅ **Anon key is safe to expose** - Security comes from RLS
✅ **No service_role_key in app** - Only in Firebase Functions

## What You Need to Do Now

1. **Run `secure_firebase_jwt_rls.sql`** in Supabase SQL Editor
   - Converts columns to TEXT
   - Creates RLS policies using `auth.jwt() ->> 'sub'`

2. **Verify main.dart has accessToken callback**
   - Already done ✅

3. **Test booking creation**
   - Should work now with OTP generation

That's it! Your setup is correct.
