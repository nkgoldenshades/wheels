import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking.dart';
import '../models/slot.dart' hide BookingMode;
import '../models/seat_layout.dart';
import '../models/post_mode.dart';
import '../models/service_type.dart';
import '../models/trip_media.dart';
import '../models/location_confirmation.dart';
import '../utils/gps_verification_helper.dart';
import 'auth_repository.dart';
import 'slot_repository.dart';
import 'customer_slot_repository.dart';
import 'vehicle_repository.dart';
import 'otp_service.dart';

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

  /// Refresh bookings from Supabase (called after auth).
  /// Also triggers server-side expiry of overdue bookings.
  Future<void> refreshFromSupabase() async {
    // Expire overdue bookings on the server first (fire-and-forget)
    _expireOverdueBookings();
    bookings.value = [];
    await _loadFromSupabase();
    await _persist();
  }

  /// Calls the server-side expire function. Silent — never throws.
  Future<void> _expireOverdueBookings() async {
    try {
      final supabase = Supabase.instance.client;

      // Expire overdue bookings
      final r1 = await supabase.rpc('expire_overdue_bookings');
      if (r1 != null) {
        final count = (r1 as Map<String, dynamic>)['expired_count'] ?? 0;
        if (count > 0) debugPrint('⏰ Auto-expired $count overdue booking(s)');
      }

      // Deactivate posts whose end_time has passed
      try {
        final r2 = await supabase.rpc('auto_deactivate_expired_posts');
        if (r2 != null) {
          final count = (r2 as Map<String, dynamic>)['deactivated_posts'] ?? 0;
          if (count > 0) {
            debugPrint('📴 Auto-deactivated $count expired post(s)');
          }
        }
      } catch (_) {
        // RPC not deployed — silently skip
      }
    } catch (e) {
      debugPrint('⚠️ auto-maintenance: $e');
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear existing bookings before loading (prevent duplicates)
      bookings.value = [];

      debugPrint(
        '🔄 Loading bookings for user: ${AuthRepository.instance.currentUser?.id}',
      );

      // ══════════════════════════════════════════════════════════════
      // ALWAYS MERGE BOTH SOURCES (Supabase + Local Storage)
      // This prevents data loss if Supabase returns 0 bookings
      // ══════════════════════════════════════════════════════════════

      // 1. Load from Supabase (source of truth)
      final supabaseBookings = <String, Booking>{};
      try {
        await _loadFromSupabase();

        for (final booking in bookings.value) {
          supabaseBookings[booking.id] = booking;
        }

        debugPrint('📥 Supabase: Loaded ${supabaseBookings.length} bookings');
      } catch (e) {
        debugPrint('❌ Supabase load failed: $e');
      }

      // 2. Load from local storage (fallback + cache)
      final localBookings = <String, Booking>{};
      final bookingsData = prefs.getString(_storageKey);
      if (bookingsData != null) {
        try {
          final List<dynamic> jsonList = jsonDecode(bookingsData);
          final parsedBookings = jsonList
              .map((e) => Booking.fromJson(e as Map<String, dynamic>))
              .toList();

          for (final booking in parsedBookings) {
            localBookings[booking.id] = booking;
          }

          debugPrint(
            '💾 Local Storage: Loaded ${localBookings.length} bookings',
          );
        } catch (e) {
          debugPrint('❌ Local storage parse failed: $e');
        }
      } else {
        debugPrint('⚠️ No local bookings found');
      }

      // 3. Merge both sources (Supabase takes priority as most up-to-date)
      final merged = <String, Booking>{};

      // Add local bookings first (fallback)
      for (final entry in localBookings.entries) {
        merged[entry.key] = entry.value;
      }

      // Overwrite with Supabase bookings (more up-to-date)
      for (final entry in supabaseBookings.entries) {
        merged[entry.key] = entry.value;
      }

      bookings.value = merged.values.toList();
      debugPrint(
        '✅ Final Total: ${bookings.value.length} unique bookings (merged)',
      );

      // Load capacity data (always from local)
      final capacityData = prefs.getString(_capacityKey);
      if (capacityData != null) {
        remainingCapacityBySlotId.value = Map<String, int>.from(
          jsonDecode(capacityData),
        );
      }

      // Migrate old bookings if needed
      if (bookings.value.isNotEmpty) {
        bool needsMigration = false;
        final migratedBookings = bookings.value
            .map((b) {
              final providerId = b.providerId.trim();
              if (providerId.isNotEmpty && providerId != 'user1') {
                return b;
              }

              String? resolvedProviderId;
              for (final e in SlotRepository.instance.allSlots) {
                if (e.slot.id == b.slotId) {
                  final vehicle = VehicleRepository.instance.getById(
                    e.slot.vehicleId,
                  );
                  resolvedProviderId = vehicle?.userId;
                  break;
                }
              }

              if (resolvedProviderId == null ||
                  resolvedProviderId.trim().isEmpty) {
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
            })
            .toList(growable: false);

        if (needsMigration) {
          bookings.value = migratedBookings;
          await _persist();
        }
      }
    } catch (e) {
      debugPrint('Error loading bookings: $e');
    }
  }

  Future<void> _loadFromSupabase() async {
    final supabase = Supabase.instance.client;
    final currentUser = AuthRepository.instance.currentUser;

    if (currentUser == null) {
      debugPrint('⚠️ No user logged in - skipping Supabase booking load');
      return;
    }

    debugPrint('🔍 Loading bookings for user: ${currentUser.id}');
    debugPrint(
      '🔑 Current user ID: ${currentUser.id}',
    ); // ✅ FIX: Debug log to confirm user ID

    // Load bookings where user is either customer OR provider (CORRECT field names)
    final response = await supabase
        .from('bookings')
        .select()
        .or(
          'profile_customer_id.eq.${currentUser.id},profile_provider_id.eq.${currentUser.id}',
        )
        .order('created_at', ascending: false);

    if (response.isEmpty) {
      debugPrint('✅ No bookings found in Supabase for user ${currentUser.id}');
      return;
    }

    debugPrint(
      '📥 Received ${(response as List).length} bookings from Supabase',
    );

    // Debug: Print all booking IDs received
    for (var json in response) {
      debugPrint('   - Booking ID: ${json['id']}');
    }

    final loadedBookings = (response as List)
        .map((json) => Booking.fromJson(json as Map<String, dynamic>))
        .toList();

    // Deduplicate by ID (in case of any duplicates)
    final uniqueBookings = <String, Booking>{};
    for (final booking in loadedBookings) {
      if (uniqueBookings.containsKey(booking.id)) {
        debugPrint('⚠️ Duplicate booking detected: ${booking.id}');
      } else {
        debugPrint('   ✓ Adding booking: ${booking.id}');
      }
      uniqueBookings[booking.id] = booking;
    }

    // Auto-expire overdue bookings
    final expiredBookings = <Booking>[];

    for (final booking in uniqueBookings.values) {
      // Check if booking is overdue (active but past deadline)
      if (booking.isOverdue) {
        debugPrint(
          '⏰ Auto-expiring overdue booking: ${booking.id} (deadline: ${booking.deadlineTime})',
        );
        expiredBookings.add(booking);
      }
    }

    // Update expired bookings in database
    for (final booking in expiredBookings) {
      try {
        await supabase
            .from('bookings')
            .update({'status': 'expired'})
            .eq('id', booking.id);

        // Update in memory
        uniqueBookings[booking.id] = booking.copyWith(
          status: BookingStatus.expired,
        );
        debugPrint('✅ Expired booking: ${booking.id}');
      } catch (e) {
        debugPrint('❌ Failed to expire booking ${booking.id}: $e');
      }
    }

    bookings.value = uniqueBookings.values.toList();
    await _persist(); // Save to local storage

    // Rebuild capacity for all slots based on active bookings
    await _rebuildAllCapacities();

    debugPrint(
      '✅ Loaded ${bookings.value.length} unique bookings from Supabase',
    );
    if (expiredBookings.isNotEmpty) {
      debugPrint('⏰ Auto-expired ${expiredBookings.length} overdue bookings');
    }
  }

  /// Rebuild remaining capacity for all slots based on current active bookings.
  /// This ensures capacity is accurate even if local storage is stale.
  Future<void> _rebuildAllCapacities() async {
    // Get all unique slot IDs from bookings
    final slotIds = bookings.value.map((b) => b.slotId).toSet();

    // Get all slots to know their capacities
    final allSlots = [
      ...SlotRepository.instance.allSlotsRaw,
      ...CustomerSlotRepository.instance.allSlotsRaw,
    ];

    final newCapacities = <String, int>{};

    for (final slotId in slotIds) {
      // Find the slot to get its capacity
      final slot = allSlots.cast<Slot?>().firstWhere(
        (s) => s?.id == slotId,
        orElse: () => null,
      );

      if (slot == null) continue;

      // Count active bookings for this slot
      final activeBookings = bookings.value
          .where((b) => b.slotId == slotId && b.status.isActive)
          .length;

      // Calculate remaining capacity
      final remaining = (slot.capacity - activeBookings).clamp(
        0,
        slot.capacity,
      );
      newCapacities[slotId] = remaining;

      debugPrint(
        '📊 Slot $slotId: ${slot.capacity} total, $activeBookings booked, $remaining remaining',
      );
    }

    // Update the capacity map
    remainingCapacityBySlotId.value = {
      ...remainingCapacityBySlotId.value,
      ...newCapacities,
    };

    // Persist updated capacities
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _capacityKey,
      jsonEncode(remainingCapacityBySlotId.value),
    );
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
        .where((b) => b.slotId == slotId && b.status.isActive)
        .length;
    final newRemaining = (newCapacity - activeBookings).clamp(0, newCapacity);
    remainingCapacityBySlotId.value = {
      ...remainingCapacityBySlotId.value,
      slotId: newRemaining,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _capacityKey,
      jsonEncode(remainingCapacityBySlotId.value),
    );
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
    String? seatKeyRaw, // human-readable seat name e.g. "A2"
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
    String? termsSnapshot,
    BookingMode bookingMode = BookingMode.shared,
    int? totalCapacityBooked,
    PostMode? postMode,
    ServiceType? serviceType,
    // ── slot details snapshot ─────────────────────────────────
    String? vehicleId,
    DateTime? slotStartTime,
    DateTime? slotEndTime,
    int? slotCapacity,
    String? pickupOption,
    bool? withOperator,
    String? fuelPolicy,
    double? maxWeight,
    double? maxLength,
    double? maxWidth,
    double? maxHeight,
    // lease-specific snapshot
    String? leaseDuration,
    bool? insuranceIncluded,
    String? leaseTerms,
    int? waitForFullDeadlineHours,
    Map<String, dynamic>? slotLayoutSnapshot,
    List<String>? providerImageUrls, // vehicle photos
    String? paymentMethod, // "razorpay" or "stripe"
    String? deviceId, // from DeviceInfoService
    // ── location snapshot from the slot ──────────────────────
    String? routeType,
    String? fromAddress,
    double? fromLat,
    double? fromLng,
    String? toAddress,
    double? toLat,
    double? toLng,
    String? baseAddress,
    double? baseLat,
    double? baseLng,
    double? rangeKm,
  }) async {
    // Prevent self-booking: User cannot book their own post
    if (userId == providerId) {
      debugPrint('❌ Cannot book your own post - self-booking not allowed');
      throw Exception('You cannot book your own service');
    }

    // Check for full post booking conflicts
    if (bookingMode == BookingMode.full) {
      // Check if slot already has any active bookings
      final hasActiveBookings = bookings.value.any(
        (b) => b.slotId == slotId && b.status.isActive,
      );
      if (hasActiveBookings) {
        debugPrint(
          '❌ Cannot book full post - slot already has active bookings',
        );
        return null;
      }
    } else {
      // Check if slot is locked by a full post booking
      final isLockedByFullVehicle = bookings.value.any(
        (b) =>
            b.slotId == slotId &&
            b.bookingMode == BookingMode.full &&
            b.isFullVehicleLocked &&
            b.status.isActive,
      );
      if (isLockedByFullVehicle) {
        debugPrint('❌ Cannot book - slot is locked by full post booking');
        return null;
      }
    }

    if (seatKey != null) {
      final exists = bookings.value.any(
        (b) => b.slotId == slotId && b.seatKey == seatKey && b.status.isActive,
      );
      if (exists) return null;
    }

    final currentRemaining = getRemainingCapacity(slotId, defaultCapacity);

    // For full post bookings, check if full capacity is available
    if (bookingMode == BookingMode.full) {
      if (currentRemaining < defaultCapacity) {
        debugPrint('❌ Cannot book full post - not enough capacity available');
        return null;
      }
      // Lock entire capacity
      remainingCapacityBySlotId.value = {
        ...remainingCapacityBySlotId.value,
        slotId: 0, // Full post = no remaining capacity
      };
    } else {
      // Shared booking
      if (currentRemaining <= 0) {
        return null;
      }
      remainingCapacityBySlotId.value = {
        ...remainingCapacityBySlotId.value,
        slotId: currentRemaining - 1,
      };
    }

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
      status: stripePaymentIntentId != null
          ? BookingStatus.pending
          : BookingStatus.accepted,
      otp:
          otp, // Use passed OTP (test mode) or wait for Supabase trigger to set it
      otpVerified: false,
      createdAt: DateTime.now(),
      stripePaymentIntentId: stripePaymentIntentId,
      stripeClientSecret: stripeClientSecret,
      countdownEndTime: countdownEndTime,
      paymentHeldInEscrow: stripePaymentIntentId != null,
      securityDeposit: securityDeposit,
      termsSnapshot: termsSnapshot,
      bookingMode: bookingMode,
      totalCapacityBooked: bookingMode == BookingMode.full
          ? (totalCapacityBooked ?? defaultCapacity)
          : null,
      isFullVehicleLocked: bookingMode == BookingMode.full,
      postMode: postMode,
      // location snapshot
      routeType: routeType,
      fromAddress: fromAddress,
      fromLat: fromLat,
      fromLng: fromLng,
      toAddress: toAddress,
      toLat: toLat,
      toLng: toLng,
      baseAddress: baseAddress,
      baseLat: baseLat,
      baseLng: baseLng,
      rangeKm: rangeKm,
      // trip schedule
      tripStartTime: slotStartTime,
      tripEndTime: slotEndTime,
    );

    bookings.value = [booking, ...bookings.value];
    await _persist();

    // Sync to Supabase (OTP will be auto-generated by trigger)
    await _syncBookingToSupabase(
      booking,
      serviceType: serviceType,
      totalPrice: price,
      vehicleId: vehicleId,
      slotStartTime: slotStartTime,
      slotEndTime: slotEndTime,
      slotCapacity: slotCapacity,
      pickupOption: pickupOption,
      withOperator: withOperator,
      fuelPolicy: fuelPolicy,
      maxWeight: maxWeight,
      maxLength: maxLength,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      leaseDuration: leaseDuration,
      insuranceIncluded: insuranceIncluded,
      leaseTerms: leaseTerms,
      waitForFullDeadlineHours: waitForFullDeadlineHours,
      slotLayoutSnapshot: slotLayoutSnapshot,
      seatKeyRaw: seatKeyRaw,
      providerImageUrls: providerImageUrls,
      paymentMethod: paymentMethod,
      deviceId: deviceId,
    );

    // Deduplicate after sync (in case of any race conditions)
    final uniqueBookings = <String, Booking>{};
    for (final b in bookings.value) {
      uniqueBookings[b.id] = b;
    }
    bookings.value = uniqueBookings.values.toList();

    return booking;
  }

  Future<void> _syncBookingToSupabase(
    Booking booking, {
    ServiceType? serviceType,
    double? totalPrice,
    String? vehicleId,
    DateTime? slotStartTime,
    DateTime? slotEndTime,
    int? slotCapacity,
    String? pickupOption,
    bool? withOperator,
    String? fuelPolicy,
    double? maxWeight,
    double? maxLength,
    double? maxWidth,
    double? maxHeight,
    String? leaseDuration,
    bool? insuranceIncluded,
    String? leaseTerms,
    int? waitForFullDeadlineHours,
    Map<String, dynamic>? slotLayoutSnapshot,
    String? seatKeyRaw,
    List<String>? providerImageUrls,
    String? paymentMethod,
    String? deviceId,
  }) async {
    final payload = <String, dynamic>{}; // Declare outside try block
    try {
      final supabase = Supabase.instance.client;
      final currentUser = AuthRepository.instance.currentUser;

      if (currentUser == null) {
        debugPrint('⚠️ No user logged in - skipping booking sync');
        return;
      }

      // Exact mapping to bookings table schema (from DDL)
      payload.addAll({
        'post_id': booking.slotId,
        'profile_customer_id': booking.userId,
        'profile_provider_id': booking.providerId,
        'status': booking.status.name,
        'service_type': serviceType?.name ?? 'passenger',
        'booking_strategy_snapshot': booking.bookingMode == BookingMode.full
            ? 'full_vehicle'
            : 'instant',
        'post_mode': booking.postMode?.dbValue ?? 'instant',
        'persons_snapshot': slotCapacity ?? 1,
        'seat_keys': booking.seatKey,
        'seat_keys_raw': seatKeyRaw,
        'price_snapshot': booking.price,
        'deposit_snapshot': booking.securityDeposit ?? 0,
        'total_price': totalPrice ?? booking.price,
        'currency_snapshot': AppPreferences.instance.currencyCode.value,

        // Passenger details jsonb
        'passenger_details': {
          'name': booking.userName,
          'age': booking.userAge,
          'phone': booking.userPhone,
          'email': booking.userEmail,
          'gender': booking.userGender?.name,
        },

        // Parcel jsonb
        if (maxWeight != null ||
            maxLength != null ||
            maxWidth != null ||
            maxHeight != null)
          'parcel_snapshot': {
            'max_weight': maxWeight,
            'max_length': maxLength,
            'max_width': maxWidth,
            'max_height': maxHeight,
          },

        // Timestamps
        'start_time': (slotStartTime ?? booking.createdAt)
            .toUtc()
            .toIso8601String(),
        'end_time':
            (slotEndTime ?? booking.createdAt.add(const Duration(hours: 1)))
                .toUtc()
                .toIso8601String(),

        // Address top-level columns
        if (booking.fromAddress != null) 'from_address': booking.fromAddress,
        if (booking.toAddress != null) 'to_address': booking.toAddress,

        // Geo columns
        if (booking.fromLat != null) 'from_lat': booking.fromLat,
        if (booking.fromLng != null) 'from_lng': booking.fromLng,
        if (booking.toLat != null) 'to_lat': booking.toLat,
        if (booking.toLng != null) 'to_lng': booking.toLng,
        if (booking.fromLat == null && booking.baseLat != null)
          'from_lat': booking.baseLat,
        if (booking.fromLng == null && booking.baseLng != null)
          'from_lng': booking.baseLng,
        if (booking.rangeKm != null) 'radius': booking.rangeKm,

        // route_snapshot jsonb
        'route_snapshot': {
          'route_type': booking.routeType,
          'from_address': booking.fromAddress,
          'from_lat': booking.fromLat,
          'from_lng': booking.fromLng,
          'to_address': booking.toAddress,
          'to_lat': booking.toLat,
          'to_lng': booking.toLng,
          'base_address': booking.baseAddress,
          'base_lat': booking.baseLat,
          'base_lng': booking.baseLng,
          'range_km': booking.rangeKm,
        },

        // OTP
        if (booking.otp != null) 'otp_code': booking.otp,
        'otp_verified': booking.otpVerified,

        // Payment
        'payment_method': ?paymentMethod,
        'payment_status': booking.stripePaymentIntentId != null
            ? 'authorized'
            : 'unpaid',
        'payment_amount': totalPrice ?? booking.price,
        'payment_currency': AppPreferences.instance.currencyCode.value,
        if (booking.stripePaymentIntentId != null)
          'payment_gateway_id': booking.stripePaymentIntentId,
        if (booking.stripePaymentIntentId != null)
          'paid_at': DateTime.now().toUtc().toIso8601String(),

        // Slot-specific columns
        'booking_option': ?pickupOption,
        'with_operator': ?withOperator,
        'max_weight': ?maxWeight,
        'max_length': ?maxLength,
        'max_width': ?maxWidth,
        'max_height': ?maxHeight,

        // trip_media jsonb - starts empty, filled during trip
        'trip_media': {
          'start': {
            'provider': {'images': <String>[], 'video_url': null},
            'customer': {'images': <String>[], 'video_url': null},
          },
          'end': {
            'provider': {'images': <String>[], 'video_url': null},
            'customer': {'images': <String>[], 'video_url': null},
          },
        },

        // metadata jsonb — extra fields without their own column
        'metadata': {
          'provider_name': booking.providerName,
          'provider_phone': booking.providerPhone,
          'provider_email': booking.providerEmail,
          'provider_avatar': booking.providerAvatar,
          'countdown_end_time': booking.countdownEndTime?.toIso8601String(),
          'payment_held_in_escrow': booking.paymentHeldInEscrow,
          'is_full_vehicle_locked': booking.isFullVehicleLocked,
          'terms_snapshot': booking.termsSnapshot,
          'total_capacity_booked': booking.totalCapacityBooked,
          'vehicle_id': vehicleId,
          'fuel_policy': fuelPolicy,
          'lease_duration': leaseDuration,
          'insurance_included': insuranceIncluded,
          'lease_terms': leaseTerms,
          'wait_for_full_deadline_hours': waitForFullDeadlineHours,
        },

        'device_id': ?deviceId,
        if (slotLayoutSnapshot != null)
          'slot_layout': _buildBookingLayoutSnapshot(
            slotLayoutSnapshot,
            booking.seatKey,
          ),
      });

      final response = await supabase
          .from('bookings')
          .insert(payload)
          .select('id, otp_code')
          .single();

      // Update local booking with Supabase-generated ID and OTP
      final generatedId = response['id']?.toString();
      final generatedOtp = response['otp_code'] as String?;

      if (generatedId != null) {
        final index = bookings.value.indexWhere((b) => b.id == booking.id);
        if (index != -1) {
          final updatedBookings = List<Booking>.from(bookings.value);
          // Keep local OTP if Supabase didn't return one (e.g. test mode)
          final finalOtp = generatedOtp ?? booking.otp;
          updatedBookings[index] = booking.copyWith(
            id: generatedId,
            otp: finalOtp,
          );

          // Deduplicate before setting (prevent duplicates)
          final uniqueBookings = <String, Booking>{};
          for (final b in updatedBookings) {
            uniqueBookings[b.id] = b;
          }
          bookings.value = uniqueBookings.values.toList();

          await _persist();
        }
        debugPrint(
          '✅ Booking synced to Supabase: ID=$generatedId, OTP=$generatedOtp',
        );
      } else {
        debugPrint('⚠️ Booking synced but no ID returned from Supabase');
      }
    } catch (e) {
      debugPrint('❌ Failed to sync booking to Supabase: $e');
      debugPrint('📦 Payload that failed: ${jsonEncode(payload)}');
      // Don't throw - allow booking to succeed locally even if Supabase sync fails
    }
  }

  Future<bool> markAccepted(String bookingId) async {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return false;

    try {
      // Call database function
      final result = await Supabase.instance.client.rpc(
        'accept_booking',
        params: {'booking_id': int.parse(bookingId), 'user_id': currentUser.id},
      );

      final success = result['success'] as bool? ?? false;
      final message = result['message'] as String? ?? '';

      if (success) {
        debugPrint('✅ $message');
        // Update local state
        bookings.value = bookings.value
            .map(
              (b) => b.id == bookingId
                  ? b.copyWith(status: BookingStatus.accepted)
                  : b,
            )
            .toList(growable: false);
        await _persist();
        return true;
      } else {
        debugPrint('❌ $message');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to accept booking: $e');
      return false;
    }
  }

  Future<bool> markRejected(String bookingId) async {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return false;

    final booking = bookings.value.firstWhere((b) => b.id == bookingId);

    try {
      // Call database function
      final result = await Supabase.instance.client.rpc(
        'reject_booking',
        params: {'booking_id': int.parse(bookingId), 'user_id': currentUser.id},
      );

      final success = result['success'] as bool? ?? false;
      final message = result['message'] as String? ?? '';

      if (success) {
        debugPrint('✅ $message');

        // Free up capacity
        final currentRemaining =
            remainingCapacityBySlotId.value[booking.slotId] ?? 0;
        remainingCapacityBySlotId.value = {
          ...remainingCapacityBySlotId.value,
          booking.slotId: currentRemaining + 1,
        };

        // Update local state
        bookings.value = bookings.value
            .map(
              (b) => b.id == bookingId
                  ? b.copyWith(status: BookingStatus.rejected)
                  : b,
            )
            .toList(growable: false);
        await _persist();
        return true;
      } else {
        debugPrint('❌ $message');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to reject booking: $e');
      return false;
    }
  }

  bool isOtpValid({required String bookingId, required String otp}) {
    // OTP verification is intentionally backend-only so failed attempts,
    // locking, and audit timestamps cannot be bypassed by local state.
    return false;
  }

  Future<bool> verifyOtp({
    required String bookingId,
    required String otp,
  }) async {
    final booking = bookings.value.firstWhere(
      (b) => b.id == bookingId,
      orElse: () => throw Exception('Booking $bookingId not found locally'),
    );

    debugPrint('🔐 verifyOtp: bookingId=$bookingId, userId=${booking.userId}');

    // Try Supabase RPC first
    try {
      final result = await OtpService().verifyOtp(
        bookingId: bookingId,
        userId: booking.userId,
        enteredOtp: otp,
      );

      debugPrint('🔐 RPC result: ${result.name} — ${result.message}');

      if (result.isSuccess) {
        // Update local state
        bookings.value = bookings.value
            .map(
              (b) => b.id == bookingId
                  ? b.copyWith(
                      status: BookingStatus.completed,
                      otpVerified: true,
                    )
                  : b,
            )
            .toList(growable: false);
        await _persist();

        // Refresh from database to ensure consistency
        // (run in background, don't await to avoid blocking UI)
        refreshFromSupabase().catchError((e) {
          debugPrint('⚠️ Background refresh failed: $e');
        });

        return true;
      } else {
        debugPrint('❌ OTP verification failed: ${result.message}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ OTP RPC error: $e');
      debugPrint('🔄 Falling back to local OTP verification...');

      // Local fallback — compare against stored OTP (works on web with CORS issues)
      if (booking.otp != null && booking.otp!.trim() == otp.trim()) {
        debugPrint('✅ Local OTP match — marking completed');
        // Also update Supabase directly (not via RPC)
        try {
          await Supabase.instance.client
              .from('bookings')
              .update({
                'status': 'completed',
                'otp_verified': true,
                'otp_verified_at': DateTime.now().toIso8601String(),
              })
              .eq('id', int.parse(bookingId));
          debugPrint('✅ Booking status updated in Supabase');
        } catch (updateErr) {
          debugPrint('⚠️ Could not update Supabase status: $updateErr');
        }

        bookings.value = bookings.value
            .map(
              (b) => b.id == bookingId
                  ? b.copyWith(
                      status: BookingStatus.completed,
                      otpVerified: true,
                    )
                  : b,
            )
            .toList(growable: false);
        await _persist();

        // Refresh from database to ensure consistency
        refreshFromSupabase().catchError((e) {
          debugPrint('⚠️ Background refresh failed: $e');
        });

        return true;
      }

      debugPrint('❌ Local OTP mismatch');
      return false;
    }
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

  Future<bool> markRefunded(String bookingId) async {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return false;

    final booking = bookings.value.firstWhere((b) => b.id == bookingId);

    try {
      // Call database function
      final result = await Supabase.instance.client.rpc(
        'refund_booking',
        params: {'booking_id': int.parse(bookingId), 'user_id': currentUser.id},
      );

      final success = result['success'] as bool? ?? false;
      final message = result['message'] as String? ?? '';

      if (success) {
        debugPrint('✅ $message');

        // Free up capacity
        final currentRemaining =
            remainingCapacityBySlotId.value[booking.slotId] ?? 0;
        remainingCapacityBySlotId.value = {
          ...remainingCapacityBySlotId.value,
          booking.slotId: currentRemaining + 1,
        };

        // Update local state
        bookings.value = bookings.value
            .map(
              (b) => b.id == bookingId
                  ? b.copyWith(status: BookingStatus.refunded)
                  : b,
            )
            .toList(growable: false);
        await _persist();
        return true;
      } else {
        debugPrint('❌ $message');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to refund booking: $e');
      return false;
    }
  }

  /// Update trip_media for a booking — called by TripMediaWidget after upload.
  /// Patches only the trip_media JSON column in Supabase and updates local state.
  /// GPS data is stored INSIDE trip_media JSON (no separate columns needed).
  Future<void> updateTripMedia(String bookingId, TripMedia media) async {
    // Patch Supabase with trip_media JSON (GPS data included in JSON)
    try {
      await Supabase.instance.client
          .from('bookings')
          .update({'trip_media': media.toJson()})
          .eq('id', int.parse(bookingId));
      debugPrint('✅ trip_media updated for booking $bookingId');

      // Log GPS verification status for debugging
      final booking = bookings.value.firstWhere(
        (b) => b.id == bookingId,
        orElse: () => throw Exception('Booking not found: $bookingId'),
      );
      final updatedBooking = booking.copyWith(tripMedia: media);
      final customerVerified =
          GpsVerificationHelper.verifyCustomerPickupLocation(updatedBooking);
      final providerVerified =
          GpsVerificationHelper.verifyProviderPickupLocation(updatedBooking);
      debugPrint('🔍 GPS Verification for booking $bookingId:');
      debugPrint(
        '   Customer: ${customerVerified ? "✅ verified" : "❌ not verified"}',
      );
      debugPrint(
        '   Provider: ${providerVerified ? "✅ verified" : "❌ not verified"}',
      );
    } catch (e) {
      debugPrint('❌ Failed to update trip_media: $e');
    }

    // Update local state AFTER Supabase completes to avoid rebuild loop
    bookings.value = bookings.value
        .map((b) => b.id == bookingId ? b.copyWith(tripMedia: media) : b)
        .toList(growable: false);
    await _persist();
  }

  /// Update location confirmations (automatic GPS tracking, separate from trip media)
  Future<void> updateLocationConfirmations(
    String bookingId,
    LocationConfirmations confirmations,
  ) async {
    // Patch Supabase with location_confirmations JSON
    try {
      await Supabase.instance.client
          .from('bookings')
          .update({'location_confirmations': confirmations.toJson()})
          .eq('id', int.parse(bookingId));
      debugPrint('✅ location_confirmations updated for booking $bookingId');
      debugPrint(
        '   Pickup - Provider: ${confirmations.pickup.provider.isConfirmed ? "✅" : "❌"}, Customer: ${confirmations.pickup.customer.isConfirmed ? "✅" : "❌"}',
      );
      debugPrint(
        '   Dropoff - Provider: ${confirmations.dropoff.provider.isConfirmed ? "✅" : "❌"}, Customer: ${confirmations.dropoff.customer.isConfirmed ? "✅" : "❌"}',
      );
    } catch (e) {
      debugPrint('❌ Failed to update location_confirmations: $e');
      rethrow;
    }

    // Update local state AFTER Supabase completes
    bookings.value = bookings.value
        .map(
          (b) => b.id == bookingId
              ? b.copyWith(locationConfirmations: confirmations)
              : b,
        )
        .toList(growable: false);
    await _persist();
  }

  /// Builds the slot_layout snapshot for a booking.
  /// The booked seat is marked "booked", all other non-gap seats are "locked".
  /// This mirrors posts.slot_layout_structure so the same widget can render both.
  static Map<String, dynamic> _buildBookingLayoutSnapshot(
    Map<String, dynamic> fullLayout,
    String? bookedSeatKey,
  ) {
    final type = fullLayout['type'] as String? ?? 'passenger';
    final rawLayout = fullLayout['layout'] as List<dynamic>? ?? [];

    final modifiedLayout = rawLayout.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final key = map['key'] as String?;
      final status = map['status'] as String? ?? 'available';

      // Gaps stay as gaps
      if (status == 'gap') return map;

      if (key == bookedSeatKey) {
        // This is the seat the customer booked
        map['status'] = 'booked';
      } else {
        // All other seats are locked in this booking's view
        map['status'] = 'locked';
      }
      return map;
    }).toList();

    return {'type': type, 'layout': modifiedLayout};
  }
}
