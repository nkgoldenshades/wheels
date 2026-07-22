import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI-based media verification service
/// Uses backend cloud functions for image/video analysis
class MediaVerificationService {
  MediaVerificationService._();
  static final MediaVerificationService instance = MediaVerificationService._();

  final _supabase = Supabase.instance.client;

  /// Verify image meets quality and content standards
  Future<bool> verifyImage({
    required String imageUrl,
    required String postId,
  }) async {
    try {
      debugPrint('🔍 Verifying image: $imageUrl');

      // Call backend Cloud Function for verification
      final result = await _supabase.functions.invoke(
        'verify-post-media',
        body: {'postId': postId, 'mediaUrl': imageUrl, 'mediaType': 'image'},
      );

      // FunctionResponse returns data that needs to be cast
      final Map<String, dynamic> response = result.data ?? {};
      final verified = response['verified'] as bool? ?? false;
      final reason = response['reason'] as String? ?? 'Unknown';

      if (!verified) {
        debugPrint('⚠️ Image rejected: $reason');
      } else {
        debugPrint('✅ Image verified successfully');
      }

      await _logVerificationResult(
        postId: postId,
        mediaUrl: imageUrl,
        verified: verified,
        reason: reason,
      );

      return verified;
    } catch (e) {
      debugPrint('❌ Image verification error: $e');
      await _logVerificationResult(
        postId: postId,
        mediaUrl: imageUrl,
        verified: false,
        reason: 'Verification failed: $e',
      );
      return false;
    }
  }

  /// Verify video meets quality and content standards
  Future<bool> verifyVideo({
    required String videoUrl,
    required String postId,
  }) async {
    try {
      debugPrint('🔍 Verifying video: $videoUrl');

      final result = await _supabase.functions.invoke(
        'verify-post-media',
        body: {'postId': postId, 'mediaUrl': videoUrl, 'mediaType': 'video'},
      );

      final Map<String, dynamic> response = result.data ?? {};
      final verified = response['verified'] as bool? ?? false;
      final reason = response['reason'] as String? ?? 'Unknown';

      if (!verified) {
        debugPrint('⚠️ Video rejected: $reason');
      } else {
        debugPrint('✅ Video verified successfully');
      }

      await _logVerificationResult(
        postId: postId,
        mediaUrl: videoUrl,
        verified: verified,
        reason: reason,
      );

      return verified;
    } catch (e) {
      debugPrint('❌ Video verification error: $e');
      await _logVerificationResult(
        postId: postId,
        mediaUrl: videoUrl,
        verified: false,
        reason: 'Video verification failed: $e',
      );
      return false;
    }
  }

  /// Log verification result to database
  Future<void> _logVerificationResult({
    required String postId,
    required String mediaUrl,
    required bool verified,
    required String reason,
  }) async {
    try {
      await _supabase.from('post_media_verification').insert({
        'post_id': postId,
        'media_url': mediaUrl,
        'verified': verified,
        'reason': reason,
        'verified_at': DateTime.now().toIso8601String(),
        'verification_method': 'ai_backend',
      });

      debugPrint('✅ Verification logged: $postId - $verified');
    } catch (e) {
      debugPrint('❌ Failed to log verification: $e');
    }
  }

  /// Batch verify all post media
  Future<void> verifyPostMedia({
    required String postId,
    required List<Map<String, String>> mediaList,
  }) async {
    try {
      debugPrint(
        '🔄 Batch verifying ${mediaList.length} media items for post: $postId',
      );

      for (final media in mediaList) {
        final url = media['url'] ?? '';
        final type = media['type'] ?? 'image';

        if (type == 'image') {
          await verifyImage(imageUrl: url, postId: postId);
        } else if (type == 'video') {
          await verifyVideo(videoUrl: url, postId: postId);
        }
      }

      debugPrint('✅ Batch verification complete for post: $postId');
    } catch (e) {
      debugPrint('❌ Batch verification error: $e');
    }
  }

  /// Check if post media is verified
  Future<bool> isMediaVerified({
    required String postId,
    required String mediaUrl,
  }) async {
    try {
      final result = await _supabase
          .from('post_media_verification')
          .select('verified')
          .eq('post_id', postId)
          .eq('media_url', mediaUrl)
          .single();

      return result['verified'] as bool;
    } catch (e) {
      debugPrint('❌ Failed to check verification status: $e');
      return false;
    }
  }

  /// Get verification report for a post (admin only)
  Future<List<Map<String, dynamic>>?> getVerificationReport(
    String postId,
  ) async {
    try {
      final results = await _supabase
          .from('post_media_verification')
          .select()
          .eq('post_id', postId)
          .eq('verified', false);

      return List<Map<String, dynamic>>.from(results);
    } catch (e) {
      debugPrint('❌ Failed to get verification report: $e');
      return null;
    }
  }
}
