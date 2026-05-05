import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/event.dart';
import 'auth_repository.dart';

class EventRepository {
  EventRepository._();

  static final EventRepository instance = EventRepository._();

  final ValueNotifier<List<Event>> _events = ValueNotifier<List<Event>>([]);
  final ValueNotifier<Map<String, bool>> _onlineStatus = ValueNotifier<Map<String, bool>>({});

  bool _initialized = false;
  static const _storageKey = 'events_data';
  static const _onlineStatusKey = 'events_online_status';

  ValueListenable<List<Event>> get eventsListenable => _events;
  ValueListenable<Map<String, bool>> get onlineStatusListenable => _onlineStatus;

  List<Event> get allEvents => List.unmodifiable(_events.value);

  List<Event> get userEvents {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return [];
    return _events.value
        .where((e) => e.userId == currentUser.id)
        .toList();
  }

  Future<void> init() async {
    if (_initialized) return;
    await _loadFromLocal();
    _initialized = true;
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      final statusData = prefs.getString(_onlineStatusKey);
      
      if (data != null) {
        final List<dynamic> jsonList = jsonDecode(data);
        _events.value = jsonList.map((json) => Event.fromJson(json)).toList();
      }
      
      if (statusData != null) {
        final Map<String, dynamic> statusMap = jsonDecode(statusData);
        _onlineStatus.value = statusMap.map((k, v) => MapEntry(k, v as bool));
      }
      
      debugPrint('✅ Loaded ${_events.value.length} events from local storage');
    } catch (e) {
      debugPrint('❌ Failed to load events: $e');
      _events.value = [];
    }
  }

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _events.value.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
      await prefs.setString(_onlineStatusKey, jsonEncode(_onlineStatus.value));
      debugPrint('✅ Saved ${_events.value.length} events to local storage');
    } catch (e) {
      debugPrint('❌ Failed to save events: $e');
    }
  }

  Future<void> loadEvents() async {
    await _loadFromLocal();
  }

  Future<void> loadAllEvents() async {
    await _loadFromLocal();
  }

  Future<void> addEvent(Event event) async {
    try {
      final currentUser = AuthRepository.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      _events.value = [event, ..._events.value];
      await _saveToLocal();

      debugPrint('✅ Event created locally: ${event.id}');
    } catch (e) {
      debugPrint('❌ Failed to create event: $e');
      rethrow;
    }
  }

  Future<void> updateEvent(Event event) async {
    try {
      final index = _events.value.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        final updated = List<Event>.from(_events.value);
        updated[index] = event;
        _events.value = updated;
        await _saveToLocal();
      }

      debugPrint('✅ Event updated locally: ${event.id}');
    } catch (e) {
      debugPrint('❌ Failed to update event: $e');
      rethrow;
    }
  }

  Future<void> removeEvent(String eventId) async {
    try {
      _events.value = _events.value.where((e) => e.id != eventId).toList();
      await _saveToLocal();

      debugPrint('✅ Event deleted locally: $eventId');
    } catch (e) {
      debugPrint('❌ Failed to delete event: $e');
      rethrow;
    }
  }

  Future<void> setOnlineStatus(String eventId, bool isOnline) async {
    try {
      final updated = Map<String, bool>.from(_onlineStatus.value);
      updated[eventId] = isOnline;
      _onlineStatus.value = updated;
      await _saveToLocal();

      debugPrint('✅ Event online status updated: $eventId = $isOnline');
    } catch (e) {
      debugPrint('❌ Failed to update event online status: $e');
    }
  }

  bool isOnline(String eventId) {
    return _onlineStatus.value[eventId] ?? false;
  }
}

