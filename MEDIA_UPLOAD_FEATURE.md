# Vehicle Media Upload Feature

## Overview
Added comprehensive media upload functionality to the Add Vehicle screen with automatic verification.

## Features Added

### 1. Profile Image (DP) Section
- **Purpose**: Main display picture for the vehicle
- **Format**: JPEG, PNG
- **Max Size**: 5MB
- **Verification**: Automatic format and size validation
- **Status**: Shows verified checkmark when validated

### 2. Gallery Images Section
- **Purpose**: Additional vehicle photos
- **Limit**: Up to 5 images
- **Format**: JPEG, PNG
- **Max Size**: 5MB per image
- **Features**:
  - Horizontal scrollable preview
  - Individual delete buttons
  - Verification status per image
  - Add more until limit reached

### 3. Video Section
- **Purpose**: Optional video showcase
- **Duration**: Max 30 seconds
- **Max Size**: 10MB
- **Format**: MP4, MOV
- **Verification**: Automatic format and size validation

## UI/UX Design

### Card-Based Layout
Each media type is presented in a clean card with:
- Icon and title
- Descriptive subtitle
- Verification status indicator
- Preview area
- Action buttons (Add/Change/Remove)

### Verification Indicators
- ✅ Green checkmark: Verified and ready
- 🟠 Orange pending: Uploaded but not verified
- No indicator: Not uploaded

### Preview Features
- **Profile Image**: Full-width preview (150px height)
- **Gallery**: Horizontal scrollable thumbnails (100x100px)
- **Video**: Placeholder with play icon

## Validation Rules

### Image Validation
```dart
- Minimum size: 1KB
- Maximum size: 5MB
- Valid formats: JPEG (FF D8), PNG (89 50 4E 47)
- Automatic compression: 1024x1024px, 85% quality
```

### Video Validation
```dart
- Minimum size: 10KB
- Maximum size: 10MB
- Maximum duration: 30 seconds
- Valid formats: MP4 (ftyp header)
```

### Save Validation
Before saving, the form checks:
1. Profile image is uploaded ✅
2. Profile image is verified ✅
3. All gallery images are verified ✅
4. Video is verified (if uploaded) ✅

## User Flow

### Adding Profile Image
1. Tap "Add" button in Profile Image section
2. Select image from gallery
3. Image is automatically compressed
4. Verification runs (format + size check)
5. If valid: Shows preview + green checkmark
6. If invalid: Shows error message

### Adding Gallery Images
1. Tap "Add" button in Gallery section
2. Select image from gallery
3. Image is automatically compressed
4. Verification runs
5. If valid: Added to horizontal scroll list
6. Can add up to 5 images total
7. Each image has delete button (X)

### Adding Video
1. Tap "Add" button in Video section
2. Select video from gallery (max 30 seconds)
3. Size check runs (max 10MB)
4. Format verification runs
5. If valid: Shows video placeholder
6. If invalid: Shows error message

## Error Messages

### Image Errors
- "Image verification failed. Please upload a clear vehicle photo."
- "Image too large. Maximum size is 5MB."

### Video Errors
- "Video too large. Maximum size is 10MB."
- "Video verification failed. Please upload a clear vehicle video."

### Save Errors
- "Please add a profile image"
- "Profile image is not verified"
- "Some gallery images are not verified"
- "Video is not verified"

## Success Messages
- "Profile image verified successfully!" (Green)
- "Gallery image verified successfully!" (Green)
- "Video verified successfully!" (Green)

## Technical Implementation

### Image Picker Configuration
```dart
final XFile? image = await _picker.pickImage(
  source: ImageSource.gallery,
  maxWidth: 1024,
  maxHeight: 1024,
  imageQuality: 85,
);
```

### Video Picker Configuration
```dart
final XFile? video = await _picker.pickVideo(
  source: ImageSource.gallery,
  maxDuration: const Duration(seconds: 30),
);
```

### Storage Format
- All media stored as Base64 strings
- Profile image: `String?`
- Gallery images: `List<String>`
- Video: `String?`

### Verification Functions
- `_verifyImageContent(Uint8List bytes)`: Checks image format and size
- `_verifyVideoContent(Uint8List bytes)`: Checks video format and size

## Database Integration

### Vehicle Model Fields
```dart
final String? profileImage;      // Base64 encoded
final List<String> galleryImages; // Base64 encoded list
final String? videoUrl;           // Base64 encoded
```

### Supabase Schema
```sql
profile_image TEXT,
gallery_images TEXT[] DEFAULT '{}',
video_url TEXT,
```

## Future Enhancements

### Potential Improvements
1. **Cloud Storage**: Upload to Supabase Storage instead of Base64
2. **Advanced Verification**: AI-based content moderation
3. **Image Editing**: Crop, rotate, filters
4. **Video Trimming**: Allow users to trim videos
5. **Progress Indicators**: Show upload progress
6. **Thumbnail Generation**: Auto-generate video thumbnails
7. **Multiple Selection**: Pick multiple gallery images at once

### AI Content Moderation (Future)
```dart
// Example integration with content moderation API
Future<bool> _moderateImage(Uint8List bytes) async {
  final response = await http.post(
    Uri.parse('https://api.moderationcontent.com/v1/check'),
    body: base64Encode(bytes),
  );
  return response.statusCode == 200;
}
```

## Testing Checklist

### Profile Image
- [ ] Upload valid JPEG image
- [ ] Upload valid PNG image
- [ ] Try uploading file > 5MB (should fail)
- [ ] Try uploading non-image file (should fail)
- [ ] Change profile image
- [ ] Remove profile image
- [ ] Try saving without profile image (should fail)

### Gallery Images
- [ ] Add 1 gallery image
- [ ] Add 5 gallery images (max)
- [ ] Try adding 6th image (button should be disabled)
- [ ] Delete individual gallery images
- [ ] Try uploading invalid image (should fail)

### Video
- [ ] Upload valid MP4 video
- [ ] Try uploading video > 10MB (should fail)
- [ ] Try uploading video > 30 seconds (should be trimmed)
- [ ] Remove video
- [ ] Save vehicle without video (should work)

### Overall Flow
- [ ] Create vehicle with all media
- [ ] Verify all media shows verified checkmarks
- [ ] Save vehicle successfully
- [ ] View vehicle in list (should show profile image)
- [ ] View vehicle details (should show all media)

## Dependencies

### Required Packages
```yaml
dependencies:
  image_picker: ^1.1.2  # Already installed ✅
```

### Permissions Required

#### Android (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

#### iOS (ios/Runner/Info.plist)
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to upload vehicle images</string>
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take vehicle photos</string>
```

## Summary

The vehicle media upload feature is now complete with:
- ✅ Profile image upload with verification
- ✅ Gallery images (up to 5) with verification
- ✅ Video upload with verification
- ✅ Clean card-based UI
- ✅ Automatic compression and validation
- ✅ Clear error and success messages
- ✅ Preview functionality
- ✅ Individual delete options

All uploaded media is verified before saving, ensuring quality and preventing invalid uploads.
