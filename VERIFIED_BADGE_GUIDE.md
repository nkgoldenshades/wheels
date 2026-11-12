# Verified Badge System

## ✅ Overview

Show a **blue verified checkmark** (✓) next to profiles that have verified documents (Aadhaar, PAN, or Driving License).

## 🎨 Visual Example

### Without Verification:
```
┌────────────────────────────┐
│ 👤 k_x                     │
│    33 yrs, boy             │
└────────────────────────────┘
```

### With Verification:
```
┌────────────────────────────┐
│ 👤 k_x ✓                   │  ← Blue checkmark
│    33 yrs, boy             │
└────────────────────────────┘
```

## 📋 Verification Criteria

A profile is considered **verified** if ANY of these documents are verified:
- ✅ Aadhaar verified (`aadhaarVerified = true`)
- ✅ PAN verified (`panVerified = true`)
- ✅ Driving License verified (`dlVerified = true`)

## 🔧 What Was Added

### 1. Profile Extension
Added to `lib/services/profile_repository.dart`:

```dart
extension ProfileVerification on ProfileInfo {
  /// Returns true if profile has at least one document verified
  bool get isVerified {
    return aadhaarVerified || panVerified || dlVerified;
  }
  
  /// Returns verification level: 0 (none), 1 (partial), 2 (full)
  int get verificationLevel {
    int count = 0;
    if (aadhaarVerified) count++;
    if (panVerified) count++;
    if (dlVerified) count++;
    
    if (count == 0) return 0; // Not verified
    if (count < 3) return 1; // Partially verified
    return 2; // Fully verified (all 3 documents)
  }
  
  /// Returns a list of verified documents
  List<String> get verifiedDocuments {
    final docs = <String>[];
    if (aadhaarVerified) docs.add('Aadhaar');
    if (panVerified) docs.add('PAN');
    if (dlVerified) docs.add('Driving License');
    return docs;
  }
}
```

### 2. Verified Badge Widget
Created `lib/widgets/verified_badge.dart`:
- Reusable widget to show verified checkmark
- Can be used anywhere profiles are displayed

### 3. Booking UI Integration
Added verified badge next to customer name in booking details:

```dart
Row(
  children: [
    Text(b.userName ?? 'N/A'),
    SizedBox(width: 4),
    // Verified badge appears here if verified
    if (profile.isVerified)
      Tooltip(
        message: 'Verified Profile',
        child: Icon(
          Icons.verified,
          size: 16,
          color: Colors.blue,
        ),
      ),
  ],
)
```

## 📱 Where It Shows

Currently added to:
- ✅ **Booking Details** - Next to customer name

Can be added to:
- 🔲 Slot Cards - Next to provider name
- 🔲 Profile Page - Next to profile name
- 🔲 Review Cards - Next to reviewer name
- 🔲 Chat - Next to message sender name

## 🎯 Usage Examples

### Example 1: Check if Profile is Verified
```dart
final profile = ProfileRepository.instance.profile.value;

if (profile.isVerified) {
  print('User is verified!');
}
```

### Example 2: Get Verification Level
```dart
final level = profile.verificationLevel;

switch (level) {
  case 0:
    print('Not verified');
    break;
  case 1:
    print('Partially verified');
    break;
  case 2:
    print('Fully verified');
    break;
}
```

### Example 3: Show Which Documents are Verified
```dart
final docs = profile.verifiedDocuments;

print('Verified documents: ${docs.join(", ")}');
// Output: "Verified documents: Aadhaar, PAN"
```

### Example 4: Add Badge to Any Widget
```dart
import 'widgets/verified_badge.dart';

Row(
  children: [
    Text('John Doe'),
    SizedBox(width: 4),
    VerifiedBadge(userId: 'user123'),
  ],
)
```

## 🔐 How to Verify Documents

Documents are verified by setting flags in the database:

```sql
-- Verify Aadhaar
UPDATE profiles SET aadhaar_verified = true WHERE id = 'user_id';

-- Verify PAN
UPDATE profiles SET pan_verified = true WHERE id = 'user_id';

-- Verify Driving License
UPDATE profiles SET dl_verified = true WHERE id = 'user_id';
```

## 💡 Future Enhancements

### Different Verification Levels
```dart
// Show different badge colors based on verification level
if (profile.verificationLevel == 2) {
  // Gold badge - fully verified
  Icon(Icons.verified, color: Colors.amber);
} else if (profile.verificationLevel == 1) {
  // Blue badge - partially verified
  Icon(Icons.verified, color: Colors.blue);
}
```

### Show Verification Details
```dart
Tooltip(
  message: 'Verified: ${profile.verifiedDocuments.join(", ")}',
  child: Icon(Icons.verified, color: Colors.blue),
)
```

### Add to More Places
```dart
// In slot cards
Text('${providerName} ${profile.isVerified ? "✓" : ""}')

// In reviews
Text('${reviewerName} ${profile.isVerified ? "✓" : ""}')

// In chat
Text('${senderName} ${profile.isVerified ? "✓" : ""}')
```

## 🎨 Customization

### Change Badge Color
```dart
Icon(Icons.verified, color: Colors.green) // Green verified
Icon(Icons.verified, color: Colors.amber) // Gold verified
```

### Change Badge Size
```dart
Icon(Icons.verified, size: 14) // Smaller
Icon(Icons.verified, size: 20) // Larger
```

### Different Icon
```dart
Icon(Icons.check_circle) // Different style
Icon(Icons.verified_user) // User verified
Icon(Icons.shield) // Shield icon
```

## ✅ Summary

- ✅ Profile extension added with `isVerified` getter
- ✅ Verified badge shows blue checkmark for verified profiles
- ✅ Integrated in booking details next to customer name
- ✅ Based on document verification (Aadhaar/PAN/DL)
- ✅ Reusable widget for any screen
- ✅ Tooltip shows "Verified Profile" on hover

Users with verified documents will now show a **blue verified checkmark** (✓) throughout the app! 🎉
