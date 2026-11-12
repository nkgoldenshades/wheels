# Remove ALL Vehicle Document Fields

**Decision:** Remove ALL document verification (including RC, Insurance, Pollution, Fitness)  
**Reason:** Legal risk, data protection liability, international complexity

---

## Fields to Remove from Vehicle Model:

### RC Book (Registration Certificate):
```dart
final String? rcFrontUrl;
final String? rcBackUrl;
final bool rcVerified;
final DateTime? rcVerifiedAt;
```

### Insurance:
```dart
final String? insuranceNumber;
final DateTime? insuranceExpiry;
final String? insuranceDocumentUrl;
final bool insuranceVerified;
final DateTime? insuranceVerifiedAt;
```

### Pollution Certificate:
```dart
final String? pollutionCertificateUrl;
final DateTime? pollutionExpiry;
```

### Fitness Certificate:
```dart
final String? fitnessCertificateUrl;
final DateTime? fitnessExpiry;
```

### Operator Document:
```dart
final String? operatorDocumentUrl;
final bool operatorDocumentVerified;
```

**Total:** 15 fields to remove

---

## What Stays (Text-Only Vehicle Info):

```dart
✅ id, userId, userName
✅ name, type, brand, model, color, year
✅ registrationNumber (text only, no upload)
✅ seatingCapacity
✅ capabilities (services offered)
✅ profileImage, galleryImages (vehicle photos for listing)
✅ videoUrl (marketing video)
✅ GPS tracking fields
✅ isVerifiedToggle, isExpertToggle (manual admin flags)
✅ ratings, bookings, statistics
✅ operatorName, operatorPhone (contact info, no documents)
✅ currency, countryCode
```

---

## Methods to Remove/Fix:

1. `isFullyVerified` getter - remove (no documents = no verification)
2. `hasMandatoryDocuments` getter - remove
3. Constructor parameters - remove 15 document fields
4. `copyWith` method - remove document parameters
5. `fromJson` factory - remove document mappings
6. `toJson` method - remove document outputs

---

## Files That Will Need Updates After:

1. `vehicle_actions_screen.dart` - remove document upload UI
2. `customer_vehicle_repository.dart` - remove document mappings
3. `slot_card.dart` - remove document checks
4. `my_posts_unified_page.dart` - remove verification checks
5. Any other files referencing these fields

---

## Database Cleanup SQL:

```sql
ALTER TABLE vehicles 
  DROP COLUMN IF EXISTS rc_front_url,
  DROP COLUMN IF EXISTS rc_back_url,
  DROP COLUMN IF EXISTS rc_verified,
  DROP COLUMN IF EXISTS rc_verified_at,
  DROP COLUMN IF EXISTS insurance_number,
  DROP COLUMN IF EXISTS insurance_expiry,
  DROP COLUMN IF EXISTS insurance_document_url,
  DROP COLUMN IF EXISTS insurance_verified,
  DROP COLUMN IF EXISTS insurance_verified_at,
  DROP COLUMN IF EXISTS pollution_certificate_url,
  DROP COLUMN IF EXISTS pollution_expiry,
  DROP COLUMN IF EXISTS fitness_certificate_url,
  DROP COLUMN IF EXISTS fitness_expiry,
  DROP COLUMN IF EXISTS operator_document_url,
  DROP COLUMN IF EXISTS operator_document_verified;
```

---

## New Trust Model (Zero Documents):

**Trust based on:**
1. Phone verification (SMS/OTP)
2. Rating history (4.5+ stars = trusted)
3. Trip count (5+ successful trips)
4. Profile completeness (name, photo, vehicle details)
5. Community reports/flags

**NO documents stored = NO legal liability!**

---

## Like OLX/Craigslist/Marketplace:

- Users list items with basic text info
- Photos for marketing (not verification)
- Trust through ratings/reviews
- Platform just facilitates contact
- Zero document storage or verification

**Simpler, safer, more international!**
