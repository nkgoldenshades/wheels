import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle.dart';
import '../models/service_type.dart';
import 'auth_repository.dart';

class VehicleRepository {
  VehicleRepository._();

  static final VehicleRepository instance = VehicleRepository._();

  static const String _vehiclesKey = 'vehicles';
  static const String _onlineStatusKey = 'vehicle_online_status';

  final _supabase = Supabase.instance.client;
  final ValueNotifier<List<Vehicle>> _vehicles = ValueNotifier<List<Vehicle>>(
    [],
  );
  final ValueNotifier<Map<String, bool>> _onlineStatus =
      ValueNotifier<Map<String, bool>>({});

  bool _initialized = false;

  ValueListenable<List<Vehicle>> get vehiclesListenable => _vehicles;
  ValueListenable<Map<String, bool>> get onlineStatusListenable =>
      _onlineStatus;

  List<Vehicle> get allVehicles => List.unmodifiable(_vehicles.value);

  List<Vehicle> get userVehicles {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return [];
    return _vehicles.value.where((v) => v.userId == currentUser.id).toList();
  }

  Future<void> init() async {
    if (_initialized) return;
    await _loadVehicles();
    await _loadOnlineStatus();
    _initialized = true;
  }

  Future<void> _loadVehicles() async {
    try {
      // Try loading from Supabase first
      dynamic response;
      try {
        response = await _supabase
            .from('vehicles')
            .select()
            .eq('is_user_vehicle', false)
            .eq('is_online', true)
            .order('created_at', ascending: false);
      } on PostgrestException catch (e) {
        if (e.code == '42703') {
          response = await _supabase
              .from('vehicles')
              .select()
              .order('created_at', ascending: false);
        } else {
          rethrow;
        }
      }

      _vehicles.value = (response as List)
          .map((json) => Vehicle.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Loaded ${_vehicles.value.length} vehicles from Supabase');
    } catch (e) {
      debugPrint('⚠️  Failed to load from Supabase, trying local: $e');
      // Fallback to local storage
      await _loadVehiclesLocal();
    }
  }

  Future<void> _loadVehiclesLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_vehiclesKey);

      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _vehicles.value = jsonList
            .map((json) => Vehicle.fromJson(json as Map<String, dynamic>))
            .toList();
        debugPrint(
          '✅ Loaded ${_vehicles.value.length} vehicles from local storage',
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to load vehicles: $e');
      _vehicles.value = [];
    }
  }

  Future<void> _saveVehicles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(
        _vehicles.value.map((v) => v.toJson()).toList(),
      );
      await prefs.setString(_vehiclesKey, jsonString);
    } catch (e) {
      debugPrint('❌ Failed to save vehicles: $e');
    }
  }

  Future<void> _loadOnlineStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_onlineStatusKey);

      if (jsonString != null) {
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        _onlineStatus.value = jsonMap.map(
          (key, value) => MapEntry(key, value as bool),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to load online status: $e');
    }
  }

  Future<void> _saveOnlineStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(_onlineStatus.value);
      await prefs.setString(_onlineStatusKey, jsonString);
    } catch (e) {
      debugPrint('❌ Failed to save online status: $e');
    }
  }

  Future<void> loadVehicles() async {
    await _loadVehicles();
  }

  Future<void> loadAllVehicles() async {
    await _loadVehicles();
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
        'user_id': vehicle.userId,
        'name': vehicle.name,
        'type': vehicle.type,
        'year': vehicle.year,
        'capabilities': vehicle.capabilities.map((e) => e.name).toList(),
        'photos': photos,
        'created_at': vehicle.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      debugPrint(
        '🚗 Supabase vehicle insert payload (provider): id=${payload['id']} user_id=${payload['user_id']}',
      );

      await _supabase.from('vehicles').insert(payload);

      // Update local state
      _vehicles.value = [vehicle, ..._vehicles.value];
      await _saveVehicles();

      debugPrint('✅ Vehicle created in Supabase: ${vehicle.id}');
    } catch (e) {
      if (e is PostgrestException) {
        debugPrint(
          '❌ Failed to create vehicle in Supabase (provider): code=${e.code} message=${e.message} details=${e.details} hint=${e.hint} id=${vehicle.id} user_id=${vehicle.userId}',
        );
      } else {
        debugPrint('❌ Failed to create vehicle in Supabase: $e');
      }
      // Fallback to local only
      _vehicles.value = [vehicle, ..._vehicles.value];
      await _saveVehicles();
      debugPrint('✅ Vehicle created locally: ${vehicle.id}');
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
      final index = _vehicles.value.indexWhere((v) => v.id == vehicle.id);
      if (index != -1) {
        final updated = List<Vehicle>.from(_vehicles.value);
        updated[index] = vehicle;
        _vehicles.value = updated;
        await _saveVehicles();
      }

      debugPrint('✅ Vehicle updated in Supabase: ${vehicle.id}');
    } catch (e) {
      debugPrint('❌ Failed to update vehicle in Supabase: $e');
      // Fallback to local only
      final index = _vehicles.value.indexWhere((v) => v.id == vehicle.id);
      if (index != -1) {
        final updated = List<Vehicle>.from(_vehicles.value);
        updated[index] = vehicle;
        _vehicles.value = updated;
        await _saveVehicles();
        debugPrint('✅ Vehicle updated locally: ${vehicle.id}');
      }
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    try {
      // Delete from Supabase
      await _supabase.from('vehicles').delete().eq('id', vehicleId);

      // Update local state
      _vehicles.value = _vehicles.value
          .where((v) => v.id != vehicleId)
          .toList();
      await _saveVehicles();

      debugPrint('✅ Vehicle deleted from Supabase: $vehicleId');
    } catch (e) {
      debugPrint('❌ Failed to delete vehicle from Supabase: $e');
      // Fallback to local only
      _vehicles.value = _vehicles.value
          .where((v) => v.id != vehicleId)
          .toList();
      await _saveVehicles();
      debugPrint('✅ Vehicle deleted locally: $vehicleId');
    }
  }

  Future<void> setOnlineStatus(String vehicleId, bool isOnline) async {
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
      final updated = Map<String, bool>.from(_onlineStatus.value);
      updated[vehicleId] = isOnline;
      _onlineStatus.value = updated;
      await _saveOnlineStatus();

      debugPrint(
        '✅ Vehicle online status updated in Supabase: $vehicleId = $isOnline',
      );
    } catch (e) {
      debugPrint('❌ Failed to update vehicle online status in Supabase: $e');
      // Fallback to local only
      final updated = Map<String, bool>.from(_onlineStatus.value);
      updated[vehicleId] = isOnline;
      _onlineStatus.value = updated;
      await _saveOnlineStatus();
    }
  }

  bool isOnline(String vehicleId) {
    return _onlineStatus.value[vehicleId] ?? true; // Default to online
  }

  Vehicle? getById(String vehicleId) {
    try {
      return _vehicles.value.firstWhere((v) => v.id == vehicleId);
    } catch (e) {
      return null;
    }
  }

  Future<void> removeVehicle(String vehicleId) async {
    await deleteVehicle(vehicleId);
  }

  Future<void> setOnline(String vehicleId, bool isOnline) async {
    await setOnlineStatus(vehicleId, isOnline);
  }

  List<Vehicle> getVehiclesByCapability(ServiceType capability) {
    return _vehicles.value
        .where((v) => v.capabilities.contains(capability))
        .toList();
  }
}
