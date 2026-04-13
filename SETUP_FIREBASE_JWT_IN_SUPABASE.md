# Setup Firebase JWT Authentication in Supabase

## Problem
Your Flutter app sends Firebase JWT tokens, but Supabase doesn't recognize them as authenticated sessions because Supabase hasn't been configured to validate Firebase JWTs.

## Solution: Configure Supabase to Accept Firebase JWTs

### Step 1: Get Your Firebase Project Details

1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project
3. Go to Project Settings (gear icon)
4. Note down your **Project ID** (e.g., `vaultwheels-12345`)

### Step 2: Configure Supabase JWT Settings

1. Go to your Supabase Dashboard
2. Navigate to **Settings** → **API**
3. Scroll down to **JWT Settings**
4. You need to add Firebase as a custom JWT provider

### Step 3: Add Firebase JWT Verification

You have two options:

#### Option A: Use Supabase Auth with Firebase (Recommended)

1. In Supabase Dashboard, go to **Authentication** → **Providers**
2. Enable **Firebase** as a provider
3. Add your Firebase credentials:
   - Project ID: `your-firebase-project-id`
   - Service Account JSON (download from Firebase)

#### Option B: Use Custom JWT Secret (Alternative)

If Option A doesn't work, you can configure Supabase to accept Firebase's public keys:

1. Get Firebase's public keys from:
   ```
   https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com
   ```

2. In Supabase, you need to configure the JWT secret to validate Firebase tokens

### Step 4: Update Your Supabase RLS Policies

Your RLS policies use `auth.jwt()->>'sub'` which expects the JWT to be validated. Make sure your policies look like this:

```sql
-- For authenticated users (Firebase JWT)
CREATE POLICY "users_insert_own_posts"
ON public.posts
FOR INSERT
TO authenticated
WITH CHECK (profile_id = auth.jwt()->>'sub');
```

### Step 5: Verify JWT is Being Sent

Add this debug code to check if JWT is in requests:

```dart
// In your slot_repository.dart
final authHeaders = supabase.headers;
debugPrint('🔑 Auth headers: ${authHeaders['Authorization']}');
```

## Alternative: Use Supabase Auth Instead

If Firebase JWT integration is too complex, consider using Supabase Auth directly:

1. Migrate from Firebase Auth to Supabase Auth
2. Use `supabase.auth.signInWithPassword()` instead of Firebase
3. RLS policies will work automatically

## Quick Test

Run this SQL in Supabase to check if JWT is being recognized:

```sql
-- This should return your user ID if JWT is valid
SELECT auth.jwt()->>'sub' as user_id;
```

If it returns NULL, the JWT is not being validated by Supabase.

## Current Issue

Your app is sending Firebase JWT, but Supabase is treating requests as `anon` (anonymous) instead of `authenticated` because it doesn't know how to validate the Firebase JWT.

## Recommended Fix

The easiest solution is to use Supabase's built-in auth instead of Firebase Auth, OR properly configure Supabase to validate Firebase JWTs using the steps above.
