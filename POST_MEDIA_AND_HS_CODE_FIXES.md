# Fixes Applied: HS Code Simplification + Post Media Upload

## Summary
This document outlines the fixes applied to simplify HS code UI and enable post media uploads.

---

## PART 1: HS CODE ADVANCED MODE SIMPLIFIED ✅

### Changes Made

**File: `lib/screens/add_flow/create_post_screen.dart`**

#### 1. Removed Complex State Variables
```dart
// REMOVED:
String _baseHSCode = '';           // Base 6-digit code
String _fromCountryCode = '';      // From country code range  
String _toCountryCode = '';        // To country code range

// KEPT:
String _hsCode = '';               // HS Code for customs classification
String _hsCodeMode = 'simple';     // 'simple' or 'advanced'
```

#### 2. Simplified Parcel Type Storage
- **Simple Mode**: `type:Normal` or `type:Normal|code:392310`
- **Advanced Mode**: Just the HS code number like `code:392310`

Storage format is now self-explanatory:
- Format starts with `type:` → it's simple mode
- Format starts with `code:` → it's advanced mode (educated users)

#### 3. Replaced Complex UI with Single Text Field
**Before**: 3 fields (Base Code + From range + To range)
**After**: 1 field (Enter HS Code)

```dart
// NEW Advanced Mode UI:
TextField(
  decoration: const InputDecoration(
    labelText: 'Enter HS Code',
    hintText: 'e.g., 39231000',
    prefixIcon: Icon(Icons.numbers),
  ),
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ],
  onChanged: (value) {
    setState(() => _hsCode = value.trim());
  },
)
```

### Result
✅ Advanced mode now just accepts a plain HS code number
✅ No unnecessary complexity for educated users
✅ Storage format is self-documenting (code prefix indicates source)
✅ Parsing in `seat_layout_builder_screen.dart` already handles this format

---

## PART 2: POST MEDIA UPLOAD FIX ⚠️ NEEDS SUPABASE RLS

### Problem
Post media uploads are failing because the `post_media` bucket lacks RLS policies.

### Solution: Add RLS Policies to Supabase

**Follow steps in: `SUPABASE_RLS_SETUP.md`**

You need to manually add 4 SQL policies to your `post_media` bucket:

1. **INSERT policy**: Allows users to upload to their own folder
2. **UPDATE policy**: Allows users to update their own files
3. **DELETE policy**: Allows users to delete their own files
4. **SELECT policy**: Allows public read access to media

### Code Changes for Better Debugging

**File: `lib/services/post_media_service.dart`**

Added detailed debug logging to help diagnose upload issues:

```dart
debugPrint('📤 Uploading image: ${imageFile.name}');
debugPrint('📦 Image size: ${(bytes.length / 1024).toStringAsFixed(2)} KB');
debugPrint('📍 Storage path: $fileName');
debugPrint('📥 Upload response: $response');
debugPrint('✅ Post image uploaded: $publicUrl');
```

**Same for videos:**
```dart
debugPrint('📹 Uploading video: ${videoFile.name}');
debugPrint('📦 Video size: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
```

### How to Test After RLS Setup

1. Open create post screen
2. Scroll to "📸 Post Media" section
3. Click "Add Images"
4. Select images from device
5. Watch for debug logs:
   - ✅ `Post image uploaded:` = Success
   - ❌ `Failed to upload post image:` = Check RLS policies

---

## HS Code Format Reference

### Simple Mode (Non-Educated Users)
User selects parcel type from dropdown, optionally enters HS code:

- Input: `Normal` + (optional) `392310`
- Storage: `type:Normal` or `type:Normal|code:392310`
- Parsing: Check if starts with `type:`

### Advanced Mode (Educated Users/Permitted)
User enters complete HS code directly:

- Input: User types `39231000` directly
- Storage: `code:39231000`
- Parsing: Check if starts with `code:`

### Storage Format Philosophy
The format itself tells you:
- Starts with `type:` → Simple mode (parcel type selected)
- Starts with `code:` → Advanced mode (user provided code directly)
- No need for labels or explanation text

---

## File Changes Summary

### Modified Files
1. **`lib/screens/add_flow/create_post_screen.dart`**
   - Removed: `_baseHSCode`, `_fromCountryCode`, `_toCountryCode` variables
   - Updated: Storage logic for advanced mode (just `code:xxxxxx`)
   - Replaced: Complex 3-field UI with simple single text field

2. **`lib/services/post_media_service.dart`**
   - Added: Detailed debug logging for uploads
   - Improved: Error diagnosis capability

### Files That Work Already (No Changes Needed)
- **`lib/screens/add_flow/seat_layout_builder_screen.dart`** - Already parses both formats correctly
- **`lib/widgets/post_media_upload_widget.dart`** - Upload widget works fine, just needs RLS policies
- **`lib/models/slot.dart`** - Stores parcelType correctly
- **`lib/models/user_post.dart`** - Stores parcelType correctly

---

## Next Steps

1. **Set up Supabase RLS** (Required for post media to work)
   - Go to Supabase dashboard
   - Navigate to Storage > post_media bucket
   - Add the 4 SQL policies from `SUPABASE_RLS_SETUP.md`
   
2. **Test Post Media Upload**
   - Create a post with images
   - Check that images upload successfully
   - Verify preview thumbnails appear
   
3. **Test HS Code Advanced Mode**
   - Create parcel post in advanced mode
   - Enter a HS code (e.g., `39231000`)
   - Verify it saves as `code:39231000`

---

## Important Notes

- **Image Compression**: Already set to quality 95 (high quality)
- **File Path Structure**: `{userId}/posts/{postId}/{timestamp}_{filename}`
- **Public Access**: Images are publicly viewable after upload
- **RLS Ownership**: Users can only upload to their own `{userId}` folder
- **Debugging**: Watch Flutter console for `✅` or `❌` messages during upload

---

## Troubleshooting

### Images won't upload?
Check:
1. User is logged in
2. RLS policies are added to `post_media` bucket
3. Bucket name is exactly `post_media`
4. Check Flutter console for error messages

### Preview not showing?
1. Image might be uploading still (check progress bar)
2. Check browser network tab for image load errors
3. Verify URL is being returned from upload
4. Check Supabase storage path exists

### HS Code not saving?
1. Make sure advanced mode is selected (toggle at top)
2. Enter a numeric HS code
3. Check that `_hsCode` variable is populated before posting
4. Verify storage format includes `code:` prefix
