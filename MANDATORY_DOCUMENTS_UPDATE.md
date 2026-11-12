# Mandatory Documents Update

## ✅ What Changed

Updated the document verification section to clearly separate mandatory and optional documents, with special handling for insurance expiry dates.

## 📋 Document Categories

### MANDATORY (Required by Law) 🔴
1. **RC Book** (Registration Certificate)
   - Proves vehicle ownership
   - Required by law
   - Red error icon if not verified
   - "REQUIRED" badge shown

2. **Insurance** (Vehicle Insurance)
   - Mandatory by law
   - Has expiry date tracking
   - Shows expiry status:
     - ✅ "Valid until [date]" (green) - More than 30 days left
     - ⚠️ "Expires soon: [date]" (orange) - Less than 30 days left
     - ❌ "Expired on [date]" (red) - Already expired
   - Button changes to "Renew" if expired
   - Red error icon if not verified or expired

### OPTIONAL (Increases Trust) 🔵
3. **Driving License**
   - Valid driving license
   - Increases user trust
   - Orange pending icon if not verified

4. **Aadhaar Card**
   - Identity verification
   - Increases user trust
   - Orange pending icon if not verified

5. **PAN Card**
   - Tax identification
   - Increases user trust
   - Orange pending icon if not verified

## 🎨 Visual Design

### Mandatory Section
- Red error icon (⚠️) in section header
- "MANDATORY (Required by Law)" label in red
- Red error icons for unverified documents
- Red "REQUIRED" badge on document titles
- Red outlined "Verify" buttons with thicker border

### Optional Section
- Blue info icon (ℹ️) in section header
- "OPTIONAL (Increases Trust)" label in blue
- Orange pending icons for unverified documents
- Standard outlined "Verify" buttons

### Insurance Expiry States
```
Not Verified:
  Icon: 🔴 Red error
  Status: "Vehicle Insurance - Mandatory by law"
  Button: "Verify" (red)

Verified & Valid (>30 days):
  Icon: ✅ Green verified
  Status: "Verified ✓"
  Expiry: "Valid until 15/05/2026" (green)
  Button: None

Expiring Soon (<30 days):
  Icon: ⚠️ Orange warning
  Status: "Verified ✓"
  Expiry: "Expires soon: 15/04/2026" (orange)
  Button: "Verify" (to renew)

Expired:
  Icon: 🔴 Red error
  Status: "Vehicle Insurance - Mandatory by law"
  Expiry: "Expired on 15/02/2026" (red)
  Button: "Renew" (red)
```

## 🔧 Technical Implementation

### New DocumentType
```dart
enum DocumentType {
  rc,        // Registration Certificate
  insurance, // Vehicle Insurance (NEW!)
  dl,        // Driving License
  aadhaar,   // Aadhaar Card
  pan,       // PAN Card
}
```

### New Widget Methods

1. **_buildDocumentItem()** - For documents without expiry
   - Added `isMandatory` parameter
   - Shows red error icon for mandatory unverified docs
   - Shows "REQUIRED" badge for mandatory docs
   - Red outlined button for mandatory docs

2. **_buildDocumentItemWithExpiry()** - For documents with expiry (NEW!)
   - All features of _buildDocumentItem
   - Plus expiry date tracking
   - Shows expiry status with color coding
   - Changes button to "Renew" if expired
   - Treats expired docs as unverified

### Files Modified
- `lib/screens/verification/document_verification_screen.dart`
  - Added `insurance` to DocumentType enum
  - Added case for insurance in _getDocumentName()

- `lib/screens/vehicle/vehicle_actions_screen.dart`
  - Updated _buildDocumentVerificationCard() with sections
  - Updated _buildDocumentItem() with mandatory flag
  - Added _buildDocumentItemWithExpiry() for insurance

## 📱 User Experience

### Before Verification
```
MANDATORY (Required by Law) 🔴
  🔴 RC Book [REQUIRED]          [Verify]
     Registration Certificate - Proves ownership
  
  🔴 Insurance [REQUIRED]        [Verify]
     Vehicle Insurance - Mandatory by law

OPTIONAL (Increases Trust) 🔵
  🟠 Driving License             [Verify]
     Valid driving license
  
  🟠 Aadhaar Card               [Verify]
     Identity verification
  
  🟠 PAN Card                   [Verify]
     Tax identification
```

