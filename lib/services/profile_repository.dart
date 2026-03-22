import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_preferences.dart';
import 'profile_name_registry.dart';
import 'auth_repository.dart';

class ProfileInfo {
  final String profileName;
  final int? age;
  final String? phone;
  final String? aadhaar;
  final String? pan;
  final String? avatarUrl;
  final String? businessType;

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

  const ProfileInfo({
    required this.profileName,
    this.age,
    this.phone,
    this.aadhaar,
    this.pan,
    this.avatarUrl,
    this.businessType,
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
  });

  ProfileInfo copyWith({
    String? profileName,
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
  }) {
    return ProfileInfo(
      profileName: profileName ?? this.profileName,
      age: setAgeNull ? null : age ?? this.age,
      phone: setPhoneNull ? null : phone ?? this.phone,
      aadhaar: setAadhaarNull ? null : aadhaar ?? this.aadhaar,
      pan: setPanNull ? null : pan ?? this.pan,
      avatarUrl: setAvatarNull ? null : avatarUrl ?? this.avatarUrl,
      businessType: setBusinessTypeNull
          ? null
          : businessType ?? this.businessType,
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
    );
  }
}

class ProfileRepository {
  ProfileRepository._();

  static final ProfileRepository instance = ProfileRepository._();

  static const String _storageKeyProfileName = 'profile_profile_name';
  static const String _storageKeyProfileAge = 'profile_age';
  static const String _storageKeyProfilePhone = 'profile_phone';
  static const String _storageKeyProfileAadhaar = 'profile_aadhaar';
  static const String _storageKeyProfilePan = 'profile_pan';
  static const String _storageKeyBusinessType = 'profile_business_type';

  final ValueNotifier<ProfileInfo> profile = ValueNotifier<ProfileInfo>(
    const ProfileInfo(profileName: 'John Doe'),
  );

