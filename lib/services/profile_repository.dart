import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'app_preferences.dart';
import 'profile_name_registry.dart';
import 'auth_repository.dart' as auth;
import 'vehicle_repository.dart';
import 'slot_repository.dart';
import 'booking_repository.dart'; // ✅ Add this import

class ProfileInfo {
  final String id; // Firebase UID
  final String profileName;
  final String? email;
  final int? age;
  final String? phone;
  final String? aadhaar;
  final String? pan;
  final String? avatarUrl;
  final String? businessType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Bank details (for receiving payments)
  final String? bankAccountHolder;
  final String? bankAccountNumber;
  final String? bankName;
  final String? bankIFSC;
  final String? bankAccountType;

  // Document images (Base64)
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
  final String paymentProvider; // 'stripe' or 'razorpay'
  final String? stripeAccountId;
  final String? razorpayAccountId;
  final double walletBalance;
  final String? country;
  
  // AI Credits for chat usage
  final int aiCredits; // Credits for AI chat (1 credit = 1 message)

  const ProfileInfo({
    required this.id,
    required this.profileName,
    this.email,
    this.age,
    this.phone,
    this.aadhaar,
    this.pan,
    this.avatarUrl,
    this.businessType,
    this.createdAt,
    this.updatedAt,
    this.bankAccountHolder,
    this.bankAccountNumber,
    this.bankName,
    this.bankIFSC,
    this.bankAccountType,
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
    this.walletBalance = 0.0,
    this.country,
    this.aiCredits = 50, // New users get 50 free credits
  });

  // Create from Supabase JSON
  factory ProfileInfo.fromJson(Map<String, dynamic> json) {
    return ProfileInfo(
      id: json['id'] as String,
      profileName: json['full_name'] as String? ?? 'Unknown User',
      email: json['email'] as String?,
      phone: json['phone_number'] as String?,
      avatarUrl: json['profile_photo_url'] as String?,
      businessType: json['business_type'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      // Map document fields
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
      // Payment provider fields
      paymentProvider: json['payment_provider'] as String? ?? 'razorpay',
      stripeAccountId: json['stripe_account_id'] as String?,
      razorpayAccountId: json['razorpay_account_id'] as String?,
      walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      country: json['country'] as String?,
      // AI Credits
      aiCredits: json['ai_credits'] as int? ?? 50, // Default 50 credits for new users
    );
  }

  // Convert to Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': profileName,
      'email': email,
      'phone_number': phone,
      'profile_photo_url': avatarUrl,
      'business_type': businessType ?? 'solo',
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
    };
  }

  ProfileInfo copyWith({
    String? id,
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
    DateTime? createdAt,
    DateTime? updatedAt,
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
    double? walletBalance,
    String? country,
    bool setCountryNull = false,
    int? aiCredits,
  }) {
    return ProfileInfo(
      id: id ?? this.id,
      profileName: profileName ?? this.profileName,
      email: setEmailNull ? null : email ?? this.email,
      age: setAgeNull ? null : age ?? this.age,
      phone: setPhoneNull ? null : phone ?? this.phone,
      aadhaar: setAadhaarNull ? null : aadhaar ?? this.aadhaar,
      pan: setPanNull ? null : pan ?? this.pan,
      avatarUrl: setAvatarNull ? null : avatarUrl ?? this.avatarUrl,
      businessType: setBusinessTypeNull
          ? null
          : businessType ?? this.businessType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      bankAccountHolder: setBankAccountHolderNull
          ? null
          : bankAccountHolder ?? this.bankAccountHolder,
      bankAccountNumber: setBankAccountNumberNull
          ? null
          : bankAccountNumber ?? this.bankAccountNumber,
      bankName: setBankNameNull ? null : bankName ?? this.bankName,
      bankIFSC: setBankIFSCNull ? null : bankIFSC ?? this.bankIFSC,
      bankAccountType: setBankAccountTypeNull
          ? null
          : bankAccountType ?? this.bankAccountType,
      aadhaarFrontImage: setAadhaarFrontNull
          ? null
          : aadhaarFrontImage ?? this.aadhaarFrontImage,
      aadhaarBackImage: setAadhaarBackNull
          ? null
          : aadhaarBackImage ?? this.aadhaarBackImage,
      panFrontImage: setPanFrontNull
          ? null
          : panFrontImage ?? this.panFrontImage,
      dlFrontImage: setDlFrontNull ? null : dlFrontImage ?? this.dlFrontImage,
      dlBackImage: setDlBackNull ? null : dlBackImage ?? this.dlBackImage,
      aadhaarVerified: aadhaarVerified ?? this.aadhaarVerified,
      panVerified: panVerified ?? this.panVerified,
      dlVerified: dlVerified ?? this.dlVerified,
      paymentProvider: paymentProvider ?? this.paymentProvider,
      stripeAccountId: setStripeAccountIdNull ? null : stripeAccountId ?? this.stripeAccountId,
      razorpayAccountId: setRazorpayAccountIdNull ? null : razorpayAccountId ?? this.razorpayAccountId,
      walletBalance: walletBalance ?? this.walletBalance,
      country: setCountryNull ? null : country ?? this.country,
      aiCredits: aiCredits ?? this.aiCredits,
    );
  }
}

