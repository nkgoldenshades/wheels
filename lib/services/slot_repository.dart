import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/slot.dart';
import '../models/slot_entry.dart';
import '../models/post_mode.dart';
import '../models/vehicle.dart';
import '../models/exceptions.dart';
import 'auth_repository.dart';
import 'vehicle_repository.dart';
import 'profile_name_registry.dart';

class SlotRepository {
  SlotRepository._();

  static final SlotRepository instance = SlotRepository._();

  static const String _slotsKey = 'slots';

  final ValueNotifier<List<Slot>> _slots = ValueNotifier<List<Slot>>([]);
  final ValueNotifier<List<SlotEntry>> _slotEntries =
      ValueNotifier<List<SlotEntry>>([]);

  bool _initialized = false;

  // Cache for vehicle profile images (vehicleId -> profileImageUrl)
  final Map<String, String> _vehicleImageCache = {};

  // Cache for user profile avatars (profileId -> avatarUrl)
  final Map<String, String> _profileAvatarCache = {};

  ValueListenable<List<SlotEntry>> get slotsListenable => _slotEntries;

  List<SlotEntry> get allSlots => List.unmodifiable(_slotEntries.value);

  List<Slot> get allSlotsRaw => List.unmodifiable(_slots.value);

  List<Slot> get userSlots {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return [];
    return _slots.value;
  }

  /// Extract lat,lng from location string format: "Address|lat,lng|keywords"
  Map<String, double>? _extractLatLng(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('|');
    if (parts.length < 2) return null;

    final coords = parts[1].split(',');
    if (coords.length != 2) return null;

    final lat = double.tryParse(coords[0].trim());
    final lng = double.tryParse(coords[1].trim());

    if (lat == null || lng == null) return null;
    return {'lat': lat, 'lng': lng};
  }

