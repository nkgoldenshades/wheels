import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'app_preferences.dart';
import 'profile_name_registry.dart';
import 'auth_repository.dart' as auth;
import 'vehicle_repository.dart';
import 'slot_repository.dart';
import 'booking_repository.dart';

class ProfileInfo {
  // ── profiles_public ───────────────────────────────────────
  final String id;
  final String profileName;
  final String? avatarUrl;
  final String? businessType;
  final String? country;
  final String? bio;
  final String? preferredLanguage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── profiles_contact (booking partners only) ──────────────
  final String? email;
  final String? phone;

  // ── profiles_private (owner only) ────────────────────────
  final int aiCredits;
  // Documents
  final String? aadhaar;
  final String? pan;
  final String? drivingLicense;
  final String? aadhaarFrontImage;
  final String? aadhaarBackImage;
  final String? panFrontImage;
  final String? panBackImage;
  final String? dlFrontImage;
  final String? dlBackImage;
  final bool aadhaarVerified;
  final bool panVerified;
  final bool dlVerified;
  // Payment
  final String? paymentProvider;
  final String? stripeAccountId;
  final String? razorpayAccountId;
  // Bank details
  final String? bankAccountHolder;
  final String? bankAccountNumber;
  final String? bankName;
  final String? bankIFSC;
  final String? bankAccountType;
  // Personal
  final String? gender;
  final DateTime? dateOfBirth;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;

  const ProfileInfo({
    required this.id,
    required this.profileName,
    this.avatarUrl,
    this.businessType,
    this.country,
    this.bio,
    this.preferredLanguage,
    this.createdAt,
    this.updatedAt,
    this.email,
    this.phone,
    this.aiCredits = 50,
    this.aadhaar,
    this.pan,
    this.drivingLicense,
    this.aadhaarFrontImage,
    this.aadhaarBackImage,
    this.panFrontImage,
    this.panBackImage,
    this.dlFrontImage,
    this.dlBackImage,
    this.aadhaarVerified = false,
    this.panVerified = false,
    this.dlVerified = false,
    this.paymentProvider,
    this.stripeAccountId,
    this.razorpayAccountId,
    this.bankAccountHolder,
    this.bankAccountNumber,
    this.bankName,
    this.bankIFSC,
    this.bankAccountType,
    this.gender,
    this.dateOfBirth,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
  });

