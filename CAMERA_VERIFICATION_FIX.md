# Camera Verification Fix

## Issue
Camera verification was not detecting faces properly or progressing through liveness detection steps.

## Root Causes

### 1. Incorrect Camera Rotation
The camera image rotation was hardcoded to `rotation0deg`, which doesn't work correctly for front-facing cameras on Android devices. Front cameras typically need 270° rotation for proper face detection.

### 2. Strict Detection Thresholds
The original thresholds were too strict:
- Required 3 consecutive detections per step
- Head rotation needed >15° (too much)
- Smile confidence needed >70%

## Fixes Applied

### 1. Dynamic Camera Rotation
Updated `_convertCameraImage()` in both verification screens to detect camera direction and apply correct rotation:

```dart
// Front camera - typically 270deg on Android
if (camera.lensDirection == CameraLensDirection.front) {
  imageRotation = InputImageRotation.rotation270deg;
} else {
  // Back camera - typically 90deg on Android
  imageRotation = InputImageRotation.rotation90deg;
}
```

### 2. Relaxed Detection Thresholds
- Reduced required detections: 3 → 2
- Reduced head rotation angle: 15° → 10°
- Reduced smile confidence: 70% → 60%

### 3. Real-time Debug Feedback
Added debug messages showing:
- Current head angle when turning
- Smile percentage when smiling
- Clear status messages for each step

## Files Modified

1. `lib/screens/verification/document_verification_screen.dart`
   - Fixed camera rotation
   - Added debug feedback
   - Relaxed thresholds

2. `lib/screens/verification/profile_photo_verification_screen.dart`
   - Fixed camera rotation
   - Added debug feedback
   - Relaxed thresholds

## Testing

### Expected Behavior:
1. **Step 1 - Detect Face**: Should complete quickly when face is visible
2. **Step 2 - Turn Left**: Shows angle in real-time, completes at >10°
3. **Step 3 - Turn Right**: Shows angle in real-time, completes at <-10°
4. **Step 4 - Hold Document/Smile**: 
   - Document verification: Just needs face present
   - Profile photo: Shows smile percentage, completes at >60%
5. **Step 5 - Capturing**: Automatically captures and processes

### Debug Messages:
- "No face detected" - Move face into frame
- "Angle: X.X° (need >10°)" - Turn head more left
- "Angle: X.X° (need <-10°)" - Turn head more right
- "Smile: XX% (need >60%)" - Smile wider
- "Face detected ✓" - Step completed
- "Ready to capture ✓" - Ready for photo

### Visual Indicators:
- Green border appears when conditions are met
- Progress counter shows X/2 detections
- Step dots show progress through verification
- Instructions update for each step

## Why This Works

1. **Correct Rotation**: ML Kit can now properly detect faces and facial landmarks
2. **Easier Thresholds**: More forgiving angles make it easier to complete steps
3. **Real-time Feedback**: Users can see exactly what the camera detects
4. **Fewer Required Detections**: Faster progression through steps

## Known Limitations

1. **Device-Specific Rotation**: Some devices may need different rotation angles
2. **Lighting Conditions**: Poor lighting can affect face detection
3. **Camera Quality**: Lower quality cameras may struggle with detection
4. **ML Kit Accuracy**: Head angle detection may vary by device

## Future Improvements

1. Auto-detect optimal rotation based on face detection success
2. Add lighting quality indicator
3. Add face position guidance (too close/far, off-center)
4. Adaptive thresholds based on device capabilities
5. Fallback to simpler verification if ML Kit fails

## Status

✅ Camera rotation fixed for both verification screens
✅ Thresholds relaxed for better UX
✅ Debug feedback added
✅ Ready for testing on real device

Test the verification flow and adjust thresholds if needed based on real-world usage.
