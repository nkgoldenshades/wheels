import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/slot.dart';
import '../models/slot_entry.dart';
import '../models/post_mode.dart';
import '../models/vehicle.dart';
import '../models/service_type.dart';
import '../models/exceptions.dart';
import 'auth_repository.dart';
import 'customer_vehicle_repository.dart';
import 'profile_name_registry.dart';

/// Separate slot repository for "My Posts" section
/// This keeps user's personal posts separate from provider posts
class CustomerSlotRepository {
  CustomerSlotRepository._();

  static final CustomerSlotRepository instance = CustomerSlotRepository._();

  static const String _userSlotsKey = 'user_slots';

  final ValueNotifier<List<Slot>> _slots = ValueNotifier<List<Slot>>([]);
  final ValueNotifier<List<SlotEntry>> slotsListenable = ValueNotifier([]);

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _loadSlots();
    
    // Listen to vehicle changes to rebuild slot entries
    CustomerVehicleRepository.instance.vehiclesListenable.addListener(_buildSlotEntries);
    
    _initialized = true;
  }

  void _buildSlotEntries() {
    final entries = <SlotEntry>[];
    for (final slot in _slots.value) {
      final vehicle = CustomerVehicleRepository.instance.getById(slot.vehicleId);
      
      if (vehicle != null) {
        // Vehicle found - use it
        entries.add(SlotEntry(slot: slot, vehicle: vehicle));
      } else {
        // Vehicle not found - create placeholder
        debugPrint('⚠️ Vehicle not found for user slot ${slot.id}, using placeholder');

        final providerName = ProfileNameRegistry.instance.getNameForUser(slot.profileId) ?? 'User ${slot.profileId.substring(0, 6)}';

        final placeholderVehicle = Vehicle(
          id: slot.vehicleId,
          userId: slot.profileId,
          userName: providerName,
          name: '${slot.serviceType.displayName} Service',
          type: slot.serviceType.name,
          capabilities: [slot.serviceType],
          seatingCapacity: slot.capacity,
          galleryImages: [],
          createdAt: slot.createdAt,
          gpsMode: VehicleGpsMode.manual,
          isVerifiedToggle: false,
          isExpertToggle: false,
          averageRating: 0.0,
          totalRatings: 0,
          totalBookings: 0,
          activePostsCount: 0,
          rcVerified: false,
          insuranceVerified: false,
          dlVerified: false,
          aadhaarVerified: false,
          panVerified: false,
          currency: 'INR',
          countryCode: 'IN',
        );
        
        entries.add(SlotEntry(slot: slot, vehicle: placeholderVehicle));
      }
    }
    slotsListenable.value = entries;
    debugPrint('📊 Built ${entries.length} user slot entries from ${_slots.value.length} slots');
  }

  Future<void> _loadSlots() async {
    try {
      // Load from Supabase first (source of truth)
      final supabase = Supabase.instance.client;
      
      debugPrint('🔍 Loading user posts from Supabase...');
      debugPrint('🔍 Firebase user: ${firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? "GUEST"}');
      
      // Load ALL active user posts (requests) - not just current user's
      final response = await supabase
          .from('posts')
          .select('*')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      debugPrint('🔍 Supabase user_posts response: ${response.length} posts found');
      
      _slots.value = (response as List)
          .map((json) => Slot.fromJson(json as Map<String, dynamic>))
          .toList();
      
      _buildSlotEntries();
      debugPrint('✅ Loaded ${_slots.value.length} user slots from Supabase');
      
      // Save to local storage as cache
      await _saveSlots();
      return;
    } catch (e) {
      debugPrint('⚠️ Failed to load user slots from Supabase, trying local: $e');
    }
    
    // Fallback to local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_userSlotsKey);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _slots.value = jsonList
            .map((json) => Slot.fromJson(json as Map<String, dynamic>))
            .toList();
        _buildSlotEntries();
        debugPrint('✅ Loaded ${_slots.value.length} user slots from local storage');
      } else {
        _slots.value = [];
        slotsListenable.value = [];
      }
    } catch (e) {
      debugPrint('❌ Failed to load user slots: $e');
      _slots.value = [];
      slotsListenable.value = [];
    }
  }

  Future<void> _saveSlots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(
        _slots.value.map((s) => s.toJson()).toList(),
      );
      await prefs.setString(_userSlotsKey, jsonString);
      debugPrint('✅ Saved ${_slots.value.length} user slots to local storage');
    } catch (e) {
      debugPrint('❌ Failed to save user slots: $e');
    }
  }

  List<SlotEntry> get allSlots => slotsListenable.value;

  List<Slot> get allSlotsRaw => _slots.value;

  Slot? getById(String id) {
    try {
      return _slots.value.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addSlot(Slot slot) async {
    final vehicle = CustomerVehicleRepository.instance.getById(slot.vehicleId);
    if (vehicle == null) {
      debugPrint('❌ Vehicle not found for slot: ${slot.vehicleId}');
      return;
    }

    _slots.value = [slot, ..._slots.value];
    _buildSlotEntries();
    await _saveSlots();
    debugPrint('✅ User slot created locally: ${slot.id}');
    
    // Sync to Supabase
    await _syncSlotToSupabase(slot);
  }

  Future<void> updateSlot(Slot slot) async {
    final vehicle = CustomerVehicleRepository.instance.getById(slot.vehicleId);
    if (vehicle == null) {
      debugPrint('❌ Vehicle not found for slot: ${slot.vehicleId}');
      return;
    }

    _slots.value = _slots.value
        .map((s) => s.id == slot.id ? slot : s)
        .toList();
    _buildSlotEntries();
    await _saveSlots();
    debugPrint('✅ User slot updated locally: ${slot.id}');
    
    // Sync to Supabase
    await _syncSlotToSupabase(slot, isUpdate: true);
  }

  Future<void> deleteSlot(String id) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    debugPrint('🗑️ Deleting user slot: $id (user: ${user.uid})');

    final supabase = Supabase.instance.client;
    final raw = await supabase.rpc(
      'safe_delete_post',
      params: {
        'p_post_id': id,
        'p_profile_id': user.uid,
      },
    );

    debugPrint('🔍 safe_delete_post raw: $raw (${raw.runtimeType})');

    // RPC not deployed yet — fall back to direct delete
    if (raw == null) {
      debugPrint('⚠️ safe_delete_post returned null — using direct delete');
      await supabase
          .from('posts')
          .delete()
          .eq('id', id)
          .eq('profile_id', user.uid);
      debugPrint('✅ User slot deleted directly: $id');
      _slots.value = _slots.value.where((s) => s.id != id).toList();
      _buildSlotEntries();
      await _saveSlots();
      return;
    }

    final Map<String, dynamic> result;
    if (raw is Map<String, dynamic>) {
      result = raw;
    } else if (raw is Map) {
      result = Map<String, dynamic>.from(raw);
    } else {
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

    debugPrint('✅ User slot deleted from Supabase: $id');
    _slots.value = _slots.value.where((s) => s.id != id).toList();
    _buildSlotEntries();
    await _saveSlots();
  }

  Future<void> _syncSlotToSupabase(Slot slot, {bool isUpdate = false}) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = AuthRepository.instance.currentUser;
      
      if (currentUser == null) {
        debugPrint('⚠️ No user logged in - skipping Supabase sync');
        return;
      }

      // Generate short 6-char reference code from timestamp
      final refCode = slot.id.toString().substring(slot.id.toString().length - 6);

      final data = {
        'id': slot.id,
        'profile_id': currentUser.id,
        'vehicle_id': slot.vehicleId,
        'service_type': slot.serviceType.name,
        'slot_type': slot.slotType.name,
        'slot_layout_structure': slot.seatLayoutStructure?.toJson(),
        'from_location': slot.fromLocation,
        'to_location': slot.toLocation,
        'base_location': slot.baseLocation,
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
        if (slot.securityDeposit != null) 'security_deposit': slot.securityDeposit,
        if (slot.fuelPolicy != null) 'fuel_policy': slot.fuelPolicy,
        'with_operator': slot.withOperator,
        // Post mode
        'postmode': slot.postMode.dbValue,
        'is_active': slot.isAvailable,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (!isUpdate) {
        data['created_at'] = DateTime.now().toIso8601String();
      }

      await supabase.from('posts').upsert(data);

      debugPrint('✅ User slot synced to Supabase: ${slot.id} (ref: $refCode)');
    } catch (e) {
      debugPrint('❌ Failed to sync user slot to Supabase: $e');
    }
  }

}


