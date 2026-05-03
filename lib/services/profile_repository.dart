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
  final String id; // Firebase UID
  final String profileName;
  final String? avatarUrl;
  final String? businessType;
  final String? country;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // From profiles_contact (conditional - visible during active bookings)
  final String? email;
  final String? phone;

  // From profiles_private (owner-only)
  final int aiCredits;
  final double walletBalance;
  final String? aadhaar;
  final String? pan;
  final int? age;

  // Document images (Base64 or URLs)
  final String? aadhaarFrontImage;
  final String? aadhaarBackImage;
  final String? panFrontImage;
  final String? dlFrontImage;
  final String? dlBackImage;

  // Verification status
  final bool aadhaarVerified;
  final bool panVerified;
  final bool dlVerified;

  // Payment provider fields
  final String paymentProvider;
  final String? stripeAccountId;
  final String? razorpayAccountId;
  final String? bankAccountHolder;
  final String? bankAccountNumber;
  final String? bankName;
  final String? bankIFSC;
  final String? bankAccountType;

  const ProfileInfo({
    required this.id,
    required this.profileName,
    this.avatarUrl,
    this.businessType,
    this.country,
    this.createdAt,
    this.updatedAt,
    // contact
    this.email,
    this.phone,
    // private
    this.aiCredits = 50,
    this.walletBalance = 0.0,
    this.aadhaar,
    this.pan,
    this.age,
    this.aadhaarFrontImage,
    this.aadhaarBackImage,
    this.panFrontImage,
    this.dlFrontImage,
    this.dlBackImage,
    this.aadhaarVerified = false,
    this.panVerified = false,
    this.dlVerified = false,
    this.paymentProvider = 'razorpay',
    this.stripeAccountId,
    this.razorpayAccountId,
    this.bankAccountHolder,
    this.bankAccountNumber,
    this.bankName,
    this.bankIFSC,
    this.bankAccountType,
  });

  // Build from merged data of all 3 tables
  factory ProfileInfo.fromJson(Map<String, dynamic> json) {
    return ProfileInfo(
      id: json['id'] as String,
      profileName: json['full_name'] as String? ?? 'Unknown User',
      avatarUrl: json['profile_photo_url'] as String?,
      businessType: json['business_type'] as String?,
      country: json['country'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      // contact fields
      email: json['email'] as String?,
      phone: json['phone_number'] as String?,
      // private fields
      aiCredits: json['ai_credits_available'] as int? ?? json['ai_credits'] as int? ?? 50,
      walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      aadhaar: json['national_id_number'] as String?,
      aadhaarVerified: json['national_id_verified'] as bool? ?? false,
      aadhaarFrontImage: json['national_id_front_url'] as String?,
      aadhaarBackImage: json['national_id_back_url'] as String?,
      pan: json['tax_id_number'] as String?,
      panVerified: json['tax_id_verified'] as bool? ?? false,
      panFrontImage: json['tax_id_front_url'] as String?,
      dlVerified: json['driving_license_verified'] as bool? ?? false,
      dlFrontImage: json['driving_license_front_url'] as String?,
      dlBackImage: json['driving_license_back_url'] as String?,
      paymentProvider: json['payment_provider'] as String? ?? 'razorpay',
      stripeAccountId: json['stripe_account_id'] as String?,
      razorpayAccountId: json['razorpay_account_id'] as String?,
      bankAccountHolder: json['bank_account_holder'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
      bankName: json['bank_name'] as String?,
      bankIFSC: json['bank_ifsc'] as String?,
      bankAccountType: json['bank_account_type'] as String?,
    );
  }

  // Public data only (for profiles table)
  Map<String, dynamic> toPublicJson() {
    return {
      'id': id,
      'full_name': profileName,
      'profile_photo_url': avatarUrl,
      'business_type': businessType ?? 'solo',
      'country': country,
    };
  }

  // Contact data (for profiles_contact table)
  Map<String, dynamic> toContactJson() {
    return {
      'id': id,
      'phone_number': phone,
      'email': email,
    };
  }

  // Private/confidential data (for profiles_private table)
  Map<String, dynamic> toPrivateJson() {
    return {
      'id': id,
      'ai_credits_available': aiCredits,
      'wallet_balance': walletBalance,
      'national_id_number': aadhaar,
      'national_id_verified': aadhaarVerified,
      'national_id_front_url': aadhaarFrontImage,
      'national_id_back_url': aadhaarBackImage,
      'tax_id_number': pan,
      'tax_id_verified': panVerified,
      'tax_id_front_url': panFrontImage,
      'driving_license_verified': dlVerified,
      'driving_license_front_url': dlFrontImage,
      'driving_license_back_url': dlBackImage,
      'payment_provider': paymentProvider,
      'stripe_account_id': stripeAccountId,
      'razorpay_account_id': razorpayAccountId,
      'bank_account_holder': bankAccountHolder,
      'bank_account_number': bankAccountNumber,
      'bank_name': bankName,
      'bank_ifsc': bankIFSC,
      'bank_account_type': bankAccountType,
    };
  }

  ProfileInfo copyWith({
    String? id,
    String? profileName,
    String? avatarUrl,
    bool setAvatarNull = false,
    String? businessType,
    bool setBusinessTypeNull = false,
    String? country,
    bool setCountryNull = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? email,
    bool setEmailNull = false,
    String? phone,
    bool setPhoneNull = false,
    int? aiCredits,
    double? walletBalance,
    String? aadhaar,
    bool setAadhaarNull = false,
    String? pan,
    bool setPanNull = false,
    int? age,
    bool setAgeNull = false,
    String? aadhaarFrontImage,
    bool setAadhaarFrontNull = false,
    String? aadhaarBackImage,
    bool setAadhaarBackNull = false,
    String? panFrontImage,
    bool setPanFrontNull = false,
    String? dlFrontImage,
    bool setDlFrontNull = false,
    String? dlBackImage,
    bool setDlBackNull = false,
    bool? aadhaarVerified,
    bool? panVerified,
    bool? dlVerified,
    String? paymentProvider,
    String? stripeAccountId,
    bool setStripeAccountIdNull = false,
    String? razorpayAccountId,
    bool setRazorpayAccountIdNull = false,
    String? bankAccountHolder,
    bool setBankAccountHolderNull = false,
    String? bankAccountNumber,
    bool setBankAccountNumberNull = false,
    String? bankName,
    bool setBankNameNull = false,
    String? bankIFSC,
    bool setBankIFSCNull = false,
    String? bankAccountType,
    bool setBankAccountTypeNull = false,
  }) {
    return ProfileInfo(
      id: id ?? this.id,
      profileName: profileName ?? this.profileName,
      avatarUrl: setAvatarNull ? null : avatarUrl ?? this.avatarUrl,
      businessType: setBusinessTypeNull ? null : businessType ?? this.businessType,
      country: setCountryNull ? null : country ?? this.country,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      email: setEmailNull ? null : email ?? this.email,
      phone: setPhoneNull ? null : phone ?? this.phone,
      aiCredits: aiCredits ?? this.aiCredits,
      walletBalance: walletBalance ?? this.walletBalance,
      aadhaar: setAadhaarNull ? null : aadhaar ?? this.aadhaar,
      pan: setPanNull ? null : pan ?? this.pan,
      age: setAgeNull ? null : age ?? this.age,
      aadhaarFrontImage: setAadhaarFrontNull ? null : aadhaarFrontImage ?? this.aadhaarFrontImage,
      aadhaarBackImage: setAadhaarBackNull ? null : aadhaarBackImage ?? this.aadhaarBackImage,
      panFrontImage: setPanFrontNull ? null : panFrontImage ?? this.panFrontImage,
      dlFrontImage: setDlFrontNull ? null : dlFrontImage ?? this.dlFrontImage,
      dlBackImage: setDlBackNull ? null : dlBackImage ?? this.dlBackImage,
      aadhaarVerified: aadhaarVerified ?? this.aadhaarVerified,
      panVerified: panVerified ?? this.panVerified,
      dlVerified: dlVerified ?? this.dlVerified,
      paymentProvider: paymentProvider ?? this.paymentProvider,
      stripeAccountId: setStripeAccountIdNull ? null : stripeAccountId ?? this.stripeAccountId,
      razorpayAccountId: setRazorpayAccountIdNull ? null : razorpayAccountId ?? this.razorpayAccountId,
      bankAccountHolder: setBankAccountHolderNull ? null : bankAccountHolder ?? this.bankAccountHolder,
      bankAccountNumber: setBankAccountNumberNull ? null : bankAccountNumber ?? this.bankAccountNumber,
      bankName: setBankNameNull ? null : bankName ?? this.bankName,
      bankIFSC: setBankIFSCNull ? null : bankIFSC ?? this.bankIFSC,
      bankAccountType: setBankAccountTypeNull ? null : bankAccountType ?? this.bankAccountType,
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
            if (kDebugMode) print('✅ Profile loaded for authenticated user');
            if (kDebugMode) print('🔄 Reloading vehicles and posts after auth...');
            await VehicleRepository.instance.loadVehicles();
            await SlotRepository.instance.loadSlots();
            await BookingRepository.instance.refreshFromSupabase();
            if (kDebugMode) print('✅ Vehicles and posts reloaded');
          } catch (e) {
            if (kDebugMode) print('⚠️ Profile not found, creating default: $e');
            final defaultProfile = ProfileInfo(
              id: firebaseUser.uid,
              profileName: firebaseUser.email?.split('@').first ?? 'User',
              email: firebaseUser.email,
              businessType: 'solo',
            );
            await saveProfile(defaultProfile);
            if (kDebugMode) print('✅ Default profile created');
          }
        } else {
          if (kDebugMode) print('⚠️ No Firebase user - setting guest profile');
          profile.value = const ProfileInfo(id: '', profileName: 'Guest User');
        }
      });

      if (kDebugMode) print('✅ ProfileRepository init completed');
    } catch (e) {
      if (kDebugMode) print('❌ ProfileRepository init error: $e');
      profile.value = const ProfileInfo(id: '', profileName: 'Guest User');
    }
  }

  /// Load profile from all 3 tables and merge
  Future<ProfileInfo> loadProfile(String userId) async {
    try {
      if (kDebugMode) print('🔍 Loading profile for user: $userId');

      // Query all 3 tables in parallel
      final results = await Future.wait([
        _supabase.from('profiles').select().eq('id', userId).maybeSingle(),
        _supabase.from('profiles_contact').select().eq('id', userId).maybeSingle(),
        _supabase.from('profiles_private').select().eq('id', userId).maybeSingle(),
      ]);

      final publicData = results[0];
      final contactData = results[1];
      final privateData = results[2];

      if (publicData == null) {
        throw Exception('Profile not found for user: $userId');
      }

      // Merge all 3 tables into one map
      final merged = {
        ...publicData,
        if (contactData != null) ...contactData,
        if (privateData != null) ...privateData,
      };

      if (kDebugMode) print('📊 Profile merged from 3 tables');

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

  /// Save profile across all 3 tables
  Future<void> saveProfile(ProfileInfo profileInfo) async {
    try {
      // Upsert all 3 tables in parallel
      await Future.wait([
        _supabase.from('profiles').upsert(profileInfo.toPublicJson()),
        _supabase.from('profiles_contact').upsert(profileInfo.toContactJson()),
        _supabase.from('profiles_private').upsert(profileInfo.toPrivateJson()),
      ]);

      profile.value = profileInfo;
      _currentProfile = profileInfo;

      if (kDebugMode) print('✅ Saved profile across 3 tables: ${profileInfo.id}');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to save profile: $e');
      rethrow;
    }
  }

  Future<void> saveDocument(
    String documentType,
    String side,
    String base64Image, {
    bool isVerified = false,
  }) async {
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isEmpty) throw Exception('No profile loaded');

    ProfileInfo updatedProfile;

    switch (documentType) {
      case 'aadhaar':
        if (side == 'front') {
          updatedProfile = currentProfile.copyWith(
            aadhaarFrontImage: base64Image,
            aadhaarVerified: isVerified ? true : currentProfile.aadhaarVerified,
          );
        } else {
          updatedProfile = currentProfile.copyWith(
            aadhaarBackImage: base64Image,
            aadhaarVerified: isVerified ? true : currentProfile.aadhaarVerified,
          );
        }
        break;
      case 'pan':
        updatedProfile = currentProfile.copyWith(
          panFrontImage: base64Image,
          panVerified: isVerified ? true : currentProfile.panVerified,
        );
        break;
      case 'dl':
        if (side == 'front') {
          updatedProfile = currentProfile.copyWith(
            dlFrontImage: base64Image,
            dlVerified: isVerified ? true : currentProfile.dlVerified,
          );
        } else {
          updatedProfile = currentProfile.copyWith(
            dlBackImage: base64Image,
            dlVerified: isVerified ? true : currentProfile.dlVerified,
          );
        }
        break;
      default:
        throw Exception('Unknown document type: $documentType');
    }

    await saveProfile(updatedProfile);
  }

  String? getDocument(String documentType, String side) {
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isEmpty) return null;

    switch (documentType) {
      case 'aadhaar':
        return side == 'front' ? currentProfile.aadhaarFrontImage : currentProfile.aadhaarBackImage;
      case 'pan':
        return currentProfile.panFrontImage;
      case 'dl':
        return side == 'front' ? currentProfile.dlFrontImage : currentProfile.dlBackImage;
      default:
        return null;
    }
  }

  Future<void> setLocalAvatarBase64(String? base64) async {
    await AppPreferences.instance.setAvatarBase64(base64);
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isNotEmpty) {
      final updatedProfile = currentProfile.copyWith(
        avatarUrl: base64,
        setAvatarNull: base64 == null,
      );
      await saveProfile(updatedProfile);
    }
  }

  Future<void> update({
    String? profileName,
    String? email,
    bool setEmailNull = false,
    int? age,
    bool setAgeNull = false,
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
  }) async {
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isEmpty) throw Exception('No profile loaded');

    if (profileName != null && profileName.trim().isNotEmpty) {
      final currentUser = auth.AuthRepository.instance.currentUser;
      if (currentUser != null) {
        final isAvailable = await ProfileNameRegistry.instance.updateName(
          currentUser.id,
          profileName.trim(),
        );
        if (!isAvailable) {
          throw Exception('Profile name already taken. Please choose a different name.');
        }
      }
    }

    final updatedProfile = currentProfile.copyWith(
      profileName: profileName,
      email: email,
      setEmailNull: setEmailNull,
      age: age,
      setAgeNull: setAgeNull,
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
    );

    await saveProfile(updatedProfile);
  }

  Future<void> updatePaymentProvider(String provider) async {
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isEmpty) throw Exception('No profile loaded');
    await saveProfile(currentProfile.copyWith(paymentProvider: provider));
  }

  Future<void> updateStripeAccount(String accountId) async {
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isEmpty) throw Exception('No profile loaded');
    await saveProfile(currentProfile.copyWith(stripeAccountId: accountId));
  }

  Future<void> updateRazorpayAccount(String accountId) async {
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isEmpty) throw Exception('No profile loaded');
    await saveProfile(currentProfile.copyWith(razorpayAccountId: accountId));
  }

  Future<void> updateWalletBalance(double balance) async {
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isEmpty) throw Exception('No profile loaded');
    await saveProfile(currentProfile.copyWith(walletBalance: balance));
  }

  /// Deduct AI credits (1 credit per message)
  Future<bool> deductAICredits(int amount) async {
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isEmpty) throw Exception('No profile loaded');

    if (currentProfile.aiCredits < amount) return false;

    final newCredits = currentProfile.aiCredits - amount;
    final updatedProfile = currentProfile.copyWith(aiCredits: newCredits);
    await saveProfile(updatedProfile);

    debugPrint('✅ Deducted $amount AI credits. Remaining: $newCredits');
    return true;
  }

  /// Add AI credits (purchase or reward)
  Future<void> addAICredits(int amount) async {
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isEmpty) throw Exception('No profile loaded');

    final newCredits = currentProfile.aiCredits + amount;
    final updatedProfile = currentProfile.copyWith(aiCredits: newCredits);
    await saveProfile(updatedProfile);

    debugPrint('✅ Added $amount AI credits. New balance: $newCredits');
  }

  Future<void> updateCountry(String country) async {
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isEmpty) throw Exception('No profile loaded');

    final paymentProvider = (country == 'IN' || country == 'India')
        ? 'razorpay'
        : 'stripe';

    await saveProfile(currentProfile.copyWith(
      country: country,
      paymentProvider: paymentProvider,
    ));
  }

  /// Fetch contact info of a booking partner (RLS allows this during active bookings)
  Future<Map<String, String?>> getBookingPartnerContact(String partnerId) async {
    try {
      final contactData = await _supabase
          .from('profiles_contact')
          .select('phone_number, email')
          .eq('id', partnerId)
          .maybeSingle();

      if (contactData == null) return {'phone': null, 'email': null};

      return {
        'phone': contactData['phone_number'] as String?,
        'email': contactData['email'] as String?,
      };
    } catch (e) {
      // RLS blocks access if no active booking exists
      if (kDebugMode) print('⚠️ Cannot access contact info (no active booking): $e');
      return {'phone': null, 'email': null};
    }
  }
}
