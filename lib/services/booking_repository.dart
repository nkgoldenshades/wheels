import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking.dart';
import '../models/seat_layout.dart';
import '../models/post_mode.dart';
import '../models/service_type.dart';
import 'auth_repository.dart';
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
      
      // TEMPORARY: Clear local storage to force fresh load from Supabase
      await prefs.remove(_storageKey);
      debugPrint('🧹 Cleared local bookings storage');
      
      // Clear existing bookings before loading (prevent duplicates)
      bookings.value = [];
      
      // Try to load from Supabase first (source of truth)
      bool supabaseSuccess = false;
      try {
        await _loadFromSupabase();
        supabaseSuccess = bookings.value.isNotEmpty;
        
        if (supabaseSuccess) {
          debugPrint('✅ Successfully loaded from Supabase');
        }
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
    String? termsSnapshot,
    BookingMode bookingMode = BookingMode.shared,
    int? totalCapacityBooked,
    PostMode? postMode, // Add PostMode parameter
    ServiceType? serviceType, // Add ServiceType parameter
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
        (b) =>
            b.slotId == slotId &&
            b.status != BookingStatus.rejected &&
            b.status != BookingStatus.refunded,
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
            b.status != BookingStatus.rejected &&
            b.status != BookingStatus.refunded,
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
            b.status != BookingStatus.rejected,
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
      otp: null, // OTP will be generated by backend trigger
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
      postMode: postMode, // Add PostMode to booking
    );

    bookings.value = [booking, ...bookings.value];
    await _persist();
    
    // Sync to Supabase (OTP will be auto-generated by trigger)
    await _syncBookingToSupabase(booking, serviceType: serviceType, totalPrice: price);
    
    // Deduplicate after sync (in case of any race conditions)
    final uniqueBookings = <String, Booking>{};
    for (final b in bookings.value) {
      uniqueBookings[b.id] = b;
    }
    bookings.value = uniqueBookings.values.toList();
    
    return booking;
  }

  Future<void> _syncBookingToSupabase(Booking booking, {ServiceType? serviceType, double? totalPrice}) async {
    final payload = <String, dynamic>{}; // Declare outside try block
    try {
      final supabase = Supabase.instance.client;
      final currentUser = AuthRepository.instance.currentUser;
      
      if (currentUser == null) {
        debugPrint('⚠️ No user logged in - skipping booking sync');
        return;
      }

      // Map Flutter model to Supabase schema (CORRECT field names)
      payload.addAll({
        // NOTE: Don't send 'id' - it's GENERATED ALWAYS AS IDENTITY
        'profile_customer_id': booking.userId, // Correct field name
        'profile_provider_id': booking.providerId, // Correct field name
        'post_id': booking.slotId, // Your DB uses post_id
        'status': booking.status.name,
        
        // Service type and pricing
        'service_type': serviceType?.name ?? 'passenger', // Add service_type
        'total_price': totalPrice ?? booking.price, // Add total_price
        
        // Snapshots
        'price_snapshot': booking.price,
        'deposit_snapshot': booking.securityDeposit ?? 0,
        'currency_snapshot': 'INR',
        'persons_snapshot': 1,
        'seat_keys': booking.seatKey,
        'booking_strategy_snapshot': booking.bookingMode == BookingMode.full ? 'full_vehicle' : 'instant',
        'post_mode_snapshot': booking.postMode?.dbValue ?? 'instant', // Add PostMode to booking data
        
        // Passenger details (jsonb)
        'passenger_details': booking.userName != null ? {
          'name': booking.userName,
          'age': booking.userAge,
          'phone': booking.userPhone,
          'email': booking.userEmail,
          'gender': booking.userGender?.name,
        } : null,
        
        // Metadata (jsonb) - provider info and other fields
        'metadata': {
          'provider_name': booking.providerName,
          'provider_phone': booking.providerPhone,
          'provider_email': booking.providerEmail,
          'provider_avatar': booking.providerAvatar,
          'countdown_end_time': booking.countdownEndTime?.toIso8601String(),
          'stripe_client_secret': booking.stripeClientSecret,
          'payment_held_in_escrow': booking.paymentHeldInEscrow,
          'is_full_vehicle_locked': booking.isFullVehicleLocked,
          'terms_snapshot': booking.termsSnapshot,
          'total_capacity_booked': booking.totalCapacityBooked,
        },
        
        // Payment
        'payment_gateway_id': booking.stripePaymentIntentId,
        'payment_status': booking.stripePaymentIntentId != null ? 'authorized' : 'unpaid',
        
        // OTP - Don't send, let backend trigger generate it
        // 'otp_code': null, // Backend will generate
        'otp_verified': booking.otpVerified,
        
        // Timestamps
        'start_time': booking.createdAt.toIso8601String(),
        'end_time': booking.createdAt.add(Duration(hours: 1)).toIso8601String(),
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
          // Update with backend-generated OTP
          updatedBookings[index] = booking.copyWith(
            otp: generatedOtp, // Use backend-generated OTP
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
}
