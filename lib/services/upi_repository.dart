import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_repository.dart';

/// Manages UPI ID storage and retrieval for payouts
/// Simple & clean - UPI ID only (no noise)
class UPIRepository {
  UPIRepository._();
  static final UPIRepository instance = UPIRepository._();

  final ValueNotifier<String?> upiId = ValueNotifier<String?>(null);

  /// Load user's UPI ID from Supabase
  Future<void> loadUPIId() async {
    try {
      final authUser = AuthRepository.instance.currentUser;
      if (authUser == null) {
        upiId.value = null;
        return;
      }

      final response = await Supabase.instance.client
          .from('profiles_private')
          .select('upi_id')
          .eq('profile_id', authUser.id)
          .maybeSingle();

      if (response != null) {
        upiId.value = response['upi_id'] as String?;
        debugPrint('✅ [UPIRepository] Loaded UPI ID: ${upiId.value}');
      }
    } catch (e) {
      debugPrint('❌ [UPIRepository] Error loading UPI ID: $e');
    }
  }

  /// Save user's UPI ID to Supabase
  /// Validates format: user@upi or user@bank
  Future<bool> saveUPIId(String newUpiId) async {
    try {
      final authUser = AuthRepository.instance.currentUser;
      if (authUser == null) {
        debugPrint('❌ [UPIRepository] No authenticated user');
        return false;
      }

      // Validate UPI format (basic check)
      if (!_isValidUPI(newUpiId)) {
        debugPrint('❌ [UPIRepository] Invalid UPI format: $newUpiId');
        return false;
      }

      // Update in Supabase
      await Supabase.instance.client
          .from('profiles_private')
          .update({'upi_id': newUpiId})
          .eq('profile_id', authUser.id);

      // Update local
      upiId.value = newUpiId;

      debugPrint('✅ [UPIRepository] UPI ID saved: $newUpiId');
      return true;
    } catch (e) {
      debugPrint('❌ [UPIRepository] Error saving UPI ID: $e');
      return false;
    }
  }

  /// Validate UPI ID format
  /// Valid formats: user@upi, user@okhdfcbank, etc.
  bool _isValidUPI(String upi) {
    final regex = RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9]+$');
    return regex.hasMatch(upi) && upi.length >= 5 && upi.length <= 60;
  }

  /// Check if UPI ID is saved
  bool hasUPIId() => upiId.value != null && upiId.value!.isNotEmpty;

  /// Clear UPI ID
  Future<bool> clearUPIId() async {
    try {
      final authUser = AuthRepository.instance.currentUser;
      if (authUser == null) return false;

      await Supabase.instance.client
          .from('profiles_private')
          .update({'upi_id': null})
          .eq('profile_id', authUser.id);

      upiId.value = null;
      debugPrint('✅ [UPIRepository] UPI ID cleared');
      return true;
    } catch (e) {
      debugPrint('❌ [UPIRepository] Error clearing UPI ID: $e');
      return false;
    }
  }
}
