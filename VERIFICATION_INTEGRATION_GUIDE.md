# Optional Document Verification - Integration Guide

## Overview

This is a 100% legally compliant optional document verification system for QuickOhunt. All documents are truly optional and only available AFTER users upgrade to Premium.

## Legal Compliance ✅

- ✅ No documents asked at signup
- ✅ No documents forced during listing creation  
- ✅ Documents only offered AFTER paid premium plan
- ✅ All fields truly optional
- ✅ User can skip and still use all premium features
- ✅ Complies with KYC law (only when receiving money)

## File Structure

```
lib/
├── screens/
│   └── verification_documents_screen.dart    # Main verification UI
└── services/
    └── verification_service.dart             # Verification logic & uploads
```

## How to Use

### 1. Add the Screen to Your Navigation

In your premium user menu or settings:

```dart
import 'screens/verification_documents_screen.dart';

// In your menu/settings widget:
ListTile(
  leading: const Icon(Icons.verified_user),
  title: const Text('Document Verification'),
  subtitle: const Text('Build trust with verification'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VerificationDocumentsScreen(),
      ),
    );
  },
)
```

### 2. Check Premium Status Before Showing

```dart
import 'services/verification_service.dart';

// Only show verification to premium users
if (VerificationService.instance.canAccessVerification()) {
  // Show verification option
}
```

### 3. Get Verification Badge Status

```dart
// Check if user has verified badge
final hasVerifiedBadge = VerificationService.instance.getVerificationBadgeStatus();

// Get progress (0-5 documents)
final progress = VerificationService.instance.getVerificationProgress();

// Get user-friendly message
final message = VerificationService.instance.getVerificationMessage();
```

## Database Setup Required

### 1. Create Storage Bucket

```sql
-- Run in Supabase SQL Editor
-- This bucket stores verification documents securely

-- Create public bucket for verification documents
INSERT INTO storage.buckets (id, name, public) 
VALUES ('verification-documents', 'verification-documents', false);

-- Set RLS policies (bucket is private, only owner can access)
CREATE POLICY "Users can upload their own verification documents"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'verification-documents' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can view their own verification documents"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'verification-documents' AND auth.uid()::text = (storage.foldername(name))[1]);
```

### 2. Update profiles_private Table

Your `profiles_private` table should already have these fields from ProfileInfo model:
- `aadhaar_front_image` (RC Book)
- `pan_front_image` (Insurance)
- `dl_front_image` (Driving License)
- `aadhaar` (National ID)
- `pan` (Tax ID)

They map like this:

| UI Field | DB Field | Purpose |
|----------|----------|---------|
| RC Book | aadhaar_front_image | Registration Certificate |
| Insurance | pan_front_image | Vehicle Insurance |
| Driving License | dl_front_image | Valid driving license |
| National ID | aadhaar | Identity verification |
| Tax ID | pan | Tax identification |

## Document Upload Flow

```
1. User clicks "Upload" on a document
   ↓
2. Image picker opens (gallery only)
   ↓
3. Image compressed to 80% quality
   ↓
4. Uploaded to Supabase storage bucket
   ↓
5. Public URL returned
   ↓
6. ProfileInfo updated with URL
   ↓
7. UI shows ✅ checkmark
```

## Features

### ✅ Upload Status Tracking
- Shows which documents are uploaded
- Visual indicators (checkmarks, icons)
- Progress counter (X of 5 uploaded)

### ✅ Optional with Clear Messaging
- "OPTIONAL (Increases Trust)" badges
- "All documents are completely optional" header
- Skip button for users who want to continue without uploading

### ✅ Benefits Display
- Each document shows benefit (e.g., "Get verified badge for more bookings")
- Encourages voluntary completion

### ✅ Secure Storage
- Documents stored in private Supabase bucket
- Only accessible to owner
- RLS policies enforce security

### ✅ Image Optimization
- Automatic compression to 80% quality
- Reduces storage costs
- Maintains visual quality

## Verification Badge Requirements

Users get the **Verified Badge ✓** when:
- At least 2 documents are successfully verified
- Documents are verified by your moderation team (manual process)
- Badge appears on their profile

## Next Steps (Future Implementation)

1. **Document Verification Queue**
   - Backend process to review uploaded documents
   - Admin dashboard to approve/reject
   - Automated image validation

2. **Smart Image Validation**
   - OCR to extract document info
   - Fraud detection
   - Liveness detection for selfies

3. **Notification System**
   - Notify users when documents are approved/rejected
   - Send verification badge earned notification

4. **Re-upload on Rejection**
   - Allow users to re-upload if document is rejected
   - Show rejection reason

## Testing

### Test on Web
```bash
flutter run -d chrome
```

### Test on Mobile
```bash
flutter run -d android
# or
flutter run -d ios
```

### Test Upload Flow
1. Ensure user has premium plan
2. Navigate to verification screen
3. Click upload on any document
4. Select image from gallery
5. Verify upload success notification
6. Check Supabase storage for uploaded file
7. Verify profile was updated

## Security Considerations

- ✅ All uploads go through Supabase RLS policies
- ✅ Only authenticated users can upload
- ✅ Only owners can view their documents
- ✅ No documents required (optional)
- ✅ No sensitive data in app code
- ✅ Storage bucket is private

## Troubleshooting

### Image Upload Fails
- Check Supabase storage bucket exists
- Verify RLS policies are correct
- Check user authentication status

### Profile Not Updating
- Ensure `profiles_private` table has required fields
- Check ProfileRepository is loaded
- Verify Supabase connection

### Storage Bucket Issues
```dart
// Debug storage access
final bucket = supabase.storage.from('verification-documents');
print('Bucket accessible: ${bucket != null}');
```

## Legal Documentation

When releasing this feature, include in your app's terms:

> **Document Verification (Optional)**
> Users may voluntarily upload identification and vehicle documents to receive a verification badge. This is completely optional. All documents are stored securely and are only used for verification purposes. Users can delete documents at any time.

## Support

For issues or questions about verification:
1. Check Supabase dashboard for storage/RLS issues
2. Review ProfileRepository for data sync issues
3. Check image_picker permissions in pubspec.yaml
