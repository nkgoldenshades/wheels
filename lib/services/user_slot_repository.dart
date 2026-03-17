import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/slot.dart';
import '../models/slot_entry.dart';
import 'user_vehicle_repository.dart';

/// Separate slot repository for "My Posts" section
/// This keeps user's personal posts separate from provider posts
class UserSlotRepository {
  UserSlotRepository._();

  static final UserSlotRepository instance = UserSlotRepository._();

  static const String _userSlotsKey = 'user_slots';

  final ValueNotifier<List<Slot>> _slots = ValueNotifier<List<Slot>>([]);
  final ValueNotifier<List<SlotEntry>> slotsListenable = ValueNotifier([]);

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _loadSlots();
    
    // Listen to vehicle changes to rebuild slot entries
    UserVehicleRepository.instance.vehiclesListenable.addListener(_buildSlotEntries);
    
    _initialized = true;
  }

  void _buildSlotEntries() {
    final entries = <SlotEntry>[];
    for (final slot in _slots.value) {
      final vehicle = UserVehicleRepository.instance.getById(slot.vehicleId);
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
    final vehicle = UserVehicleRepository.instance.getById(slot.vehicleId);
    if (vehicle == null) {
      debugPrint('❌ Vehicle not found for slot: ${slot.vehicleId}');
      return;
    }

    _slots.value = [slot, ..._slots.value];
    _buildSlotEntries();
    await _saveSlots();
    debugPrint('✅ User slot created locally: ${slot.id}');
  }

  Future<void> updateSlot(Slot slot) async {
    final vehicle = UserVehicleRepository.instance.getById(slot.vehicleId);
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
  }

  Future<void> deleteSlot(String id) async {
    _slots.value = _slots.value.where((s) => s.id != id).toList();
    _buildSlotEntries();
    await _saveSlots();
    debugPrint('✅ User slot deleted locally: $id');
  }
}
