import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle.dart';
import 'auth_repository.dart';

/// Separate vehicle repository for "My Posts" section
/// This keeps user's personal vehicles separate from provider vehicles
class CustomerVehicleRepository {
  CustomerVehicleRepository._();

  static final CustomerVehicleRepository instance = CustomerVehicleRepository._();

  final _supabase = Supabase.instance.client;
  final ValueNotifier<List<Vehicle>> vehiclesListenable = ValueNotifier([]);
  final ValueNotifier<Map<String, bool>> onlineStatusListenable = ValueNotifier(
    {},
  );

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _loadVehicles();
    _initialized = true;
  }

  Future<void> _loadVehicles() async {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) {
      vehiclesListenable.value = [];
      return;
    }

    try {
      // Load customer vehicles from Supabase (vehicles user is looking for)
      final response = await _supabase
          .from('vehicles')
          .select()
          .eq('profile_id', currentUser.id)
          .order('created_at', ascending: false);

      vehiclesListenable.value = (response as List)
          .map((json) => Vehicle.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint(
        '✅ Loaded ${vehiclesListenable.value.length} vehicles from Supabase',
      );
    } catch (e) {
      debugPrint('⚠️  Failed to load customer vehicles from Supabase: $e');
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
    try {
      // Add to Supabase (match the real public.vehicles schema)
      final photos = <String>[];
      if (vehicle.profileImage != null && vehicle.profileImage!.trim().isNotEmpty) {
        photos.add(vehicle.profileImage!.trim());
      }
      photos.addAll(vehicle.galleryImages.where((e) => e.trim().isNotEmpty));

      final payload = <String, dynamic>{
        'id': vehicle.id,
        'profile_id': vehicle.userId,
        'vehicle_type': vehicle.type,
        'vehicle_name': vehicle.name,
        'registration_number': vehicle.registrationNumber ?? 'TEMP-${vehicle.id.substring(0, 8)}',
        'seating_capacity': vehicle.seatingCapacity ?? 4,
        'vehicle_photo_url': vehicle.profileImage,
        'gallery_images': vehicle.galleryImages.where((e) => e.trim().isNotEmpty).toList(),
        'video_url': vehicle.videoUrl,
        'created_at': vehicle.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_active': true,
        
        // Legal documents
        'rc_front_url': vehicle.rcFrontUrl,
        'rc_back_url': vehicle.rcBackUrl,
        'insurance_number': vehicle.insuranceNumber,
        'insurance_expiry': vehicle.insuranceExpiry?.toIso8601String(),
        'insurance_document_url': vehicle.insuranceDocumentUrl,
        'pollution_certificate_url': vehicle.pollutionCertificateUrl,
        'pollution_expiry': vehicle.pollutionExpiry?.toIso8601String(),
        'fitness_certificate_url': vehicle.fitnessCertificateUrl,
        'fitness_expiry': vehicle.fitnessExpiry?.toIso8601String(),
        
        // Statistics
        'total_trips': vehicle.totalBookings,
        'total_reviews': vehicle.totalRatings,
        'active_posts_count': vehicle.activePostsCount,
        'is_verified': vehicle.rcVerified,
        'verified_at': vehicle.rcVerifiedAt?.toIso8601String(),
        
        // Operator info
        'operator_name': vehicle.operatorName,
        'operator_phone': vehicle.operatorPhone,
        'operator_profile_photo_url': vehicle.operatorPhoto,
      };

      debugPrint(
        '🚗 Supabase vehicle insert payload (customer): id=${payload['id']} profile_id=${payload['profile_id']}',
      );

      await _supabase.from('vehicles').insert(payload);

      // Update local state
      vehiclesListenable.value = [...vehiclesListenable.value, vehicle];

      debugPrint('✅ User vehicle created in Supabase: ${vehicle.id}');
    } catch (e) {
      debugPrint('❌ Failed to create user vehicle in Supabase: $e');
      // Fallback to local only
      vehiclesListenable.value = [...vehiclesListenable.value, vehicle];
      debugPrint('✅ User vehicle created locally: ${vehicle.id}');
    }
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    try {
      // Update in Supabase
      Map<String, dynamic> payload = Map<String, dynamic>.from(vehicle.toJson());
      while (true) {
        try {
          await _supabase.from('vehicles').update(payload).eq('id', vehicle.id);
          break;
        } on PostgrestException catch (e) {
          if (e.code == '42703') {
            payload.remove('is_online');
            payload.remove('is_user_vehicle');
            continue;
          }
          if (e.code == 'PGRST204') {
            final match = RegExp(r"Could not find the '([^']+)' column").firstMatch(
              e.message,
            );
            final missingColumn = match?.group(1);
            if (missingColumn == null || !payload.containsKey(missingColumn)) {
              rethrow;
            }
            payload.remove(missingColumn);
            continue;
          }
          rethrow;
        }
      }

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
    }
  }

  Future<void> removeVehicle(String id) async {
    try {
      // Delete from Supabase
      await _supabase.from('vehicles').delete().eq('id', id);

      // Update local state
      vehiclesListenable.value = vehiclesListenable.value
          .where((v) => v.id != id)
          .toList();

      debugPrint('✅ User vehicle deleted from Supabase: $id');
    } catch (e) {
      debugPrint('❌ Failed to delete user vehicle from Supabase: $e');
      // Fallback to local only
      vehiclesListenable.value = vehiclesListenable.value
          .where((v) => v.id != id)
          .toList();
      debugPrint('✅ User vehicle deleted locally: $id');
    }
  }

  void deleteVehicle(String id) {
    vehiclesListenable.value = vehiclesListenable.value
        .where((v) => v.id != id)
        .toList();
    // Also remove from online status
    final newStatus = Map<String, bool>.from(onlineStatusListenable.value);
    newStatus.remove(id);
    onlineStatusListenable.value = newStatus;

    // Delete from Supabase asynchronously
    _supabase
        .from('vehicles')
        .delete()
        .eq('id', id)
        .then((_) {
          debugPrint('✅ User vehicle deleted from Supabase: $id');
        })
        .catchError((e) {
          debugPrint('❌ Failed to delete user vehicle from Supabase: $e');
        });
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
