/// Represents a credit purchase or usage transaction
class CreditTransaction {
  final String id;
  final String userId;
  final String type; // 'purchase' | 'usage' | 'bonus' | 'refund'
  final int creditsChanged; // Positive for purchase/bonus, negative for usage
  final double? amountUSD; // For purchases
  final String? description;
  final String? relatedBookingId; // For usage/refund transactions
  final String? paymentGatewayId; // Stripe/Razorpay transaction ID
  final DateTime createdAt;
  final Map<String, dynamic>? metadata; // Additional data (e.g., Gemini usage)

  const CreditTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.creditsChanged,
    this.amountUSD,
    this.description,
    this.relatedBookingId,
    this.paymentGatewayId,
    required this.createdAt,
    this.metadata,
  });

  factory CreditTransaction.fromJson(Map<String, dynamic> json) {
    return CreditTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      creditsChanged: json['credits_changed'] as int,
      amountUSD: (json['amount_usd'] as num?)?.toDouble(),
      description: json['description'] as String?,
      relatedBookingId: json['related_booking_id'] as String?,
      paymentGatewayId: json['payment_gateway_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'type': type,
    'credits_changed': creditsChanged,
    'amount_usd': amountUSD,
    'description': description,
    'related_booking_id': relatedBookingId,
    'payment_gateway_id': paymentGatewayId,
    'created_at': createdAt.toIso8601String(),
    'metadata': metadata,
  };

  /// Human-readable description of transaction
  String get displayName {
    switch (type) {
      case 'purchase':
        return 'Credit Purchase';
      case 'usage':
        return 'Used for message';
      case 'bonus':
        return 'Sign-up bonus';
      case 'refund':
        return 'Refunded credits';
      default:
        return 'Transaction';
    }
  }
}
