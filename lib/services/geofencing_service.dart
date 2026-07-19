import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/booking.dart';
import '../models/location_confirmation.dart';
import '../utils/gps_verification_helper.dart';
import 'booking_repository.dart';
import 'auth_repository.dart';

/// Automatic geofencing service that monitors location and marks arrival
/// when provider/customer reaches start or end location
class GeofencingService {
  static final GeofencingService _instance = GeofencingService._internal();
  static GeofencingService get instance => _instance;
  GeofencingService._internal();

  // Callback for showing notifications (set by main app)
  void Function(String message, {bool isSuccess})? onNotification;

  StreamSubscription<Position>? _positionStream;
  final Set<String> _monitoredBookingIds = {};
  final Map<String, bool> _startArrivalMarked = {}; // bookingId -> marked
  final Map<String, bool> _endArrivalMarked = {}; // bookingId -> marked

  /// Start monitoring location for active bookings
  Future<void> startMonitoring() async {
    if (_positionStream != null) {
      debugPrint('🌍 Geofencing already running');
      return;
    }

    // Check permissions
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('⚠️ Location permission denied - cannot start geofencing');
      return;
    }

    debugPrint('🌍 Starting geofencing service...');

    // Start listening to position updates
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // Update every 10 meters
          ),
        ).listen(
          _onLocationUpdate,
          onError: (error) {
            debugPrint('⚠️ Geofencing error: $error');
          },
        );

    debugPrint('✅ Geofencing service started');
  }

  /// Stop monitoring location
  void stopMonitoring() {
    _positionStream?.cancel();
    _positionStream = null;
    _monitoredBookingIds.clear();
    _startArrivalMarked.clear();
    _endArrivalMarked.clear();
    debugPrint('🛑 Geofencing service stopped');
  }

  /// Add a booking to monitor
  void monitorBooking(Booking booking) {
    if (_monitoredBookingIds.contains(booking.id)) return;

    _monitoredBookingIds.add(booking.id);
    _startArrivalMarked[booking.id] = false;
    _endArrivalMarked[booking.id] = false;

    debugPrint('📍 Monitoring booking ${booking.id}');

    // Start monitoring if not already started
    if (_positionStream == null) {
      startMonitoring();
    }
  }

  /// Remove a booking from monitoring
  void stopMonitoringBooking(String bookingId) {
    _monitoredBookingIds.remove(bookingId);
    _startArrivalMarked.remove(bookingId);
    _endArrivalMarked.remove(bookingId);

    debugPrint('📍 Stopped monitoring booking $bookingId');

    // Stop service if no bookings to monitor
    if (_monitoredBookingIds.isEmpty) {
      stopMonitoring();
    }
  }

  /// Called on each location update
  /// ⚠️ SECURITY: Only uses real device GPS, ignores manual/fake locations
  Future<void> _onLocationUpdate(Position position) async {
    // 🛡️ SECURITY: Detect mock/fake GPS locations
    if (position.isMocked) {
      debugPrint('⚠️ MOCK LOCATION DETECTED - Ignoring spoofed GPS');
      onNotification?.call(
        'Mock GPS detected. Real location required for bookings with security deposit.',
        isSuccess: false,
      );
      return; // Reject fake GPS
    }

    // 🛡️ SECURITY: Check GPS accuracy for high-value bookings
    // Low accuracy = likely spoofed or unreliable
    if (position.accuracy > 100) {
      // More than 100 meters error
      debugPrint(
        '⚠️ LOW GPS ACCURACY (${position.accuracy}m) - Ignoring unreliable location',
      );
      return; // Reject low-accuracy GPS
    }
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return;

    debugPrint(
      '📍 Location update: ${position.latitude}, ${position.longitude}',
    );

    // Check each monitored booking
    for (final bookingId in _monitoredBookingIds.toList()) {
      final booking = BookingRepository.instance.bookings.value
          .where((b) => b.id == bookingId)
          .firstOrNull;

      if (booking == null) {
        stopMonitoringBooking(bookingId);
        continue;
      }

      // Determine if user is provider or customer
      final isProvider = booking.providerId == currentUser.id;
      final isCustomer = booking.userId == currentUser.id;

      if (!isProvider && !isCustomer) continue;

      // Check if trip has started but not completed
      if (booking.status != BookingStatus.confirmed &&
          booking.status != BookingStatus.inProgress &&
          booking.status != BookingStatus.accepted) {
        continue;
      }

      // Check START location arrival
      if (!(_startArrivalMarked[bookingId] ?? false)) {
        await _checkStartArrival(booking, position, isProvider: isProvider);
      }

      // Check END location arrival (only after start is marked)
      if ((_startArrivalMarked[bookingId] ?? false) &&
          !(_endArrivalMarked[bookingId] ?? false)) {
        await _checkEndArrival(booking, position, isProvider: isProvider);
      }
    }
  }

  /// Check if user has arrived at START location
  Future<void> _checkStartArrival(
    Booking booking,
    Position position, {
    required bool isProvider,
  }) async {
    // Check if booking has start coordinates
    if (booking.fromLat == null || booking.fromLng == null) {
      debugPrint('⚠️ No start coordinates for booking ${booking.id}');
      return;
    }

    // Calculate distance to start location
    final distance = GpsVerificationHelper.calculateDistance(
      lat1: booking.fromLat!,
      lng1: booking.fromLng!,
      lat2: position.latitude,
      lng2: position.longitude,
    );

    debugPrint(
      '📏 Distance to START: ${(distance * 1000).toStringAsFixed(0)}m',
    );

    // Check if within geofence (100 meters)
    if (distance <= GpsVerificationHelper.maxAllowedDistanceKm) {
      debugPrint('✅ Arrived at START location!');
      await _markStartArrival(
        booking,
        position.latitude,
        position.longitude,
        isProvider: isProvider,
      );
    }
  }

  /// Check if user has arrived at END location
  Future<void> _checkEndArrival(
    Booking booking,
    Position position, {
    required bool isProvider,
  }) async {
    // Check if booking has end coordinates
    if (booking.toLat == null || booking.toLng == null) {
      debugPrint('⚠️ No end coordinates for booking ${booking.id}');
      return;
    }

    // Calculate distance to end location
    final distance = GpsVerificationHelper.calculateDistance(
      lat1: booking.toLat!,
      lng1: booking.toLng!,
      lat2: position.latitude,
      lng2: position.longitude,
    );

    debugPrint('📏 Distance to END: ${(distance * 1000).toStringAsFixed(0)}m');

    // Check if within geofence (100 meters)
    if (distance <= GpsVerificationHelper.maxAllowedDistanceKm) {
      debugPrint('✅ Arrived at END location!');
      await _markEndArrival(
        booking,
        position.latitude,
        position.longitude,
        isProvider: isProvider,
      );
    }
  }

  /// Mark arrival at START location
  Future<void> _markStartArrival(
    Booking booking,
    double lat,
    double lng, {
    required bool isProvider,
  }) async {
    try {
      _startArrivalMarked[booking.id] = true;

      // Get current location confirmations
      final currentConfirmations = booking.locationConfirmations;
      final now = DateTime.now();

      // Update GPS data for the appropriate party
      final LocationConfirmationParty updatedParty = LocationConfirmationParty(
        gpsLat: lat,
        gpsLng: lng,
        confirmedAt: now,
        isConfirmed: true,
      );

      // Create updated location confirmations
      final updatedConfirmations = currentConfirmations.copyWith(
        pickup: isProvider
            ? currentConfirmations.pickup.copyWith(provider: updatedParty)
            : currentConfirmations.pickup.copyWith(customer: updatedParty),
      );

      // Update booking in database
      await BookingRepository.instance.updateLocationConfirmations(
        booking.id,
        updatedConfirmations,
      );

      debugPrint(
        '✅ START arrival marked for ${isProvider ? 'provider' : 'customer'}',
      );

      // Show notification
      onNotification?.call(
        '✅ Location Confirmed at Pickup Point',
        isSuccess: true,
      );
    } catch (e) {
      debugPrint('❌ Failed to mark START arrival: $e');
      _startArrivalMarked[booking.id] = false; // Reset to retry
    }
  }

  /// Mark arrival at END location
  Future<void> _markEndArrival(
    Booking booking,
    double lat,
    double lng, {
    required bool isProvider,
  }) async {
    try {
      _endArrivalMarked[booking.id] = true;

      // Get current location confirmations
      final currentConfirmations = booking.locationConfirmations;
      final now = DateTime.now();

      // Update GPS data for the appropriate party
      final LocationConfirmationParty updatedParty = LocationConfirmationParty(
        gpsLat: lat,
        gpsLng: lng,
        confirmedAt: now,
        isConfirmed: true,
      );

      // Create updated location confirmations
      final updatedConfirmations = currentConfirmations.copyWith(
        dropoff: isProvider
            ? currentConfirmations.dropoff.copyWith(provider: updatedParty)
            : currentConfirmations.dropoff.copyWith(customer: updatedParty),
      );

      // Update booking in database
      await BookingRepository.instance.updateLocationConfirmations(
        booking.id,
        updatedConfirmations,
      );

      debugPrint(
        '✅ END arrival marked for ${isProvider ? 'provider' : 'customer'}',
      );

      // Show notification
      onNotification?.call(
        '✅ Location Confirmed at Dropoff Point',
        isSuccess: true,
      );

      // Stop monitoring this booking after end is marked
      stopMonitoringBooking(booking.id);
    } catch (e) {
      debugPrint('❌ Failed to mark END arrival: $e');
      _endArrivalMarked[booking.id] = false; // Reset to retry
    }
  }

  /// Check if a booking should be monitored based on its status
  bool shouldMonitorBooking(Booking booking) {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return false;

    // Only monitor bookings where user is provider or customer
    final isProvider = booking.providerId == currentUser.id;
    final isCustomer = booking.userId == currentUser.id;
    if (!isProvider && !isCustomer) return false;

    // Only monitor active bookings
    return booking.status == BookingStatus.accepted ||
        booking.status == BookingStatus.confirmed ||
        booking.status == BookingStatus.inProgress;
  }
}
