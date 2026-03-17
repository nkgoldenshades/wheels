import 'seat_layout.dart';

enum BookingStatus { pending, accepted, completed, rejected }

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
    };
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'],
      slotId: json['slotId'],
      providerId: json['providerId'],
      providerName: json['providerName'],
      providerPhone: json['providerPhone'],
      providerEmail: json['providerEmail'],
      providerAvatar: json['providerAvatar'],
      userId: json['userId'],
      price: (json['price'] as num?)?.toDouble() ?? 0,
      seatKey: json['seatKey'],
      userGender: json['userGender'] != null
          ? SeatGender.values.firstWhere((e) => e.name == json['userGender'])
          : null,
      userName: json['userName'],
      userAge: json['userAge'],
      userPhone: json['userPhone'],
      userEmail: json['userEmail'],
      status: BookingStatus.values.firstWhere((e) => e.name == json['status']),
      otp: json['otp'],
      otpVerified: json['otpVerified'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
