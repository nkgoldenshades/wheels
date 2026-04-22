import 'seat_layout.dart';
import 'post_mode.dart';
import 'trip_media.dart';

enum BookingStatus {
  // ── Active (blocks post delete, payment held) ──────────────────────────
  pending,              // Created, waiting for provider to accept
  accepted,             // Provider accepted, trip not started yet
  confirmed,            // Payment confirmed, both parties ready
  inProgress,           // Trip/service currently happening

  // ── Terminal (post can be deleted, payment resolved) ───────────────────
  completed,            // Trip done, OTP verified, payment released
  rejected,             // Provider rejected the booking
  refunded,             // Payment refunded to customer
  cancelled,            // Cancelled (generic)
  cancelledByCustomer,  // Customer cancelled
  cancelledByProvider,  // Provider cancelled
  noShow,               // Customer didn't show up
  disputed,             // Dispute raised — under review
  expired,              // Countdown timer ran out, auto-refunded
}

extension BookingStatusX on BookingStatus {
  /// True = booking is live, payment held, post cannot be deleted
  bool get isActive => const {
    BookingStatus.pending,
    BookingStatus.accepted,
    BookingStatus.confirmed,
    BookingStatus.inProgress,
  }.contains(this);

  /// True = booking is fully resolved, post can be deleted
  bool get isTerminal => !isActive;

  /// True = money needs to be returned to customer
  bool get needsRefund => const {
    BookingStatus.refunded,
    BookingStatus.cancelledByCustomer,
    BookingStatus.cancelledByProvider,
    BookingStatus.expired,
    BookingStatus.disputed,
  }.contains(this);

  /// Display label shown in UI
  String get label {
    switch (this) {
      case BookingStatus.pending:             return 'Pending';
      case BookingStatus.accepted:            return 'Accepted';
      case BookingStatus.confirmed:           return 'Confirmed';
      case BookingStatus.inProgress:          return 'In Progress';
      case BookingStatus.completed:           return 'Completed';
      case BookingStatus.rejected:            return 'Rejected';
      case BookingStatus.refunded:            return 'Refunded';
      case BookingStatus.cancelled:           return 'Cancelled';
      case BookingStatus.cancelledByCustomer: return 'Cancelled by Customer';
      case BookingStatus.cancelledByProvider: return 'Cancelled by Provider';
      case BookingStatus.noShow:              return 'No Show';
      case BookingStatus.disputed:            return 'Disputed';
      case BookingStatus.expired:             return 'Expired';
    }
  }

  /// DB/JSON value (snake_case to match Supabase)
  String get dbValue {
    switch (this) {
      case BookingStatus.pending:             return 'pending';
      case BookingStatus.accepted:            return 'accepted';
      case BookingStatus.confirmed:           return 'confirmed';
      case BookingStatus.inProgress:          return 'in_progress';
      case BookingStatus.completed:           return 'completed';
      case BookingStatus.rejected:            return 'rejected';
      case BookingStatus.refunded:            return 'refunded';
      case BookingStatus.cancelled:           return 'cancelled';
      case BookingStatus.cancelledByCustomer: return 'cancelled_by_customer';
      case BookingStatus.cancelledByProvider: return 'cancelled_by_provider';
      case BookingStatus.noShow:              return 'no_show';
      case BookingStatus.disputed:            return 'disputed';
      case BookingStatus.expired:             return 'expired';
    }
  }

  static BookingStatus fromString(String? value) {
    switch (value) {
      case 'pending':               return BookingStatus.pending;
      case 'accepted':              return BookingStatus.accepted;
      case 'confirmed':             return BookingStatus.confirmed;
      case 'in_progress':           return BookingStatus.inProgress;
      case 'completed':             return BookingStatus.completed;
      case 'rejected':              return BookingStatus.rejected;
      case 'refunded':              return BookingStatus.refunded;
      case 'cancelled':             return BookingStatus.cancelled;
      case 'cancelled_by_customer': return BookingStatus.cancelledByCustomer;
      case 'cancelled_by_provider': return BookingStatus.cancelledByProvider;
      case 'no_show':               return BookingStatus.noShow;
      case 'disputed':              return BookingStatus.disputed;
      case 'expired':               return BookingStatus.expired;
      default:                      return BookingStatus.pending;
    }
  }
}

