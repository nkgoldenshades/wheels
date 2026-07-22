import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for handling post media uploads (images, videos)
/// Stores media in the 'post_media' bucket in Supabase
class PostMediaService {
  PostMediaService._();
  static final PostMediaService instance = PostMediaService._();

  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  /// Upload image to post_media bucket
  Future<String?> uploadPostImage({
    required String postId,
    required XFile imageFile,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileName =
          'posts/$postId/${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';

      final response = await _supabase.storage
          .from('post_media')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      if (response.isEmpty) {
        debugPrint('❌ Upload response empty');
        return null;
      }

      // Get public URL
      final publicUrl = _supabase.storage
          .from('post_media')
          .getPublicUrl(response);

      debugPrint('✅ Post image uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Failed to upload post image: $e');
      return null;
    }
  }

  /// Upload video to post_media bucket
  Future<String?> uploadPostVideo({
    required String postId,
    required XFile videoFile,
  }) async {
    try {
      final bytes = await videoFile.readAsBytes();
      final fileName =
          'posts/$postId/videos/${DateTime.now().millisecondsSinceEpoch}_${videoFile.name}';

      final response = await _supabase.storage
          .from('post_media')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      if (response.isEmpty) {
        debugPrint('❌ Upload response empty');
        return null;
      }

      // Get public URL
      final publicUrl = _supabase.storage
          .from('post_media')
          .getPublicUrl(response);

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
        imageQuality: 85,
      );
    } catch (e) {
      debugPrint('❌ Failed to pick image: $e');
      return null;
    }
  }

  /// Pick multiple images from gallery for post
  Future<List<XFile>> pickMultiplePostImages() async {
    try {
      return await _imagePicker.pickMultipleMedia(imageQuality: 85);
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
