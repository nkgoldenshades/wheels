# Quick Start: Fixing Post Media Uploads

## The Issue
Post media (images/videos) don't upload or show previews. This is because Supabase needs permission rules (RLS policies).

## The Fix (5 minutes)

### Step 1: Open Supabase Dashboard
- Go to your Supabase project: https://app.supabase.com
- Click on your project

### Step 2: Navigate to Storage
- Left sidebar → **Storage**
- Click on **post_media** bucket

### Step 3: Open Policies Tab
- Look for the **Policies** tab (or **RLS** tab)
- Click on it

### Step 4: Copy & Paste These 4 Policies

Run each SQL policy one at a time:

**Policy 1: Upload (Insert)**
```sql
CREATE POLICY "post_media upload - owner" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'post_media'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);
```

**Policy 2: Update**
```sql
CREATE POLICY "post_media update - owner" ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id = 'post_media'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
)
WITH CHECK (
  bucket_id = 'post_media'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);
```

**Policy 3: Delete**
```sql
CREATE POLICY "post_media delete - owner" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'post_media'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);
```

**Policy 4: Read (Public)**
```sql
CREATE POLICY "post_media read - public" ON storage.objects
FOR SELECT
USING (
  bucket_id = 'post_media'
);
```

### Step 5: Test
1. Reload your app
2. Create a post
3. Click "Add Images"
4. Pick images
5. They should upload! ✅

## If It Still Doesn't Work

Check these:
1. **Bucket name**: Make sure it says `post_media` exactly
2. **User logged in**: Make sure you're logged into the app
3. **Network**: Check your internet connection
4. **Console logs**: Look at Flutter console for error messages (starts with ❌)

## What We Fixed in Code

### HS Code Advanced Mode ✅ DONE
- Removed complex "From/To" fields
- Now just one text field where you enter the HS code
- Example: `39231000` instead of `392310` + from `00` + to `99`

### Post Media Upload ⏳ NEEDS RLS POLICIES
- Code is ready, just needs Supabase permissions
- Upload path: `userId/posts/postId/timestamp_filename`
- RLS ensures users can only upload to their own folder

## Questions?

- Can't find Policies tab? Look for "RLS" or click the three dots
- Not seeing success message? Check the flutter console output
- Did you paste the policies correctly? Copy exactly as shown above
