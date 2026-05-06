enum AcceptanceStatus {
  pending, // Provider accepted, waiting for user OTP
  otpVerified, // User verified OTP, payment processing
  paid, // Payment completed
  cancelled, // Cancelled by either party
}

class UserPostAcceptance {
  final String id;
  final String postId;
  final String providerId;
  final String userId;
  final double amount;
  final AcceptanceStatus status;
  final String? otp; // 6-digit OTP
  final DateTime? otpExpiresAt;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final DateTime createdAt;
  final DateTime? paidAt;

  const UserPostAcceptance({
    required this.id,
    required this.postId,
    required this.providerId,
    required this.userId,
    required this.amount,
    required this.status,
    this.otp,
    this.otpExpiresAt,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    required this.createdAt,
    this.paidAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'provider_id': providerId,
      'user_id': userId,
      'amount': amount,
      'status': status.name,
      'otp': otp,
      'otp_expires_at': otpExpiresAt?.toIso8601String(),
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'created_at': createdAt.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
    };
  }

  factory UserPostAcceptance.fromJson(Map<String, dynamic> json) {
    return UserPostAcceptance(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      providerId: json['provider_id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: AcceptanceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AcceptanceStatus.pending,
      ),
      otp: json['otp'] as String?,
      otpExpiresAt: json['otp_expires_at'] != null
          ? DateTime.parse(json['otp_expires_at'] as String)
          : null,
      razorpayOrderId: json['razorpay_order_id'] as String?,
      razorpayPaymentId: json['razorpay_payment_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
    );
  }

  UserPostAcceptance copyWith({
    String? id,
    String? postId,
    String? providerId,
    String? userId,
    double? amount,
    AcceptanceStatus? status,
    String? otp,
    DateTime? otpExpiresAt,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    DateTime? createdAt,
    DateTime? paidAt,
  }) {
    return UserPostAcceptance(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      providerId: providerId ?? this.providerId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      otp: otp ?? this.otp,
      otpExpiresAt: otpExpiresAt ?? this.otpExpiresAt,
      razorpayOrderId: razorpayOrderId ?? this.razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId ?? this.razorpayPaymentId,
      createdAt: createdAt ?? this.createdAt,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}