enum BookingMode {
  shared,  // Multiple customers (default)
  full,    // One customer takes all (charter)
}

class Booking {
  final String id;
  final String slotId;
  final String providerId;
  final String? providerName;
  final String? providerPhone;
  final String? providerEmail;
  final String? providerAvatar;
  final String userId;
  final double price;
  final String? seatKey;
  final SeatGender? userGender;
  final String? userName;
  final int? userAge;
  final String? userPhone;
  final String? userEmail;
  final BookingStatus status;
  final String? otp;
  final bool otpVerified;
  final DateTime createdAt;
  
  // Escrow payment fields
  final String? stripePaymentIntentId;
  final String? stripeClientSecret;
  final DateTime? countdownEndTime;   // payment must be confirmed by this time
  final bool paymentHeldInEscrow;

  // Trip schedule — snapshotted from the post at booking time
  final DateTime? tripStartTime;      // when the trip/service begins
  final DateTime? tripEndTime;        // when the trip/service ends

  // Deadline — booking must reach 'completed' by this time or it auto-expires
  // Defaults to tripEndTime + 2 hours grace period
  // After this: status → expired, payment → refunded
  final DateTime? deadlineTime;

  // Lease security deposit
  final double? securityDeposit;

  // Terms snapshot — frozen at booking time
  final String? termsSnapshot;

  // Booking mode fields
  final BookingMode bookingMode;
  final int? totalCapacityBooked; // For full post bookings
  final bool isFullVehicleLocked;
  final PostMode? postMode;

  // Route / location snapshot — copied from the slot at booking time
  final String? routeType;       // 'from_to' | 'base_range'
  final String? fromAddress;
  final double? fromLat;
  final double? fromLng;
  final String? toAddress;
  final double? toLat;
  final double? toLng;
  final String? baseAddress;
  final double? baseLat;
  final double? baseLng;
  final double? rangeKm;

  // Trip media — photos/videos uploaded by provider & customer at start/end
  final TripMedia tripMedia;

  Booking({
    required this.id,
    required this.slotId,
    required this.providerId,
    this.providerName,
    this.providerPhone,
    this.providerEmail,
    this.providerAvatar,
    required this.userId,
    required this.price,
    this.seatKey,
    this.userGender,
    this.userName,
    this.userAge,
    this.userPhone,
    this.userEmail,
    required this.status,
    this.otp,
    this.otpVerified = false,
    required this.createdAt,
    this.stripePaymentIntentId,
    this.stripeClientSecret,
    this.countdownEndTime,
    this.paymentHeldInEscrow = false,
    this.tripStartTime,
    this.tripEndTime,
    DateTime? deadlineTime,
    this.securityDeposit,
    this.termsSnapshot,
    this.bookingMode = BookingMode.shared,
    this.totalCapacityBooked,
    this.isFullVehicleLocked = false,
    this.postMode,
    // location
    this.routeType,
    this.fromAddress,
    this.fromLat,
    this.fromLng,
    this.toAddress,
    this.toLat,
    this.toLng,
    this.baseAddress,
    this.baseLat,
    this.baseLng,
    this.rangeKm,
    // trip media
    this.tripMedia = TripMedia.empty,
  }) : deadlineTime = deadlineTime ?? tripEndTime;

