import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking.dart';
import '../models/seat_layout.dart';
import '../models/post_mode.dart';
import '../models/service_type.dart';
import '../models/trip_media.dart';
import 'auth_repository.dart';
import 'slot_repository.dart';
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
      final r2 = await supabase.rpc('auto_deactivate_expired_posts');
      if (r2 != null) {
        final count = (r2 as Map<String, dynamic>)['deactivated_posts'] ?? 0;
        if (count > 0) debugPrint('📴 Auto-deactivated $count expired post(s)');
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
      
      // Try to load from Supabase first (source of truth)
      bool supabaseSuccess = false;
      try {
        await _loadFromSupabase();
        supabaseSuccess = true; // ✅ FIX: Supabase responded without error = success
        
        debugPrint('✅ Successfully loaded ${bookings.value.length} bookings from Supabase');
      } catch (e) {
        debugPrint('❌ Supabase load failed: $e');
        supabaseSuccess = false;
      }
      
      // Only load from local storage if Supabase failed
      if (!supabaseSuccess) {
        debugPrint('⚠️ Falling back to local storage');
        
        final bookingsData = prefs.getString(_storageKey);
        if (bookingsData != null) {
          final List<dynamic> jsonList = jsonDecode(bookingsData);
          final localBookings = jsonList
              .map((e) => Booking.fromJson(e as Map<String, dynamic>))
              .toList();
          
          // Deduplicate local bookings
          final uniqueLocal = <String, Booking>{};
          for (final booking in localBookings) {
            uniqueLocal[booking.id] = booking;
          }
          bookings.value = uniqueLocal.values.toList();
          debugPrint('✅ Loaded ${bookings.value.length} bookings from local storage');
        } else {
          debugPrint('⚠️ No local bookings found');
        }
      }
      
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

  Future<void> _loadFromSupabase() async {
    final supabase = Supabase.instance.client;
    final currentUser = AuthRepository.instance.currentUser;
    
    if (currentUser == null) {
      debugPrint('⚠️ No user logged in - skipping Supabase booking load');
      return;
    }

    debugPrint('🔍 Loading bookings for user: ${currentUser.id}');
    debugPrint('🔑 Current user ID: ${currentUser.id}'); // ✅ FIX: Debug log to confirm user ID

    // Load bookings where user is either customer OR provider (CORRECT field names)
    final response = await supabase
        .from('bookings')
        .select()
        .or('profile_customer_id.eq.${currentUser.id},profile_provider_id.eq.${currentUser.id}')
        .order('created_at', ascending: false);

    if (response.isEmpty) {
      debugPrint('✅ No bookings found in Supabase for user ${currentUser.id}');
      return;
    }

    debugPrint('📥 Received ${(response as List).length} bookings from Supabase');
    
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

    bookings.value = uniqueBookings.values.toList();
    await _persist(); // Save to local storage
    
    debugPrint('✅ Loaded ${bookings.value.length} unique bookings from Supabase');
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
            b.status.isActive)
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
    String? seatKeyRaw,       // human-readable seat name e.g. "A2"
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
    List<String>? providerImageUrls,  // vehicle photos
    String? paymentMethod,            // "razorpay" or "stripe"
    String? deviceId,                 // from DeviceInfoService
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
        debugPrint('❌ Cannot book full post - slot already has active bookings');
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
        (b) =>
            b.slotId == slotId &&
            b.seatKey == seatKey &&
            b.status.isActive,
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
      status: stripePaymentIntentId != null ? BookingStatus.pending : BookingStatus.accepted,
      otp: otp, // Use passed OTP (test mode) or wait for Supabase trigger to set it
      otpVerified: false,
      createdAt: DateTime.now(),
      stripePaymentIntentId: stripePaymentIntentId,
      stripeClientSecret: stripeClientSecret,
      countdownEndTime: countdownEndTime,
      paymentHeldInEscrow: stripePaymentIntentId != null,
      securityDeposit: securityDeposit,
      termsSnapshot: termsSnapshot,
      bookingMode: bookingMode,
      totalCapacityBooked: bookingMode == BookingMode.full ? (totalCapacityBooked ?? defaultCapacity) : null,
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
        'booking_strategy_snapshot': booking.bookingMode == BookingMode.full ? 'full_vehicle' : 'instant',
        'post_mode': booking.postMode?.dbValue ?? 'instant',
        'persons_snapshot': slotCapacity ?? 1,
        'seat_keys': booking.seatKey,
        'seat_keys_raw': seatKeyRaw,
        'price_snapshot': booking.price,
        'deposit_snapshot': booking.securityDeposit ?? 0,
        'total_price': totalPrice ?? booking.price,
        'currency_snapshot': 'INR',

        // Passenger details jsonb
        'passenger_details': {
          'name': booking.userName,
          'age': booking.userAge,
          'phone': booking.userPhone,
          'email': booking.userEmail,
          'gender': booking.userGender?.name,
        },

        // Parcel jsonb
        if (maxWeight != null || maxLength != null || maxWidth != null || maxHeight != null)
          'parcel_snapshot': {
            'max_weight': maxWeight,
            'max_length': maxLength,
            'max_width': maxWidth,
            'max_height': maxHeight,
          },

        // Timestamps
        'start_time': (slotStartTime ?? booking.createdAt).toUtc().toIso8601String(),
        'end_time': (slotEndTime ?? booking.createdAt.add(const Duration(hours: 1))).toUtc().toIso8601String(),

        // Address top-level columns
        if (booking.fromAddress != null) 'from_address': booking.fromAddress,
        if (booking.toAddress != null) 'to_address': booking.toAddress,

        // Geo columns
        if (booking.fromLat != null) 'from_lat': booking.fromLat,
        if (booking.fromLng != null) 'from_lng': booking.fromLng,
        if (booking.toLat != null) 'to_lat': booking.toLat,
        if (booking.toLng != null) 'to_lng': booking.toLng,
        if (booking.fromLat == null && booking.baseLat != null) 'from_lat': booking.baseLat,
        if (booking.fromLng == null && booking.baseLng != null) 'from_lng': booking.baseLng,
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
        'payment_status': booking.stripePaymentIntentId != null ? 'authorized' : 'unpaid',
        'payment_amount': totalPrice ?? booking.price,
        'payment_currency': 'INR',
        if (booking.stripePaymentIntentId != null) 'payment_gateway_id': booking.stripePaymentIntentId,
        if (booking.stripePaymentIntentId != null) 'paid_at': DateTime.now().toUtc().toIso8601String(),

        // Slot-specific columns
        'booking_option': ?pickupOption,
        'with_operator': ?withOperator,
        'max_weight': ?maxWeight,
        'max_length': ?maxLength,
        'max_width': ?maxWidth,
        'max_height': ?maxHeight,

        // trip_media jsonb
        'trip_media': {
          'start': {
            'provider': {
              'images': providerImageUrls ?? <String>[],
              'video_url': null,
            },
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
          'slot_layout': _buildBookingLayoutSnapshot(slotLayoutSnapshot, booking.seatKey),
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
        debugPrint('✅ Booking synced to Supabase: ID=$generatedId, OTP=$generatedOtp');
      } else {
        debugPrint('⚠️ Booking synced but no ID returned from Supabase');
      }
    } catch (e) {
      debugPrint('❌ Failed to sync booking to Supabase: $e');
      debugPrint('📦 Payload that failed: ${jsonEncode(payload)}');
      // Don't throw - allow booking to succeed locally even if Supabase sync fails
    }
  }

  Future<void> markAccepted(String bookingId) async {
    bookings.value = bookings.value
        .map(
          (b) => (b.id == bookingId && b.status == BookingStatus.pending)
              ? b.copyWith(
                  status: BookingStatus.accepted,
                  otp: null, // OTP will be regenerated by Supabase trigger
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
    final booking = bookings.value.firstWhere(
      (b) => b.id == bookingId,
      orElse: () => throw Exception('Booking $bookingId not found locally'),
    );

    debugPrint('🔐 verifyOtp: bookingId=$bookingId, otp=$otp');
    debugPrint('   booking.otp (local)=${booking.otp}, booking.userId=${booking.userId}');

    // ── Local fallback: compare against OTP stored in the booking ──────────
    // This works when Supabase sync succeeded and otp_code was returned.
    if (booking.otp != null && booking.otp!.isNotEmpty) {
      if (booking.otp!.trim() == otp.trim()) {
        debugPrint('✅ OTP matched locally — marking complete');
        bookings.value = bookings.value
            .map((b) => b.id == bookingId
                ? b.copyWith(status: BookingStatus.completed, otpVerified: true)
                : b)
            .toList(growable: false);
        await _persist();
        // Also update Supabase
        try {
          await Supabase.instance.client
              .from('bookings')
              .update({'otp_verified': true, 'status': 'completed'})
              .eq('id', int.parse(bookingId));
        } catch (e) {
          debugPrint('⚠️ Could not update Supabase after local OTP match: $e');
        }
        return true;
      } else {
        debugPrint('❌ OTP mismatch: entered=$otp, stored=${booking.otp}');
        return false;
      }
    }

    // ── Remote fallback: call Supabase RPC ─────────────────────────────────
    try {
      final parsedId = int.tryParse(bookingId);
      if (parsedId == null) {
        debugPrint('❌ bookingId "$bookingId" is not a valid integer — Supabase sync may have failed');
        return false;
      }

      final result = await OtpService().verifyOtp(
        bookingId: parsedId,
        userId: booking.userId,
        enteredOtp: otp,
      );

      debugPrint('🔐 RPC result: ${result.name} — ${result.message}');

      if (result.isSuccess) {
        bookings.value = bookings.value
            .map((b) => b.id == bookingId
                ? b.copyWith(status: BookingStatus.completed, otpVerified: true)
                : b)
            .toList(growable: false);
        await _persist();
        return true;
      } else {
        debugPrint('❌ OTP verification failed: ${result.message}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ OTP verification error: $e');
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

  Future<void> markRefunded(String bookingId) async {
    final booking = bookings.value.firstWhere((b) => b.id == bookingId);
    final currentRemaining = remainingCapacityBySlotId.value[booking.slotId] ?? 0;
    remainingCapacityBySlotId.value = {
      ...remainingCapacityBySlotId.value,
      booking.slotId: currentRemaining + 1,
    };
    bookings.value = bookings.value
        .map((b) => b.id == bookingId ? b.copyWith(status: BookingStatus.refunded) : b)
        .toList(growable: false);
    await _persist();
  }

  /// Update trip_media for a booking — called by TripMediaWidget after upload.
  /// Patches only the trip_media column in Supabase and updates local state.
  Future<void> updateTripMedia(String bookingId, TripMedia media) async {
    // Update local state immediately
    bookings.value = bookings.value
        .map((b) => b.id == bookingId ? b.copyWith(tripMedia: media) : b)
        .toList(growable: false);
    await _persist();

    // Patch Supabase
    try {
      await Supabase.instance.client
          .from('bookings')
          .update({'trip_media': media.toJson()})
          .eq('id', int.parse(bookingId));
      debugPrint('✅ trip_media updated for booking $bookingId');
    } catch (e) {
      debugPrint('❌ Failed to update trip_media: $e');
    }
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

    return {
      'type': type,
      'layout': modifiedLayout,
    };
  }
}


