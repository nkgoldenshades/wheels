import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_repository.dart';

enum MediaSource { uploaded, external }

enum UploadMethod { upload, url }

class VehicleMediaItem {
  final String url;
  final MediaSource source;
  final DateTime createdAt;
  final String? storageId;
  final int? compressedSize;

  const VehicleMediaItem({
    required this.url,
    required this.source,
    required this.createdAt,
    this.storageId,
    this.compressedSize,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'source': source.name,
    'created_at': createdAt.toIso8601String(),
    'storage_id': storageId,
    'compressed_size': compressedSize,
  };

  factory VehicleMediaItem.fromJson(Map<String, dynamic> json) {
    return VehicleMediaItem(
      url: json['url'],
      source: MediaSource.values.firstWhere((e) => e.name == json['source']),
      createdAt: DateTime.parse(json['created_at']),
      storageId: json['storage_id'],
      compressedSize: json['compressed_size'],
    );
  }
}

class VehicleMediaService {
  static final VehicleMediaService instance = VehicleMediaService._();
  VehicleMediaService._();

  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  // Upload image to vehicle_media bucket
  Future<VehicleMediaItem?> uploadImage({
    required String vehicleId,
    required XFile imageFile,
    int quality = 70,
  }) async {
    try {
      final userId = AuthRepository.instance.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Read image bytes (no compression for now - can add later)
      final imageBytes = await imageFile.readAsBytes();

      // Generate storage path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.name.split('.').last;
      final fileName = 'image_$timestamp.$extension';
      final storagePath = 'vehicles/$vehicleId/$userId/$fileName';

      // Upload to Supabase Storage
      await _supabase.storage
          .from('vehicle_media')
          .uploadBinary(storagePath, imageBytes);

      // Get public URL
      final publicUrl = _supabase.storage
          .from('vehicle_media')
          .getPublicUrl(storagePath);

      return VehicleMediaItem(
        url: publicUrl,
        source: MediaSource.uploaded,
        createdAt: DateTime.now(),
        storageId: storagePath,
        compressedSize: imageBytes.length,
      );
    } catch (e) {
      debugPrint('❌ Image upload failed: $e');
      return null;
    }
  }

  // Upload video to vehicle_media bucket
  Future<VehicleMediaItem?> uploadVideo({
    required String vehicleId,
    required XFile videoFile,
  }) async {
    try {
      final userId = AuthRepository.instance.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Read video bytes
      final videoBytes = await videoFile.readAsBytes();

      // Generate storage path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = videoFile.name.split('.').last;
      final fileName = 'video_$timestamp.$extension';
      final storagePath = 'vehicles/$vehicleId/$userId/$fileName';

      // Upload to Supabase Storage
      await _supabase.storage
          .from('vehicle_media')
          .uploadBinary(storagePath, videoBytes);

      // Get public URL
      final publicUrl = _supabase.storage
          .from('vehicle_media')
          .getPublicUrl(storagePath);

      return VehicleMediaItem(
        url: publicUrl,
        source: MediaSource.uploaded,
        createdAt: DateTime.now(),
        storageId: storagePath,
        compressedSize: videoBytes.length,
      );
    } catch (e) {
      debugPrint('❌ Video upload failed: $e');
      return null;
    }
  }

  // Create external URL media item
  VehicleMediaItem createExternalMedia(String url) {
    return VehicleMediaItem(
      url: url,
      source: MediaSource.external,
      createdAt: DateTime.now(),
    );
  }

  // Pick image from gallery
  Future<XFile?> pickImage() async {
    try {
      return await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
    } catch (e) {
      debugPrint('❌ Image picker failed: $e');
      return null;
    }
  }

  // Pick video from gallery
  Future<XFile?> pickVideo() async {
    try {
      return await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
    } catch (e) {
      debugPrint('❌ Video picker failed: $e');
      return null;
    }
  }

  // Validate external URL
  bool isValidImageUrl(String url) {
    if (!url.startsWith('https://')) return false;
    final lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.jpg') || 
           lowerUrl.endsWith('.jpeg') || 
           lowerUrl.endsWith('.png') || 
           lowerUrl.endsWith('.webp');
  }

  bool isValidVideoUrl(String url) {
    if (!url.startsWith('https://')) return false;
    final lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.mp4') || 
           lowerUrl.endsWith('.mov') || 
           lowerUrl.endsWith('.avi') || 
           lowerUrl.endsWith('.webm');
  }

  // Delete uploaded media from storage
  Future<bool> deleteUploadedMedia(String storagePath) async {
    try {
      await _supabase.storage
          .from('vehicle_media')
          .remove([storagePath]);
      return true;
    } catch (e) {
      debugPrint('❌ Delete media failed: $e');
      return false;
    }
  }
}
