# Quick Reference Guide

## How to Use the Features

### 1. Profile Photo Verification

**Steps:**
1. Go to Account Settings
2. Tap the edit button on profile photo
3. Select photo from gallery
4. Confirm the photo in preview dialog
5. Follow on-screen instructions:
   - Show your face
   - Turn left
   - Turn right
   - Smile
6. Wait for face matching (70% threshold)
7. ✅ Success: Photo saved | ❌ Failed: Retry option shown

**Location:** Account Settings → Profile Photo → Edit button

---

### 2. Document Verification

**Steps:**
1. Go to Vehicle Actions Screen
2. Scroll to "Document Verification" card
3. Tap "Verify" button on any document
4. Select document photo from gallery
5. Confirm the document in preview dialog
6. **For documents with face (PAN, Aadhaar, DL):**
   - Follow liveness detection steps
   - Face matching with document photo
7. **For documents without face (RC, Insurance):**
   - Direct save (no liveness check)

**Location:** Vehicle Actions → Document Verification section

**Document Types:**
- **Mandatory:** RC Book, Insurance (required by law)
- **Optional:** Driving License, Aadhaar, PAN (increases trust)

---

### 3. GPS Location Settings

**Steps:**
1. Go to Vehicle Actions Screen
2. Scroll to "GPS Settings" card
3. Select GPS mode:
   - **Device Live:** Real-time GPS from device
   - **External Link:** Third-party GPS tracker URL
   - **Manual:** Manual coordinate entry

**For Manual Mode:**
1. Select "Manual" from dropdown
2. Option A: Tap "Get Current Location" button
   - Grants location permission
   - Auto-fills latitude and longitude
3. Option B: Enter coordinates manually
   - Latitude: -90 to 90
   - Longitude: -180 to 180
4. Tap "Save GPS Settings"

**Location:** Vehicle Actions → GPS Settings section

---

## Important Notes

### ML Kit Face Detection
- ⚠️ Only works on real devices, not emulators
- Requires good lighting
- Face should be clearly visible
- Remove glasses/mask if possible

### Face Matching Threshold
- 70% match required (industry standard)
- Used by Uber, banking apps, KYC platforms
- Prevents fake photos and identity fraud

### Location Permissions
- Required for "Get Current Location" feature
- High-accuracy GPS (within 10 meters)
- 10-second timeout for location request

---

## Testing on Real Device

### Prerequisites:
1. Real Android device (not emulator)
2. Camera permission granted
3. Location permission granted (for GPS feature)
4. Good lighting for face detection

### Test Sequence:
1. Profile photo verification
2. Document verification (PAN, Aadhaar, DL)
3. Document upload (RC, Insurance)
4. GPS location feature

---

## Troubleshooting

### Face Detection Not Working
- ✅ Use real device (not emulator)
- ✅ Ensure good lighting
- ✅ Face camera directly
- ✅ Remove glasses/mask

### Face Matching Failed
- ✅ Use clear, recent photo
- ✅ Same lighting conditions
- ✅ Same facial expression
- ✅ No glasses/mask difference

### Location Not Working
- ✅ Grant location permission
- ✅ Enable GPS on device
- ✅ Go outdoors for better signal
- ✅ Wait 10 seconds for GPS lock

---

## File Locations

### Verification Screens:
- `lib/screens/verification/profile_photo_verification_screen.dart`
- `lib/screens/verification/document_verification_screen.dart`
- `lib/screens/verification/web_camera_verification_screen.dart`

### Main Functions:
- `lib/main.dart` - `_pickAndSaveAvatar()`, `_uploadDocument()`
- `lib/screens/vehicle/vehicle_actions_screen.dart` - `_getCurrentLocation()`, `_saveGpsSettings()`

### Services:
- `lib/services/face_matching_service.dart` - Face matching logic
- `lib/services/profile_repository.dart` - Profile data management
- `lib/services/user_vehicle_repository.dart` - Vehicle data management

---

## Summary

All features are correctly implemented and ready for testing on a real Android device. The verification system follows industry standards with 2-step verification (upload → verify) and 70% face matching threshold.