  Future<void> init() async {
    await ProfileNameRegistry.instance.init();
    await _loadCore();
    final avatar = AppPreferences.instance.avatarBase64.value;
    if (avatar != null && avatar.trim().isNotEmpty) {
      profile.value = profile.value.copyWith(avatarUrl: avatar);
    }

    // Load document images from SharedPreferences
    await _loadDocuments();
    
    // Register current profile name if user is logged in
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser != null && profile.value.profileName.isNotEmpty) {
      await ProfileNameRegistry.instance.registerName(
        currentUser.id,
        profile.value.profileName,
      );
    }
  }

  Future<void> _loadCore() async {
    final prefs = await SharedPreferences.getInstance();
    final profileName = prefs.getString(_storageKeyProfileName);
    final age = prefs.getInt(_storageKeyProfileAge);
    final phone = prefs.getString(_storageKeyProfilePhone);
    final aadhaar = prefs.getString(_storageKeyProfileAadhaar);
    final pan = prefs.getString(_storageKeyProfilePan);
    final businessType = prefs.getString(_storageKeyBusinessType);

    profile.value = profile.value.copyWith(
      profileName: (profileName == null || profileName.trim().isEmpty)
          ? null
          : profileName,
      age: age,
      setAgeNull: age == null,
      phone: (phone == null || phone.trim().isEmpty) ? null : phone,
      setPhoneNull: phone == null,
      aadhaar: (aadhaar == null || aadhaar.trim().isEmpty) ? null : aadhaar,
      setAadhaarNull: aadhaar == null,
      pan: (pan == null || pan.trim().isEmpty) ? null : pan,
      setPanNull: pan == null,
      businessType: (businessType == null || businessType.trim().isEmpty)
          ? null
          : businessType,
      setBusinessTypeNull: businessType == null,
    );
  }

  Future<void> _saveCore(ProfileInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKeyProfileName, info.profileName);
    if (info.age == null) {
      await prefs.remove(_storageKeyProfileAge);
    } else {
      await prefs.setInt(_storageKeyProfileAge, info.age!);
    }
    if (info.phone == null || info.phone!.trim().isEmpty) {
      await prefs.remove(_storageKeyProfilePhone);
    } else {
      await prefs.setString(_storageKeyProfilePhone, info.phone!);
    }
    if (info.aadhaar == null || info.aadhaar!.trim().isEmpty) {
      await prefs.remove(_storageKeyProfileAadhaar);
    } else {
      await prefs.setString(_storageKeyProfileAadhaar, info.aadhaar!);
    }
    if (info.pan == null || info.pan!.trim().isEmpty) {
      await prefs.remove(_storageKeyProfilePan);
    } else {
      await prefs.setString(_storageKeyProfilePan, info.pan!);
    }
    if (info.businessType == null || info.businessType!.trim().isEmpty) {
      await prefs.remove(_storageKeyBusinessType);
    } else {
      await prefs.setString(_storageKeyBusinessType, info.businessType!);
    }
  }

  Future<void> _loadDocuments() async {
    final prefs = await SharedPreferences.getInstance();

    final aadhaarFront = prefs.getString('document_aadhaar_front');
    final aadhaarBack = prefs.getString('document_aadhaar_back');
    final panFront = prefs.getString('document_pan_front');
    final dlFront = prefs.getString('document_dl_front');
    final dlBack = prefs.getString('document_dl_back');

    final aadhaarVerified = prefs.getBool('document_aadhaar_verified') ?? false;
    final panVerified = prefs.getBool('document_pan_verified') ?? false;
    final dlVerified = prefs.getBool('document_dl_verified') ?? false;

    profile.value = profile.value.copyWith(
      aadhaarFrontImage: aadhaarFront,
      aadhaarBackImage: aadhaarBack,
      panFrontImage: panFront,
      dlFrontImage: dlFront,
      dlBackImage: dlBack,
      aadhaarVerified: aadhaarVerified,
      panVerified: panVerified,
      dlVerified: dlVerified,
    );
  }

  Future<void> saveDocument(
    String documentType,
    String side,
    String base64Image, {
    bool isVerified = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'document_${documentType}_$side';
    await prefs.setString(key, base64Image);

    // Update verification status if verified
    if (isVerified) {
      await prefs.setBool('document_${documentType}_verified', true);
    }

    // Update profile value
    switch (documentType) {
      case 'aadhaar':
        if (side == 'front') {
          profile.value = profile.value.copyWith(
            aadhaarFrontImage: base64Image,
            aadhaarVerified: isVerified ? true : profile.value.aadhaarVerified,
          );
        } else {
          profile.value = profile.value.copyWith(
            aadhaarBackImage: base64Image,
            aadhaarVerified: isVerified ? true : profile.value.aadhaarVerified,
          );
        }
        break;
      case 'pan':
        profile.value = profile.value.copyWith(
          panFrontImage: base64Image,
          panVerified: isVerified ? true : profile.value.panVerified,
        );
        break;
      case 'dl':
        if (side == 'front') {
          profile.value = profile.value.copyWith(
            dlFrontImage: base64Image,
            dlVerified: isVerified ? true : profile.value.dlVerified,
          );
        } else {
          profile.value = profile.value.copyWith(
            dlBackImage: base64Image,
            dlVerified: isVerified ? true : profile.value.dlVerified,
          );
        }
        break;
    }
  }

  String? getDocument(String documentType, String side) {
    switch (documentType) {
      case 'aadhaar':
        return side == 'front'
            ? profile.value.aadhaarFrontImage
            : profile.value.aadhaarBackImage;
      case 'pan':
        return profile.value.panFrontImage;
      case 'dl':
        return side == 'front'
            ? profile.value.dlFrontImage
            : profile.value.dlBackImage;
      default:
        return null;
    }
  }

  Future<void> setLocalAvatarBase64(String? base64) async {
    await AppPreferences.instance.setAvatarBase64(base64);
    await update(avatarUrl: base64, setAvatarNull: base64 == null);
  }

  Future<void> update({
    String? profileName,
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
    // If updating profile name, check uniqueness
    if (profileName != null && profileName.trim().isNotEmpty) {
      final currentUser = AuthRepository.instance.currentUser;
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
    
    profile.value = profile.value.copyWith(
      profileName: profileName,
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

    await _saveCore(profile.value);
  }
}
