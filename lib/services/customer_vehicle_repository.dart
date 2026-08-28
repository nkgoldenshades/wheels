import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle.dart';
import 'auth_repository.dart';

/// Separate vehicle repository for "My Posts" section
/// This keeps user's personal vehicles separate from provider vehicles
class CustomerVehicleRepository {
  CustomerVehicleRepository._();

  static final CustomerVehicleRepository instance =
      CustomerVehicleRepository._();

  final _supabase = Supabase.instance.client;
  final ValueNotifier<List<Vehicle>> vehiclesListenable = ValueNotifier([]);
  final ValueNotifier<Map<String, bool>> onlineStatusListenable = ValueNotifier(
    {},
  );

  bool _initialized = false;

  Future<void> init() async {
    debugPrint('🚀 CustomerVehicleRepository: INIT CALLED');
    if (_initialized) {
      debugPrint('⚠️ CustomerVehicleRepository: Already initialized, skipping');
      return;
    }
    debugPrint(
      '🔄 CustomerVehicleRepository: First time init, loading vehicles...',
    );
    await _loadVehicles();
    _initialized = true;
    debugPrint('✅ CustomerVehicleRepository: Init complete');
  }

  // Public method to reload vehicles (e.g., after user login)
  Future<void> reload() async {
    debugPrint('🔄 CustomerVehicleRepository: RELOAD called');
    await _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    debugPrint(
      '🚗 CustomerVehicleRepository: Starting to load customer vehicles...',
    );
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) {
      debugPrint('⚠️ No user logged in - cannot load customer vehicles');
      vehiclesListenable.value = [];
      return;
    }

    debugPrint('🔑 Loading customer vehicles for user: ${currentUser.id}');

    try {
      // Load customer vehicles from Supabase (simplified query - no JOIN needed)
      final response = await _supabase
          .from('vehicles')
          .select('*')
          .eq('profile_id', currentUser.id)
          .eq('vehicle_owner', 'customer')
          .order('created_at', ascending: false);

      debugPrint(
        '📦 Query completed: ${(response as List).length} vehicles returned',
      );

      if ((response as List).isEmpty) {
        debugPrint('⚠️ No customer vehicles found for user ${currentUser.id}');
        debugPrint('💡 Make sure vehicles have vehicle_owner="customer"');
        vehiclesListenable.value = [];
        return;
      }

      final newList = (response as List).map((json) {
        return Vehicle.fromJson(Map<String, dynamic>.from(json));
      }).toList();

      vehiclesListenable.value = newList;

      debugPrint('✅ Loaded ${newList.length} customer vehicles');

      if (vehiclesListenable.value.isNotEmpty) {
        debugPrint(
          '🔍 First customer vehicle: id=${vehiclesListenable.value[0].id}, userName=${vehiclesListenable.value[0].userName}',
        );
      } else {
        debugPrint('⚠️ No customer vehicles found for user ${currentUser.id}');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load customer vehicles from Supabase: $e');
      vehiclesListenable.value = [];
    }
  }

  List<Vehicle> get allVehicles => vehiclesListenable.value;