### After Verification
```
MANDATORY (Required by Law) 🔴
  ✅ RC Book
     Verified ✓
  
  ✅ Insurance
     Verified ✓
     Valid until 15/05/2026

OPTIONAL (Increases Trust) 🔵
  ✅ Driving License
     Verified ✓
  
  🟠 Aadhaar Card               [Verify]
     Identity verification
  
  🟠 PAN Card                   [Verify]
     Tax identification
```

## 🚀 Next Steps (Production)

### 1. Add to Vehicle Model
```dart
class Vehicle {
  // Mandatory documents
  final bool rcVerified;
  final String? rcPhotoUrl;
  final DateTime? rcVerifiedAt;
  
  final bool insuranceVerified;
  final String? insurancePhotoUrl;
  final DateTime? insuranceVerifiedAt;
  final DateTime? insuranceExpiryDate; // NEW!
  
  // Optional documents
  final bool dlVerified;
  final bool aadhaarVerified;
  final bool panVerified;
  // ... photo URLs and timestamps
}
```

### 2. Update Database Schema
```sql
-- Mandatory documents
ALTER TABLE vehicles ADD COLUMN rc_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE vehicles ADD COLUMN rc_photo_url TEXT;
ALTER TABLE vehicles ADD COLUMN rc_verified_at TIMESTAMPTZ;

ALTER TABLE vehicles ADD COLUMN insurance_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE vehicles ADD COLUMN insurance_photo_url TEXT;
ALTER TABLE vehicles ADD COLUMN insurance_verified_at TIMESTAMPTZ;
ALTER TABLE vehicles ADD COLUMN insurance_expiry_date DATE; -- NEW!

-- Optional documents
ALTER TABLE vehicles ADD COLUMN dl_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE vehicles ADD COLUMN aadhaar_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE vehicles ADD COLUMN pan_verified BOOLEAN DEFAULT FALSE;
```

### 3. Add Expiry Date Input
When verifying insurance, prompt user to enter expiry date:

```dart
Future<void> _startDocumentVerification(DocumentType documentType) async {
  // If insurance, ask for expiry date first
  DateTime? expiryDate;
  if (documentType == DocumentType.insurance) {
    expiryDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Select insurance expiry date',
    );
    
    if (expiryDate == null) return; // User cancelled
  }
  
  // Then proceed with face detection verification
  final result = await Navigator.push<Map<String, dynamic>>(...);
  
  // Save with expiry date
  if (result != null && result['faceVerified']) {
    // Save verification + expiry date to vehicle model
  }
}
```

### 4. Add Expiry Notifications
```dart
// Check for expiring insurance
void checkExpiringDocuments() {
  final vehicles = VehicleRepository.instance.vehicles;
  
  for (final vehicle in vehicles) {
    if (vehicle.insuranceExpiryDate != null) {
      final daysUntilExpiry = vehicle.insuranceExpiryDate!
          .difference(DateTime.now())
          .inDays;
      
      if (daysUntilExpiry <= 30 && daysUntilExpiry > 0) {
        // Show notification: "Insurance expires in X days"
      } else if (daysUntilExpiry <= 0) {
        // Show notification: "Insurance expired! Renew now"
      }
    }
  }
}
```

### 5. Prevent Bookings Without Mandatory Docs
```dart
// In booking flow
if (!vehicle.rcVerified || !vehicle.insuranceVerified) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Documents Required'),
      content: const Text(
        'This vehicle must have verified RC Book and Insurance before accepting bookings. '
        'This is required by law.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  return;
}

// Check insurance expiry
if (vehicle.insuranceExpiryDate != null && 
    vehicle.insuranceExpiryDate!.isBefore(DateTime.now())) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Insurance Expired'),
      content: const Text(
        'This vehicle\'s insurance has expired. Please renew before accepting bookings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  return;
}
```

## 💡 Benefits

### Legal Compliance
- Ensures all vehicles have mandatory documents
- Prevents illegal operations
- Protects platform from liability

### User Trust
- Clear distinction between mandatory and optional
- Expiry tracking prevents expired insurance
- Professional appearance

### Safety
- Verified insurance protects customers
- RC Book proves legitimate ownership
- Reduces fraud and scams

## 🎯 Business Impact

### Risk Reduction
- No vehicles without insurance
- No vehicles without ownership proof
- Automatic expiry tracking

### User Confidence
- Customers see mandatory docs verified
- Trust increases booking rates
- Premium pricing justified

### Compliance
- Meets legal requirements
- Audit trail for verifications
- Expiry date tracking

## 🎉 Ready to Test!

The mandatory/optional document separation is now live. Test on a real device to see the new UI with red mandatory indicators and expiry date tracking!
