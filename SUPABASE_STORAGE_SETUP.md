# Supabase Storage Buckets Setup Guide

## 📋 Overview

You need to create 4 storage buckets in Supabase for storing images and documents.

## 🗄️ Buckets to Create

1. **profile-photos** - User profile pictures (public)
2. **vehicle-images** - Vehicle photos (public)
3. **document-verifications** - KYC documents (private)
4. **vehicle-videos** - Vehicle videos (public, optional)

---

## 🚀 Step-by-Step Setup

### Step 1: Open Supabase Dashboard

1. Go to https://supabase.com/dashboard
2. Sign in to your account
3. Select your project (or create one if you haven't)

### Step 2: Navigate to Storage

1. In the left sidebar, click **"Storage"**
2. You'll see the Storage page with existing buckets (if any)

---

## 📦 Bucket 1: profile-photos

### Create Bucket
1. Click **"New bucket"** button
2. Fill in the details:
   ```
   Name: profile-photos
   Public bucket: ✅ YES (checked)
   File size limit: 5 MB
   Allowed MIME types: image/jpeg, image/png, image/jpg
   ```
3. Click **"Create bucket"**

### Set Policies
1. Click on **"profile-photos"** bucket
2. Go to **"Policies"** tab
3. Click **"New policy"**

**Policy 1: Allow users to upload their own photos**
```sql
Policy name: Users can upload own profile photo
Allowed operation: INSERT
Target roles: authenticated

WITH CHECK:
bucket_id = 'profile-photos' 
AND auth.uid()::text = (storage.foldername(name))[1]
```

**Policy 2: Allow public read access**
```sql
Policy name: Profile photos are publicly readable
Allowed operation: SELECT
Target roles: public

USING:
bucket_id = 'profile-photos'
```

**Policy 3: Allow users to update their own photos**
```sql
Policy name: Users can update own profile photo
Allowed operation: UPDATE
Target roles: authenticated

USING:
bucket_id = 'profile-photos' 
AND auth.uid()::text = (storage.foldername(name))[1]
```

**Policy 4: Allow users to delete their own photos**
```sql
Policy name: Users can delete own profile photo
Allowed operation: DELETE
Target roles: authenticated

USING:
bucket_id = 'profile-photos' 
AND auth.uid()::text = (storage.foldername(name))[1]
```

---

## 📦 Bucket 2: vehicle-images

### Create Bucket
1. Click **"New bucket"** button
2. Fill in the details:
   ```
   Name: vehicle-images
   Public bucket: ✅ YES (checked)
   File size limit: 5 MB
   Allowed MIME types: image/jpeg, image/png, image/jpg
   ```
3. Click **"Create bucket"**

### Set Policies
1. Click on **"vehicle-images"** bucket
2. Go to **"Policies"** tab
3. Click **"New policy"**

**Policy 1: Allow authenticated users to upload**
```sql
Policy name: Users can upload vehicle images
Allowed operation: INSERT
Target roles: authenticated

WITH CHECK:
bucket_id = 'vehicle-images'
```

**Policy 2: Allow public read access**
```sql
Policy name: Vehicle images are publicly readable
Allowed operation: SELECT
Target roles: public

USING:
bucket_id = 'vehicle-images'
```

**Policy 3: Allow users to update their vehicle images**
```sql
Policy name: Users can update vehicle images
Allowed operation: UPDATE
Target roles: authenticated

USING:
bucket_id = 'vehicle-images'
```

**Policy 4: Allow users to delete their vehicle images**
```sql
Policy name: Users can delete vehicle images
Allowed operation: DELETE
Target roles: authenticated

USING:
bucket_id = 'vehicle-images'
```

---

## 📦 Bucket 3: document-verifications (PRIVATE)

### Create Bucket
1. Click **"New bucket"** button
2. Fill in the details:
   ```
   Name: document-verifications
   Public bucket: ❌ NO (unchecked) - IMPORTANT!
   File size limit: 5 MB
   Allowed MIME types: image/jpeg, image/png, image/jpg
   ```
3. Click **"Create bucket"**

### Set Policies
1. Click on **"document-verifications"** bucket
2. Go to **"Policies"** tab
3. Click **"New policy"**

**Policy 1: Allow users to upload their own documents**
```sql
Policy name: Users can upload own documents
Allowed operation: INSERT
Target roles: authenticated

WITH CHECK:
bucket_id = 'document-verifications' 
AND auth.uid()::text = (storage.foldername(name))[1]
```

**Policy 2: Allow users to view only their own documents**
```sql
Policy name: Users can view own documents
Allowed operation: SELECT
Target roles: authenticated

USING:
bucket_id = 'document-verifications' 
AND auth.uid()::text = (storage.foldername(name))[1]
```

**Policy 3: Allow users to update their own documents**
```sql
Policy name: Users can update own documents
Allowed operation: UPDATE
Target roles: authenticated

USING:
bucket_id = 'document-verifications' 
AND auth.uid()::text = (storage.foldername(name))[1]
```

**Policy 4: Allow users to delete their own documents**
```sql
Policy name: Users can delete own documents
Allowed operation: DELETE
Target roles: authenticated

USING:
bucket_id = 'document-verifications' 
AND auth.uid()::text = (storage.foldername(name))[1]
```

---

## 📦 Bucket 4: vehicle-videos (Optional)

### Create Bucket
1. Click **"New bucket"** button
2. Fill in the details:
   ```
   Name: vehicle-videos
   Public bucket: ✅ YES (checked)
   File size limit: 10 MB
   Allowed MIME types: video/mp4, video/quicktime, video/x-msvideo
   ```
3. Click **"Create bucket"**

### Set Policies
Same as vehicle-images bucket (replace bucket_id with 'vehicle-videos')

---

## ✅ Verification Checklist

After creating all buckets, verify:

- [ ] **profile-photos** bucket exists and is PUBLIC
- [ ] **vehicle-images** bucket exists and is PUBLIC
- [ ] **document-verifications** bucket exists and is PRIVATE
- [ ] **vehicle-videos** bucket exists and is PUBLIC (optional)
- [ ] All buckets have RLS policies configured
- [ ] Test upload from your app works

---

## 🧪 Test Your Buckets

### Test Upload (using Supabase Dashboard)

1. Go to Storage → Select a bucket
2. Click **"Upload file"**
3. Create a folder: `test-user-id`
4. Upload a test image
5. Verify you can see it
6. Delete the test file

### Test from Flutter App

```dart
// Test profile photo upload
Future<void> testUpload() async {
  try {
    final bytes = Uint8List.fromList([1, 2, 3]); // Dummy data
    final userId = 'test-user-123';
    final fileName = 'test.jpg';
    
    await Supabase.instance.client.storage
        .from('profile-photos')
        .uploadBinary('$userId/$fileName', bytes);
    
    print('✅ Upload successful!');
    
    // Get public URL
    final url = Supabase.instance.client.storage
        .from('profile-photos')
        .getPublicUrl('$userId/$fileName');
    
    print('📷 Image URL: $url');
  } catch (e) {
    print('❌ Upload failed: $e');
  }
}
```

---

## 📁 Folder Structure

### profile-photos
```
profile-photos/
├── user-id-1/
│   ├── profile_1234567890.jpg
│   └── profile_1234567891.jpg
├── user-id-2/
│   └── profile_1234567892.jpg
```

### vehicle-images
```
vehicle-images/
├── vehicle-id-1/
│   ├── profile.jpg
│   ├── gallery_1.jpg
│   ├── gallery_2.jpg
│   └── gallery_3.jpg
├── vehicle-id-2/
│   └── profile.jpg
```

### document-verifications
```
document-verifications/
├── user-id-1/
│   ├── aadhaar_front_1234567890.jpg
│   ├── aadhaar_back_1234567890.jpg
│   ├── pan_front_1234567891.jpg
│   ├── dl_front_1234567892.jpg
│   └── dl_back_1234567892.jpg
├── user-id-2/
│   └── aadhaar_front_1234567893.jpg
```

### vehicle-videos
```
vehicle-videos/
├── vehicle-id-1/
│   └── showcase_1234567890.mp4
├── vehicle-id-2/
│   └── showcase_1234567891.mp4
```

---

## 🔒 Security Best Practices

### 1. Always Use User ID in Path
```dart
// ✅ GOOD - User can only access their own files
'$userId/profile.jpg'

// ❌ BAD - Anyone can access
'profile.jpg'
```

### 2. Validate File Types
```dart
// Check MIME type before upload
if (!['image/jpeg', 'image/png'].contains(file.mimeType)) {
  throw Exception('Invalid file type');
}
```

### 3. Check File Size
```dart
// Limit file size
if (bytes.length > 5 * 1024 * 1024) { // 5 MB
  throw Exception('File too large');
}
```

### 4. Use Signed URLs for Private Files
```dart
// For document-verifications bucket
final signedUrl = await Supabase.instance.client.storage
    .from('document-verifications')
    .createSignedUrl('$userId/aadhaar_front.jpg', 3600); // 1 hour
```

---

## 💡 Quick Reference

### Upload File
```dart
await Supabase.instance.client.storage
    .from('bucket-name')
    .uploadBinary('path/file.jpg', bytes);
```

### Get Public URL
```dart
final url = Supabase.instance.client.storage
    .from('bucket-name')
    .getPublicUrl('path/file.jpg');
```

### Get Signed URL (Private)
```dart
final url = await Supabase.instance.client.storage
    .from('bucket-name')
    .createSignedUrl('path/file.jpg', 3600);
```

### Delete File
```dart
await Supabase.instance.client.storage
    .from('bucket-name')
    .remove(['path/file.jpg']);
```

### List Files
```dart
final files = await Supabase.instance.client.storage
    .from('bucket-name')
    .list(path: 'user-id');
```

---

## 🎉 You're Done!

Once all buckets are created and policies are set, you're ready to:
1. Upload profile photos with liveness verification
2. Upload vehicle images
3. Upload KYC documents securely
4. Upload vehicle videos

Next step: Integrate storage upload in your Flutter app!
