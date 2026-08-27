# Verification System - Quick Reference

## Import Statements

```dart
import 'screens/verification_documents_screen.dart';
import 'services/verification_service.dart';
```

## Add to Navigation

```dart
// In your settings/menu widget
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

## Common API Calls

### Check if User Can Access Verification
```dart
if (VerificationService.instance.canAccessVerification()) {
  // Show verification option
}
```

### Get Verification Badge Status
```dart
final hasVerifiedBadge = VerificationService.instance.getVerificationBadgeStatus();
if (hasVerifiedBadge) {
  // Show verified badge ✓ on profile
}
```

### Get Progress (0-5)
```dart
final progress = VerificationService.instance.getVerificationProgress();
print('$progress of 5 documents uploaded');
```

### Get User-Friendly Message
```dart
final message = VerificationService.instance.getVerificationMessage();
print(message); // e.g., "✅ 2 of 5 documents verified"
```

### Open Verification Screen
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const VerificationDocumentsScreen(),
  ),
);
```

## Document Types

```dart
'rc_book'          // RC Book (Registration Certificate)
'insurance'        // Insurance (Vehicle Insurance)
'driving_license'  // Driving License
'national_id'      // National ID (Aadhaar/Passport)
'tax_id'           // Tax ID (PAN/GST)
```

## UI Elements You Can Use

### Show Verification Badge on Profile
```dart
if (VerificationService.instance.getVerificationBadgeStatus()) {
  Badge(
    label: const Text('✓ Verified'),
    child: ProfileAvatar(),
  )
}
```

### Show Verification Progress in Settings
```dart
Text(
  VerificationService.instance.getVerificationMessage(),
  style: const TextStyle(fontSize: 14, color: Colors.green),
)
```

### Add Verified Badge to Listings
```dart
if (VerificationService.instance.getVerificationBadgeStatus()) {
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.green,
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified, size: 14, color: Colors.white),
        SizedBox(width: 4),
        Text(
          'Verified',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    ),
  )
}
```

## Database Fields Mapping

| UI Field | Profile Field | Type |
|----------|---------------|------|
| RC Book | aadhaar_front_image | String? (URL) |
| Insurance | pan_front_image | String? (URL) |
| Driving License | dl_front_image | String? (URL) |
| National ID | aadhaar | String? (ID) |
| Tax ID | pan | String? (ID) |

## Verification Flow Logic

```
1. canAccessVerification()
   └─ Returns: subscription_plan == 'premium' or 'expert'

2. uploadDocumentImage()
   ├─ Pick image from gallery
   ├─ Compress to 80% quality
   ├─ Upload to Supabase storage
   └─ Returns: public URL

3. updateVerificationDocuments()
   └─ Update profiles_private with document URL

4. getVerificationBadgeStatus()
   └─ Returns: >=2 documents verified

5. getVerificationProgress()
   └─ Counts uploaded documents (0-5)
```

## Error Handling

```dart
try {
  final imageUrl = await VerificationService.instance.uploadDocumentImage(
    documentType: 'rc_book',
    userId: userId,
  );
  
  if (imageUrl == null) {
    print('Upload cancelled by user');
    return;
  }
  
  // Successfully uploaded
} catch (e) {
  print('Upload failed: $e');
  // Handle error
}
```

## Supabase Storage Bucket

```
Bucket: verification-documents
Type: Private (not publicly accessible)
Path Format: verification_documents/{userId}/{documentType}_{timestamp}.jpg

Example: verification_documents/user-123/rc_book_1691000000000.jpg
```

## RLS Policies Required

```sql
-- Upload policy
CREATE POLICY "upload_own_verification_docs"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'verification-documents' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Read policy
CREATE POLICY "read_own_verification_docs"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'verification-documents' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Delete policy
CREATE POLICY "delete_own_verification_docs"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'verification-documents' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);
```

## Testing Checklist

- [ ] User has premium plan before accessing
- [ ] Can pick and upload image
- [ ] Image compressed to 80% quality
- [ ] File uploaded to Supabase storage
- [ ] Profile updated with image URL
- [ ] UI shows uploaded status
- [ ] Can skip verification
- [ ] Badge appears when 2+ docs verified
- [ ] Error handling works for failed uploads
- [ ] RLS policies prevent unauthorized access

## Performance Tips

1. **Image Compression**
   - Set to 80% quality to reduce file size
   - Typical: 500KB → 100KB per image

2. **Batch Updates**
   - Update profile after each upload
   - Don't defer updates

3. **Caching**
   - ProfileRepository caches profile data
   - Call `ProfileRepository.instance.loadProfile()` to refresh

4. **Error Recovery**
   - Check internet before upload
   - Retry failed uploads
   - Show clear error messages

## Common Issues & Fixes

| Issue | Solution |
|-------|----------|
| "Upload failed" | Check Supabase storage bucket exists |
| "RLS policy error" | Verify RLS policies are created |
| "No image selected" | User cancelled image picker - handle gracefully |
| "Profile not updating" | Reload profile: `loadProfile(userId)` |
| "Badge not showing" | Requires 2 verified docs, check verification status |

## Key Constants

```dart
// Verification badge requires this many verified docs
final requiredDocsForBadge = 2;

// Image quality (0-100)
final imageQuality = 80;

// Total document types
final totalDocuments = 5; // RC, Insurance, DL, National ID, Tax ID

// Premium plans that can access verification
final premiumPlans = ['premium', 'expert'];
```

## Widget Tree

```
VerificationDocumentsScreen
├── AppBar
├── SingleChildScrollView
│   └── Column
│       ├── _buildHeaderCard()
│       │   └── Gradient container with explanation
│       ├── _buildStatusBadge()
│       │   └── Progress indicator
│       ├── Document List
│       │   └── _buildDocumentCard() × 5
│       │       ├── Icon
│       │       ├── Title & Status Badge
│       │       ├── Subtitle & Hint
│       │       ├── Upload Status
│       │       └── Benefit Badge
│       └── Action Buttons
│           ├── Save & Continue
│           └── Skip for Now
```

## Key Files

| File | Purpose | Size |
|------|---------|------|
| `verification_documents_screen.dart` | Main UI widget | 250 lines |
| `verification_service.dart` | Business logic | 200 lines |
| `VERIFICATION_INTEGRATION_GUIDE.md` | Setup guide | 300 lines |
| `VERIFICATION_SUMMARY.md` | Overview | 250 lines |

---

**Last Updated**: August 9, 2026
**Version**: 1.0.0
**Status**: ✅ Production Ready
