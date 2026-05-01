# Profiles Table Split - Implementation Guide

## Overview
This guide explains the 3-table split for profiles and how to implement it in your Flutter app.

## Table Structure

### 1. `profiles` (PUBLIC - visible to all authenticated users)
**Columns:**
- `id` (Firebase UID)
- `full_name`
- `profile_photo_url`
- `business_type`
- `city`, `state`, `country`
- `preferred_language`
- `rating` (if exists)
- `created_at`, `updated_at`

**Access:** All authenticated users can read, only owner can update

### 2. `profile_contact` (CONDITIONAL - visible during active bookings)
**Columns:**
- `id` (references profiles.id)
- `phone_number`
- `email`
- `created_at`, `updated_at`

**Access:** 
- Owner can always read their own
- Booking partners can read during active bookings (pending, confirmed, in_progress)

### 3. `profile_confidential` (PRIVATE - owner-only)
**Columns:**
- `id` (references profiles.id)
- **Financial:** `ai_credits`, `wallet_balance`, bank details, payment provider IDs
- **Documents:** Aadhaar, PAN, DL numbers and images (Base64/URLs)
- **Verification:** verification flags, AI logs, fraud scores, vetting status
- `created_at`, `updated_at`

**Access:** Only the owner can read/write

## Step 1: Run Migration SQL

1. Open Supabase Dashboard → SQL Editor
2. Copy contents of `split_profiles_migration.sql`
3. Run the SQL script
4. Verify tables created: `profile_contact`, `profile_confidential`
5. Verify data migrated correctly
6. Verify columns removed from `profiles` table

## Step 2: Update Flutter Code

### A. Update ProfileInfo Model

The model needs to handle data from 3 tables. Here's the updated structure:

```dart
class ProfileInfo {
  // From 'profiles' table (PUBLIC)
  final String id;
  final String profileName;
  final String? avatarUrl;
  final String? businessType;
  final String? country;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // From 'profile_contact' table (CONDITIONAL)
  final String? email;
  final String? phone;

  // From 'profile_confidential' table (PRIVATE)
  final int aiCredits;
  final double walletBalance;
  final String? aadhaar;
  final String? pan;
  final String? aadhaarFrontImage;
  final String? aadhaarBackImage;
  final String? panFrontImage;
  final String? dlFrontImage;
  final String? dlBackImage;
  final bool aadhaarVerified;
  final bool panVerified;
  final bool dlVerified;
  final String paymentProvider;
  final String? stripeAccountId;
  final String? razorpayAccountId;
  final String? bankAccountHolder;
  final String? bankAccountNumber;
  final String? bankName;
  final String? bankIFSC;
  final String? bankAccountType;
  
  // ... constructor and methods
}
```

### B. Update Repository Methods

#### Load Profile (JOIN 3 tables)

```dart
Future<ProfileInfo> loadProfile(String userId) async {
  try {
    // Query all 3 tables
    final profileData = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    
    final contactData = await _supabase
        .from('profile_contact')
        .select()
        .eq('id', userId)
        .maybeSingle();
    
    final confidentialData = await _supabase
        .from('profile_confidential')
        .select()
        .eq('id', userId)
        .maybeSingle();
    
    if (profileData == null) {
      throw Exception('Profile not found');
    }
    
    // Merge data from all 3 tables
    final mergedData = {
      ...profileData,
      if (contactData != null) ...contactData,
      if (confidentialData != null) ...confidentialData,
    };
    
    return ProfileInfo.fromJson(mergedData);
  } catch (e) {
    if (kDebugMode) print('❌ Failed to load profile: $e');
    rethrow;
  }
}
```

#### Save Profile (UPDATE 3 tables)

