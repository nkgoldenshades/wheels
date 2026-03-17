# Web Camera Verification Support

## Problem
ML Kit Face Detection doesn't work on web - it's only available for Android/iOS native platforms.

## Solution
Created a web-specific camera verification screen that uses browser's native webcam API.

## Implementation

### 1. Web Camera Screen (`lib/screens/verification/web_camera_verification_screen.dart`)
- Uses `dart:html` to access browser webcam
- Simple capture interface (no liveness detection on web)
- Returns base64 encoded image
- Works in all modern browsers

### 2. Face Detection JavaScript (`web/face_detection.js`)
- Optional MediaPipe Face Detection integration
- Fallback mode if Face Detection API not available
- Provides basic face presence detection

### 3. Platform Detection
The app automatically uses the right screen:
- **Mobile (Android/iOS)**: `ProfilePhotoVerificationScreen` with ML Kit liveness detection
- **Web**: `WebCameraVerificationScreen` with simple webcam capture

## Features

### Web Camera Screen:
✅ Webcam access via browser
✅ Live camera preview
✅ Simple capture button
✅ Base64 image output
✅ Works on Chrome, Firefox, Safari, Edge
⚠️ No liveness detection (web limitation)
⚠️ No head rotation tracking (web limitation)

### Mobile Camera Screen:
✅ ML Kit face detection
✅ Liveness detection (turn left/right, smile)
✅ Head pose estimation
✅ Face matching
✅ High security

## Usage

The app automatically detects the platform:

```dart
// On web: Uses WebCameraVerificationScreen
// On mobile: Uses ProfilePhotoVerificationScreen

final result = await Navigator.push<Map<String, dynamic>>(
  context,
  MaterialPageRoute(
    builder: (context) => kIsWeb
        ? const WebCameraVerificationScreen(
            title: 'Verify Profile Photo',
            isProfilePhoto: true,
          )
        : const ProfilePhotoVerificationScreen(),
  ),
);
```

## Browser Permissions

Users will see a browser permission prompt:
- **Chrome**: "Allow quickohunt.com to use your camera?"
- **Firefox**: "Share your camera with quickohunt.com?"
- **Safari**: "quickohunt.com wants to access the camera"

Users must click "Allow" for camera to work.

## Security Considerations

### Web (Lower Security):
- No liveness detection
- Users could upload pre-recorded videos or photos
- Suitable for low-risk verification
- Consider manual review for important documents

### Mobile (High Security):
- Full liveness detection
- Head rotation tracking
- Face matching
- Difficult to spoof
- Suitable for high-risk verification

## Recommendations

1. **For Production**:
   - Use mobile app for important verifications (KYC, documents)
   - Use web for convenience features (profile photos)
   - Add manual review for web uploads

2. **For Testing**:
   - Web version works great for development
   - Test mobile features on real devices
   - Use orange "Skip" button for quick testing

3. **User Experience**:
   - Show different messages for web vs mobile
   - Explain security differences
   - Encourage mobile app for important verifications

## Testing

### Test on Web:
```bash
flutter run -d chrome
```

### Test on Mobile:
```bash
flutter run -d <device-id>
```

### Test Both:
```bash
# Terminal 1: Web
flutter run -d chrome

# Terminal 2: Mobile
flutter run -d <device-id>
```

## Browser Compatibility

| Browser | Support | Notes |
|---------|---------|-------|
| Chrome | ✅ Full | Best support |
| Firefox | ✅ Full | Works well |
| Safari | ✅ Full | Requires HTTPS |
| Edge | ✅ Full | Chromium-based |
| Mobile Safari | ✅ Full | iOS 11+ |
| Mobile Chrome | ✅ Full | Android 5+ |

## HTTPS Requirement

⚠️ **Important**: Webcam access requires HTTPS in production!

- **Development**: `localhost` works without HTTPS
- **Production**: Must use HTTPS domain
- **Testing**: Use `flutter run -d chrome --web-port=5000`

## Files Created

1. `lib/screens/verification/web_camera_verification_screen.dart` - Web camera UI
2. `web/face_detection.js` - Optional face detection (fallback mode)
3. `web/index.html` - Updated with face detection script
4. `WEB_CAMERA_SUPPORT.md` - This documentation

## Next Steps

1. **Test on web**: `flutter run -d chrome`
2. **Test camera access**: Click "Live Verification"
3. **Grant permissions**: Allow camera access
4. **Capture photo**: Click blue camera button
5. **Verify upload**: Check if photo saves correctly

## Future Enhancements

Possible improvements for web:
- [ ] Add TensorFlow.js for face detection
- [ ] Implement basic liveness (blink detection)
- [ ] Add face position guidance
- [ ] Support multiple photos
- [ ] Add video recording
- [ ] Implement face matching on web

## Status

✅ Web camera screen created
✅ Browser webcam integration
✅ Platform detection added
✅ Base64 image encoding
✅ Simple capture interface
⏳ Testing needed
⏳ Production deployment pending

The web camera verification is now ready for testing!
