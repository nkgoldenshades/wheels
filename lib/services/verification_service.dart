import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_repository.dart';

/// Service to manage optional document verification
/// All documents are truly optional - user can skip
/// Verification only available AFTER premium plan purchase
class VerificationService {
  static final VerificationService _instance = VerificationService._internal();

  factory VerificationService() => _instance;
  VerificationService._internal();

  static VerificationService get instance => _instance;

  final ImagePicker _picker = ImagePicker();
  final supabase = Supabase.instance.client;

  /// Upload document image to Supabase storage
  /// Returns the public URL of the uploaded image
  Future<String?> uploadDocumentImage({
    required String
    documentType, // 'rc_book', 'insurance', 'driving_license', 'national_id', 'tax_id'
    required String userId,
  }) async {
    try {
      if (kDebugMode) print('📸 Picking image for $documentType...');

      // Pick image from gallery
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Compress to 80% quality
        requestFullMetadata: false,
      );

      if (image == null) {
        if (kDebugMode) print('⚠️ Image selection cancelled');
        return null;
      }

      if (kDebugMode) print('📤 Uploading $documentType to storage...');

      // Read image bytes
      final bytes = await image.readAsBytes();

      // Create unique file path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${documentType}_$timestamp.jpg';
      final filePath = 'verification_documents/$userId/$fileName';

      // Upload to Supabase storage bucket: 'verification-documents'
      await supabase.storage
          .from('verification-documents')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      if (kDebugMode) print('✅ Document uploaded: $filePath');

      // Get public URL
      final publicUrl = supabase.storage
          .from('verification-documents')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      if (kDebugMode) print('❌ Failed to upload document: $e');
      rethrow;
    }
  }

  /// Update profile with verification document URLs
  /// Only updates the fields that have new images
  Future<void> updateVerificationDocuments({
    required String documentType,
    required String imageUrl,
  }) async {
    try {
      final profile = ProfileRepository.instance.profile.value;

      // Map document type to profile fields
      final updateData = <String, dynamic>{};

      switch (documentType) {
        case 'rc_book':
          // Store RC book info in available fields
          updateData['aadhaar_front_image'] = imageUrl;
          break;
        case 'insurance':
          updateData['pan_front_image'] = imageUrl;
          break;
        case 'driving_license':
          updateData['dl_front_image'] = imageUrl;
          updateData['dl_verified'] = false; // Waiting for verification
          break;
        case 'national_id':
          updateData['aadhaar'] = imageUrl;
          updateData['aadhaar_verified'] = false;
          break;
        case 'tax_id':
          updateData['pan'] = imageUrl;
          updateData['pan_verified'] = false;
          break;
      }

      if (updateData.isEmpty) return;

      if (kDebugMode) print('💾 Updating profile with $documentType...');

      // Update profiles_private table
      await supabase
          .from('profiles_private')
          .update(updateData)
          .eq('id', profile.id);

      if (kDebugMode) print('✅ Profile updated with $documentType');

      // Reload profile to reflect changes
      await ProfileRepository.instance.loadProfile(profile.id);
    } catch (e) {
      if (kDebugMode) print('❌ Failed to update verification: $e');
      rethrow;
    }
  }

  /// Get verification badge status
  /// Returns true if enough documents are verified
  bool getVerificationBadgeStatus() {
    final profile = ProfileRepository.instance.profile.value;

    // Check if at least 2 documents are verified
    int verifiedCount = 0;
    if (profile.aadhaarVerified) verifiedCount++;
    if (profile.panVerified) verifiedCount++;
    if (profile.dlVerified) verifiedCount++;

    return verifiedCount >= 2; // Badge requires at least 2 verified docs
  }

  /// Get verification progress (0-5)
  int getVerificationProgress() {
    final profile = ProfileRepository.instance.profile.value;

    int count = 0;
    if (profile.aadhaarFrontImage != null &&
        profile.aadhaarFrontImage!.isNotEmpty) {
      count++;
    }
    if (profile.panFrontImage != null && profile.panFrontImage!.isNotEmpty) {
      count++;
    }
    if (profile.dlFrontImage != null && profile.dlFrontImage!.isNotEmpty) {
      count++;
    }
    if (profile.aadhaar != null && profile.aadhaar!.isNotEmpty) count++;
    if (profile.pan != null && profile.pan!.isNotEmpty) count++;

    return count;
  }

  /// Check if user has premium plan (required for verification)
  bool canAccessVerification() {
    final profile = ProfileRepository.instance.profile.value;
    return profile.subscriptionPlan == 'premium' ||
        profile.subscriptionPlan == 'expert';
  }

  /// Get user-friendly message about verification status
  String getVerificationMessage() {
    final progress = getVerificationProgress();

    if (!canAccessVerification()) {
      return 'Upgrade to Premium to unlock verification';
    }

    if (progress == 0) {
      return 'No documents uploaded yet. Add them to increase trust!';
    } else if (progress == 5) {
      return '✅ All documents verified! You have the verified badge.';
    } else {
      return '✅ $progress of 5 documents verified';
    }
  }
}