  void _buildSlotEntries() {
    final entries = <SlotEntry>[];

    final vehicleCount = VehicleRepository.instance.allVehicles.length;
    final slotCount = _slots.value.length;

    if (kDebugMode) {
      debugPrint(
        '🔍 _buildSlotEntries: Building $slotCount slots with $vehicleCount vehicles available',
      );
    }

    int foundCount = 0;
    int notFoundCount = 0;

    for (final slot in _slots.value) {
      final vehicle = VehicleRepository.instance.getById(slot.vehicleId);

      if (vehicle != null) {
        // Vehicle found - use it
        foundCount++;
        entries.add(SlotEntry(slot: slot, vehicle: vehicle));
      } else {
        // Vehicle not found - create placeholder
        // Try to get the provider name from ProfileNameRegistry
        notFoundCount++;
        if (kDebugMode && notFoundCount == 1) {
          debugPrint('⚠️ Vehicle not found: ${slot.vehicleId}');
          if (vehicleCount > 0) {
            debugPrint(
              '⚠️ Available IDs: ${VehicleRepository.instance.allVehicles.take(3).map((v) => v.id).join(", ")}...',
            );
          }
        }

        // Try to get name from ProfileNameRegistry
        final providerName =
            ProfileNameRegistry.instance.getNameForUser(slot.profileId) ??
            'User ${slot.profileId.substring(0, 6)}';

        // Get cached vehicle image if available
        final cachedImage = _vehicleImageCache[slot.vehicleId];

        final placeholderVehicle = Vehicle(
          id: slot.vehicleId,
          userId: slot.profileId,
          userName: providerName,
          name:
              '${slot.serviceType.name[0].toUpperCase()}${slot.serviceType.name.substring(1)} Service',
          type: slot.serviceType.name,
          capabilities: [slot.serviceType],
          seatingCapacity: slot.capacity,
          profileImage: cachedImage, // Use cached image
          galleryImages: [],
          createdAt: slot.createdAt,
          gpsMode: VehicleGpsMode.manual,
          isVerifiedToggle: false,
          isExpertToggle: false,
          averageRating: 0.0,
          totalRatings: 0,
          totalBookings: 0,
          activePostsCount: 0,
          // All document verification fields removed
          currency: 'INR',
          countryCode: 'IN',
        );

        entries.add(SlotEntry(slot: slot, vehicle: placeholderVehicle));
      }
    }

    _slotEntries.value = entries;

    if (kDebugMode) {
      debugPrint(
        '📊 Built ${entries.length} entries: $foundCount found, $notFoundCount missing',
      );
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    await _loadSlots();

    // Listen to vehicle changes to rebuild slot entries
    VehicleRepository.instance.vehiclesListenable.addListener(
      _buildSlotEntries,
    );

    // Force rebuild after vehicles are loaded (in case they loaded after slots)
    _buildSlotEntries();

    _initialized = true;
  }

  Future<void> _loadSlots() async {
    try {
      // Load from Supabase first (source of truth)
      final supabase = Supabase.instance.client;

      debugPrint('🔍 Loading posts from Supabase...');
      debugPrint(
        '🔍 Firebase user: ${firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? "GUEST"}',
      );

      // Load only active, non-expired PROVIDER posts from Supabase.
      // Simplified: Just check post_type (no vehicle JOIN needed)
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final response = await supabase
          .from('posts')
          .select('*')
          .eq('is_active', true)
          .not('vehicle_id', 'is', null)
          .or('post_type.eq.offer,post_type.is.null')
          .gt('end_time', nowUtc)
          .order('created_at', ascending: false);

      debugPrint('🔍 Supabase response: ${response.length} posts found');

      _slots.value = (response as List)
          .map((json) => Slot.fromJson(json as Map<String, dynamic>))
          .toList();

      // Load profile names for all unique profile IDs
      await _loadProfileNames(_slots.value);

      // Load vehicle images for missing vehicles and cache them
      final imageMap = await _loadVehicleImages(_slots.value);
      _vehicleImageCache.addAll(imageMap);

      _buildSlotEntries();
      debugPrint('✅ Loaded ${_slots.value.length} slots from Supabase');

      // Save to local storage as cache
      await _saveSlots();
      return;
    } catch (e) {
      debugPrint('⚠️ Failed to load slots from Supabase, trying local: $e');
    }

    // Fallback to local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_slotsKey);

      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _slots.value = jsonList
            .map((json) => Slot.fromJson(json as Map<String, dynamic>))
            .toList();
        _buildSlotEntries();
        debugPrint('✅ Loaded ${_slots.value.length} slots from local storage');
      }
    } catch (e) {
      debugPrint('❌ Failed to load slots: $e');
      _slots.value = [];
      _slotEntries.value = [];
    }
  }

  Future<void> _saveSlots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(
        _slots.value.map((s) => s.toJson()).toList(),
      );
      await prefs.setString(_slotsKey, jsonString);
    } catch (e) {
      debugPrint('❌ Failed to save slots: $e');
    }
  }

  /// Load profile names from Supabase and cache them in ProfileNameRegistry
  Future<void> _loadProfileNames(List<Slot> slots) async {
    try {
      // Get unique profile IDs
      final profileIds = slots.map((s) => s.profileId).toSet().toList();

      if (profileIds.isEmpty) {
        debugPrint('📝 No profile IDs to load names for');
        return;
      }

      debugPrint('📝 Loading profile names for ${profileIds.length} users');

      final supabase = Supabase.instance.client;

      // Fetch profile names AND avatars from profiles_public table
      final response = await supabase
          .from('profiles_public')
          .select('id, full_name, avatar_url')
          .inFilter('id', profileIds);

      debugPrint('📝 Fetched ${response.length} profile names from Supabase');

      // Register each name in the ProfileNameRegistry
      await ProfileNameRegistry.instance.init();

      for (final profile in response) {
        final id = profile['id'] as String;
        final name = profile['full_name'] as String?;
        final avatarUrl = profile['avatar_url'] as String?;

        if (name != null && name.isNotEmpty) {
          // Directly update the registry (bypass availability check)
          await ProfileNameRegistry.instance.registerName(id, name);
          debugPrint('📝 Registered name for user $id: $name');
        }

        // Cache avatar URL (we'll create this cache)
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          _profileAvatarCache[id] = avatarUrl;
          debugPrint('📸 Cached avatar for user $id');
        }
      }

      debugPrint('✅ Profile names loaded and cached');
    } catch (e) {
      debugPrint('⚠️ Failed to load profile names: $e');
      // Don't throw - this is not critical enough to block loading
    }
  }

  /// Load vehicle profile images from Supabase for missing vehicles
  /// Returns a map of vehicleId -> profileImage
  Future<Map<String, String>> _loadVehicleImages(List<Slot> slots) async {
    try {
      // Get unique vehicle IDs from slots where vehicle not found
      final missingVehicleIds = <String>[];
      for (final slot in slots) {
        final vehicle = VehicleRepository.instance.getById(slot.vehicleId);
        if (vehicle == null) {
          missingVehicleIds.add(slot.vehicleId);
        }
      }

      if (missingVehicleIds.isEmpty) {
        debugPrint('📷 No missing vehicle images to load');
        return {};
      }

      debugPrint('📷 Loading images for ${missingVehicleIds.length} vehicles');

      final supabase = Supabase.instance.client;

      // Fetch vehicle profile images from vehicles table
      final response = await supabase
          .from('vehicles')
          .select('id, vehicle_photo_url')
          .inFilter('id', missingVehicleIds);

      debugPrint('📷 Fetched ${response.length} vehicle images from Supabase');

      // Build map of vehicleId -> profileImage
      final imageMap = <String, String>{};
      for (final vehicle in response) {
        final id = vehicle['id'] as String;
        final photoUrl = vehicle['vehicle_photo_url'] as String?;

        if (photoUrl != null && photoUrl.isNotEmpty) {
          imageMap[id] = photoUrl;
          debugPrint('📷 Cached image for vehicle $id');
        }
      }

      return imageMap;
    } catch (e) {
      debugPrint('⚠️ Failed to load vehicle images: $e');
      return {};
    }
  }

  Future<void> loadSlots() async {
    await _loadSlots();
    // Rebuild entries after loading slots (in case vehicles are already loaded)
    _buildSlotEntries();
  }

  Future<void> loadAllSlots() async {
    await _loadSlots();
    // Rebuild entries after loading slots (in case vehicles are already loaded)
    _buildSlotEntries();
  }

  /// Fetch ALL slots (including inactive) for a specific vehicle directly from Supabase
  /// This is used in vehicle detail screen to show all posts history
  Future<List<SlotEntry>> getAllSlotsForVehicle(String vehicleId) async {
    try {
      final supabase = Supabase.instance.client;
      debugPrint(
        '🔍 getAllSlotsForVehicle: Starting fetch for vehicleId=$vehicleId',
      );

      final response = await supabase
          .from('posts')
          .select('*')
          .eq('vehicle_id', vehicleId)
          .or('post_type.eq.offer,post_type.is.null')
          .order('created_at', ascending: false)
          .timeout(
            const Duration(seconds: 10),
          ); // Add timeout to prevent hanging

      debugPrint(
        '🔍 getAllSlotsForVehicle: Query returned ${response.length} slots',
      );

      final slots = (response as List)
          .map((json) => Slot.fromJson(json as Map<String, dynamic>))
          .toList();

      // Get the vehicle
      final vehicle = VehicleRepository.instance.getById(vehicleId);
      if (vehicle == null) {
        debugPrint('⚠️ getAllSlotsForVehicle: Vehicle not found in repository');
        return [];
      }

      // Build slot entries
      final entries = slots
          .map((slot) => SlotEntry(slot: slot, vehicle: vehicle))
          .toList();

      debugPrint(
        '✅ getAllSlotsForVehicle: Returning ${entries.length} slot entries',
      );
      return entries;
    } catch (e) {
      debugPrint('❌ Failed to load all slots for vehicle $vehicleId: $e');
      return [];
    }
  }

  /// Get total count of ALL posts (including inactive) for a vehicle
  Future<int> getTotalPostCountForVehicle(String vehicleId) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('posts')
          .select('id')
          .eq('vehicle_id', vehicleId)
          .or('post_type.eq.offer,post_type.is.null');

      return (response as List).length;
    } catch (e) {
      debugPrint('❌ Failed to get post count for vehicle $vehicleId: $e');
      return 0;
    }
  }

  Future<void> addSlot(Slot slot) async {
    try {
      _slots.value = [slot, ..._slots.value];
      _buildSlotEntries();
      await _saveSlots();
      debugPrint('✅ Slot created locally: ${slot.id}');

      // Sync to Supabase
      await _syncSlotToSupabase(slot);
    } catch (e) {
      debugPrint('❌ Failed to create slot: $e');
      rethrow;
    }
  }

  Future<void> _syncSlotToSupabase(Slot slot) async {
    try {
      debugPrint('🚨🚨🚨 SYNCING SLOT TO SUPABASE - START 🚨🚨🚨');

      final supabase = Supabase.instance.client;
      final currentUser = AuthRepository.instance.currentUser;

      if (currentUser == null) {
        debugPrint('⚠️ No user logged in - skipping Supabase sync');
        return;
      }

      // Generate short 6-char reference code from timestamp
      final refCode = slot.id.toString().substring(
        slot.id.toString().length - 6,
      );

      debugPrint('🔍 DEBUG: profile_id to insert: ${currentUser.id}');

      // Check if profile exists first
      try {
        final profileCheck = await supabase
            .from('profiles_public')
            .select('id')
            .eq('id', currentUser.id)
            .maybeSingle();

        if (profileCheck == null) {
          debugPrint('❌ CRITICAL: Profile does not exist in Supabase!');
          debugPrint('👉 Run syncUserToSupabase() first');
          throw Exception(
            'Profile not found in Supabase. Please sync user first.',
          );
        }
        debugPrint('✅ Profile exists in Supabase');
      } catch (e) {
        debugPrint('❌ Failed to check profile: $e');
        rethrow;
      }

      // Verify vehicle belongs to current user
      try {
        final vehicleCheck = await supabase
            .from('vehicles')
            .select('profile_id')
            .eq('id', slot.vehicleId)
            .maybeSingle();

        if (vehicleCheck == null) {
          debugPrint('❌ CRITICAL: Vehicle not found in Supabase!');
          throw Exception('Vehicle not found: ${slot.vehicleId}');
        }

        // Detailed logging for debugging
        final vehicleProfileId = vehicleCheck['profile_id'];
        final currentUserId = currentUser.id;

        debugPrint('🔍 VEHICLE OWNERSHIP CHECK:');
        debugPrint('   Vehicle ID: ${slot.vehicleId}');
        debugPrint('   Vehicle profile_id from DB: $vehicleProfileId');
        debugPrint(
          '   Vehicle profile_id type: ${vehicleProfileId.runtimeType}',
        );
        debugPrint('   Current user ID: $currentUserId');
        debugPrint('   Current user ID type: ${currentUserId.runtimeType}');
        debugPrint('   Are they equal? ${vehicleProfileId == currentUserId}');
        debugPrint(
          '   String comparison: ${vehicleProfileId.toString() == currentUserId.toString()}',
        );

        // Also check Firebase UID
        final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          debugPrint('   Firebase UID: ${firebaseUser.uid}');
          debugPrint(
            '   Firebase UID matches currentUser.id? ${firebaseUser.uid == currentUserId}',
          );
        }

        if (vehicleProfileId != currentUserId) {
          debugPrint('❌ CRITICAL: Vehicle does not belong to current user!');
          throw Exception(
            'Vehicle does not belong to current user. Please select your own vehicle.',
          );
        }

        debugPrint('✅ Vehicle ownership verified');
      } catch (e) {
        debugPrint('❌ Failed to verify vehicle ownership: $e');
        rethrow;
      }

      // Check current auth state
      final authHeaders = supabase.headers;
      debugPrint(
        '🔑 Auth headers: ${authHeaders['Authorization']?.substring(0, 50)}...',
      );

      // Extract coordinates from location strings
      final fromCoords = _extractLatLng(slot.fromLocation);
      final toCoords = _extractLatLng(slot.toLocation);
      final baseCoords = _extractLatLng(slot.baseLocation);

      debugPrint('📍 Location coordinates:');
      debugPrint(
        '   From: ${slot.fromLocation} → lat: ${fromCoords?['lat']}, lng: ${fromCoords?['lng']}',
      );
      debugPrint(
        '   To: ${slot.toLocation} → lat: ${toCoords?['lat']}, lng: ${toCoords?['lng']}',
      );
      debugPrint(
        '   Base: ${slot.baseLocation} → lat: ${baseCoords?['lat']}, lng: ${baseCoords?['lng']}',
      );

      final insertData = {
        'id': slot.id,
        'profile_id': currentUser.id,
        'vehicle_id': slot.vehicleId,
        'service_type': slot.serviceType.name,
        'slot_type': slot.slotType.name,
        'slot_layout_structure': slot.seatLayoutStructure?.toJson(),

        // Location strings (for display)
        'from_location': slot.fromLocation,
        'to_location': slot.toLocation,
        'base_location': slot.baseLocation,

        // Separate coordinate columns (for mapping/distance calculations)
        if (fromCoords != null) 'from_lat': fromCoords['lat'],
        if (fromCoords != null) 'from_lng': fromCoords['lng'],
        if (toCoords != null) 'to_lat': toCoords['lat'],
        if (toCoords != null) 'to_lng': toCoords['lng'],
        if (baseCoords != null) 'base_lat': baseCoords['lat'],
        if (baseCoords != null) 'base_lng': baseCoords['lng'],

        'radius': slot.radius,
        'start_time': slot.startTime.toUtc().toIso8601String(),
        'end_time': slot.endTime.toUtc().toIso8601String(),
        'price': slot.price,
        'capacity': slot.capacity,
        'terms': slot.notes, // notes maps to terms in DB
        'pickup_option': slot.pickupOption.name,
        // Parcel fields
        if (slot.maxWeight != null) 'max_weight': slot.maxWeight,
        if (slot.maxLength != null) 'max_length': slot.maxLength,
        if (slot.maxWidth != null) 'max_width': slot.maxWidth,
        if (slot.maxHeight != null) 'max_height': slot.maxHeight,
        // Lease fields
        if (slot.securityDeposit != null)
          'security_deposit': slot.securityDeposit,
        if (slot.fuelPolicy != null) 'fuel_policy': slot.fuelPolicy,
        'with_operator': slot.withOperator,
        // Post mode
        'postmode': slot.postMode.dbValue,
        'post_type': 'offer', // Mark as provider post (offering service)
        'is_active': slot.isAvailable,
        'currency_type': slot.currencyType,
        'created_at': DateTime.now().toIso8601String(),
      };

      debugPrint('⏰ TIME DEBUG - START ⏰');
      debugPrint('slot.startTime: ${slot.startTime}');
      debugPrint('slot.startTime.isUtc: ${slot.startTime.isUtc}');
      debugPrint('startTime ISO: ${slot.startTime.toIso8601String()}');
      debugPrint('⏰ TIME DEBUG - END ⏰');
      debugPrint(
        '📤 Inserting: start_time=${insertData['start_time']}, end_time=${insertData['end_time']}',
      );

      await supabase.from('posts').insert(insertData);

      debugPrint('✅ Slot synced to Supabase: ${slot.id} (ref: $refCode)');
    } catch (e) {
      debugPrint('❌ Failed to sync slot to Supabase: $e');
      // Don't throw - allow slot creation to succeed even if Supabase sync fails
    }
  }

  Future<void> updateSlot(Slot slot) async {
    try {
      final index = _slots.value.indexWhere((s) => s.id == slot.id);
      if (index != -1) {
        final updated = List<Slot>.from(_slots.value);
        updated[index] = slot;
        _slots.value = updated;
        _buildSlotEntries();
        await _saveSlots();
        debugPrint('✅ Slot updated locally: ${slot.id}');

        // Sync to Supabase
        await _updateSlotInSupabase(slot);
      }
    } catch (e) {
      debugPrint('❌ Failed to update slot: $e');
      rethrow;
    }
  }

  Future<void> deleteSlot(String slotId) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    debugPrint('🗑️ Deleting slot: $slotId (user: ${user.uid})');

    final supabase = Supabase.instance.client;
    final raw = await supabase.rpc(
      'safe_delete_post',
      params: {'p_post_id': slotId, 'p_profile_id': user.uid},
    );

    debugPrint('🔍 safe_delete_post raw: $raw (${raw.runtimeType})');

    // RPC not deployed yet — fall back to direct delete
    if (raw == null) {
      debugPrint(
        '⚠️ safe_delete_post returned null — RPC not deployed, using direct delete',
      );
      await supabase
          .from('posts')
          .delete()
          .eq('id', slotId)
          .eq('profile_id', user.uid);
      debugPrint('✅ Slot deleted directly: $slotId');
      _slots.value = _slots.value.where((s) => s.id != slotId).toList();
      _buildSlotEntries();
      await _saveSlots();
      return;
    }

    // Parse result safely
    final Map<String, dynamic> result;
    if (raw is Map<String, dynamic>) {
      result = raw;
    } else if (raw is Map) {
      result = Map<String, dynamic>.from(raw);
    } else {
      debugPrint('⚠️ Unexpected RPC result type: ${raw.runtimeType} — $raw');
      throw Exception('Unexpected response from safe_delete_post: $raw');
    }

    debugPrint('🗑️ safe_delete_post result: $result');

    final success = result['success'] as bool? ?? false;
    final code = result['code'] as String? ?? '';

    if (!success) {
      if (code == 'has_active_bookings') {
        final count = result['active_count'] as int? ?? 0;
        throw ActiveBookingsException(count);
      }
      throw Exception(result['message'] ?? 'Delete failed');
    }

    debugPrint('✅ Slot deleted from Supabase: $slotId');
    _slots.value = _slots.value.where((s) => s.id != slotId).toList();
    _buildSlotEntries();
    await _saveSlots();
  }

  Future<void> _updateSlotInSupabase(Slot slot) async {
    try {
      final supabase = Supabase.instance.client;

      // Extract coordinates from location strings
      final fromCoords = _extractLatLng(slot.fromLocation);
      final toCoords = _extractLatLng(slot.toLocation);
      final baseCoords = _extractLatLng(slot.baseLocation);

      debugPrint('📍 Updating location coordinates:');
      debugPrint(
        '   From: ${slot.fromLocation} → lat: ${fromCoords?['lat']}, lng: ${fromCoords?['lng']}',
      );
      debugPrint(
        '   To: ${slot.toLocation} → lat: ${toCoords?['lat']}, lng: ${toCoords?['lng']}',
      );
      debugPrint(
        '   Base: ${slot.baseLocation} → lat: ${baseCoords?['lat']}, lng: ${baseCoords?['lng']}',
      );

      await supabase
          .from('posts')
          .update({
            'vehicle_id': slot.vehicleId,
            'service_type': slot.serviceType.name,
            'slot_type': slot.slotType.name,
            'slot_layout_structure': slot.seatLayoutStructure?.toJson(),

            // Location strings (for display)
            'from_location': slot.fromLocation,
            'to_location': slot.toLocation,
            'base_location': slot.baseLocation,

            // Separate coordinate columns (for mapping/distance calculations)
            if (fromCoords != null) 'from_lat': fromCoords['lat'],
            if (fromCoords != null) 'from_lng': fromCoords['lng'],
            if (toCoords != null) 'to_lat': toCoords['lat'],
            if (toCoords != null) 'to_lng': toCoords['lng'],
            if (baseCoords != null) 'base_lat': baseCoords['lat'],
            if (baseCoords != null) 'base_lng': baseCoords['lng'],

            'radius': slot.radius,
            'start_time': slot.startTime.toUtc().toIso8601String(),
            'end_time': slot.endTime.toUtc().toIso8601String(),
            'price': slot.price,
            'capacity': slot.capacity,
            'terms': slot.notes, // notes maps to terms in DB
            // 'images': removed - posts use vehicle images
            'pickup_option': slot.pickupOption.name,
            // Parcel fields
            if (slot.maxWeight != null) 'max_weight': slot.maxWeight,
            if (slot.maxLength != null) 'max_length': slot.maxLength,
            if (slot.maxWidth != null) 'max_width': slot.maxWidth,
            if (slot.maxHeight != null) 'max_height': slot.maxHeight,
            // Lease fields
            if (slot.securityDeposit != null)
              'security_deposit': slot.securityDeposit,
            if (slot.fuelPolicy != null) 'fuel_policy': slot.fuelPolicy,
            'with_operator': slot.withOperator,
            // Post mode
            'postmode': slot.postMode.dbValue,
            'is_active': slot.isAvailable,
            'currency_type': slot.currencyType,
            // Edit history - save to Edittimesanddetails column (matches Supabase schema)
            'Edittimesanddetails': slot.editHistory.toJson(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', slot.id);

      debugPrint('✅ Slot updated in Supabase: ${slot.id}');
      if (slot.editHistory.hasEdits) {
        debugPrint(
          '📝 Edit history saved: ${slot.editHistory.totalEdits} edits',
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to update slot in Supabase: $e');
    }
  }

  List<Slot> getSlotsForVehicle(String vehicleId) {
    return _slots.value.where((s) => s.vehicleId == vehicleId).toList();
  }

  List<Slot> getSlotsByVehicleId(String vehicleId) {
    return getSlotsForVehicle(vehicleId);
  }

  /// Get cached avatar URL for a profile ID
  String getProfileAvatar(String profileId) {
    return _profileAvatarCache[profileId] ?? '';
  }

  List<SlotEntry> getSlotEntriesByVehicleId(String vehicleId) {
    return _slotEntries.value
        .where((e) => e.slot.vehicleId == vehicleId)
        .toList();
  }
}
