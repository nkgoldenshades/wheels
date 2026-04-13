import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/slot.dart';
import '../models/slot_entry.dart';
import '../models/post_mode.dart';
import 'auth_repository.dart';
import 'customer_vehicle_repository.dart';

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
        entries.add(SlotEntry(slot: slot, vehicle: vehicle));
      }
    }
    slotsListenable.value = entries;
  }

  Future<void> _loadSlots() async {
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
    try {
      // Check for active bookings first
      final activeBookings = await _getActiveBookingsForSlot(id);
      
      if (activeBookings.isNotEmpty) {
        throw Exception('Cannot delete post: ${activeBookings.length} active booking(s) exist. Please wait for bookings to complete or cancel them first.');
      }
      
      _slots.value = _slots.value.where((s) => s.id != id).toList();
      _buildSlotEntries();
      await _saveSlots();
      debugPrint('✅ User slot deleted locally: $id');
      
      // Delete from Supabase
      await _deleteSlotFromSupabase(id);
    } catch (e) {
      debugPrint('❌ Failed to delete user slot: $e');
      rethrow;
    }
  }

  /// Check if slot has active bookings that would prevent deletion
  Future<List<Map<String, dynamic>>> _getActiveBookingsForSlot(String slotId) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Query Supabase for active bookings on this slot
      final response = await supabase
          .from('bookings')
          .select('id, status, user_name')
          .eq('slot_id', slotId)
          .not('status', 'in', '(rejected,cancelled,completed,refunded)');
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('⚠️ Could not check active bookings, allowing deletion: $e');
      return []; // Allow deletion if we can't check Supabase
    }
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
        'seat_layout_structure': slot.seatLayoutStructure?.toJson(),
        'from_location': slot.fromLocation,
        'to_location': slot.toLocation,
        'base_location': slot.baseLocation,
        'radius': slot.radius,
        'start_time': slot.startTime.toIso8601String(),
        'end_time': slot.endTime.toIso8601String(),
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

      await supabase.from('user_posts').upsert(data);

      debugPrint('✅ User slot synced to Supabase: ${slot.id} (ref: $refCode)');
    } catch (e) {
      debugPrint('❌ Failed to sync user slot to Supabase: $e');
    }
  }

  Future<void> _deleteSlotFromSupabase(String id) async {
    try {
      final supabase = Supabase.instance.client;
      
      await supabase.from('user_posts').delete().eq('id', id);

      debugPrint('✅ User slot deleted from Supabase: $id');
    } catch (e) {
      debugPrint('❌ Failed to delete user slot from Supabase: $e');
    }
  }
}
