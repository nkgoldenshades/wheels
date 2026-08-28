# Document Verification Removal - Progress Tracker

**Started:** 2026-08-28  
**Option Selected:** Option 1 - Complete Removal  
**Status:** 🟡 IN PROGRESS

---

## ✅ Completed:

### Services Deleted:
- ✅ `lib/services/verification_service.dart` - DELETED
- ✅ `lib/services/document_retention_service.dart` - DELETED

---

## 🔄 In Progress:

### Critical Files Need Manual Review (Too Complex for Auto-Removal):

#### 1. `lib/models/vehicle.dart` - LARGE FILE
**Document fields to remove:**
```dart
// Remove these:
- aadhaarVerified
- aadhaarVerifiedAt  
- aadhaarImageBase64
- panVerified
- panVerifiedAt
- panImageBase64
- dlVerified (Driving License)
- dlVerifiedAt
- dlImageBase64
```

**Keep these (vehicle-related, not personal documents):**
```dart
// These are OK - vehicle documents, not personal ID:
- rcFrontUrl (RC Book - vehicle registration)
- rcBackUrl
- rcVerified
- insuranceNumber
- insuranceExpiry
- insuranceDocumentUrl
- pollutionCertificateUrl
- fitnessCertificateUrl
```

**Reasoning:** Vehicle documents (RC, insurance) are about the VEHICLE, not the person. Less risky legally.

---

#### 2. `lib/services/profile_repository.dart` - LARGE FILE
**Document fields to remove:**
```dart
// Remove personal ID documents:
- aadhaar
- aadhaarFrontImage
- aadhaarBackImage
- aadhaarVerified
- pan
- panFrontImage
- panBackImage
- panVerified
- drivingLicense
- dlFrontImage
- dlBackImage
- dlVerified
```

**Keep these:**
```dart
// Safe profile data:
- id, profileName, email, phone
- avatarUrl
- gender, businessType
- accountCreated
- aiCredits
- rating, totalRatings
```

---

#### 3. `lib/main.dart` - MASSIVE FILE (10,000+ lines)
**Areas to update:**
- Remove document upload UI sections
- Remove Aadhaar/PAN/DL TextField controllers
- Remove document verification screens/navigation
- Update Settings page to remove document fields

**This needs careful manual editing due to file size.**

---

#### 4. `lib/widgets/verified_badge.dart`
**Change verification logic:**
```dart
// OLD (document-based):
hasDocuments = aadhaarVerified || panVerified || dlVerified

// NEW (behavior-based):
isTrusted = phoneVerified && emailVerified && (totalTrips >= 5) && (avgRating >= 4.5)
```

---

#### 5. `lib/models/demand_plan.dart`
**Update descriptions:**
```dart
// OLD:
case DemandPlan.verified:
  return 'Requires verified Aadhaar, PAN, or Driving License';

// NEW:
case DemandPlan.verified:
  return 'Requires phone verification and 3+ completed trips';
```

---

## ⏳ Pending:

### Database Changes (SQL):
```sql
-- Backup first!
-- Then remove document columns from profiles_private:
ALTER TABLE profiles_private 
  DROP COLUMN IF EXISTS national_id_number,
  DROP COLUMN IF EXISTS national_id_verified,
  DROP COLUMN IF EXISTS national_id_front_url,
  DROP COLUMN IF EXISTS national_id_back_url,
  DROP COLUMN IF EXISTS tax_id_number,
  DROP COLUMN IF EXISTS tax_id_verified,
  DROP COLUMN IF EXISTS tax_id_front_url,
  DROP COLUMN IF EXISTS tax_id_back_url,
  DROP COLUMN IF EXISTS dl_number,
  DROP COLUMN IF EXISTS dl_verified,
  DROP COLUMN IF EXISTS dl_front_url,
  DROP COLUMN IF EXISTS dl_back_url;
```

### Storage Buckets:
- Delete or stop using: `verification-documents` bucket
- Keep: `profile_media`, `vehicle_media`, `post_media` (these are fine)

---

## 📋 Recommendation for Large Files:

Due to the complexity of `vehicle.dart`, `profile_repository.dart`, and `main.dart`:

### Option A: Manual Edit (Safer)
1. I provide you with specific line numbers to remove
2. You review and edit manually
3. Test after each file

### Option B: Create New Clean Files (Cleaner)
1. I create new versions without document fields
2. You review the new files
3. Replace old files with new ones
4. Test everything

### Option C: Gradual Approach (Safest)
1. Comment out document fields first (don't delete)
2. Test that app still works
3. Remove commented code later

---

## ⚠️ Complexity Note:

The codebase has document verification deeply integrated:
- 50+ files reference document fields
- 500+ lines of document-related code
- Multiple UI screens for document upload
- Database columns in multiple tables

**This is why Option 1 is a multi-day effort.**

---

## Next Decision Point:

**For the large files (vehicle.dart, profile_repository.dart, main.dart), which approach do you prefer?**

A. I provide line-by-line removal instructions (you edit manually)  
B. I create new clean files (you review and replace)  
C. Comment out first, remove later (safest testing)

**Your call!** 

Stopping here to get your direction on how to handle the complex files. The service files are already deleted. ✅