  Vehicle? getById(String id) {
    try {
      return vehiclesListenable.value.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addVehicle(Vehicle vehicle) async {
    debugPrint(
      '🚗 CustomerVehicleRepository: Starting addVehicle for ${vehicle.id}',
    );
    try {
      // Add to Supabase (match the real public.vehicles schema)
      final photos = <String>[];
      if (vehicle.profileImage != null &&
          vehicle.profileImage!.trim().isNotEmpty) {
        photos.add(vehicle.profileImage!.trim());
      }
      photos.addAll(vehicle.galleryImages.where((e) => e.trim().isNotEmpty));

      final payload = <String, dynamic>{
        'id': vehicle.id,
        'profile_id': vehicle.userId,
        'vehicle_type': vehicle.type,
        'vehicle_name': vehicle.name,
        'registration_number':
            vehicle.registrationNumber ?? 'TEMP-${vehicle.id.substring(0, 8)}',
        'seating_capacity': vehicle.seatingCapacity ?? 4,
        'vehicle_photo_url': vehicle.profileImage,
        'gallery_images': vehicle.galleryImages
            .where((e) => e.trim().isNotEmpty)
            .toList(),
        'video_url': vehicle.videoUrl,
        'created_at': vehicle.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_active': true,
        'vehicle_owner': 'customer', // Enum: provider or customer
        // Statistics
        'total_trips': vehicle.totalBookings,
        'total_reviews': vehicle.totalRatings,
        'active_posts_count': vehicle.activePostsCount,
        // All document verification removed
      };

      debugPrint(
        '🚗 Supabase vehicle insert payload (customer): id=${payload['id']} profile_id=${payload['profile_id']} vehicle_owner=${payload['vehicle_owner']}',
      );

      await _supabase.from('vehicles').insert(payload);
      debugPrint('✅ Vehicle inserted to Supabase successfully');

      // Skip vehicle_sensitive_info - no documents to store anymore
      // All document fields removed for legal safety
          'operator_profile_photo_url': vehicle.operatorPhoto,
      };
      await _supabase
          .from('vehicle_sensitive_info')
          .upsert(sensitivePayload, onConflict: 'vehicle_id');
      debugPrint('✅ Vehicle sensitive info saved');

      // Reload from Supabase to ensure consistency
      debugPrint('🔄 Reloading all customer vehicles from database...');
      await _loadVehicles();
      debugPrint(
        '✅ Reload complete. Total vehicles now: ${vehiclesListenable.value.length}',
      );

      debugPrint('✅ User vehicle created in Supabase: ${vehicle.id}');
    } catch (e) {
      debugPrint('❌ Failed to create user vehicle in Supabase: $e');
      // Fallback to local only
      debugPrint('🔄 Adding vehicle to local list as fallback');
      vehiclesListenable.value = [...vehiclesListenable.value, vehicle];
      debugPrint(
        '✅ User vehicle created locally: ${vehicle.id}. Total vehicles: ${vehiclesListenable.value.length}',
      );
    }
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    try {
      // Build payload manually to match database schema
      final payload = <String, dynamic>{
        'vehicle_type': vehicle.type,
        'vehicle_name': vehicle.name,
        'registration_number': vehicle.registrationNumber,
        'seating_capacity': vehicle.seatingCapacity,
        'vehicle_photo_url': vehicle.profileImage,
        'gallery_images': vehicle.galleryImages
            .where((e) => e.trim().isNotEmpty)
            .toList(),
        'video_url': vehicle.videoUrl,
        'updated_at': DateTime.now().toIso8601String(),
        'total_trips': vehicle.totalBookings,
        'total_reviews': vehicle.totalRatings,
        'active_posts_count': vehicle.activePostsCount,
        if (vehicle.year != null) 'year': vehicle.year,
        if (vehicle.brand != null) 'brand': vehicle.brand,
        if (vehicle.model != null) 'model': vehicle.model,
        if (vehicle.color != null) 'color': vehicle.color,
        // All document verification fields removed for legal safety
      };

      await _supabase.from('vehicles').update(payload).eq('id', vehicle.id);

      // Skip sensitive info update - no documents stored anymore
      // All document fields removed for legal safety

      // Update local state
      vehiclesListenable.value = vehiclesListenable.value
          .map((v) => v.id == vehicle.id ? vehicle : v)
          .toList();

      debugPrint('✅ User vehicle updated in Supabase: ${vehicle.id}');
    } catch (e) {
      debugPrint('❌ Failed to update user vehicle in Supabase: $e');
      // Fallback to local only
      vehiclesListenable.value = vehiclesListenable.value
          .map((v) => v.id == vehicle.id ? vehicle : v)
          .toList();
      debugPrint('✅ User vehicle updated locally: ${vehicle.id}');
      rethrow; // Re-throw so UI can show error
    }
  }

  Future<void> removeVehicle(String id) async {
    try {
      // Check if vehicle has ANY user posts
      final posts = await _supabase
          .from('posts')
          .select('id')
          .eq('vehicle_id', id);

      if (posts.isNotEmpty) {
        final postCount = posts.length;
        throw Exception(
          'Cannot delete vehicle: $postCount post${postCount > 1 ? 's' : ''} exist. '
          'Please delete all posts using this vehicle first.',
        );
      }

      // Safe to delete - no posts exist
      await _supabase.from('vehicles').delete().eq('id', id);

      // Update local state
      vehiclesListenable.value = vehiclesListenable.value
          .where((v) => v.id != id)
          .toList();

      debugPrint('✅ User vehicle deleted from Supabase: $id');
    } catch (e) {
      debugPrint('❌ Failed to delete user vehicle: $e');
      rethrow; // Re-throw to show error to user
    }
  }

  Future<void> deleteVehicle(String id) async {
    try {
      // Check if vehicle has ANY user posts
      final posts = await _supabase
          .from('posts')
          .select('id')
          .eq('vehicle_id', id);

      if (posts.isNotEmpty) {
        final postCount = posts.length;
        debugPrint('❌ Cannot delete vehicle: $postCount post(s) exist');
        throw Exception(
          'Cannot delete vehicle: $postCount post${postCount > 1 ? 's' : ''} exist. '
          'Please delete all posts using this vehicle first.',
        );
      }

      // Safe to delete
      vehiclesListenable.value = vehiclesListenable.value
          .where((v) => v.id != id)
          .toList();

      // Also remove from online status
      final newStatus = Map<String, bool>.from(onlineStatusListenable.value);
      newStatus.remove(id);
      onlineStatusListenable.value = newStatus;

      // Delete from Supabase asynchronously
      await _supabase.from('vehicles').delete().eq('id', id);

      debugPrint('✅ User vehicle deleted from Supabase: $id');
    } catch (e) {
      debugPrint('❌ Failed to delete user vehicle: $e');
      rethrow; // Re-throw to show error to user
    }
  }

  bool isOnline(String vehicleId) {
    return onlineStatusListenable.value[vehicleId] ?? true; // Default to online
  }

  Future<void> setOnline(String vehicleId, bool isOnline) async {
    try {
      // Update in Supabase
      try {
        await _supabase
            .from('vehicles')
            .update({
              'is_online': isOnline,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', vehicleId);
      } on PostgrestException catch (e) {
        if (e.code != '42703') rethrow;
      }

      // Update local state
      final newStatus = Map<String, bool>.from(onlineStatusListenable.value);
      newStatus[vehicleId] = isOnline;
      onlineStatusListenable.value = newStatus;

      debugPrint(
        '✅ User vehicle ${isOnline ? "online" : "offline"} in Supabase: $vehicleId',
      );
    } catch (e) {
      debugPrint(
        '❌ Failed to update user vehicle online status in Supabase: $e',
      );
      // Fallback to local only
      final newStatus = Map<String, bool>.from(onlineStatusListenable.value);
      newStatus[vehicleId] = isOnline;
      onlineStatusListenable.value = newStatus;
      debugPrint(
        '✅ User vehicle ${isOnline ? "online" : "offline"} locally: $vehicleId',
      );
    }
  }
}
