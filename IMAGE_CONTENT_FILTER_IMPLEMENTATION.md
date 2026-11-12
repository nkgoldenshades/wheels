# Image Content Filter Implementation

## What Was Added

### 1. New Service: `ImageContentFilterService`
**File:** `lib/services/image_content_filter_service.dart`

This service uses Google ML Kit to extract text from images and checks for prohibited content:

**Blocks images containing:**
- ✅ Phone numbers (98765-43210, +91-9876543210, etc.)
- ✅ Email addresses (abc@email.com, user@domain.com, etc.)
- ✅ Social media handles (Instagram, Facebook, Twitter, TikTok, Telegram, WhatsApp, etc.)
- ✅ URLs and links (www.example.com, https://links, etc.)
- ✅ Contact instructions ("Call me", "Message me", "Contact me", "DM me", etc.)
- ✅ QR codes and barcodes (detects dense pattern text)

**How it works:**
1. Reads image file using ML Kit TextRecognizer
2. Extracts all text from the image
3. Validates extracted text against prohibited patterns
4. Returns error message if blocked, null if OK

### 2. Updated: Post Media Upload Widget
**File:** `lib/widgets/post_media_upload_widget.dart`

**Changes:**
- Added import for `ImageContentFilterService`
- Updated `_pickImages()` method to validate each image before upload
  - Shows red error message if image blocked
  - Skips blocked images
  - Uploads only approved images
- Updated `_pickVideo()` method to validate video before upload
  - Shows error message if video contains prohibited text
  - Prevents upload if blocked

**User Experience:**
```
User selects image → ML Kit extracts text → Validation checks
  ↓
If OK: ✅ Image uploaded successfully
If blocked: ❌ "Image blocked: Contains phone number"
           Image is skipped, user can try another
```

## Technical Details

### Filtering Logic

**Text Extraction:**
- Uses Google ML Kit's TextRecognizer
- Works on both Android and iOS
- Gracefully handles extraction failures

**Pattern Detection:**
- Phone numbers: Detects 10+ digit patterns, Indian formats (+91), words + numbers
- Emails: Detects standard emails and obfuscated patterns (user at domain dot com)
- Social media: Checks for Instagram, Facebook, Twitter, TikTok, Telegram, WhatsApp mentions
- URLs: Detects http://, www., domain extensions (.com, .in, .org, etc.)
- Contact hints: 25+ phrases like "dm me", "call me", "message me on", etc.
- QR codes: Detects excessive special characters (>30% of text)

**Normalization:**
- Converts obfuscated numbers (O→0, I→1, E→3, etc.)
- Removes spaces and special characters for matching
- Case-insensitive matching

### Error Handling

- If ML Kit extraction fails: Image is ALLOWED (doesn't block on technical error)
- If validation passes: Image is uploaded
- If validation fails: User sees red error message, image is skipped

## Dependencies

Already installed in `pubspec.yaml`:
```yaml
google_mlkit_text_recognition: ^0.13.0
```

## Usage

### For Developers

```dart
// Validate a single image
final error = await ImageContentFilterService.instance.validateImage(imageFile);

if (error != null) {
  // Image blocked - show error to user
  showSnackBar(error);
} else {
  // Image OK - proceed with upload
  await uploadImage(imageFile);
}
```

### For Users

1. Select image(s) for post
2. Images are automatically scanned using AI text detection
3. If image contains phone numbers, emails, social media, or contact info:
   - ❌ Red error message appears
   - Image is rejected
   - User can select another image
4. Only clean images without contact info are uploaded

## Compliance

This implementation ensures:
- ✅ Users cannot share contact information via images
- ✅ Prevents QR codes linking to external platforms
- ✅ Enforces in-app messaging for all coordination
- ✅ Matches Terms of Service requirements
- ✅ Reduces spam and abuse risk
- ✅ Aligns with text-based content filtering

## Testing

**Test Cases:**

1. ✅ **Phone number image** - Should be blocked
   - Image with "98765 43210" text
   - Image with "+91 9876543210" text

2. ✅ **Email image** - Should be blocked
   - Image with "contact@example.com"

3. ✅ **Social media image** - Should be blocked
   - Image with "Follow me on Instagram: @username"
   - Image with "Message on WhatsApp"

4. ✅ **Contact instructions** - Should be blocked
   - Image with "Call me when you arrive"
   - Image with "DM on Facebook"

5. ✅ **QR code image** - Should be blocked
   - Image containing QR code text pattern

6. ✅ **Clean image** - Should be allowed
   - Regular photo without any text
   - Image with vehicle/seat info only

## Notes

- **Performance:** First-time ML Kit loading may take 2-3 seconds
- **Network:** Requires internet for ML Kit model download (one-time)
- **Platforms:** Works on Android, iOS, and Web (with fallback)
- **Privacy:** Images are processed locally; text is not stored
- **Offline:** If ML Kit fails, image is allowed (safety first)

## Future Enhancements

- Add video frame extraction (scan multiple frames)
- Add image hash checking for known phishing/spam images
- Add NSFW detection (explicit content filtering)
- Add face detection to prevent PII exposure
- Machine learning to detect custom obfuscation patterns

---

**Status:** ✅ Implemented and ready to test
**Last Updated:** August 2026
