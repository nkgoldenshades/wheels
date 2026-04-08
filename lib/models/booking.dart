import 'seat_layout.dart';

enum BookingStatus { pending, accepted, completed, rejected, refunded }

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
  final DateTime? countdownEndTime;
  final bool paymentHeldInEscrow;

  // Lease security deposit
  final double? securityDeposit;

  // Terms snapshot — frozen at booking time
  final String? termsSnapshot;

  // Booking mode fields
  final BookingMode bookingMode;
  final int? totalCapacityBooked; // For full vehicle bookings
  final bool isFullVehicleLocked;

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
    this.securityDeposit,
    this.termsSnapshot,
    this.bookingMode = BookingMode.shared,
    this.totalCapacityBooked,
    this.isFullVehicleLocked = false,
  });

  Booking copyWith({
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
    double? securityDeposit,
    String? termsSnapshot,
    BookingMode? bookingMode,
    int? totalCapacityBooked,
    bool? isFullVehicleLocked,
  }) {
    return Booking(
      id: id,
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
      securityDeposit: securityDeposit ?? this.securityDeposit,
      termsSnapshot: termsSnapshot ?? this.termsSnapshot,
      bookingMode: bookingMode ?? this.bookingMode,
      totalCapacityBooked: totalCapacityBooked ?? this.totalCapacityBooked,
      isFullVehicleLocked: isFullVehicleLocked ?? this.isFullVehicleLocked,
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
      'status': status.name,
      'otp': otp,
      'otpVerified': otpVerified,
      'createdAt': createdAt.toIso8601String(),
      'stripePaymentIntentId': stripePaymentIntentId,
      'stripeClientSecret': stripeClientSecret,
      'countdownEndTime': countdownEndTime?.toIso8601String(),
      'paymentHeldInEscrow': paymentHeldInEscrow,
      'securityDeposit': securityDeposit,
      'termsSnapshot': termsSnapshot,
      'bookingMode': bookingMode.name,
      'totalCapacityBooked': totalCapacityBooked,
      'isFullVehicleLocked': isFullVehicleLocked,
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
      status: BookingStatus.values.firstWhere((e) => e.name == json['status']),
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
    );
  }
  
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
