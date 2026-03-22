import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/booking.dart';
import '../models/seat_layout.dart';
import 'slot_repository.dart';
import 'vehicle_repository.dart';

class BookingRepository {
  BookingRepository._();

  static final BookingRepository instance = BookingRepository._();

  static const _storageKey = 'bookings_data';
  static const _capacityKey = 'remaining_capacity';

  final ValueNotifier<Map<String, int>> remainingCapacityBySlotId =
      ValueNotifier<Map<String, int>>({});

  final ValueNotifier<List<Booking>> bookings = ValueNotifier<List<Booking>>(
    [],
  );

  Future<void> init() async {
    await _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load capacity
      final capacityData = prefs.getString(_capacityKey);
      if (capacityData != null) {
        remainingCapacityBySlotId.value = Map<String, int>.from(
          jsonDecode(capacityData),
        );
      }

      // Load bookings
      final bookingsData = prefs.getString(_storageKey);
      if (bookingsData != null) {
        final List<dynamic> jsonList = jsonDecode(bookingsData);
        bookings.value = jsonList
            .map((e) => Booking.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      if (bookings.value.isNotEmpty) {
        bool needsMigration = false;
        final migratedBookings = bookings.value.map((b) {
          final providerId = b.providerId.trim();
          if (providerId.isNotEmpty && providerId != 'user1') {
            return b;
          }

          String? resolvedProviderId;
          for (final e in SlotRepository.instance.allSlots) {
            if (e.slot.id == b.slotId) {
              final vehicle = VehicleRepository.instance.getById(e.slot.vehicleId);
              resolvedProviderId = vehicle?.userId;
              break;
            }
          }

          if (resolvedProviderId == null || resolvedProviderId.trim().isEmpty) {
            return b;
          }

          needsMigration = true;
          return Booking(
            id: b.id,
            slotId: b.slotId,
            providerId: resolvedProviderId,
            providerName: b.providerName,
            providerPhone: b.providerPhone,
            providerEmail: b.providerEmail,
            providerAvatar: b.providerAvatar,
            userId: b.userId,
            price: b.price,
            seatKey: b.seatKey,
            userGender: b.userGender,
            userName: b.userName,
            userAge: b.userAge,
            userPhone: b.userPhone,
            userEmail: b.userEmail,
            status: b.status,
            otp: b.otp,
            otpVerified: b.otpVerified,
            createdAt: b.createdAt,
          );
        }).toList(growable: false);

        if (needsMigration) {
          bookings.value = migratedBookings;
          await _persist();
        }
      }
    } catch (e) {
      debugPrint('Error loading bookings: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save capacity
      final capacityData = jsonEncode(remainingCapacityBySlotId.value);
      await prefs.setString(_capacityKey, capacityData);

      // Save bookings
      final bookingsData = jsonEncode(
        bookings.value.map((e) => e.toJson()).toList(),
      );
      await prefs.setString(_storageKey, bookingsData);
    } catch (e) {
      debugPrint('Error persisting bookings: $e');
    }
  }

  int getRemainingCapacity(String slotId, int defaultCapacity) {
    return remainingCapacityBySlotId.value[slotId] ?? defaultCapacity;
  }

  bool canBook(String slotId, int defaultCapacity) {
    return getRemainingCapacity(slotId, defaultCapacity) > 0;
  }

  /// Call this when a slot's capacity is edited.
  /// Recalculates remaining = newCapacity - activeBookings for that slot.
  Future<void> recalculateCapacity(String slotId, int newCapacity) async {
    final activeBookings = bookings.value
        .where((b) =>
            b.slotId == slotId &&
            b.status != BookingStatus.rejected)
        .length;
    final newRemaining = (newCapacity - activeBookings).clamp(0, newCapacity);
    remainingCapacityBySlotId.value = {
      ...remainingCapacityBySlotId.value,
      slotId: newRemaining,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _capacityKey, jsonEncode(remainingCapacityBySlotId.value));
  }

  Future<Booking?> createBooking({
    required String slotId,
    required String providerId,
    String? providerName,
    String? providerPhone,
    String? providerEmail,
    String? providerAvatar,
    required String userId,
    required int defaultCapacity,
    required double price,
    String? seatKey,
    SeatGender? userGender,
    String? userName,
    int? userAge,
    String? userPhone,
    String? userEmail,
    String? stripePaymentIntentId,
    String? stripeClientSecret,
    DateTime? countdownEndTime,
    String? otp,
    double? securityDeposit,
  }) async {
    if (seatKey != null) {
      final exists = bookings.value.any(
        (b) =>
            b.slotId == slotId &&
            b.seatKey == seatKey &&
            b.status != BookingStatus.rejected,
      );
      if (exists) return null;
    }

    final currentRemaining = getRemainingCapacity(slotId, defaultCapacity);
    if (currentRemaining <= 0) {
      return null;
    }

    remainingCapacityBySlotId.value = {
      ...remainingCapacityBySlotId.value,
      slotId: currentRemaining - 1,
    };

    final booking = Booking(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      slotId: slotId,
      providerId: providerId,
      providerName: providerName,
      providerPhone: providerPhone,
      providerEmail: providerEmail,
      providerAvatar: providerAvatar,
      userId: userId,
      price: price,
      seatKey: seatKey,
      userGender: userGender,
      userName: userName,
      userAge: userAge,
      userPhone: userPhone,
      userEmail: userEmail,
      status: stripePaymentIntentId != null ? BookingStatus.pending : BookingStatus.accepted,
      otp: otp ?? _generateOtp(),
      otpVerified: false,
      createdAt: DateTime.now(),
      stripePaymentIntentId: stripePaymentIntentId,
      stripeClientSecret: stripeClientSecret,
      countdownEndTime: countdownEndTime,
      paymentHeldInEscrow: stripePaymentIntentId != null,
      securityDeposit: securityDeposit,
    );

    bookings.value = [booking, ...bookings.value];
    await _persist();
    return booking;
  }

  Future<void> markAccepted(String bookingId) async {
    bookings.value = bookings.value
        .map(
          (b) => (b.id == bookingId && b.status == BookingStatus.pending)
              ? b.copyWith(
                  status: BookingStatus.accepted,
                  otp: _generateOtp(),
                  otpVerified: false,
                )
              : b,
        )
        .toList(growable: false);
    await _persist();
  }

  Future<void> markRejected(String bookingId) async {
    final booking = bookings.value.firstWhere((b) => b.id == bookingId);
    final currentRemaining =
        remainingCapacityBySlotId.value[booking.slotId] ?? 0;
    remainingCapacityBySlotId.value = {
      ...remainingCapacityBySlotId.value,
      booking.slotId: currentRemaining + 1,
    };

    bookings.value = bookings.value
        .map(
          (b) => (b.id == bookingId && b.status == BookingStatus.pending)
              ? b.copyWith(status: BookingStatus.rejected)
              : b,
        )
        .toList(growable: false);
    await _persist();
  }

  bool isOtpValid({required String bookingId, required String otp}) {
    final booking = bookings.value.firstWhere((b) => b.id == bookingId);
    return booking.otp == otp;
  }

  Future<bool> verifyOtp({required String bookingId, required String otp}) async {
    final valid = isOtpValid(bookingId: bookingId, otp: otp);
    if (!valid) return false;

    bookings.value = bookings.value
        .map(
          (b) => (b.id == bookingId)
              ? b.copyWith(
                  status: BookingStatus.completed,
                  otpVerified: true,
                )
              : b,
        )
        .toList(growable: false);
    await _persist();
    return true;
  }

  /// Update booking after escrow payment is captured
  Future<void> updateBookingAfterPayment({
    required String bookingId,
    required BookingStatus status,
    bool? otpVerified,
  }) async {
    bookings.value = bookings.value
        .map(
          (b) => (b.id == bookingId)
              ? b.copyWith(
                  status: status,
                  otpVerified: otpVerified ?? b.otpVerified,
                )
              : b,
        )
        .toList(growable: false);
    await _persist();
  }

  /// Get booking by ID
  Booking? getBookingById(String bookingId) {
    try {
      return bookings.value.firstWhere((b) => b.id == bookingId);
    } catch (_) {
      return null;
    }
  }

  String _generateOtp() {
    return (100000 + (DateTime.now().microsecondsSinceEpoch % 900000))
        .toString();
  }
}
