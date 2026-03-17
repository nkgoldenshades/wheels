import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_post_acceptance.dart';
import 'auth_repository.dart';

class UserPostAcceptanceRepository {
  UserPostAcceptanceRepository._();

  static final UserPostAcceptanceRepository instance =
      UserPostAcceptanceRepository._();

  final _supabase = Supabase.instance.client;
  final ValueNotifier<List<UserPostAcceptance>> acceptances =
      ValueNotifier<List<UserPostAcceptance>>([]);

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await loadAcceptances();
    _initialized = true;
  }

  Future<void> loadAcceptances() async {
    try {
      final currentUser = AuthRepository.instance.currentUser;
      if (currentUser == null) {
        acceptances.value = [];
        return;
      }

      // Load acceptances where user is either provider or post owner
      final response = await _supabase
          .from('user_post_acceptances')
          .select()
          .or('provider_id.eq.${currentUser.id},user_id.eq.${currentUser.id}')
          .order('created_at', ascending: false);

      acceptances.value = (response as List)
          .map((json) => UserPostAcceptance.fromJson(json))
          .toList();

      debugPrint(
          '✅ Loaded ${acceptances.value.length} post acceptances from Supabase');
    } catch (e) {
      debugPrint('❌ Failed to load post acceptances: $e');
      acceptances.value = [];
    }
  }

  /// Provider accepts a user post
  Future<UserPostAcceptance> acceptPost({
    required String postId,
    required String userId,
    required double amount,
  }) async {
    try {
      final currentUser = AuthRepository.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Generate 6-digit OTP
      final otp = _generateOTP();
      final otpExpiresAt = DateTime.now().add(const Duration(minutes: 10));

      final acceptance = UserPostAcceptance(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        postId: postId,
        providerId: currentUser.id,
        userId: userId,
        amount: amount,
        status: AcceptanceStatus.pending,
        otp: otp,
        otpExpiresAt: otpExpiresAt,
        createdAt: DateTime.now(),
      );

      // Insert to Supabase
      await _supabase.from('user_post_acceptances').insert(acceptance.toJson());

      // Update local state
      acceptances.value = [acceptance, ...acceptances.value];

      debugPrint('✅ Post acceptance created with OTP: $otp');
      
      // NOTE: OTP delivery via SMS/Email to be implemented in production
      // For development, OTP is logged to console
      debugPrint('📱 OTP for user: $otp (expires in 10 minutes)');

      return acceptance;
    } catch (e) {
      debugPrint('❌ Failed to accept post: $e');
      rethrow;
    }
  }

  /// User verifies OTP
  Future<bool> verifyOTP({
    required String acceptanceId,
    required String enteredOTP,
  }) async {
    try {
      final acceptance = acceptances.value.firstWhere(
        (a) => a.id == acceptanceId,
        orElse: () => throw Exception('Acceptance not found'),
      );

      // Check if OTP expired
      if (acceptance.otpExpiresAt != null &&
          DateTime.now().isAfter(acceptance.otpExpiresAt!)) {
        throw Exception('OTP expired');
      }

      // Verify OTP
      if (acceptance.otp != enteredOTP) {
        throw Exception('Invalid OTP');
      }

      // Update status to otpVerified
      await _supabase
          .from('user_post_acceptances')
          .update({'status': AcceptanceStatus.otpVerified.name})
          .eq('id', acceptanceId);

      // Update local state
      acceptances.value = acceptances.value
          .map((a) => a.id == acceptanceId
              ? a.copyWith(status: AcceptanceStatus.otpVerified)
              : a)
          .toList();

      debugPrint('✅ OTP verified for acceptance: $acceptanceId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to verify OTP: $e');
      return false;
    }
  }

  /// Update acceptance with payment details
  Future<void> updatePaymentDetails({
    required String acceptanceId,
    required String razorpayOrderId,
    String? razorpayPaymentId,
    AcceptanceStatus? status,
  }) async {
    try {
      final updates = <String, dynamic>{
        'razorpay_order_id': razorpayOrderId,
      };

      if (razorpayPaymentId != null) {
        updates['razorpay_payment_id'] = razorpayPaymentId;
      }

      if (status != null) {
        updates['status'] = status.name;
        if (status == AcceptanceStatus.paid) {
          updates['paid_at'] = DateTime.now().toIso8601String();
        }
      }

      await _supabase
          .from('user_post_acceptances')
          .update(updates)
          .eq('id', acceptanceId);

      // Update local state
      acceptances.value = acceptances.value
          .map((a) => a.id == acceptanceId
              ? a.copyWith(
                  razorpayOrderId: razorpayOrderId,
                  razorpayPaymentId: razorpayPaymentId,
                  status: status ?? a.status,
                  paidAt: status == AcceptanceStatus.paid
                      ? DateTime.now()
                      : a.paidAt,
                )
              : a)
          .toList();

      debugPrint('✅ Payment details updated for acceptance: $acceptanceId');
    } catch (e) {
      debugPrint('❌ Failed to update payment details: $e');
      rethrow;
    }
  }

  /// Cancel acceptance
  Future<void> cancel(String acceptanceId) async {
    try {
      await _supabase
          .from('user_post_acceptances')
          .update({'status': AcceptanceStatus.cancelled.name})
          .eq('id', acceptanceId);

      // Update local state
      acceptances.value = acceptances.value
          .map((a) => a.id == acceptanceId
              ? a.copyWith(status: AcceptanceStatus.cancelled)
              : a)
          .toList();

      debugPrint('✅ Acceptance cancelled: $acceptanceId');
    } catch (e) {
      debugPrint('❌ Failed to cancel acceptance: $e');
      rethrow;
    }
  }

  /// Get acceptances for a specific post
  List<UserPostAcceptance> getAcceptancesForPost(String postId) {
    return acceptances.value
        .where((a) => a.postId == postId)
        .toList(growable: false);
  }

  /// Check if current user has already accepted a post
  bool hasAccepted(String postId) {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return false;

    return acceptances.value.any(
      (a) =>
          a.postId == postId &&
          a.providerId == currentUser.id &&
          a.status != AcceptanceStatus.cancelled,
    );
  }

  String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }
}
