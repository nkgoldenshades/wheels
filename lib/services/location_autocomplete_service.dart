import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LocationSuggestion {
  final String displayName;
  final double lat;
  final double lon;
  final String type;
  final GeoLocation? geo; // parsed from addressdetails in search response

  LocationSuggestion({
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.type,
    this.geo,
  });

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      displayName: json['display_name'] as String,
      lat: double.parse(json['lat'] as String),
      lon: double.parse(json['lon'] as String),
      type: json['type'] as String? ?? 'unknown',
      geo: json['address'] != null ? GeoLocation.fromJson(json) : null,
    );
  }
}

/// Structured result from reverse geocoding a lat/lon
class GeoLocation {
  final String displayName;
  final String? village;
  final String? suburb;
  final String? city;
  final String? district;
  final String? stateDistrict;
  final String? state;
  final String? postcode;
  final String? country;
  final String? countryCode;

  GeoLocation({
    required this.displayName,
    this.village,
    this.suburb,
    this.city,
    this.district,
    this.stateDistrict,
    this.state,
    this.postcode,
    this.country,
    this.countryCode,
  });

  factory GeoLocation.fromJson(Map<String, dynamic> json) {
    final addr = (json['address'] as Map<String, dynamic>?) ?? {};

    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = addr[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    return GeoLocation(
      displayName: json['display_name'] as String? ?? '',
      village: pick(['village', 'hamlet', 'locality', 'neighbourhood']),
      suburb: pick(['suburb', 'quarter', 'borough']),
      city: pick(['city', 'town', 'municipality', 'city_district']),
      district: pick(['district', 'county', 'state_district', 'region', 'department']),
      stateDistrict: pick(['state_district', 'district', 'county']),
      state: pick(['state', 'province', 'region']),
      postcode: pick(['postcode', 'postal_code']),
      country: pick(['country']),
      countryCode: pick(['country_code']),
    );
  }

  /// e.g. "Chennai District, Tamil Nadu, India (IN)"
  String get summary {
    final parts = <String>[
      ?district,
      ?state,
      ?country,
    ];
    final code = countryCode?.toUpperCase();
    return parts.join(', ') + (code != null ? ' ($code)' : '');
  }

  /// Short label: district + state
  String get shortLabel {
    final parts = <String>[
      if (district != null || stateDistrict != null)
        (district ?? stateDistrict)!,
      ?state,
    ];
    return parts.join(', ');
  }
}

class LocationAutocompleteService {
  static final LocationAutocompleteService instance = LocationAutocompleteService._();
  LocationAutocompleteService._();

  Timer? _debounceTimer;
  
  /// Search for locations using OpenStreetMap Nominatim API
  /// Searches globally by default — pass countryCode to restrict (e.g. 'in', 'us')
  Future<List<LocationSuggestion>> searchLocations(
    String query, {
    String? countryCode, // null = worldwide
    int limit = 5,
  }) async {
    if (query.trim().isEmpty || query.length < 3) {
      return [];
    }

    try {
      return await _searchNominatim(
        query: query.trim(),
        countryCode: countryCode,
        limit: limit,
      );
    } catch (e) {
      debugPrint('❌ Network error: $e');
      return [];
    }
  }

  Future<List<LocationSuggestion>> _searchNominatim({
    required String query,
    required int limit,
    String? countryCode,
  }) async {
    final encodedQuery = Uri.encodeComponent(query);
    final countryParam = (countryCode != null && countryCode.isNotEmpty)
        ? '&countrycodes=$countryCode'
        : '';

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?'
      'q=$encodedQuery'
      '$countryParam'
      '&format=json'
      '&limit=$limit'
      '&addressdetails=1',
    );

    debugPrint('🌐 Calling API: $url');

    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'VaultWheels/1.0',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 5));

    debugPrint('📡 Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      debugPrint('❌ API error: ${response.statusCode}');
      return [];
    }

    final List<dynamic> data = json.decode(response.body);
    debugPrint('📦 Parsed ${data.length} locations');
    return data.map((json) => LocationSuggestion.fromJson(json)).toList();
  }

  /// Reverse geocode coordinates — returns full structured GeoLocation
  Future<GeoLocation?> reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1',
      );

      debugPrint('🌐 Calling Reverse Geocode API: $url');

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'VaultWheels/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return GeoLocation.fromJson(data);
      }
    } catch (e) {
      debugPrint('❌ Reverse geocode error: $e');
    }
    return null;
  }

  /// Convenience: just the display_name string
  Future<String?> reverseGeocodeString(double lat, double lon) async {
    final geo = await reverseGeocode(lat, lon);
    return geo?.displayName;
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