```dart
Future<void> saveProfile(ProfileInfo profileInfo) async {
  try {
    // Split data into 3 parts
    final publicData = {
      'id': profileInfo.id,
      'full_name': profileInfo.profileName,
      'profile_photo_url': profileInfo.avatarUrl,
      'business_type': profileInfo.businessType ?? 'solo',
      'country': profileInfo.country,
    };
    
    final contactData = {
      'id': profileInfo.id,
      'phone_number': profileInfo.phone,
      'email': profileInfo.email,
    };
    
    final confidentialData = {
      'id': profileInfo.id,
      'ai_credits': profileInfo.aiCredits,
      'wallet_balance': profileInfo.walletBalance,
      'national_id_number': profileInfo.aadhaar,
      'national_id_verified': profileInfo.aadhaarVerified,
      'national_id_front_url': profileInfo.aadhaarFrontImage,
      'national_id_back_url': profileInfo.aadhaarBackImage,
      'tax_id_number': profileInfo.pan,
      'tax_id_verified': profileInfo.panVerified,
      'tax_id_front_url': profileInfo.panFrontImage,
      'driving_license_verified': profileInfo.dlVerified,
      'driving_license_front_url': profileInfo.dlFrontImage,
      'driving_license_back_url': profileInfo.dlBackImage,
      'payment_provider': profileInfo.paymentProvider,
      'stripe_account_id': profileInfo.stripeAccountId,
      'razorpay_account_id': profileInfo.razorpayAccountId,
      'bank_account_holder': profileInfo.bankAccountHolder,
      'bank_account_number': profileInfo.bankAccountNumber,
      'bank_name': profileInfo.bankName,
      'bank_ifsc': profileInfo.bankIFSC,
      'bank_account_type': profileInfo.bankAccountType,
    };
    
    // Update all 3 tables
    await _supabase.from('profiles').upsert(publicData).eq('id', profileInfo.id);
    await _supabase.from('profile_contact').upsert(contactData).eq('id', profileInfo.id);
    await _supabase.from('profile_confidential').upsert(confidentialData).eq('id', profileInfo.id);
    
    profile.value = profileInfo;
    _currentProfile = profileInfo;
    
    if (kDebugMode) print('✅ Saved profile across 3 tables');
  } catch (e) {
    if (kDebugMode) print('❌ Failed to save profile: $e');
    rethrow;
  }
}
```

### C. Load Booking Partner Contact Info

When displaying booking details, you can now fetch contact info:

```dart
Future<Map<String, String?>> getBookingPartnerContact(String partnerId) async {
  try {
    final contactData = await _supabase
        .from('profile_contact')
        .select('phone_number, email')
        .eq('id', partnerId)
        .maybeSingle();
    
    if (contactData == null) {
      return {'phone': null, 'email': null};
    }
    
    return {
      'phone': contactData['phone_number'] as String?,
      'email': contactData['email'] as String?,
    };
  } catch (e) {
    // RLS will block if no active booking exists
    if (kDebugMode) print('⚠️ Cannot access contact info: $e');
    return {'phone': null, 'email': null};
  }
}
```

## Step 3: Test the Implementation

### Test 1: Profile Creation
1. Create a new user account
2. Verify rows created in all 3 tables
3. Verify default values (ai_credits=50, wallet_balance=0.0)

### Test 2: Profile Updates
1. Update profile name → should update `profiles` table
2. Update phone/email → should update `profile_contact` table
3. Update bank details → should update `profile_confidential` table

### Test 3: Contact Visibility (RLS)
1. Create 2 users (User A, User B)
2. User A creates a vehicle
3. User B creates a booking (status='pending')
4. **Expected:** User B can now read User A's phone/email
5. **Expected:** User A can now read User B's phone/email
6. Cancel booking (status='cancelled')
7. **Expected:** Neither user can read the other's contact info anymore

### Test 4: Confidential Data (RLS)
1. User A tries to read User B's `profile_confidential` data
2. **Expected:** Query returns empty/null (RLS blocks access)
3. User A reads their own `profile_confidential` data
4. **Expected:** Query succeeds and returns their data

## Security Benefits

✅ **Separation of concerns:** Public, contact, and confidential data in separate tables  
✅ **RLS enforcement:** Database-level security, not just app-level  
✅ **Conditional access:** Contact info only visible during active bookings  
✅ **Owner-only access:** Financial and document data never exposed to others  
✅ **Audit trail:** Separate tables make it easier to track access patterns  

## Rollback Plan

If something goes wrong, you can rollback:

```sql
-- Restore columns to profiles table
ALTER TABLE public.profiles 
    ADD COLUMN phone_number TEXT,
    ADD COLUMN email TEXT,
    ADD COLUMN ai_credits INTEGER DEFAULT 50,
    -- ... add all other columns back

-- Copy data back from split tables
UPDATE public.profiles p
SET 
    phone_number = pc.phone_number,
    email = pc.email
FROM public.profile_contact pc
WHERE p.id = pc.id;

-- Drop split tables
DROP TABLE public.profile_contact;
DROP TABLE public.profile_confidential;
```

## Next Steps

1. ✅ Run `split_profiles_migration.sql` in Supabase
2. ⏳ Update `lib/services/profile_repository.dart` with new query logic
3. ⏳ Test profile creation and updates
4. ⏳ Test booking contact visibility
5. ⏳ Test RLS policies are working correctly