  Booking copyWith({
    String? id,
    BookingStatus? status,
    String? otp,
    bool? otpVerified,
    String? providerName,
    String? providerPhone,
    String? providerEmail,
    String? providerAvatar,
    String? userName,
    int? userAge,
    String? userPhone,
    String? userEmail,
    double? price,
    String? stripePaymentIntentId,
    String? stripeClientSecret,
    DateTime? countdownEndTime,
    bool? paymentHeldInEscrow,
    DateTime? tripStartTime,
    DateTime? tripEndTime,
    DateTime? deadlineTime,
    double? securityDeposit,
    String? termsSnapshot,
    BookingMode? bookingMode,
    int? totalCapacityBooked,
    bool? isFullVehicleLocked,
    PostMode? postMode,
    TripMedia? tripMedia,
  }) {
    return Booking(
      id: id ?? this.id,
      slotId: slotId,
      providerId: providerId,
      providerName: providerName ?? this.providerName,
      providerPhone: providerPhone ?? this.providerPhone,
      providerEmail: providerEmail ?? this.providerEmail,
      providerAvatar: providerAvatar ?? this.providerAvatar,
      userId: userId,
      price: price ?? this.price,
      seatKey: seatKey,
      userGender: userGender,
      userName: userName ?? this.userName,
      userAge: userAge ?? this.userAge,
      userPhone: userPhone ?? this.userPhone,
      userEmail: userEmail ?? this.userEmail,
      status: status ?? this.status,
      otp: otp ?? this.otp,
      otpVerified: otpVerified ?? this.otpVerified,
      createdAt: createdAt,
      stripePaymentIntentId: stripePaymentIntentId ?? this.stripePaymentIntentId,
      stripeClientSecret: stripeClientSecret ?? this.stripeClientSecret,
      countdownEndTime: countdownEndTime ?? this.countdownEndTime,
      paymentHeldInEscrow: paymentHeldInEscrow ?? this.paymentHeldInEscrow,
      tripStartTime: tripStartTime ?? this.tripStartTime,
      tripEndTime: tripEndTime ?? this.tripEndTime,
      deadlineTime: deadlineTime ?? this.deadlineTime,
      securityDeposit: securityDeposit ?? this.securityDeposit,
      termsSnapshot: termsSnapshot ?? this.termsSnapshot,
      bookingMode: bookingMode ?? this.bookingMode,
      totalCapacityBooked: totalCapacityBooked ?? this.totalCapacityBooked,
      isFullVehicleLocked: isFullVehicleLocked ?? this.isFullVehicleLocked,
      postMode: postMode ?? this.postMode,
      // preserve location fields unchanged
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
      // trip media
      tripMedia: tripMedia ?? this.tripMedia,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slotId': slotId,
      'providerId': providerId,
      'providerName': providerName,
      'providerPhone': providerPhone,
      'providerEmail': providerEmail,
      'providerAvatar': providerAvatar,
      'userId': userId,
      'price': price,
      'seatKey': seatKey,
      'userGender': userGender?.name,
      'userName': userName,
      'userAge': userAge,
      'userPhone': userPhone,
      'userEmail': userEmail,
      'status': status.dbValue,
      'otp': otp,
      'otpVerified': otpVerified,
      'createdAt': createdAt.toIso8601String(),
      'stripePaymentIntentId': stripePaymentIntentId,
      'stripeClientSecret': stripeClientSecret,
      'countdownEndTime': countdownEndTime?.toIso8601String(),
      'paymentHeldInEscrow': paymentHeldInEscrow,
      'tripStartTime': tripStartTime?.toIso8601String(),
      'tripEndTime': tripEndTime?.toIso8601String(),
      'deadlineTime': deadlineTime?.toIso8601String(),
      'securityDeposit': securityDeposit,
      'termsSnapshot': termsSnapshot,
      'bookingMode': bookingMode.name,
      'totalCapacityBooked': totalCapacityBooked,
      'isFullVehicleLocked': isFullVehicleLocked,
      'postMode': postMode?.dbValue,
      // location snapshot
      'routeType': routeType,
      'fromAddress': fromAddress,
      'fromLat': fromLat,
      'fromLng': fromLng,
      'toAddress': toAddress,
      'toLat': toLat,
      'toLng': toLng,
      'baseAddress': baseAddress,
      'baseLat': baseLat,
      'baseLng': baseLng,
      'rangeKm': rangeKm,
      // trip media
      'tripMedia': tripMedia.toJson(),
    };
  }