class ProfileRepository {
  ProfileRepository._();

  static final ProfileRepository instance = ProfileRepository._();
  
  // Get Supabase client
  SupabaseClient get _supabase => Supabase.instance.client;

  // Current profile state
  ProfileInfo? _currentProfile;
  final ValueNotifier<ProfileInfo> profile = ValueNotifier<ProfileInfo>(
    const ProfileInfo(id: '', profileName: 'Loading...'),
  );

  Future<void> init() async {
    try {
      if (kDebugMode) print('🔧 ProfileRepository init starting...');
      await ProfileNameRegistry.instance.init();
      
      // Listen to Firebase auth state changes (CORRECT approach)
      firebase_auth.FirebaseAuth.instance.authStateChanges().listen((firebaseUser) async {
        if (firebaseUser != null) {
          if (kDebugMode) print('✅ Firebase user ready: ${firebaseUser.uid}');
          try {
            await loadProfile(firebaseUser.uid);
            if (kDebugMode) print('✅ Profile loaded for authenticated user');
            
            // IMPORTANT: Reload vehicles and posts after authentication
            // This fixes the timing issue where they load before auth completes
            if (kDebugMode) print('🔄 Reloading vehicles and posts after auth...');
            await VehicleRepository.instance.loadVehicles();
            await SlotRepository.instance.loadSlots();
            await BookingRepository.instance.refreshFromSupabase(); // ✅ Reload bookings after auth
            if (kDebugMode) print('✅ Vehicles and posts reloaded');
          } catch (e) {
            if (kDebugMode) print('⚠️ Profile not found, creating default: $e');
            // Create default profile if doesn't exist
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
      // Set fallback profile
      profile.value = const ProfileInfo(id: '', profileName: 'Guest User');
    }
  }

  Future<ProfileInfo> loadProfile(String userId) async {
    try {
      if (kDebugMode) print('🔍 Loading profile for user: $userId');
      
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle(); // Use maybeSingle() instead of single()
      
      if (response == null) {
        throw Exception('Profile not found for user: $userId');
      }
      
      if (kDebugMode) print('📊 Profile data received: $response');
      
      final profileInfo = ProfileInfo.fromJson(response);
      profile.value = profileInfo;
      _currentProfile = profileInfo;
      
      if (kDebugMode) print('✅ Profile loaded successfully: ${profileInfo.profileName}');
      return profileInfo;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to load profile: $e');
      rethrow;
    }
  }

  Future<void> saveProfile(ProfileInfo profileInfo) async {
    try {
      await _supabase
          .from('profiles')
          .upsert(profileInfo.toJson())
          .eq('id', profileInfo.id);
      
      profile.value = profileInfo;
      _currentProfile = profileInfo;
      
      if (kDebugMode) print('✅ Saved profile for user: ${profileInfo.id}');
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
    if (currentProfile.id.isEmpty) {
      throw Exception('No profile loaded');
    }

    ProfileInfo updatedProfile;
    
    // Update profile with document data
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
        return side == 'front'
            ? currentProfile.aadhaarFrontImage
            : currentProfile.aadhaarBackImage;
      case 'pan':
        return currentProfile.panFrontImage;
      case 'dl':
        return side == 'front'
            ? currentProfile.dlFrontImage
            : currentProfile.dlBackImage;
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
    if (currentProfile.id.isEmpty) {
      throw Exception('No profile loaded');
    }

    // If updating profile name, check uniqueness
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

  // Payment provider update methods
  Future<void> updatePaymentProvider(String provider) async {
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isEmpty) {
      throw Exception('No profile loaded');
    }

    final updatedProfile = currentProfile.copyWith(
      paymentProvider: provider,
    );

    await saveProfile(updatedProfile);
  }

  Future<void> updateStripeAccount(String accountId) async {
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isEmpty) {
      throw Exception('No profile loaded');
    }

    final updatedProfile = currentProfile.copyWith(
      stripeAccountId: accountId,
    );

    await saveProfile(updatedProfile);
  }

  Future<void> updateRazorpayAccount(String accountId) async {
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isEmpty) {
      throw Exception('No profile loaded');
    }

    final updatedProfile = currentProfile.copyWith(
      razorpayAccountId: accountId,
    );

    await saveProfile(updatedProfile);
  }

  Future<void> updateWalletBalance(double balance) async {
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isEmpty) {
      throw Exception('No profile loaded');
    }

    final updatedProfile = currentProfile.copyWith(
      walletBalance: balance,
    );

    await saveProfile(updatedProfile);
  }
  
  /// Deduct AI credits (1 credit per message)
  Future<bool> deductAICredits(int amount) async {
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isEmpty) {
      throw Exception('No profile loaded');
    }
    
    // Check if user has enough credits
    if (currentProfile.aiCredits < amount) {
      return false; // Not enough credits
    }
    
    final newCredits = currentProfile.aiCredits - amount;
    final updatedProfile = currentProfile.copyWith(
      aiCredits: newCredits,
    );
    
    await saveProfile(updatedProfile);
    
    // Also update in Supabase
    try {
      await _supabase
          .from('profiles')
          .update({'ai_credits': newCredits})
          .eq('id', currentProfile.id);
      debugPrint('✅ Deducted $amount AI credits. Remaining: $newCredits');
    } catch (e) {
      debugPrint('⚠️ Failed to update AI credits in Supabase: $e');
    }
    
    return true; // Success
  }
  
  /// Add AI credits (purchase or reward)
  Future<void> addAICredits(int amount) async {
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isEmpty) {
      throw Exception('No profile loaded');
    }
    
    final newCredits = currentProfile.aiCredits + amount;
    final updatedProfile = currentProfile.copyWith(
      aiCredits: newCredits,
    );
    
    await saveProfile(updatedProfile);
    
    // Also update in Supabase
    try {
      await _supabase
          .from('profiles')
          .update({'ai_credits': newCredits})
          .eq('id', currentProfile.id);
      debugPrint('✅ Added $amount AI credits. New balance: $newCredits');
    } catch (e) {
      debugPrint('⚠️ Failed to update AI credits in Supabase: $e');
    }
  }

  Future<void> updateCountry(String country) async {
    final currentProfile = _currentProfile ?? profile.value;
    if (currentProfile.id.isEmpty) {
      throw Exception('No profile loaded');
    }

    // Auto-set payment provider based on country
    final paymentProvider = (country == 'IN' || country == 'India') 
        ? 'razorpay' 
        : 'stripe';

    final updatedProfile = currentProfile.copyWith(
      country: country,
      paymentProvider: paymentProvider,
    );

    await saveProfile(updatedProfile);
  }
}
