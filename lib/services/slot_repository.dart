import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    } catch (e) {
      debugPrint('❌ Failed to create slot: $e');
      rethrow;
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
      }
    } catch (e) {
      debugPrint('❌ Failed to update slot: $e');
      rethrow;
    }
  }

  Future<void> deleteSlot(String slotId) async {
    try {
      _slots.value = _slots.value.where((s) => s.id != slotId).toList();
      _buildSlotEntries();
      await _saveSlots();
      debugPrint('✅ Slot deleted locally: $slotId');
    } catch (e) {
      debugPrint('❌ Failed to delete slot: $e');
      rethrow;
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
