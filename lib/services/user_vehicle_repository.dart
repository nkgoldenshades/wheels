import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle.dart';
import 'auth_repository.dart';

/// Separate vehicle repository for "My Posts" section
/// This keeps user's personal vehicles separate from provider vehicles
class UserVehicleRepository {
  UserVehicleRepository._();

  static final UserVehicleRepository instance = UserVehicleRepository._();

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
      // Load user vehicles from Supabase
      dynamic response;
      try {
        response = await _supabase
            .from('vehicles')
            .select()
            .eq('user_id', currentUser.id)
            .eq('is_user_vehicle', true)
            .order('created_at', ascending: false);
      } on PostgrestException catch (e) {
        if (e.code == '42703') {
          response = await _supabase
              .from('vehicles')
              .select()
              .eq('user_id', currentUser.id)
              .order('created_at', ascending: false);
        } else {
          rethrow;
        }
      }

      vehiclesListenable.value = (response as List)
          .map((json) => Vehicle.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint(
        '✅ Loaded ${vehiclesListenable.value.length} user vehicles from Supabase',
      );
    } catch (e) {
      debugPrint('⚠️  Failed to load user vehicles from Supabase: $e');
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
      // Add to Supabase
      final vehicleJson = vehicle.toJson();
      vehicleJson['is_user_vehicle'] = true; // User vehicle

      try {
        await _supabase.from('vehicles').insert(vehicleJson);
      } on PostgrestException catch (e) {
        if (e.code == '42703') {
          final fallbackJson = Map<String, dynamic>.from(vehicleJson);
          fallbackJson.remove('is_user_vehicle');
          await _supabase.from('vehicles').insert(fallbackJson);
        } else {
          rethrow;
        }
      }

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
      await _supabase
          .from('vehicles')
          .update(vehicle.toJson())
          .eq('id', vehicle.id);

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
      await _supabase
          .from('vehicles')
          .update({
            'is_online': isOnline,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', vehicleId);

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
