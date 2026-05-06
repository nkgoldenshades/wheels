import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Registry to track all used profile names and ensure uniqueness
class ProfileNameRegistry {
  ProfileNameRegistry._();

  static final ProfileNameRegistry instance = ProfileNameRegistry._();

  static const String _storageKey = 'profile_name_registry';
  
  // Map of userId -> profileName
  Map<String, String> _registry = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_storageKey);
    
    if (json != null && json.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(json);
        _registry = decoded.map((key, value) => MapEntry(key, value.toString()));
      } catch (e) {
        _registry = {};
      }
    }
    
    _initialized = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_registry));
  }

  /// Check if a profile name is available (case-insensitive)
  /// Returns true if available, false if taken
  bool isNameAvailable(String profileName, {String? currentUserId}) {
    final normalizedName = profileName.trim().toLowerCase();
    
    if (normalizedName.isEmpty) return false;
    
    // Check if any other user has this name
    for (final entry in _registry.entries) {
      // Skip current user's own name
      if (currentUserId != null && entry.key == currentUserId) continue;
      
      if (entry.value.toLowerCase() == normalizedName) {
        return false;
      }
    }
    
    return true;
  }

  /// Register a profile name for a user
  Future<bool> registerName(String userId, String profileName) async {
    await init();
    
    final trimmedName = profileName.trim();
    
    if (trimmedName.isEmpty) {
      return false;
    }
    
    // Check if name is available
    if (!isNameAvailable(trimmedName, currentUserId: userId)) {
      return false;
    }
    
    // Register the name
    _registry[userId] = trimmedName;
    await _save();
    
    return true;
  }

  /// Update a user's profile name
  Future<bool> updateName(String userId, String newProfileName) async {
    await init();
    
    final trimmedName = newProfileName.trim();
    
    if (trimmedName.isEmpty) {
      return false;
    }
    
    // Check if new name is available (excluding current user)
    if (!isNameAvailable(trimmedName, currentUserId: userId)) {
      return false;
    }
    
    // Update the name
    _registry[userId] = trimmedName;
    await _save();
    
    return true;
  }

  /// Get the current profile name for a user
  String? getNameForUser(String userId) {
    return _registry[userId];
  }

  /// Remove a user's profile name (e.g., on account deletion)
  Future<void> removeName(String userId) async {
    await init();
    _registry.remove(userId);
    await _save();
  }

  /// Get all registered names (for debugging)
  List<String> getAllNames() {
    return _registry.values.toList();
  }
  
  /// Check if a name is available without requiring userId (for registration)
  Future<bool> checkNameAvailability(String profileName) async {
    await init();
    return isNameAvailable(profileName);
  }
}


