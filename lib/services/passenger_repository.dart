import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/passenger.dart';

class PassengerRepository {
  PassengerRepository._();
  static final PassengerRepository instance = PassengerRepository._();

  static const _storageKey = 'saved_passengers';
  final ValueNotifier<List<Passenger>> savedPassengers =
      ValueNotifier<List<Passenger>>([]);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      savedPassengers.value = jsonList
          .map((e) => Passenger.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> savePassenger(Passenger passenger) async {
    // Avoid duplicates by name/age/gender (simple check)
    final exists = savedPassengers.value.any(
      (p) =>
          p.name == passenger.name &&
          p.age == passenger.age &&
          p.gender == passenger.gender,
    );

    if (exists) return;

    savedPassengers.value = [...savedPassengers.value, passenger];
    await _persist();
  }

  Future<void> removePassenger(String id) async {
    savedPassengers.value = savedPassengers.value
        .where((p) => p.id != id)
        .toList();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(
      savedPassengers.value.map((e) => e.toJson()).toList(),
    );
    await prefs.setString(_storageKey, data);
  }
}


