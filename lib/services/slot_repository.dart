import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/slot.dart';
import '../models/slot_entry.dart';
import 'auth_repository.dart';
import 'vehicle_repository.dart';

class SlotRepository {
  SlotRepository._();

  static final SlotRepository instance = SlotRepository._();

  static const String _slotsKey = 'slots';

  final ValueNotifier<List<Slot>> _slots = ValueNotifier<List<Slot>>([]);
  final ValueNotifier<List<SlotEntry>> _slotEntries = ValueNotifier<List<SlotEntry>>([]);

  bool _initialized = false;

  ValueListenable<List<SlotEntry>> get slotsListenable => _slotEntries;

  List<SlotEntry> get allSlots => List.unmodifiable(_slotEntries.value);

  List<Slot> get allSlotsRaw => List.unmodifiable(_slots.value);

  List<Slot> get userSlots {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return [];
    return _slots.value;
  }

  void _buildSlotEntries() {
    final entries = <SlotEntry>[];
    for (final slot in _slots.value) {
      final vehicle = VehicleRepository.instance.getById(slot.vehicleId);
      if (vehicle != null) {
        entries.add(SlotEntry(slot: slot, vehicle: vehicle));
      }
    }
    _slotEntries.value = entries;
  }

  Future<void> init() async {
    if (_initialized) return;
    await _loadSlots();
    
    // Listen to vehicle changes to rebuild slot entries
    VehicleRepository.instance.vehiclesListenable.addListener(_buildSlotEntries);
    
    _initialized = true;
  }

  Future<void> _loadSlots() async {
    try {
      // Load from Supabase first (source of truth)
      final supabase = Supabase.instance.client;
      final currentUser = AuthRepository.instance.currentUser;
      
      if (currentUser != null) {
        final response = await supabase
            .from('posts')
            .select()
            .eq('profile_id', currentUser.id)
            .eq('is_active', true)
            .order('created_at', ascending: false);

        _slots.value = (response as List)
            .map((json) => Slot.fromJson(json as Map<String, dynamic>))
            .toList();
        
        _buildSlotEntries();
        debugPrint('✅ Loaded ${_slots.value.length} slots from Supabase');
        
        // Save to local storage as cache
        await _saveSlots();
        return;
      }
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

  Future<void> loadSlots() async {
    await _loadSlots();
  }

  Future<void> loadAllSlots() async {
    await _loadSlots();
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
      final supabase = Supabase.instance.client;
      final currentUser = AuthRepository.instance.currentUser;
      
      if (currentUser == null) {
        debugPrint('⚠️ No user logged in - skipping Supabase sync');
        return;
      }

      // Generate short 6-char reference code from timestamp
      final refCode = slot.id.toString().substring(slot.id.toString().length - 6);

      await supabase.from('posts').insert({
        'id': slot.id,
        'provider_id': currentUser.id,
        'ref_code': refCode, // Short code shown to users (e.g. "791379")
        'vehicle_id': slot.vehicleId,
        'service_type': slot.serviceType.name,
        'slot_type': slot.slotType.name,
        'from_location': slot.fromLocation,
        'to_location': slot.toLocation,
        'base_location': slot.baseLocation,
        'radius': slot.radius,
        'start_time': slot.startTime.toIso8601String(),
        'end_time': slot.endTime.toIso8601String(),
        'price': slot.price,
        'capacity': slot.capacity,
        'notes': slot.notes,
        'images': slot.images,
        'is_available': slot.isAvailable,
        'pickup_option': slot.pickupOption.name,
        'requires_approval': slot.requiresApproval,
        'max_weight': slot.maxWeight,
        'max_length': slot.maxLength,
        'max_width': slot.maxWidth,
        'max_height': slot.maxHeight,
        'lease_duration': slot.leaseDuration,
        'security_deposit': slot.securityDeposit,
        'mileage_limit': slot.mileageLimit,
        'fuel_policy': slot.fuelPolicy,
        'insurance_included': slot.insuranceIncluded,
        'lease_terms': slot.leaseTerms,
        'with_operator': slot.withOperator,
        'created_at': DateTime.now().toIso8601String(),
      });

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
    try {
      // Check for active bookings first
      final activeBookings = await _getActiveBookingsForSlot(slotId);
      
      if (activeBookings.isNotEmpty) {
        throw Exception('Cannot delete post: ${activeBookings.length} active booking(s) exist. Please wait for bookings to complete or cancel them first.');
      }
      
      _slots.value = _slots.value.where((s) => s.id != slotId).toList();
      _buildSlotEntries();
      await _saveSlots();
      debugPrint('✅ Slot deleted locally: $slotId');
      
      // Delete from Supabase
      await _deleteSlotFromSupabase(slotId);
    } catch (e) {
      debugPrint('❌ Failed to delete slot: $e');
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
      // If we can't check Supabase, fall back to local check
      return _getLocalActiveBookingsForSlot(slotId);
    }
  }

  /// Fallback: Check local bookings if Supabase is unavailable
  List<Map<String, dynamic>> _getLocalActiveBookingsForSlot(String slotId) {
    // Import BookingRepository to check local bookings
    // Note: This creates a circular dependency, so we'll handle it differently
    return []; // For now, allow deletion if we can't check Supabase
  }

  Future<void> _updateSlotInSupabase(Slot slot) async {
    try {
      final supabase = Supabase.instance.client;
      
      await supabase.from('posts').update({
        'vehicle_id': slot.vehicleId,
        'service_type': slot.serviceType.name,
        'slot_type': slot.slotType.name,
        'from_location': slot.fromLocation,
        'to_location': slot.toLocation,
        'base_location': slot.baseLocation,
        'radius': slot.radius,
        'start_time': slot.startTime.toIso8601String(),
        'end_time': slot.endTime.toIso8601String(),
        'price': slot.price,
        'capacity': slot.capacity,
        'notes': slot.notes,
        'images': slot.images,
        'is_available': slot.isAvailable,
        'pickup_option': slot.pickupOption.name,
        'requires_approval': slot.requiresApproval,
        'max_weight': slot.maxWeight,
        'max_length': slot.maxLength,
        'max_width': slot.maxWidth,
        'max_height': slot.maxHeight,
        'lease_duration': slot.leaseDuration,
        'security_deposit': slot.securityDeposit,
        'mileage_limit': slot.mileageLimit,
        'fuel_policy': slot.fuelPolicy,
        'insurance_included': slot.insuranceIncluded,
        'lease_terms': slot.leaseTerms,
        'with_operator': slot.withOperator,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', slot.id);

      debugPrint('✅ Slot updated in Supabase: ${slot.id}');
    } catch (e) {
      debugPrint('❌ Failed to update slot in Supabase: $e');
    }
  }

  Future<void> _deleteSlotFromSupabase(String slotId) async {
    try {
      final supabase = Supabase.instance.client;
      
      await supabase.from('posts').delete().eq('id', slotId);

      debugPrint('✅ Slot deleted from Supabase: $slotId');
    } catch (e) {
      debugPrint('❌ Failed to delete slot from Supabase: $e');
    }
  }

  List<Slot> getSlotsForVehicle(String vehicleId) {
    return _slots.value.where((s) => s.vehicleId == vehicleId).toList();
  }

  List<Slot> getSlotsByVehicleId(String vehicleId) {
    return getSlotsForVehicle(vehicleId);
  }

  List<SlotEntry> getSlotEntriesByVehicleId(String vehicleId) {
    return _slotEntries.value.where((e) => e.slot.vehicleId == vehicleId).toList();
  }
}
