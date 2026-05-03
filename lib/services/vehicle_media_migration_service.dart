import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'vehicle_media_service.dart';
import '../models/vehicle.dart';

/// Service to migrate existing base64 vehicle images/videos to new storage system
class VehicleMediaMigrationService {
  static final VehicleMediaMigrationService instance = VehicleMediaMigrationService._();
  VehicleMediaMigrationService._();

  final _supabase = Supabase.instance.client;

  /// Migrate a single vehicle's media from base64 to storage URLs
  Future<Vehicle?> migrateVehicleMedia(Vehicle vehicle) async {
    try {
      List<VehicleMediaItem> newGalleryImages = [];
      VehicleMediaItem? newVideo;

      // Migrate profile image
      String? newProfileImage;
      if (vehicle.profileImage != null && _isBase64(vehicle.profileImage!)) {
        final uploaded = await _uploadBase64Image(
          vehicleId: vehicle.id,
          base64Data: vehicle.profileImage!,
          fileName: 'profile_image',
        );
        newProfileImage = uploaded?.url ?? vehicle.profileImage;
      } else {
        newProfileImage = vehicle.profileImage;
      }

      // Migrate gallery images
      for (int i = 0; i < vehicle.galleryImages.length; i++) {
        final imageData = vehicle.galleryImages[i];
        
        if (_isBase64(imageData)) {
          final uploaded = await _uploadBase64Image(
            vehicleId: vehicle.id,
            base64Data: imageData,
            fileName: 'gallery_$i',
          );
          if (uploaded != null) {
            newGalleryImages.add(uploaded);
          }
        } else {
          // Already a URL, create external media item
          newGalleryImages.add(VehicleMediaService.instance.createExternalMedia(imageData));
        }
      }

      // Migrate video
      if (vehicle.videoUrl != null && _isBase64(vehicle.videoUrl!)) {
        newVideo = await _uploadBase64Video(
          vehicleId: vehicle.id,
          base64Data: vehicle.videoUrl!,
          fileName: 'vehicle_video',
        );
      } else if (vehicle.videoUrl != null) {
        // Already a URL, create external media item
        newVideo = VehicleMediaService.instance.createExternalMedia(vehicle.videoUrl!);
      }

      // Create updated vehicle with new URLs
      final updatedVehicle = vehicle.copyWith(
        profileImage: newProfileImage,
        galleryImages: newGalleryImages.map((item) => item.url).toList(),
        videoUrl: newVideo?.url,
      );

      // Update in database
      await _updateVehicleInDatabase(updatedVehicle, newGalleryImages, newVideo);

      return updatedVehicle;
    } catch (e) {
      debugPrint('❌ Vehicle migration failed: $e');
      return null;
    }
  }

  /// Upload base64 image to storage
  Future<VehicleMediaItem?> _uploadBase64Image({
    required String vehicleId,
    required String base64Data,
    required String fileName,
  }) async {
    try {
      // Extract base64 content (remove data:image/jpeg;base64, prefix if present)
      final cleanBase64 = base64Data.contains(',') 
          ? base64Data.split(',').last 
          : base64Data;

      final bytes = base64Decode(cleanBase64);
      
      // Generate storage path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'vehicles/$vehicleId/migrated/${fileName}_$timestamp.jpg';

      // Upload to storage
      await _supabase.storage
          .from('vehicle_media')
          .uploadBinary(storagePath, bytes);

      // Get public URL
      final publicUrl = _supabase.storage
          .from('vehicle_media')
          .getPublicUrl(storagePath);

      return VehicleMediaItem(
        url: publicUrl,
        source: MediaSource.uploaded,
        createdAt: DateTime.now(),
        storageId: storagePath,
        compressedSize: bytes.length,
      );
    } catch (e) {
      debugPrint('❌ Base64 image upload failed: $e');
      return null;
    }
  }

  /// Upload base64 video to storage
  Future<VehicleMediaItem?> _uploadBase64Video({
    required String vehicleId,
    required String base64Data,
    required String fileName,
  }) async {
    try {
      // Extract base64 content
      final cleanBase64 = base64Data.contains(',') 
          ? base64Data.split(',').last 
          : base64Data;

      final bytes = base64Decode(cleanBase64);
      
      // Generate storage path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'vehicles/$vehicleId/migrated/${fileName}_$timestamp.mp4';

      // Upload to storage
      await _supabase.storage
          .from('vehicle_media')
          .uploadBinary(storagePath, bytes);

      // Get public URL
      final publicUrl = _supabase.storage
          .from('vehicle_media')
          .getPublicUrl(storagePath);

      return VehicleMediaItem(
        url: publicUrl,
        source: MediaSource.uploaded,
        createdAt: DateTime.now(),
        storageId: storagePath,
        compressedSize: bytes.length,
      );
    } catch (e) {
      debugPrint('❌ Base64 video upload failed: $e');
      return null;
    }
  }

  /// Update vehicle in database with new media URLs
  Future<void> _updateVehicleInDatabase(
    Vehicle vehicle,
    List<VehicleMediaItem> galleryItems,
    VehicleMediaItem? videoItem,
  ) async {
    try {
      // Prepare update data
      final updateData = {
        'vehicle_photo_url': vehicle.profileImage,
        'gallery_images': vehicle.galleryImages,
        'video_url': vehicle.videoUrl,
        'updated_at': DateTime.now().toIso8601String(),
        // Store media metadata for future reference
        'media_metadata': {
          'gallery_items': galleryItems.map((item) => item.toJson()).toList(),
          'video_item': videoItem?.toJson(),
          'migrated_at': DateTime.now().toIso8601String(),
        },
      };

      await _supabase
          .from('vehicles')
          .update(updateData)
          .eq('id', vehicle.id);

      debugPrint('✅ Vehicle ${vehicle.id} media updated in database');
    } catch (e) {
      debugPrint('❌ Database update failed: $e');
      rethrow;
    }
  }

  /// Check if string is base64 encoded
  bool _isBase64(String data) {
    // Check if it starts with data: prefix or looks like base64
    if (data.startsWith('data:')) return true;
    if (data.startsWith('http')) return false;
    
    // Try to decode as base64
    try {
      base64Decode(data.contains(',') ? data.split(',').last : data);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Migrate all vehicles in batch
  Future<void> migrateAllVehicles() async {
    try {
      debugPrint('🔄 Starting vehicle media migration...');
      
      // Get all vehicles from database
      final response = await _supabase
          .from('vehicles')
          .select('*')
          .order('created_at');

      final vehicles = (response as List)
          .map((json) => Vehicle.fromJson(json))
          .toList();

      debugPrint('📊 Found ${vehicles.length} vehicles to migrate');

      int migrated = 0;
      int failed = 0;

      for (final vehicle in vehicles) {
        try {
          final result = await migrateVehicleMedia(vehicle);
          if (result != null) {
            migrated++;
            debugPrint('✅ Migrated vehicle ${vehicle.id}');
          } else {
            failed++;
            debugPrint('❌ Failed to migrate vehicle ${vehicle.id}');
          }
        } catch (e) {
          failed++;
          debugPrint('❌ Error migrating vehicle ${vehicle.id}: $e');
        }

        // Small delay to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 500));
      }

      debugPrint('🎉 Migration complete: $migrated migrated, $failed failed');
    } catch (e) {
      debugPrint('❌ Batch migration failed: $e');
      rethrow;
    }
  }
}
