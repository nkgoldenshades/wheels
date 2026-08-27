# Supabase Post Media Upload - RLS Setup Required

## Problem
Post media uploads are failing because the `post_media` bucket in Supabase doesn't have Row Level Security (RLS) policies configured.

## Solution

You need to add RLS policies to the `post_media` storage bucket. Follow these steps:

### Step 1: Go to Supabase Dashboard
1. Open your Supabase project
2. Navigate to **Storage** → **Buckets**
3. Click on the `post_media` bucket

### Step 2: Add Policies

Go to the **Policies** tab and add the following SQL policies:

#### Policy 1: Allow Authenticated Users to Upload (Insert)
```sql
CREATE POLICY "post_media upload - owner" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'post_media'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);
```

#### Policy 2: Allow Authenticated Users to Update Their Own Files
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

#### Policy 3: Allow Authenticated Users to Delete Their Own Files
```sql
CREATE POLICY "post_media delete - owner" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'post_media'
  AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);
```

#### Policy 4: Allow Anyone to View/Download Files (Public Read)
```sql
CREATE POLICY "post_media read - public" ON storage.objects
FOR SELECT
USING (
  bucket_id = 'post_media'
);
```

### Step 3: Verify Setup
After adding these policies:
1. The upload path format is: `{userId}/posts/{postId}/{filename}`
2. RLS will automatically validate that users can only upload/delete files in their own `{userId}` folder
3. Anyone can read/view the images (public bucket)

### Important Notes
- The `storage.foldername(name)` function extracts the first folder level (user ID) from the path
- This prevents users from uploading to other users' folders
- File paths must follow: `{userId}/posts/{postId}/{timestamp}_{filename}`
- The app already generates paths correctly - no code changes needed

## Testing

After setting up RLS:
1. Pick images from your device
2. Click "Add Images" button
3. Images should upload successfully
4. Preview thumbnails should appear in the media grid
5. Post creation should work normally

## Troubleshooting

If uploads still fail:
1. **Check user authentication**: Make sure user is logged in
2. **Check browser console**: Look for specific error messages
3. **Verify path format**: Ensure files are uploaded to `{userId}/posts/...` path
4. **Check bucket name**: Make sure bucket is named exactly `post_media`
5. **Enable debug logs**: Check Flutter debug output for upload messages

## Debugging with Flutter

The app logs upload progress. Check Android Studio/VS Code console for:
- `✅ Post image uploaded:` - successful upload
- `❌ Failed to upload post image:` - failed upload
- `❌ Upload response empty` - Supabase response issue

These messages help identify where the upload process fails.
