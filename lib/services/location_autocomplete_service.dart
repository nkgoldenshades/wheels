import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LocationSuggestion {
  final String displayName;
  final double lat;
  final double lon;
  final String type;

  LocationSuggestion({
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.type,
  });

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      displayName: json['display_name'] as String,
      lat: double.parse(json['lat'] as String),
      lon: double.parse(json['lon'] as String),
      type: json['type'] as String? ?? 'unknown',
    );
  }
}

class LocationAutocompleteService {
  static final LocationAutocompleteService instance = LocationAutocompleteService._();
  LocationAutocompleteService._();

  Timer? _debounceTimer;
  
  /// Search for locations using OpenStreetMap Nominatim API
  /// Returns list of suggestions based on query
  Future<List<LocationSuggestion>> searchLocations(
    String query, {
    String countryCode = 'in', // Default to India
    int limit = 5,
  }) async {
    if (query.trim().isEmpty || query.length < 3) {
      return [];
    }

    try {
      final encodedQuery = Uri.encodeComponent(query.trim());
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=$encodedQuery'
        '&countrycodes=$countryCode'
        '&format=json'
        '&limit=$limit'
        '&addressdetails=1',
      );

      debugPrint('🌐 Calling API: $url');

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'QuickOhunt/1.0', // Required by Nominatim
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      debugPrint('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('📦 Parsed ${data.length} locations');
        return data
            .map((json) => LocationSuggestion.fromJson(json))
            .toList();
      } else {
        debugPrint('❌ API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Network error: $e');
      return [];
    }
  }

  /// Debounced search - waits for user to stop typing before searching
  void searchWithDebounce(
    String query,
    Function(List<LocationSuggestion>) onResults, {
    Duration delay = const Duration(milliseconds: 500),
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () async {
      final results = await searchLocations(query);
      onResults(results);
    });
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}
