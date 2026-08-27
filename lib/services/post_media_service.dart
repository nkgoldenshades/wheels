import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_repository.dart';

/// Service for handling post media uploads (images, videos)
/// Stores media in the 'post_media' bucket in Supabase
class PostMediaService {
  PostMediaService._();
  static final PostMediaService instance = PostMediaService._();

  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  /// Upload image to post_media bucket
  /// Path structure: {userId}/posts/{postId}/{timestamp}_{filename}
  /// This allows RLS policies to validate ownership
  Future<String?> uploadPostImage({
    required String postId,
    required XFile imageFile,
  }) async {
    try {
      // Get user ID from AuthRepository instead of auth.currentUser
      final user = AuthRepository.instance.currentUser;
      if (user == null) {
        debugPrint('❌ User not authenticated');
        return null;
      }

      debugPrint('📤 Uploading image: ${imageFile.name}');
      final bytes = await imageFile.readAsBytes();
      debugPrint(
        '📦 Image size: ${(bytes.length / 1024).toStringAsFixed(2)} KB',
      );

      final fileName =
          '${user.id}/posts/$postId/${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';

      debugPrint('📍 Storage path: $fileName');

      final response = await _supabase.storage
          .from('post_media')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      debugPrint('📥 Upload response: $response');

      if (response.isEmpty) {
        debugPrint('❌ Upload response empty');
        return null;
      }

      // Get public URL - use fileName, not response
      final publicUrl = _supabase.storage
          .from('post_media')
          .getPublicUrl(fileName);

      debugPrint('✅ Post image uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Failed to upload post image: $e');
      return null;
    }
  }

  /// Upload video to post_media bucket
  /// Path structure: {userId}/posts/{postId}/videos/{timestamp}_{filename}
  /// This allows RLS policies to validate ownership
  Future<String?> uploadPostVideo({
    required String postId,
    required XFile videoFile,
  }) async {
    try {
      // Get user ID from AuthRepository instead of auth.currentUser
      final user = AuthRepository.instance.currentUser;
      if (user == null) {
        debugPrint('❌ User not authenticated');
        return null;
      }

      debugPrint('📹 Uploading video: ${videoFile.name}');
      final bytes = await videoFile.readAsBytes();
      debugPrint(
        '📦 Video size: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      final fileName =
          '${user.id}/posts/$postId/videos/${DateTime.now().millisecondsSinceEpoch}_${videoFile.name}';

      debugPrint('📍 Storage path: $fileName');

      final response = await _supabase.storage
          .from('post_media')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      debugPrint('📥 Upload response: $response');

      if (response.isEmpty) {
        debugPrint('❌ Upload response empty');
        return null;
      }

      // Get public URL - use fileName, not response
      final publicUrl = _supabase.storage
          .from('post_media')
          .getPublicUrl(fileName);

      debugPrint('✅ Post video uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Failed to upload post video: $e');
      return null;
    }
  }

  /// Pick image from gallery for post
  Future<XFile?> pickPostImage() async {
    try {
      return await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95, // High quality for post media
      );
    } catch (e) {
      debugPrint('❌ Failed to pick image: $e');
      return null;
    }
  }

  /// Pick multiple images from gallery for post
  Future<List<XFile>> pickMultiplePostImages() async {
    try {
      final files = await _imagePicker.pickMultiImage(
        imageQuality: 95,
      ); // High quality for post media
      return files;
    } catch (e) {
      debugPrint('❌ Failed to pick images: $e');
      return [];
    }
  }

  /// Pick video from gallery for post
  Future<XFile?> pickPostVideo() async {
    try {
      return await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );
    } catch (e) {
      debugPrint('❌ Failed to pick video: $e');
      return null;
    }
  }

  /// Delete uploaded post media
  Future<bool> deletePostMedia(String storagePath) async {
    try {
      await _supabase.storage.from('post_media').remove([storagePath]);
      debugPrint('✅ Post media deleted: $storagePath');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete post media: $e');
      return false;
    }
  }
}
