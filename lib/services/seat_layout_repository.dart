import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/seat_layout.dart';

class SeatLayoutRepository {
  SeatLayoutRepository._();

  static final SeatLayoutRepository instance = SeatLayoutRepository._();

  static const _storageKey = 'seat_layouts';
  final ValueNotifier<Map<String, SeatLayout>> layoutsByOwnerId =
      ValueNotifier<Map<String, SeatLayout>>({});

  Future<void> init() async {
    await _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null) {
        final Map<String, dynamic> jsonMap = jsonDecode(data);
        final next = jsonMap.map(
          (key, value) => MapEntry(key, SeatLayout.fromJson(value)),
        );
        layoutsByOwnerId.value = next;
      }
    } catch (e) {
      debugPrint('Error loading layouts: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(
        layoutsByOwnerId.value.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      );
      await prefs.setString(_storageKey, data);
    } catch (e) {
      debugPrint('Error persisting layouts: $e');
    }
  }

  SeatLayout? getLayout(String ownerId) {
    return layoutsByOwnerId.value[ownerId];
  }

  Future<void> upsert({
    required String ownerId,
    required SeatLayout layout,
  }) async {
    layoutsByOwnerId.value = {...layoutsByOwnerId.value, ownerId: layout};
    await _persist();
  }

  Future<void> remove(String ownerId) async {
    final next = Map<String, SeatLayout>.from(layoutsByOwnerId.value);
    next.remove(ownerId);
    layoutsByOwnerId.value = next;
    await _persist();
  }
}
