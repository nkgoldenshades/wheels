# Configure Supabase to Accept Firebase JWT

## Problem
Supabase is rejecting Firebase JWT tokens because it doesn't recognize Firebase as a trusted authentication provider.

## Solution: Add Firebase as Custom JWT Provider

### Step 1: Get Your Firebase Project ID
1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project
3. Go to **Project Settings** (gear icon)
4. Copy your **Project ID** (e.g., `quickohunt-12345`)

### Step 2: Configure Supabase to Trust Firebase JWT

Go to your Supabase Dashboard and run this SQL:

```sql
-- Configure Supabase to accept Firebase JWT tokens
-- Replace 'YOUR_FIREBASE_PROJECT_ID' with your actual Firebase project ID

-- Add Firebase as a trusted JWT issuer
INSERT INTO auth.config (key, value)
VALUES ('jwt_aud', 'YOUR_FIREBASE_PROJECT_ID')
ON CONFLICT (key) DO UPDATE SET value = 'YOUR_FIREBASE_PROJECT_ID';

-- Set JWT secret to verify Firebase tokens
-- Firebase uses RS256 (public key verification)
-- We need to tell Supabase to fetch the public keys from Firebase

-- Note: This requires Supabase to be configured to use Firebase's JWKS endpoint
-- The JWKS URL for Firebase is:
-- https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com
```

### Step 3: Alternative - Use Supabase Dashboard UI

1. Go to **Supabase Dashboard** → **Authentication** → **Providers**
2. Scroll down to **"Custom"** or **"Third-party Auth"**
3. Add a new provider with:
   - **Provider Name**: Firebase
   - **JWKS URL**: `https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com`
   - **JWT Audience**: Your Firebase Project ID
   - **JWT Issuer**: `https://securetoken.google.com/YOUR_FIREBASE_PROJECT_ID`

### Step 4: Verify Configuration

Run this SQL to test:

```sql
-- Test if auth.uid() returns the Firebase UID
SELECT 
  auth.uid() as firebase_uid,
  auth.role() as role,
  (auth.jwt()->>'sub')::text as jwt_subject;
```

If `firebase_uid` shows your Firebase UID (JgBbKBwgXpTBkttVNryBMCIco172), it's working!

### Step 5: Apply Proper RLS Policies

Once Firebase JWT is recognized, run this SQL:

```sql
-- Drop existing policies
DROP POLICY IF EXISTS "trip_media_select" ON storage.objects;
DROP POLICY IF EXISTS "trip_media_insert" ON storage.objects;
DROP POLICY IF EXISTS "trip_media_delete" ON storage.objects;
DROP POLICY IF EXISTS "trip_media_update" ON storage.objects;

-- Allow public to read
CREATE POLICY "trip_media_select"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'trip_media');

-- Allow authenticated users to upload to their own path
CREATE POLICY "trip_media_insert"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'trip_media' AND
  (string_to_array(name, '/'))[2] = auth.uid()::text
);

-- Allow authenticated users to update their own files
CREATE POLICY "trip_media_update"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'trip_media' AND
  (string_to_array(name, '/'))[2] = auth.uid()::text
);

-- Allow authenticated users to delete their own files
CREATE POLICY "trip_media_delete"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'trip_media' AND
  (string_to_array(name, '/'))[2] = auth.uid()::text
);
```

## Troubleshooting

If it still doesn't work, check:
1. Firebase JWT is being sent (you see "🔐 Sending Firebase JWT to Supabase" in logs) ✅
2. Supabase recognizes the JWT (run the test SQL above)
3. The storage path matches the format: `{bookingId}/{userId}/{phase}/{filename}`

## Quick Test (Temporary)

If you want to test quickly while setting up Firebase JWT, you can temporarily use:

```sql
-- TEMPORARY: Allow all authenticated users (less secure)
CREATE POLICY "trip_media_insert"
ON storage.objects
FOR INSERT
TO anon, authenticated
WITH CHECK (bucket_id = 'trip_media');
```

This allows uploads from anyone with the anon key, but it's not secure for production.
