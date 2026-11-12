import 'package:flutter/foundation.dart';

enum PaymentStatus {
  pending,
  held, // Money held in escrow
  released, // Released to provider
  refunded, // Refunded to user
  failed,
}

class Payment {
  final String id;
  final String bookingId;
  final String userId;
  final String providerId;
  final double amount;
  final PaymentStatus status;
  final String? razorpayPaymentId;
  final String? razorpayOrderId;
  final DateTime createdAt;
  final DateTime? releasedAt;
  final DateTime? refundedAt;

  Payment({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.providerId,
    required this.amount,
    required this.status,
    this.razorpayPaymentId,
    this.razorpayOrderId,
    required this.createdAt,
    this.releasedAt,
    this.refundedAt,
  });

  Payment copyWith({
    PaymentStatus? status,
    String? razorpayPaymentId,
    DateTime? releasedAt,
    DateTime? refundedAt,
  }) {
    return Payment(
      id: id,
      bookingId: bookingId,
      userId: userId,
      providerId: providerId,
      amount: amount,
      status: status ?? this.status,
      razorpayPaymentId: razorpayPaymentId ?? this.razorpayPaymentId,
      razorpayOrderId: razorpayOrderId,
      createdAt: createdAt,
      releasedAt: releasedAt ?? this.releasedAt,
      refundedAt: refundedAt ?? this.refundedAt,
    );
  }
}

class PaymentRepository {
  static final PaymentRepository instance = PaymentRepository._();
  PaymentRepository._();

  final ValueNotifier<List<Payment>> _payments = ValueNotifier([]);

  ValueListenable<List<Payment>> get paymentsListenable => _payments;
  List<Payment> get allPayments => List.unmodifiable(_payments.value);

  /// Create a payment in escrow (money held)
  Payment createEscrowPayment({
    required String bookingId,
    required String userId,
    required String providerId,
    required double amount,
    required String razorpayPaymentId,
    required String razorpayOrderId,
  }) {
    final payment = Payment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bookingId: bookingId,
      userId: userId,
      providerId: providerId,
      amount: amount,
      status: PaymentStatus.held,
      razorpayPaymentId: razorpayPaymentId,
      razorpayOrderId: razorpayOrderId,
      createdAt: DateTime.now(),
    );

    _payments.value = [..._payments.value, payment];
    return payment;
  }

  /// Release payment to provider (after OTP verification)
  void releasePayment(String paymentId) {
    _payments.value = _payments.value.map((p) {
      if (p.id == paymentId) {
        return p.copyWith(
          status: PaymentStatus.released,
          releasedAt: DateTime.now(),
        );
      }
      return p;
    }).toList();
  }

  /// Refund payment to user
  void refundPayment(String paymentId) {
    _payments.value = _payments.value.map((p) {
      if (p.id == paymentId) {
        return p.copyWith(
          status: PaymentStatus.refunded,
          refundedAt: DateTime.now(),
        );
      }
      return p;
    }).toList();
  }

  /// Get payment by booking ID
  Payment? getByBookingId(String bookingId) {
    try {
      return _payments.value.firstWhere((p) => p.bookingId == bookingId);
    } catch (_) {
      return null;
    }
  }

  /// Get payments for a user
  List<Payment> getUserPayments(String userId) {
    return _payments.value.where((p) => p.userId == userId).toList();
  }

  /// Get payments for a provider
  List<Payment> getProviderPayments(String providerId) {
    return _payments.value.where((p) => p.providerId == providerId).toList();
  }
}



