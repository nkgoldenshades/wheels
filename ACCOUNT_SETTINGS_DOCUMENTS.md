# Account Settings Document Upload

## ✅ What's Added

Added document upload cards in Account Settings for Aadhaar, PAN, and Driving License with liveness verification.

## 📍 Location

**Account Settings Screen** (Profile tab → Account Settings)

After the text input fields for Aadhaar number and PAN number, you'll now see upload cards for each document.

## 🎯 Features

### Document Upload Cards

1. **Aadhaar Card**
   - Upload Front button
   - Upload Back button
   - Icon: Credit card
   - Subtitle: "Upload front and back"

2. **PAN Card**
   - Upload Front button (single image)
   - Icon: Badge
   - Subtitle: "Upload PAN card image"

3. **Driving License**
   - Upload Front button
   - Upload Back button
   - Icon: Car
   - Subtitle: "Upload front and back"

### Upload Options

When user clicks any upload button, they get two options:

```
Upload AADHAAR (front)
─────────────────────────
✓ Live Verification
  Recommended - With liveness detection
  [VERIFIED]

📷 Choose from Gallery
  Upload existing photo
```

## 🔒 Verification Flow

### Live Verification (Recommended)
1. User clicks "Upload Front" or "Upload Back"
2. Selects "Live Verification"
3. Opens DocumentVerificationScreen with liveness detection:
   - Step 1: Detect face
   - Step 2: Turn head LEFT
   - Step 3: Turn head RIGHT
   - Step 4: Hold document
4. Auto-captures photo
5. Success message: "AADHAAR (front) verified with liveness detection! ✓"

### Gallery Upload
1. User clicks "Upload Front" or "Upload Back"
2. Selects "Choose from Gallery"
3. Standard image picker opens
4. User selects existing photo
5. Success message: "AADHAAR (front) uploaded successfully!"

## 🎨 UI Design

### Document Card Layout
```
┌─────────────────────────────────────┐
│ 🎫 Aadhaar Card                     │
│    Upload front and back            │
│                                     │
│ [Upload Front]  [Upload Back]      │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 🎖️ PAN Card                         │
│    Upload PAN card image            │
│                                     │
│ [Upload Front]                      │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 🚗 Driving License                  │
│    Upload front and back            │
│                                     │
│ [Upload Front]  [Upload Back]      │
└─────────────────────────────────────┘
```

### Account Settings Flow
```
Account Settings
─────────────────
Name: [John Doe]
Contact number: [+91 1234567890]

Aadhaar number: [1234 5678 9012]
[Aadhaar Card Upload Card]

PAN number: [ABCDE1234F]
[PAN Card Upload Card]

[Driving License Upload Card]

Currency: [INR (₹)]
Preferred country: [India]
```

## 💾 Data Storage

Currently, the uploaded documents are:
- Captured with liveness verification
- Converted to bytes
- Logged to console (for testing)

### TODO: Production Implementation
```dart
// Save to ProfileRepository
final base64Image = base64Encode(bytes);
await ProfileRepository.instance.saveDocument(
  documentType,  // 'aadhaar', 'pan', 'dl'
  side,          // 'front', 'back'
  base64Image,
);
```

## 🔧 Technical Implementation

### Files Modified
- `lib/main.dart`
  - Added `_buildDocumentUploadCard()` widget
  - Added `_uploadDocument()` function
  - Added document upload cards in Account Settings
  - Imported `DocumentVerificationScreen`

### Functions Added

1. **_buildDocumentUploadCard()**
   - Creates card UI for each document type
   - Shows title, subtitle, icon
   - Renders upload buttons (front/back)

2. **_uploadDocument()**
   - Shows upload options modal
   - Handles live verification flow
   - Handles gallery upload flow
   - Shows success/error messages

## 📱 User Experience

### Before Upload
```
Account Settings
─────────────────
Aadhaar number: [1234 5678 9012]

┌─────────────────────────────────────┐
│ 🎫 Aadhaar Card                     │
│    Upload front and back            │
│                                     │
│ [Upload Front]  [Upload Back]      │
└─────────────────────────────────────┘
```

### During Upload
```
Upload AADHAAR (front)
─────────────────────────
✓ Live Verification        [VERIFIED]
  Recommended - With liveness detection

📷 Choose from Gallery
  Upload existing photo
```

### After Upload (Live Verification)
```
✅ AADHAAR (front) verified with liveness detection! ✓
```

### After Upload (Gallery)
```
✅ AADHAAR (front) uploaded successfully!
```

## 🎯 Benefits

### For Users
- Easy document upload in one place
- Liveness verification prevents fake documents
- Can upload both front and back sides
- Clear visual feedback

### For Platform
- All documents in Account Settings
- Verified documents increase trust
- Reduces fraud
- Better compliance

## 🚀 Testing Instructions

### On Real Device
```bash
flutter run
```

### Test Flow
1. Go to **Profile** tab
2. Tap **Account Settings**
3. Scroll down to document cards
4. Tap **"Upload Front"** on Aadhaar Card
5. Select **"Live Verification"**
6. Follow liveness detection steps
7. See success message
8. Repeat for:
   - Aadhaar Back
   - PAN Front
   - DL Front
   - DL Back

## 💡 Next Steps (Production)

### 1. Add to ProfileInfo Model
```dart
class ProfileInfo {
  // ... existing fields
  
  // Document images (Base64)
  final String? aadhaarFront;
  final String? aadhaarBack;
  final String? panFront;
  final String? dlFront;
  final String? dlBack;
  
  // Verification status
  final bool aadhaarVerified;
  final bool panVerified;
  final bool dlVerified;
  
  // Verification timestamps
  final DateTime? aadhaarVerifiedAt;
  final DateTime? panVerifiedAt;
  final DateTime? dlVerifiedAt;
}
```

### 2. Update ProfileRepository
```dart
class ProfileRepository {
  Future<void> saveDocument(
    String documentType,
    String side,
    String base64Image,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'document_${documentType}_$side';
    await prefs.setString(key, base64Image);
  }
  
  String? getDocument(String documentType, String side) {
    final prefs = SharedPreferences.getInstance();
    final key = 'document_${documentType}_$side';
    return prefs.getString(key);
  }
}
```

### 3. Show Uploaded Documents
Add preview thumbnails in the upload cards:
```dart
if (hasUploadedFront) {
  // Show thumbnail with "Change" button
  Image.memory(base64Decode(frontImage), height: 100)
} else {
  // Show upload button
  OutlinedButton.icon(...)
}
```

### 4. Add Verification Badges
Show verified badge when document is verified:
```dart
if (aadhaarVerified) {
  Row(
    children: [
      Text('Aadhaar Card'),
      Icon(Icons.verified, color: Colors.green, size: 16),
    ],
  )
}
```

## 🎉 Ready to Test!

Document upload cards are now live in Account Settings. Test the liveness verification flow for each document type!

Users can now upload:
- Aadhaar (front + back) ✅
- PAN (front) ✅
- Driving License (front + back) ✅

All with optional liveness verification for maximum security!