  /// Convert to Supabase format with snake_case and JSONB fields
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'post_id': slotId,
      'profile_customer_id': userId,
      'profile_provider_id': providerId,
      'price_snapshot': price,
      'deposit_snapshot': securityDeposit,
      'seat_keys': seatKey != null ? [seatKey] : [],
      'passenger_details': [
        {
          'name': userName,
          'age': userAge,
          'phone': userPhone,
          'email': userEmail,
          'gender': userGender?.name,
        }
      ],
      'metadata': {
        'provider_name': providerName,
        'provider_phone': providerPhone,
        'provider_email': providerEmail,
        'provider_avatar': providerAvatar,
        'stripe_client_secret': stripeClientSecret,
        'countdown_end_time': countdownEndTime?.toIso8601String(),
        'payment_held_in_escrow': paymentHeldInEscrow,
        'terms_snapshot': termsSnapshot,
        'total_capacity_booked': totalCapacityBooked,
        'is_full_vehicle_locked': isFullVehicleLocked,
      },
      'booking_strategy_snapshot': bookingMode == BookingMode.full ? 'full_vehicle' : 'instant',
      'status': status.dbValue,
      'otp_code': otp,
      'otp_verified': otpVerified,
      'payment_gateway_id': stripePaymentIntentId,
      'created_at': createdAt.toIso8601String(),
      // trip schedule
      if (tripStartTime != null) 'start_time': tripStartTime!.toUtc().toIso8601String(),
      if (tripEndTime != null)   'end_time':   tripEndTime!.toUtc().toIso8601String(),
      // deadline_time not sent — DB uses end_time directly
      'trip_media': tripMedia.toJson(),
    };
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    // Support both camelCase (local storage) and snake_case (Supabase)
    // Also handle Supabase's nested jsonb fields
    
    // Extract from metadata if it exists (Supabase format)
    final metadata = json['metadata'] as Map<String, dynamic>?;
    
    // Extract from passenger_details if it exists (Supabase format)
    final passengerDetails = json['passenger_details'];
    final firstPassenger = passengerDetails is Map<String, dynamic> 
        ? passengerDetails 
        : (passengerDetails is List && passengerDetails.isNotEmpty 
            ? passengerDetails[0] as Map<String, dynamic> 
            : null);
    
    // Extract seat_keys (can be string or array)
    final seatKeysRaw = json['seat_keys'];
    final seatKey = json['seatKey'] ?? json['seat_key'] ?? 
        (seatKeysRaw is String ? seatKeysRaw : 
         (seatKeysRaw is List && seatKeysRaw.isNotEmpty ? seatKeysRaw[0] : null));
    
    return Booking(
      id: json['id']?.toString() ?? '', // Handle bigint from Supabase
      slotId: json['slotId'] ?? json['slot_id'] ?? json['post_id'], // Supabase uses post_id
      providerId: json['providerId'] ?? json['provider_id'] ?? json['profile_provider_id'], // Correct field
      providerName: json['providerName'] ?? json['provider_name'] ?? metadata?['provider_name'],
      providerPhone: json['providerPhone'] ?? json['provider_phone'] ?? metadata?['provider_phone'],
      providerEmail: json['providerEmail'] ?? json['provider_email'] ?? metadata?['provider_email'],
      providerAvatar: json['providerAvatar'] ?? json['provider_avatar'] ?? metadata?['provider_avatar'],
      userId: json['userId'] ?? json['user_id'] ?? json['profile_customer_id'], // Correct field
      price: (json['price'] ?? json['price_snapshot'] as num?)?.toDouble() ?? 0,
      seatKey: seatKey,
      userGender: (json['userGender'] ?? json['user_gender'] ?? firstPassenger?['gender']) != null
          ? SeatGender.values.firstWhere((e) => e.name == (json['userGender'] ?? json['user_gender'] ?? firstPassenger?['gender']))
          : null,
      userName: json['userName'] ?? json['user_name'] ?? firstPassenger?['name'],
      userAge: json['userAge'] ?? json['user_age'] ?? firstPassenger?['age'],
      userPhone: json['userPhone'] ?? json['user_phone'] ?? firstPassenger?['phone'],
      userEmail: json['userEmail'] ?? json['user_email'] ?? firstPassenger?['email'],
      status: BookingStatusX.fromString(json['status'] as String?),
      otp: json['otp'] ?? json['otp_code'],
      otpVerified: json['otpVerified'] ?? json['otp_verified'] ?? false,
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
      stripePaymentIntentId: json['stripePaymentIntentId'] ?? json['stripe_payment_intent_id'] ?? json['payment_gateway_id'],
      stripeClientSecret: json['stripeClientSecret'] ?? json['stripe_client_secret'] ?? metadata?['stripe_client_secret'],
      countdownEndTime: (json['countdownEndTime'] ?? json['countdown_end_time'] ?? metadata?['countdown_end_time']) != null 
          ? DateTime.parse(json['countdownEndTime'] ?? json['countdown_end_time'] ?? metadata?['countdown_end_time'])
          : null,
      paymentHeldInEscrow: json['paymentHeldInEscrow'] ?? json['payment_held_in_escrow'] ?? metadata?['payment_held_in_escrow'] ?? false,
      securityDeposit: (json['securityDeposit'] ?? json['security_deposit'] ?? json['deposit_snapshot'] as num?)?.toDouble(),
      termsSnapshot: (json['termsSnapshot'] ?? json['terms_snapshot'] ?? metadata?['terms_snapshot']) as String?,
      bookingMode: (json['bookingMode'] ?? json['booking_mode'] ?? json['booking_strategy_snapshot']) != null
          ? _parseBookingMode(json['bookingMode'] ?? json['booking_mode'] ?? json['booking_strategy_snapshot'])
          : BookingMode.shared,
      totalCapacityBooked: (json['totalCapacityBooked'] ?? json['total_capacity_booked'] ?? metadata?['total_capacity_booked']) as int?,
      isFullVehicleLocked: json['isFullVehicleLocked'] ?? json['is_full_vehicle_locked'] ?? metadata?['is_full_vehicle_locked'] ?? false,
      postMode: (json['postMode'] ?? json['post_mode'] ?? json['post_mode_snapshot']) != null
          ? PostModeExtension.fromDbValue(json['postMode'] ?? json['post_mode'] ?? json['post_mode_snapshot'])
          : null,
      // location snapshot
      routeType: json['routeType'] ?? json['route_type'],
      fromAddress: json['fromAddress'] ?? json['from_address'],
      fromLat: (json['fromLat'] ?? json['from_lat'] as num?)?.toDouble(),
      fromLng: (json['fromLng'] ?? json['from_lng'] as num?)?.toDouble(),
      toAddress: json['toAddress'] ?? json['to_address'],
      toLat: (json['toLat'] ?? json['to_lat'] as num?)?.toDouble(),
      toLng: (json['toLng'] ?? json['to_lng'] as num?)?.toDouble(),
      baseAddress: json['baseAddress'] ?? json['base_address'],
      baseLat: (json['baseLat'] ?? json['base_lat'] as num?)?.toDouble(),
      baseLng: (json['baseLng'] ?? json['base_lng'] as num?)?.toDouble(),
      rangeKm: (json['rangeKm'] ?? json['range_km'] as num?)?.toDouble(),
      // trip schedule — from Supabase start_time/end_time columns
      tripStartTime: (json['tripStartTime'] ?? json['start_time']) != null
          ? DateTime.tryParse(json['tripStartTime'] ?? json['start_time'])?.toLocal()
          : null,
      tripEndTime: (json['tripEndTime'] ?? json['end_time']) != null
          ? DateTime.tryParse(json['tripEndTime'] ?? json['end_time'])?.toLocal()
          : null,
      deadlineTime: (json['deadlineTime'] ?? json['deadline_time']) != null
          ? DateTime.tryParse(json['deadlineTime'] ?? json['deadline_time'])?.toLocal()
          : null,
      // trip media — new unified column (falls back to empty)
      tripMedia: TripMedia.fromJson(
        (json['tripMedia'] ?? json['trip_media']) as Map<String, dynamic>?,
      ),
    );
  }
  
  // ── Deadline helpers ────────────────────────────────────────────────────

  /// Time remaining until deadline. Null if no deadline set.
  Duration? get timeUntilDeadline {
    if (deadlineTime == null) return null;
    final remaining = deadlineTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// True if deadline has passed and booking is still active (should auto-expire)
  bool get isOverdue {
    if (deadlineTime == null) return false;
    return DateTime.now().isAfter(deadlineTime!) && status.isActive;
  }

  /// True if trip has started (now >= tripStartTime)
  bool get tripHasStarted =>
      tripStartTime != null && DateTime.now().isAfter(tripStartTime!);

  /// True if trip has ended (now >= tripEndTime)
  bool get tripHasEnded =>
      tripEndTime != null && DateTime.now().isAfter(tripEndTime!);

  // Helper to parse booking mode from different formats
  static BookingMode _parseBookingMode(dynamic value) {
    if (value == null) return BookingMode.shared;
    final str = value.toString();
    if (str == 'full_vehicle' || str == 'full') return BookingMode.full;
    if (str == 'instant' || str == 'shared') return BookingMode.shared;
    return BookingMode.values.firstWhere(
      (e) => e.name == str,
      orElse: () => BookingMode.shared,
    );
  }
}
