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
    debugPrint('⏳ Starting VehicleRepository initialization...');
    await _loadVehicles();
    await _loadOnlineStatus();
    _initialized = true;
    debugPrint('✅ VehicleRepository initialized with ${_vehicles.value.length} vehicles');
  }

  Future<void> _loadVehicles() async {
    debugPrint('🔍 VehicleRepository: Starting to load vehicles from vehicles table...');
    try {
      // Load provider vehicles from Supabase (vehicles users are offering)
      // Query vehicles table directly - NO FILTER to test RLS
      final response = await _supabase
          .from('vehicles')  // ✅ Query vehicles table directly
          .select('''
            *,
            profiles_public (
              full_name,
              profile_photo_url
            )
          ''')  // Join with profiles_public - PostgREST auto-detects FK
          // .eq('is_active', true)  // Temporarily removed to test
          .order('created_at', ascending: false);

      debugPrint('🔍 VehicleRepository: Query completed, processing ${(response as List).length} vehicles');
      
      _vehicles.value = (response as List)
          .map((json) {
            // 🔍 DEBUG: Print raw JSON (truncate large fields)
            if (kDebugMode) {
              final debugJson = Map<String, dynamic>.from(json);
              // Truncate base64 images to avoid huge logs
              if (debugJson['vehicle_photo_url'] != null && debugJson['vehicle_photo_url'].toString().length > 100) {
                debugJson['vehicle_photo_url'] = '${debugJson['vehicle_photo_url'].toString().substring(0, 50)}... [TRUNCATED]';
              }
              if (debugJson['gallery_images'] is List) {
                debugJson['gallery_images'] = '[${(debugJson['gallery_images'] as List).length} images]';
              }
              debugPrint('🔍 RAW VEHICLE JSON: $debugJson');
              debugPrint('🔍 profiles value: ${json['profiles']}');
            }
            
            // Flatten the profiles data into the vehicle object
            final vehicleData = Map<String, dynamic>.from(json);
            if (json['profiles_public'] != null) {
              vehicleData['profile_name'] = json['profiles_public']['full_name'];
              vehicleData['profile_avatar'] = json['profiles_public']['profile_photo_url'];
              if (kDebugMode) {
                debugPrint('✅ Profile found: ${json['profiles_public']['full_name']}');
              }
            } else {
              if (kDebugMode) {
                debugPrint('❌ profiles_public is NULL for vehicle: ${json['id']}');
              }
            }
            return Vehicle.fromJson(vehicleData);
          })
          .toList();

      debugPrint('✅ Loaded ${_vehicles.value.length} vehicles from Supabase');
      if (_vehicles.value.isNotEmpty) {
        final firstVehicle = _vehicles.value[0];
        debugPrint('🔍 First vehicle: id=${firstVehicle.id}, userName=${firstVehicle.userName}, name=${firstVehicle.name}');
      } else {
        debugPrint('⚠️ No vehicles returned - RLS is blocking ALL vehicles!');
      }
    } catch (e) {
      debugPrint('❌ Failed to load from Supabase: $e');
      if (e is PostgrestException) {
        debugPrint('❌ Postgrest error: code=${e.code}, message=${e.message}');
      }
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
      // Add to Supabase - match the real public.vehicles schema
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
        'is_online': true, // Vehicle is online by default when created
        'vehicle_owner': 'provider', // Enum: provider or customer
        
        // Statistics
        'total_trips': vehicle.totalBookings,
        'total_reviews': vehicle.totalRatings,
        'active_posts_count': vehicle.activePostsCount,
        'is_verified': vehicle.rcVerified,
        'verified_at': vehicle.rcVerifiedAt?.toIso8601String(),
      };

      debugPrint(
        '🚗 Supabase vehicle insert payload (provider): id=${payload['id']} profile_id=${payload['profile_id']}',
      );

      await _supabase.from('vehicles').insert(payload);

      // Insert sensitive info into vehicle_sensitive_info table
      final sensitivePayload = <String, dynamic>{
        'vehicle_id': vehicle.id,
        'profile_id': vehicle.userId,
        if (vehicle.rcFrontUrl != null) 'rc_front_url': vehicle.rcFrontUrl,
        if (vehicle.rcBackUrl != null) 'rc_back_url': vehicle.rcBackUrl,
        if (vehicle.insuranceNumber != null) 'insurance_number': vehicle.insuranceNumber,
        if (vehicle.insuranceExpiry != null) 'insurance_expiry': vehicle.insuranceExpiry!.toIso8601String().split('T').first,
        if (vehicle.insuranceDocumentUrl != null) 'insurance_document_url': vehicle.insuranceDocumentUrl,
        if (vehicle.pollutionCertificateUrl != null) 'pollution_certificate_url': vehicle.pollutionCertificateUrl,
        if (vehicle.pollutionExpiry != null) 'pollution_expiry': vehicle.pollutionExpiry!.toIso8601String().split('T').first,
        if (vehicle.fitnessCertificateUrl != null) 'fitness_certificate_url': vehicle.fitnessCertificateUrl,
        if (vehicle.fitnessExpiry != null) 'fitness_expiry': vehicle.fitnessExpiry!.toIso8601String().split('T').first,
        if (vehicle.operatorName != null) 'operator_name': vehicle.operatorName,
        if (vehicle.operatorPhone != null) 'operator_phone': vehicle.operatorPhone,
        if (vehicle.operatorPhoto != null) 'operator_profile_photo_url': vehicle.operatorPhoto,
      };
      await _supabase.from('vehicle_sensitive_info').upsert(sensitivePayload, onConflict: 'vehicle_id');

      // Update local state
      _vehicles.value = [vehicle, ..._vehicles.value];
      await _saveVehicles();

      debugPrint('✅ Provider vehicle created in Supabase: ${vehicle.id}');
    } catch (e) {
      if (e is PostgrestException) {
        debugPrint(
          '❌ Failed to create provider vehicle in Supabase: code=${e.code} message=${e.message} details=${e.details} hint=${e.hint} id=${vehicle.id} profile_id=${vehicle.userId}',
        );
      } else {
        debugPrint('❌ Failed to create provider vehicle in Supabase: $e');
      }
      // Fallback to local only
      _vehicles.value = [vehicle, ..._vehicles.value];
      await _saveVehicles();
      debugPrint('✅ Provider vehicle created locally: ${vehicle.id}');
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
      // Check if vehicle has ANY posts
      final posts = await _supabase
          .from('posts')
          .select('id')
          .eq('vehicle_id', vehicleId);
      
      if (posts.isNotEmpty) {
        final postCount = posts.length;
        throw Exception(
          'Cannot delete vehicle: $postCount post${postCount > 1 ? 's' : ''} exist. '
          'Please delete all posts using this vehicle first.'
        );
      }
      
      // Safe to delete - no posts exist
      // Note: Delete from main vehicles table (not the view)
      await _supabase.from('vehicles').delete().eq('id', vehicleId);

      // Update local state
      _vehicles.value = _vehicles.value
          .where((v) => v.id != vehicleId)
          .toList();
      await _saveVehicles();

      debugPrint('✅ Vehicle deleted from Supabase: $vehicleId');
    } catch (e) {
      debugPrint('❌ Failed to delete vehicle: $e');
      rethrow; // Re-throw to show error to user
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



