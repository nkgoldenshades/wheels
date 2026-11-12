import 'dart:math';
import '../models/booking.dart';

/// Helper class to verify GPS locations match expected pickup/dropoff points
class GpsVerificationHelper {
  /// Maximum allowed distance from expected location (in kilometers)
  /// 100 meters = 0.1 km
  static const double maxAllowedDistanceKm = 0.1;

  /// Calculate distance between two GPS coordinates using Haversine formula
  /// Returns distance in kilometers
  static double calculateDistance({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const double earthRadiusKm = 6371.0;

    // Convert degrees to radians
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Verify if customer GPS at trip start matches the promised pickup location
  static bool verifyCustomerPickupLocation(Booking booking) {
    // Check if we have all required data
    if (booking.fromLat == null || booking.fromLng == null) {
      return false; // No pickup location in booking
    }

    final customerGps = booking.tripMedia.start.customer;
    if (!customerGps.hasGps) {
      return false; // Customer didn't provide GPS
    }

    // Calculate distance from promised pickup location
    final distance = calculateDistance(
      lat1: booking.fromLat!,
      lng1: booking.fromLng!,
      lat2: customerGps.gpsLat!,
      lng2: customerGps.gpsLng!,
    );

    // Within 100 meters = verified
    return distance <= maxAllowedDistanceKm;
  }

  /// Verify if provider GPS at trip start matches the promised pickup location
  static bool verifyProviderPickupLocation(Booking booking) {
    // Check if we have all required data
    if (booking.fromLat == null || booking.fromLng == null) {
      return false; // No pickup location in booking
    }

    final providerGps = booking.tripMedia.start.provider;
    if (!providerGps.hasGps) {
      return false; // Provider didn't provide GPS
    }

    // Calculate distance from promised pickup location
    final distance = calculateDistance(
      lat1: booking.fromLat!,
      lng1: booking.fromLng!,
      lat2: providerGps.gpsLat!,
      lng2: providerGps.gpsLng!,
    );

    // Within 100 meters = verified
    return distance <= maxAllowedDistanceKm;
  }

  /// Verify if customer GPS at trip end matches the promised dropoff location
  static bool verifyCustomerDropoffLocation(Booking booking) {
    // Check if we have all required data
    if (booking.toLat == null || booking.toLng == null) {
      return false; // No dropoff location in booking (might be local/range booking)
    }

    final customerGps = booking.tripMedia.end.customer;
    if (!customerGps.hasGps) {
      return false; // Customer didn't provide GPS
    }

    // Calculate distance from promised dropoff location
    final distance = calculateDistance(
      lat1: booking.toLat!,
      lng1: booking.toLng!,
      lat2: customerGps.gpsLat!,
      lng2: customerGps.gpsLng!,
    );

    // Within 100 meters = verified
    return distance <= maxAllowedDistanceKm;
  }

  /// Verify if provider GPS at trip end matches the promised dropoff location
  static bool verifyProviderDropoffLocation(Booking booking) {
    // Check if we have all required data
    if (booking.toLat == null || booking.toLng == null) {
      return false; // No dropoff location in booking
    }

    final providerGps = booking.tripMedia.end.provider;
    if (!providerGps.hasGps) {
      return false; // Provider didn't provide GPS
    }

    // Calculate distance from promised dropoff location
    final distance = calculateDistance(
      lat1: booking.toLat!,
      lng1: booking.toLng!,
      lat2: providerGps.gpsLat!,
      lng2: providerGps.gpsLng!,
    );

    // Within 100 meters = verified
    return distance <= maxAllowedDistanceKm;
  }

  /// Get human-readable distance message
  static String getDistanceMessage({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final distanceKm = calculateDistance(
      lat1: lat1,
      lng1: lng1,
      lat2: lat2,
      lng2: lng2,
    );

    if (distanceKm < 0.001) {
      // Less than 1 meter
      return 'At exact location';
    } else if (distanceKm < 0.01) {
      // Less than 10 meters
      return '${(distanceKm * 1000).toStringAsFixed(0)}m away';
    } else if (distanceKm < 1) {
      // Less than 1 km
      return '${(distanceKm * 1000).toStringAsFixed(0)}m away';
    } else {
      // 1 km or more
      return '${distanceKm.toStringAsFixed(2)}km away';
    }
  }

  /// Comprehensive verification result with details
  static GpsVerificationResult verifyBookingLocations(Booking booking) {
    return GpsVerificationResult(
      customerPickupVerified: verifyCustomerPickupLocation(booking),
      providerPickupVerified: verifyProviderPickupLocation(booking),
      customerDropoffVerified: verifyCustomerDropoffLocation(booking),
      providerDropoffVerified: verifyProviderDropoffLocation(booking),
      customerPickupDistance: _getPickupDistance(booking, isCustomer: true),
      providerPickupDistance: _getPickupDistance(booking, isCustomer: false),
    );
  }

  static double? _getPickupDistance(Booking booking, {required bool isCustomer}) {
    if (booking.fromLat == null || booking.fromLng == null) return null;

    final gps = isCustomer 
        ? booking.tripMedia.start.customer 
        : booking.tripMedia.start.provider;

    if (!gps.hasGps) return null;

    return calculateDistance(
      lat1: booking.fromLat!,
      lng1: booking.fromLng!,
      lat2: gps.gpsLat!,
      lng2: gps.gpsLng!,
    );
  }
}

/// Result of GPS verification with detailed information
class GpsVerificationResult {
  final bool customerPickupVerified;
  final bool providerPickupVerified;
  final bool customerDropoffVerified;
  final bool providerDropoffVerified;
  final double? customerPickupDistance; // in km
  final double? providerPickupDistance; // in km

  GpsVerificationResult({
    required this.customerPickupVerified,
    required this.providerPickupVerified,
    required this.customerDropoffVerified,
    required this.providerDropoffVerified,
    this.customerPickupDistance,
    this.providerPickupDistance,
  });

  /// Both parties verified at pickup (minimum requirement for reviews)
  bool get bothPartiesVerified => 
      customerPickupVerified && providerPickupVerified;

  /// Get summary message
  String get summary {
    if (bothPartiesVerified) {
      return '✅ Both parties verified at pickup location';
    } else if (customerPickupVerified) {
      return '⚠️ Only customer verified at pickup';
    } else if (providerPickupVerified) {
      return '⚠️ Only provider verified at pickup';
    } else {
      return '❌ Neither party verified at pickup';
    }
  }

  /// Get detailed report
  String get detailedReport {
    final buffer = StringBuffer();
    buffer.writeln('GPS Verification Report:');
    buffer.writeln('');
    buffer.writeln('Pickup Location:');
    buffer.writeln('  Customer: ${customerPickupVerified ? "✅" : "❌"} ${_formatDistance(customerPickupDistance)}');
    buffer.writeln('  Provider: ${providerPickupVerified ? "✅" : "❌"} ${_formatDistance(providerPickupDistance)}');
    buffer.writeln('');
    buffer.writeln('Dropoff Location:');
    buffer.writeln('  Customer: ${customerDropoffVerified ? "✅" : "❌"}');
    buffer.writeln('  Provider: ${providerDropoffVerified ? "✅" : "❌"}');
    return buffer.toString();
  }

  String _formatDistance(double? distanceKm) {
    if (distanceKm == null) return '(no GPS data)';
    if (distanceKm < 0.001) return '(0m)';
    if (distanceKm < 1) return '(${(distanceKm * 1000).toStringAsFixed(0)}m)';
    return '(${distanceKm.toStringAsFixed(2)}km)';
  }
}
