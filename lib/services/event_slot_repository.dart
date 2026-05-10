import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event_slot.dart';

class EventSlotRepository {
  static final EventSlotRepository instance = EventSlotRepository._();
  EventSlotRepository._();

  static const String _eventSlotsKey = 'event_slots';

  final ValueNotifier<List<EventSlot>> _eventSlotsNotifier = ValueNotifier([]);
  ValueListenable<List<EventSlot>> get eventSlotsListenable => _eventSlotsNotifier;

  Future<void> initialize() async {
    await _loadEventSlots();
  }

  Future<void> _loadEventSlots() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_eventSlotsKey);
    
    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      _eventSlotsNotifier.value = jsonList
          .map((json) => EventSlot.fromJson(json as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> _saveEventSlots() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(
      _eventSlotsNotifier.value.map((slot) => slot.toJson()).toList(),
    );
    await prefs.setString(_eventSlotsKey, jsonString);
  }

  Future<void> addEventSlot(EventSlot slot) async {
    _eventSlotsNotifier.value = [..._eventSlotsNotifier.value, slot];
    await _saveEventSlots();
  }

  Future<void> removeEventSlot(String slotId) async {
    _eventSlotsNotifier.value = _eventSlotsNotifier.value
        .where((slot) => slot.id != slotId)
        .toList();
    await _saveEventSlots();
  }

  List<EventSlot> getSlotsByEventId(String eventId) {
    return _eventSlotsNotifier.value
        .where((slot) => slot.eventId == eventId)
        .toList();
  }

  Future<void> updateEventSlot(EventSlot updatedSlot) async {
    final index = _eventSlotsNotifier.value
        .indexWhere((slot) => slot.id == updatedSlot.id);
    
    if (index != -1) {
      final updated = [..._eventSlotsNotifier.value];
      updated[index] = updatedSlot;
      _eventSlotsNotifier.value = updated;
      await _saveEventSlots();
    }
  }
}



