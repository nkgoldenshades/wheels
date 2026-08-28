import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'app_preferences.dart';
import 'profile_name_registry.dart';
import 'auth_repository.dart' as auth;
import 'vehicle_repository.dart';
import 'slot_repository.dart';
import 'booking_repository.dart';
import '../models/demand_plan.dart';

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

  // ── Rating fields (profiles_public) ───────────────────────
  // Provider ratings (when providing service)
  final double providerRating;
  final int providerTotalReviews;
  final int providerTotalTrips;
  // Customer ratings (when using service)
  final double customerRating;
  final int customerTotalReviews;
  final int customerTotalTrips;

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
  final String?
  bankCurrency; // Currency of connected bank account (INR/USD/GBP/EUR)
  // Bank details - REMOVED for PCI-DSS compliance
  // Bank account details are now managed by Razorpay/Stripe directly
  // We only store account IDs, not actual bank details
  // Personal
  final String? gender;
  final DateTime? dateOfBirth;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  // Subscription
  final String subscriptionPlan; // 'basic', 'premium', 'expert'
  final DateTime? subscriptionExpiresAt;
  final String? subscriptionPaymentId;

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
    // Rating fields
    this.providerRating = 0.0,
    this.providerTotalReviews = 0,
    this.providerTotalTrips = 0,
    this.customerRating = 0.0,
    this.customerTotalReviews = 0,
    this.customerTotalTrips = 0,
    // Contact
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
    this.bankCurrency,
    this.gender,
    this.dateOfBirth,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.subscriptionPlan = 'basic',
    this.subscriptionExpiresAt,
    this.subscriptionPaymentId,
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
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      // Rating fields
      providerRating: (json['provider_rating'] as num?)?.toDouble() ?? 0.0,
      providerTotalReviews: json['provider_total_reviews'] as int? ?? 0,
      providerTotalTrips: json['provider_total_trips'] as int? ?? 0,
      customerRating: (json['customer_rating'] as num?)?.toDouble() ?? 0.0,
      customerTotalReviews: json['customer_total_reviews'] as int? ?? 0,
      customerTotalTrips: json['customer_total_trips'] as int? ?? 0,
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
      bankCurrency: json['bank_currency'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'] as String)
          : null,
      addressLine1: json['address_line1'] as String?,
      addressLine2: json['address_line2'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      subscriptionPlan: json['subscription_plan'] as String? ?? 'basic',
      subscriptionExpiresAt: json['subscription_expires_at'] != null
          ? DateTime.parse(json['subscription_expires_at'] as String)
          : null,
      subscriptionPaymentId: json['subscription_payment_id'] as String?,
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
    // Rating fields (usually updated by system, not user)
    'provider_rating': providerRating,
    'provider_total_reviews': providerTotalReviews,
    'provider_total_trips': providerTotalTrips,
    'customer_rating': customerRating,
    'customer_total_reviews': customerTotalReviews,
    'customer_total_trips': customerTotalTrips,
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
    if (bankCurrency != null) 'bank_currency': bankCurrency,
    if (gender != null) 'gender': gender,
    if (dateOfBirth != null)
      'date_of_birth': dateOfBirth!.toIso8601String().split('T').first,
    if (addressLine1 != null) 'address_line1': addressLine1,
    if (addressLine2 != null) 'address_line2': addressLine2,
    if (city != null) 'city': city,
    if (state != null) 'state': state,
    'subscription_plan': subscriptionPlan,
    if (subscriptionExpiresAt != null)
      'subscription_expires_at': subscriptionExpiresAt!.toIso8601String(),
    if (subscriptionPaymentId != null)
      'subscription_payment_id': subscriptionPaymentId,
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
    String? bankCurrency,
    bool setBankCurrencyNull = false,
    String? gender,
    DateTime? dateOfBirth,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? subscriptionPlan,
    DateTime? subscriptionExpiresAt,
    String? subscriptionPaymentId,
  }) {
    return ProfileInfo(
      id: id ?? this.id,
      profileName: profileName ?? this.profileName,
      avatarUrl: setAvatarNull ? null : avatarUrl ?? this.avatarUrl,
      businessType: setBusinessTypeNull
          ? null
          : businessType ?? this.businessType,
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
      aadhaarFrontImage: setAadhaarFrontNull
          ? null
          : aadhaarFrontImage ?? this.aadhaarFrontImage,
      aadhaarBackImage: setAadhaarBackNull
          ? null
          : aadhaarBackImage ?? this.aadhaarBackImage,
      panFrontImage: setPanFrontNull
          ? null
          : panFrontImage ?? this.panFrontImage,
      panBackImage: setPanBackNull ? null : panBackImage ?? this.panBackImage,
      dlFrontImage: setDlFrontNull ? null : dlFrontImage ?? this.dlFrontImage,
      dlBackImage: setDlBackNull ? null : dlBackImage ?? this.dlBackImage,
      aadhaarVerified: aadhaarVerified ?? this.aadhaarVerified,
      panVerified: panVerified ?? this.panVerified,
      dlVerified: dlVerified ?? this.dlVerified,
      paymentProvider: paymentProvider ?? this.paymentProvider,
      stripeAccountId: setStripeNull
          ? null
          : stripeAccountId ?? this.stripeAccountId,
      razorpayAccountId: setRazorpayNull
          ? null
          : razorpayAccountId ?? this.razorpayAccountId,
      bankCurrency: setBankCurrencyNull
          ? null
          : bankCurrency ?? this.bankCurrency,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      subscriptionExpiresAt:
          subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      subscriptionPaymentId:
          subscriptionPaymentId ?? this.subscriptionPaymentId,
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

      firebase_auth.FirebaseAuth.instance.authStateChanges().listen((
        firebaseUser,
      ) async {
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
              profileName:
                  firebaseUser.displayName ??
                  firebaseUser.email?.split('@').first ??
                  'User',
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
        _supabase
            .from('profiles_public')
            .select()
            .eq('id', userId)
            .maybeSingle(),
        _supabase
            .from('profiles_contact')
            .select()
            .eq('profile_id', userId)
            .maybeSingle(),
        _supabase
            .from('profiles_private')
            .select()
            .eq('profile_id', userId)
            .maybeSingle(),
      ]);

      final publicData = results[0];
      if (publicData == null) {
        throw Exception('Profile not found for user: $userId');
      }

      final merged = {
        ...publicData,
        if (results[1] != null) ...results[1]!,
        if (results[2] != null) ...results[2]!,
      };

      final profileInfo = ProfileInfo.fromJson(merged);

      // Fix for existing users: If profile name is "User" or "Unknown User",
      // try to update it from Firebase displayName
      if ((profileInfo.profileName == 'User' ||
              profileInfo.profileName == 'Unknown User') &&
          firebase_auth.FirebaseAuth.instance.currentUser?.displayName !=
              null) {
        final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser!;
        if (kDebugMode) {
          print(
            '⚠️ Fixing profile name from Firebase: ${firebaseUser.displayName}',
          );
        }
        final updatedInfo = profileInfo.copyWith(
          profileName: firebaseUser.displayName!,
        );
        await saveProfile(updatedInfo);
        profile.value = updatedInfo;
        _currentProfile = updatedInfo;
      } else {
        profile.value = profileInfo;
        _currentProfile = profileInfo;
      }

      // CRITICAL: Sync AppPreferences currency with payment provider
      // When profile loads, ensure AppPreferences matches the payment provider
      if (profileInfo.paymentProvider == 'razorpay') {
        // Razorpay only supports INR
        await AppPreferences.instance.setCurrencyCode('INR');
        debugPrint('✅ Profile loaded with Razorpay: Currency synced to INR');
      } else if (profileInfo.bankCurrency != null &&
          profileInfo.bankCurrency!.isNotEmpty) {
        // For Stripe or other providers with bankCurrency, sync that
        await AppPreferences.instance.setCurrencyCode(
          profileInfo.bankCurrency!.toUpperCase(),
        );
        debugPrint(
          '✅ Profile loaded with bankCurrency: Currency synced to ${profileInfo.bankCurrency}',
        );
      } else {
        // No payment provider or bank currency set - default to INR for India-based users
        await AppPreferences.instance.setCurrencyCode('INR');
        debugPrint('✅ No payment provider set: Currency defaulted to INR');
      }

      if (kDebugMode) print('✅ Profile loaded: ${profile.value.profileName}');
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
        _supabase
            .from('profiles_contact')
            .upsert(contactJson, onConflict: 'profile_id'),
        _supabase
            .from('profiles_private')
            .upsert(privateJson, onConflict: 'profile_id'),
      ]);

      profile.value = profileInfo;
      _currentProfile = profileInfo;

      if (kDebugMode) print('✅ Saved profile: ${profileInfo.id}');
    } catch (e) {
      if (kDebugMode) print('❌ Failed to save profile: $e');
      rethrow;
    }
  }

  /// Helper method to ensure profile is loaded for new users
  Future<ProfileInfo> _ensureProfileLoaded() async {
    final p = _currentProfile ?? profile.value;
    if (p.id.isNotEmpty) return p;

    // For new users, try to reload profile first
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      try {
        await loadProfile(firebaseUser.uid);
        final reloadedProfile = _currentProfile ?? profile.value;
        if (reloadedProfile.id.isNotEmpty) return reloadedProfile;
      } catch (e) {
        debugPrint('⚠️ Could not load profile: $e');
      }
    }
    throw Exception('No profile loaded. Please try logging in again.');
  }

  Future<void> saveDocument(
    String documentType,
    String side,
    String base64Image, {
    bool isVerified = false,
  }) async {
    final p = await _ensureProfileLoaded();

    ProfileInfo updated;
    switch (documentType) {
      case 'aadhaar':
        updated = side == 'front'
            ? p.copyWith(
                aadhaarFrontImage: base64Image,
                aadhaarVerified: isVerified ? true : p.aadhaarVerified,
              )
            : p.copyWith(
                aadhaarBackImage: base64Image,
                aadhaarVerified: isVerified ? true : p.aadhaarVerified,
              );
        break;
      case 'pan':
        updated = side == 'front'
            ? p.copyWith(
                panFrontImage: base64Image,
                panVerified: isVerified ? true : p.panVerified,
              )
            : p.copyWith(
                panBackImage: base64Image,
                panVerified: isVerified ? true : p.panVerified,
              );
        break;
      case 'dl':
        updated = side == 'front'
            ? p.copyWith(
                dlFrontImage: base64Image,
                dlVerified: isVerified ? true : p.dlVerified,
              )
            : p.copyWith(
                dlBackImage: base64Image,
                dlVerified: isVerified ? true : p.dlVerified,
              );
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
      case 'aadhaar':
        return side == 'front' ? p.aadhaarFrontImage : p.aadhaarBackImage;
      case 'pan':
        return side == 'front' ? p.panFrontImage : p.panBackImage;
      case 'dl':
        return side == 'front' ? p.dlFrontImage : p.dlBackImage;
      default:
        return null;
    }
  }

  /// Upload avatar to Supabase Storage and update profile
  Future<void> setLocalAvatarBase64(String? base64) async {
    if (base64 == null) {
      // Clear avatar
      await AppPreferences.instance.setAvatarBase64(null);
      final p = await _ensureProfileLoaded();
      await saveProfile(p.copyWith(avatarUrl: null, setAvatarNull: true));
      return;
    }

    try {
      final userId = auth.AuthRepository.instance.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Decode base64 to bytes
      Uint8List bytes = base64Decode(
        base64.startsWith('data:image') ? base64.split(',')[1] : base64,
      );

      // Compress image using Flutter's built-in codec
      // This reduces file size significantly (e.g., 400KB → 50KB)
      try {
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: 512, // Resize to max 512px width
          targetHeight: 512, // Resize to max 512px height
        );
        final frame = await codec.getNextFrame();
        final byteData = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (byteData != null) {
          bytes = byteData.buffer.asUint8List();
          debugPrint(
            '🗜️ Compressed avatar: ${base64.length} → ${bytes.length} bytes',
          );
        }
      } catch (e) {
        debugPrint('⚠️ Image compression failed, using original: $e');
      }

      // Upload to Supabase Storage profile_media bucket
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$userId/avatar_$timestamp.jpg';

      await Supabase.instance.client.storage
          .from('profile_media')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Get public URL
      final publicUrl = Supabase.instance.client.storage
          .from('profile_media')
          .getPublicUrl(path);

      debugPrint('✅ Uploaded avatar to Storage: $publicUrl');

      // Save public URL to profile (not base64)
      await AppPreferences.instance.setAvatarBase64(null); // Clear local base64
      final p = await _ensureProfileLoaded();
      await saveProfile(p.copyWith(avatarUrl: publicUrl));
    } catch (e) {
      debugPrint('❌ Failed to upload avatar to Storage: $e');
      // Fallback: save base64 locally
      await AppPreferences.instance.setAvatarBase64(base64);
      final p = await _ensureProfileLoaded();
      await saveProfile(p.copyWith(avatarUrl: base64));
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
    final currentProfile = await _ensureProfileLoaded();

    if (profileName != null && profileName.trim().isNotEmpty) {
      final currentUser = auth.AuthRepository.instance.currentUser;
      if (currentUser != null) {
        final isAvailable = await ProfileNameRegistry.instance.updateName(
          currentUser.id,
          profileName.trim(),
        );
        if (!isAvailable) {
          throw Exception(
            'Profile name already taken. Please choose a different name.',
          );
        }
      }
    }

    await saveProfile(
      currentProfile.copyWith(
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
      ),
    );
  }

  Future<void> updatePaymentProvider(String provider) async {
    final p = await _ensureProfileLoaded();
    await saveProfile(p.copyWith(paymentProvider: provider));

    // CRITICAL: Sync AppPreferences currency with payment provider
    // Razorpay only supports INR, so force it
    if (provider == 'razorpay') {
      await AppPreferences.instance.setCurrencyCode('INR');
      debugPrint('✅ Razorpay selected: Currency set to INR');
    }
  }

  Future<void> updateStripeAccount(String accountId, {String? currency}) async {
    final p = await _ensureProfileLoaded();

    // Determine bank currency from Stripe account
    // Priority:
    // 1. Explicit currency parameter (if provided)
    // 2. Existing bank currency (if already set)
    // 3. Default to USD for test accounts (temporary until Stripe API integration)
    String? bankCurrency;

    if (currency != null && currency.isNotEmpty) {
      // Use provided currency (highest priority)
      bankCurrency = currency.toUpperCase();
      debugPrint('✅ Using provided currency: $bankCurrency');
    } else if (p.bankCurrency != null && p.bankCurrency!.isNotEmpty) {
      // Keep existing currency if already set (don't override)
      bankCurrency = p.bankCurrency;
      debugPrint('✅ Keeping existing currency: $bankCurrency');
    } else {
      // Default fallback for new accounts
      // TODO: Fetch actual currency from Stripe API using account ID
      // For now, default based on account type
      if (accountId.startsWith('acct_test_')) {
        // Test accounts - default to USD
        bankCurrency = 'USD';
        debugPrint(
          '⚠️ Test account detected, defaulting to USD. Set currency manually if needed.',
        );
      } else {
        // Live accounts - require explicit currency or keep existing
        bankCurrency = p.bankCurrency ?? 'USD';
        debugPrint(
          '⚠️ Live account without currency. Defaulting to: $bankCurrency',
        );
      }
    }

    await saveProfile(
      p.copyWith(stripeAccountId: accountId, bankCurrency: bankCurrency),
    );

    debugPrint(
      '✅ Stripe account updated: $accountId (Currency: $bankCurrency)',
    );
  }

  Future<void> updateRazorpayAccount(String accountId) async {
    final p = await _ensureProfileLoaded();

    // Razorpay is India-only, always INR
    await saveProfile(
      p.copyWith(razorpayAccountId: accountId, bankCurrency: 'INR'),
    );

    // CRITICAL: Sync AppPreferences currency when Razorpay account is set
    await AppPreferences.instance.setCurrencyCode('INR');
    debugPrint('✅ Razorpay account linked: Currency forced to INR');
  }

  Future<void> updateCountry(String country) async {
    final p = await _ensureProfileLoaded();
    await saveProfile(p.copyWith(country: country));
  }

  Future<bool> deductAICredits(int amount) async {
    final p = await _ensureProfileLoaded();
    if (p.aiCredits < amount) return false;
    await saveProfile(p.copyWith(aiCredits: p.aiCredits - amount));
    debugPrint(
      '✅ Deducted $amount credits. Remaining: ${p.aiCredits - amount}',
    );
    return true;
  }

  Future<void> addAICredits(int amount) async {
    final p = await _ensureProfileLoaded();
    await saveProfile(p.copyWith(aiCredits: p.aiCredits + amount));
    debugPrint('✅ Added $amount credits. New balance: ${p.aiCredits + amount}');
  }

  /// Update subscription plan after successful payment
  Future<void> updateSubscription({
    required String plan,
    required DateTime expiresAt,
    required String paymentId,
  }) async {
    final p = await _ensureProfileLoaded();

    await saveProfile(
      p.copyWith(
        subscriptionPlan: plan,
        subscriptionExpiresAt: expiresAt,
        subscriptionPaymentId: paymentId,
      ),
    );

    debugPrint('✅ Subscription updated: $plan (expires: $expiresAt)');
  }

  Future<Map<String, String?>> getBookingPartnerContact(
    String partnerId,
  ) async {
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

/// Extension to check if profile is verified
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

    if (count == 0) return 0;
    if (count < 3) return 1;
    return 2;
  }

  /// Returns a list of verified documents
  List<String> get verifiedDocuments {
    final docs = <String>[];
    if (aadhaarVerified) docs.add('Aadhaar');
    if (panVerified) docs.add('PAN');
    if (dlVerified) docs.add('Driving License');
    return docs;
  }

  /// Returns true if profile qualifies as expert
  bool get isExpert {
    return subscriptionPlan == 'expert' && hasActiveSubscription;
  }

  /// Returns true if profile has enough experience to potentially qualify for expert
  bool get hasExpertLevelExperience {
    final providerQualifies = providerTotalTrips >= 50 && providerRating >= 4.5;
    final customerQualifies = customerTotalTrips >= 50 && customerRating >= 4.5;
    return providerQualifies || customerQualifies;
  }

  /// Returns true if profile meets the demand plan requirements
  bool meetsDemandPlan(DemandPlan plan) {
    switch (plan) {
      case DemandPlan.basic:
        return true;
      case DemandPlan.verified:
        return isVerified;
      case DemandPlan.expert:
        return isExpert;
    }
  }

  /// Returns true if user has an active paid subscription
  bool get hasActiveSubscription {
    if (subscriptionPlan == 'basic') return false;
    if (subscriptionExpiresAt == null) return false;
    return subscriptionExpiresAt!.isAfter(DateTime.now());
  }

  /// Returns true if user has Premium plan (active)
  bool get isPremium {
    return subscriptionPlan == 'premium' && hasActiveSubscription;
  }

  /// Returns true if user has Expert plan (active)
  bool get isExpertSubscriber {
    return subscriptionPlan == 'expert' && hasActiveSubscription;
  }
}