  factory ProfileInfo.fromJson(Map<String, dynamic> json) {
    return ProfileInfo(
      // profiles_public
      id: json['id'] as String,
      profileName: json['full_name'] as String? ?? 'Unknown User',
      avatarUrl: json['profile_photo_url'] as String?,
      businessType: json['business_type'] as String?,
      country: json['country'] as String?,
      bio: json['bio'] as String?,
      preferredLanguage: json['preferred_language'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      // profiles_contact
      email: json['email'] as String?,
      phone: json['phone_number'] as String?,
      // profiles_private
      aiCredits: json['ai_credits_available'] as int? ?? 50,
      aadhaar: json['national_id_number'] as String?,
      aadhaarVerified: json['national_id_verified'] as bool? ?? false,
      aadhaarFrontImage: json['national_id_front_url'] as String?,
      aadhaarBackImage: json['national_id_back_url'] as String?,
      pan: json['tax_id_number'] as String?,
      panVerified: json['tax_id_verified'] as bool? ?? false,
      panFrontImage: json['tax_id_front_url'] as String?,
      panBackImage: json['tax_id_back_url'] as String?,
      drivingLicense: json['driving_license_number'] as String?,
      dlVerified: json['driving_license_verified'] as bool? ?? false,
      dlFrontImage: json['driving_license_front_url'] as String?,
      dlBackImage: json['driving_license_back_url'] as String?,
      paymentProvider: json['payment_provider'] as String?,
      stripeAccountId: json['stripe_account_id'] as String?,
      razorpayAccountId: json['razorpay_account_id'] as String?,
      bankAccountHolder: json['bank_account_holder'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
      bankName: json['bank_name'] as String?,
      bankIFSC: json['bank_ifsc'] as String?,
      bankAccountType: json['bank_account_type'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: json['date_of_birth'] != null ? DateTime.tryParse(json['date_of_birth'] as String) : null,
      addressLine1: json['address_line1'] as String?,
      addressLine2: json['address_line2'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
    );
  }

  // profiles_public table
  Map<String, dynamic> toPublicJson() => {
    'id': id,
    'full_name': profileName,
    if (avatarUrl != null) 'profile_photo_url': avatarUrl,
    if (businessType != null) 'business_type': businessType,
    if (country != null) 'country': country,
    if (bio != null) 'bio': bio,
    if (preferredLanguage != null) 'preferred_language': preferredLanguage,
  };

  // profiles_contact table
  Map<String, dynamic> toContactJson() => {
    'profile_id': id,
    if (phone != null) 'phone_number': phone,
    if (email != null) 'email': email,
  };

  // profiles_private table
  Map<String, dynamic> toPrivateJson() => {
    'profile_id': id,
    'ai_credits_available': aiCredits,
    if (aadhaar != null) 'national_id_number': aadhaar,
    if (aadhaarVerified) 'national_id_verified': aadhaarVerified,
    if (aadhaarFrontImage != null) 'national_id_front_url': aadhaarFrontImage,
    if (aadhaarBackImage != null) 'national_id_back_url': aadhaarBackImage,
    if (pan != null) 'tax_id_number': pan,
    if (panVerified) 'tax_id_verified': panVerified,
    if (panFrontImage != null) 'tax_id_front_url': panFrontImage,
    if (panBackImage != null) 'tax_id_back_url': panBackImage,
    if (drivingLicense != null) 'driving_license_number': drivingLicense,
    if (dlVerified) 'driving_license_verified': dlVerified,
    if (dlFrontImage != null) 'driving_license_front_url': dlFrontImage,
    if (dlBackImage != null) 'driving_license_back_url': dlBackImage,
    if (paymentProvider != null) 'payment_provider': paymentProvider,
    if (stripeAccountId != null) 'stripe_account_id': stripeAccountId,
    if (razorpayAccountId != null) 'razorpay_account_id': razorpayAccountId,
    if (bankAccountHolder != null) 'bank_account_holder': bankAccountHolder,
    if (bankAccountNumber != null) 'bank_account_number': bankAccountNumber,
    if (bankName != null) 'bank_name': bankName,
    if (bankIFSC != null) 'bank_ifsc': bankIFSC,
    if (bankAccountType != null) 'bank_account_type': bankAccountType,
    if (gender != null) 'gender': gender,
    if (dateOfBirth != null) 'date_of_birth': dateOfBirth!.toIso8601String().split('T').first,
    if (addressLine1 != null) 'address_line1': addressLine1,
    if (addressLine2 != null) 'address_line2': addressLine2,
    if (city != null) 'city': city,
    if (state != null) 'state': state,
  };

  ProfileInfo copyWith({
    String? id,
    String? profileName,
    String? avatarUrl,
    bool setAvatarNull = false,
    String? businessType,
    bool setBusinessTypeNull = false,
    String? country,
    bool setCountryNull = false,
    String? bio,
    bool setBioNull = false,
    String? preferredLanguage,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? email,
    bool setEmailNull = false,
    String? phone,
    bool setPhoneNull = false,
    int? aiCredits,
    String? aadhaar,
    bool setAadhaarNull = false,
    String? pan,
    bool setPanNull = false,
    String? drivingLicense,
    bool setDlNull = false,
    String? aadhaarFrontImage,
    bool setAadhaarFrontNull = false,
    String? aadhaarBackImage,
    bool setAadhaarBackNull = false,
    String? panFrontImage,
    bool setPanFrontNull = false,
    String? panBackImage,
    bool setPanBackNull = false,
    String? dlFrontImage,
    bool setDlFrontNull = false,
    String? dlBackImage,
    bool setDlBackNull = false,
    bool? aadhaarVerified,
    bool? panVerified,
    bool? dlVerified,
    String? paymentProvider,
    String? stripeAccountId,
    bool setStripeNull = false,
    String? razorpayAccountId,
    bool setRazorpayNull = false,
    String? bankAccountHolder,
    bool setBankHolderNull = false,
    String? bankAccountNumber,
    bool setBankNumberNull = false,
    String? bankName,
    bool setBankNameNull = false,
    String? bankIFSC,
    bool setBankIFSCNull = false,
    String? bankAccountType,
    bool setBankTypeNull = false,
    String? gender,
    DateTime? dateOfBirth,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
  }) {
    return ProfileInfo(
      id: id ?? this.id,
      profileName: profileName ?? this.profileName,
      avatarUrl: setAvatarNull ? null : avatarUrl ?? this.avatarUrl,
      businessType: setBusinessTypeNull ? null : businessType ?? this.businessType,
      country: setCountryNull ? null : country ?? this.country,
      bio: setBioNull ? null : bio ?? this.bio,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      email: setEmailNull ? null : email ?? this.email,
      phone: setPhoneNull ? null : phone ?? this.phone,
      aiCredits: aiCredits ?? this.aiCredits,
      aadhaar: setAadhaarNull ? null : aadhaar ?? this.aadhaar,
      pan: setPanNull ? null : pan ?? this.pan,
      drivingLicense: setDlNull ? null : drivingLicense ?? this.drivingLicense,
      aadhaarFrontImage: setAadhaarFrontNull ? null : aadhaarFrontImage ?? this.aadhaarFrontImage,
      aadhaarBackImage: setAadhaarBackNull ? null : aadhaarBackImage ?? this.aadhaarBackImage,
      panFrontImage: setPanFrontNull ? null : panFrontImage ?? this.panFrontImage,
      panBackImage: setPanBackNull ? null : panBackImage ?? this.panBackImage,
      dlFrontImage: setDlFrontNull ? null : dlFrontImage ?? this.dlFrontImage,
      dlBackImage: setDlBackNull ? null : dlBackImage ?? this.dlBackImage,
      aadhaarVerified: aadhaarVerified ?? this.aadhaarVerified,
      panVerified: panVerified ?? this.panVerified,
      dlVerified: dlVerified ?? this.dlVerified,
      paymentProvider: paymentProvider ?? this.paymentProvider,
      stripeAccountId: setStripeNull ? null : stripeAccountId ?? this.stripeAccountId,
      razorpayAccountId: setRazorpayNull ? null : razorpayAccountId ?? this.razorpayAccountId,
      bankAccountHolder: setBankHolderNull ? null : bankAccountHolder ?? this.bankAccountHolder,
      bankAccountNumber: setBankNumberNull ? null : bankAccountNumber ?? this.bankAccountNumber,
      bankName: setBankNameNull ? null : bankName ?? this.bankName,
      bankIFSC: setBankIFSCNull ? null : bankIFSC ?? this.bankIFSC,
      bankAccountType: setBankTypeNull ? null : bankAccountType ?? this.bankAccountType,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
    );
  }
}

class ProfileRepository {
  ProfileRepository._();
  static final ProfileRepository instance = ProfileRepository._();

  SupabaseClient get _supabase => Supabase.instance.client;

  ProfileInfo? _currentProfile;
  final ValueNotifier<ProfileInfo> profile = ValueNotifier<ProfileInfo>(
    const ProfileInfo(id: '', profileName: 'Loading...'),
  );

  Future<void> init() async {
    try {
      if (kDebugMode) print('🔧 ProfileRepository init starting...');
      await ProfileNameRegistry.instance.init();

      firebase_auth.FirebaseAuth.instance.authStateChanges().listen((firebaseUser) async {
        if (firebaseUser != null) {
          if (kDebugMode) print('✅ Firebase user ready: ${firebaseUser.uid}');
          try {
            await loadProfile(firebaseUser.uid);
            await VehicleRepository.instance.loadVehicles();
            await SlotRepository.instance.loadSlots();
            await BookingRepository.instance.refreshFromSupabase();
          } catch (e) {
            if (kDebugMode) print('⚠️ Profile not found, creating default: $e');
            final defaultProfile = ProfileInfo(
              id: firebaseUser.uid,
              profileName: firebaseUser.email?.split('@').first ?? 'User',
              email: firebaseUser.email,
              businessType: 'solo',
            );
            await saveProfile(defaultProfile);
          }
        } else {
          profile.value = const ProfileInfo(id: '', profileName: 'Guest User');
        }
      });

      if (kDebugMode) print('✅ ProfileRepository init completed');
    } catch (e) {
      if (kDebugMode) print('❌ ProfileRepository init error: $e');
      profile.value = const ProfileInfo(id: '', profileName: 'Guest User');
    }
  }

  Future<ProfileInfo> loadProfile(String userId) async {
    try {
      if (kDebugMode) print('🔍 Loading profile for user: $userId');

      final results = await Future.wait([
        _supabase.from('profiles_public').select().eq('id', userId).maybeSingle(),
        _supabase.from('profiles_contact').select().eq('profile_id', userId).maybeSingle(),
        _supabase.from('profiles_private').select().eq('profile_id', userId).maybeSingle(),
      ]);

      final publicData = results[0];
      if (publicData == null) throw Exception('Profile not found for user: $userId');

      final merged = {
        ...publicData,
        if (results[1] != null) ...results[1]!,
        if (results[2] != null) ...results[2]!,
      };

      final profileInfo = ProfileInfo.fromJson(merged);
      profile.value = profileInfo;
      _currentProfile = profileInfo;

      if (kDebugMode) print('✅ Profile loaded: ${profileInfo.profileName}');
      return profileInfo;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to load profile: $e');
      rethrow;
    }
  }

  Future<void> saveProfile(ProfileInfo profileInfo) async {
    try {
      final publicJson = profileInfo.toPublicJson();
      final contactJson = profileInfo.toContactJson();
      final privateJson = profileInfo.toPrivateJson();

      if (kDebugMode) {
        print('📤 profiles_public: $publicJson');
        print('📤 profiles_contact: $contactJson');
        print('📤 profiles_private: $privateJson');
      }

      await Future.wait([
        _supabase.from('profiles_public').upsert(publicJson, onConflict: 'id'),
        _supabase.from('profiles_contact').upsert(contactJson, onConflict: 'profile_id'),
        _supabase.from('profiles_private').upsert(privateJson, onConflict: 'profile_id'),
      ]);

      profile.value = profileInfo;
      _currentProfile = profileInfo;

      if (kDebugMode) print('✅ Saved profile: ${profileInfo.id}');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to save profile: $e');
      rethrow;
    }
  }

  Future<void> saveDocument(String documentType, String side, String base64Image, {bool isVerified = false}) async {
    final p = _currentProfile ?? profile.value;
    if (p.id.isEmpty) throw Exception('No profile loaded');

    ProfileInfo updated;
    switch (documentType) {
      case 'aadhaar':
        updated = side == 'front'
            ? p.copyWith(aadhaarFrontImage: base64Image, aadhaarVerified: isVerified ? true : p.aadhaarVerified)
            : p.copyWith(aadhaarBackImage: base64Image, aadhaarVerified: isVerified ? true : p.aadhaarVerified);
        break;
      case 'pan':
        updated = side == 'front'
            ? p.copyWith(panFrontImage: base64Image, panVerified: isVerified ? true : p.panVerified)
            : p.copyWith(panBackImage: base64Image, panVerified: isVerified ? true : p.panVerified);
        break;
      case 'dl':
        updated = side == 'front'
            ? p.copyWith(dlFrontImage: base64Image, dlVerified: isVerified ? true : p.dlVerified)
            : p.copyWith(dlBackImage: base64Image, dlVerified: isVerified ? true : p.dlVerified);
        break;
      default:
        throw Exception('Unknown document type: $documentType');
    }
    await saveProfile(updated);
  }

  String? getDocument(String documentType, String side) {
    final p = _currentProfile ?? profile.value;
    if (p.id.isEmpty) return null;
    switch (documentType) {
      case 'aadhaar': return side == 'front' ? p.aadhaarFrontImage : p.aadhaarBackImage;
      case 'pan': return side == 'front' ? p.panFrontImage : p.panBackImage;
      case 'dl': return side == 'front' ? p.dlFrontImage : p.dlBackImage;
      default: return null;
    }
  }

  Future<void> setLocalAvatarBase64(String? base64) async {
    await AppPreferences.instance.setAvatarBase64(base64);
    final p = _currentProfile ?? profile.value;
    if (p.id.isNotEmpty) {
      await saveProfile(p.copyWith(avatarUrl: base64, setAvatarNull: base64 == null));
    }
  }

  Future<void> update({
    String? profileName,
    String? email,
    bool setEmailNull = false,
    String? phone,
    bool setPhoneNull = false,
    String? aadhaar,
    bool setAadhaarNull = false,
    String? pan,
    bool setPanNull = false,
    String? avatarUrl,
    bool setAvatarNull = false,
    String? businessType,
    bool setBusinessTypeNull = false,
    String? bio,
    bool setBioNull = false,
    String? gender,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
  }) async {
    final p = _currentProfile ?? profile.value;
    if (p.id.isEmpty) throw Exception('No profile loaded');

    if (profileName != null && profileName.trim().isNotEmpty) {
      final currentUser = auth.AuthRepository.instance.currentUser;
      if (currentUser != null) {
        final isAvailable = await ProfileNameRegistry.instance.updateName(currentUser.id, profileName.trim());
        if (!isAvailable) throw Exception('Profile name already taken. Please choose a different name.');
      }
    }

    await saveProfile(p.copyWith(
      profileName: profileName,
      email: email,
      setEmailNull: setEmailNull,
      phone: phone,
      setPhoneNull: setPhoneNull,
      aadhaar: aadhaar,
      setAadhaarNull: setAadhaarNull,
      pan: pan,
      setPanNull: setPanNull,
      avatarUrl: avatarUrl,
      setAvatarNull: setAvatarNull,
      businessType: businessType,
      setBusinessTypeNull: setBusinessTypeNull,
      bio: bio,
      setBioNull: setBioNull,
      gender: gender,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      city: city,
      state: state,
    ));
  }

  Future<void> updatePaymentProvider(String provider) async {
    final p = _currentProfile ?? profile.value;
    if (p.id.isEmpty) throw Exception('No profile loaded');
    await saveProfile(p.copyWith(paymentProvider: provider));
  }

  Future<void> updateStripeAccount(String accountId) async {
    final p = _currentProfile ?? profile.value;
    if (p.id.isEmpty) throw Exception('No profile loaded');
    await saveProfile(p.copyWith(stripeAccountId: accountId));
  }

  Future<void> updateRazorpayAccount(String accountId) async {
    final p = _currentProfile ?? profile.value;
    if (p.id.isEmpty) throw Exception('No profile loaded');
    await saveProfile(p.copyWith(razorpayAccountId: accountId));
  }

  Future<void> updateCountry(String country) async {
    final p = _currentProfile ?? profile.value;
    if (p.id.isEmpty) throw Exception('No profile loaded');
    final provider = (country == 'IN' || country == 'India') ? 'razorpay' : 'stripe';
    await saveProfile(p.copyWith(country: country, paymentProvider: provider));
  }

  Future<bool> deductAICredits(int amount) async {
    final p = _currentProfile ?? profile.value;
    if (p.id.isEmpty) throw Exception('No profile loaded');
    if (p.aiCredits < amount) return false;
    await saveProfile(p.copyWith(aiCredits: p.aiCredits - amount));
    debugPrint('✅ Deducted $amount credits. Remaining: ${p.aiCredits - amount}');
    return true;
  }

  Future<void> addAICredits(int amount) async {
    final p = _currentProfile ?? profile.value;
    if (p.id.isEmpty) throw Exception('No profile loaded');
    await saveProfile(p.copyWith(aiCredits: p.aiCredits + amount));
    debugPrint('✅ Added $amount credits. New balance: ${p.aiCredits + amount}');
  }

  Future<Map<String, String?>> getBookingPartnerContact(String partnerId) async {
    try {
      final data = await _supabase
          .from('profiles_contact')
          .select('phone_number, email')
          .eq('profile_id', partnerId)
          .maybeSingle();
      if (data == null) return {'phone': null, 'email': null};
      return {
        'phone': data['phone_number'] as String?,
        'email': data['email'] as String?,
      };
    } catch (e) {
      if (kDebugMode) print('⚠️ Cannot access contact info: $e');
      return {'phone': null, 'email': null};
    }
  }
}



