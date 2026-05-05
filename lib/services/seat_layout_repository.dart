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
    
    // Sync to Supabase
    await _syncLayoutToSupabase(ownerId, layout);
  }

  Future<void> remove(String ownerId) async {
    final next = Map<String, SeatLayout>.from(layoutsByOwnerId.value);
    next.remove(ownerId);
    layoutsByOwnerId.value = next;
    await _persist();
    
    // Delete from Supabase
    await _deleteLayoutFromSupabase(ownerId);
  }

  Future<void> _syncLayoutToSupabase(String ownerId, SeatLayout layout) async {
    // NOTE: seat_layout_structure is now stored directly in posts table as JSONB
    // No need for separate seat_layouts table
    // This sync is disabled
    return;
    
    /* OLD CODE - DISABLED
    try {
      final supabase = Supabase.instance.client;
      final currentUser = AuthRepository.instance.currentUser;
      
      if (currentUser == null) return;

      await supabase.from('seat_layouts').upsert({
        'id': layout.id,
        'user_id': currentUser.id,
        'name': layout.name,
        'layout_data': layout.toJson(),
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Seat layout synced to Supabase: ${layout.id}');
    } catch (e) {
      debugPrint('❌ Failed to sync seat layout to Supabase: $e');
    }
    */
  }

  Future<void> _deleteLayoutFromSupabase(String ownerId) async {
    // NOTE: seat_layout_structure is now stored directly in posts table as JSONB
    // No need for separate seat_layouts table
    // This delete is disabled
    return;
    
    /* OLD CODE - DISABLED
    try {
      final supabase = Supabase.instance.client;
      
      await supabase.from('seat_layouts').delete().eq('user_id', ownerId);

      debugPrint('✅ Seat layout deleted from Supabase');
    } catch (e) {
      debugPrint('❌ Failed to delete seat layout from Supabase: $e');
    }
    */
  }
}

