# Razorpay Payment Integration with Escrow

## Setup Steps

### 1. Get Razorpay Credentials
1. Sign up at https://razorpay.com/
2. Go to Settings → API Keys
3. Copy your `Key ID` and `Key Secret`
4. Update in `lib/services/razorpay_service.dart`:
   ```dart
   static const String keyId = 'YOUR_RAZORPAY_KEY_ID';
   static const String keySecret = 'YOUR_RAZORPAY_KEY_SECRET';
   ```

### 2. Initialize Razorpay in main.dart

Add to your main() function:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Razorpay
  RazorpayService.instance.initialize();
  
  runApp(MyApp());
}
```

### 3. Payment Flow with Escrow

#### Step 1: User Books a Service
When user confirms booking, initiate payment:

```dart
// In your booking handler
final amount = (slot.price * 100).toInt(); // Convert to paise

RazorpayService.instance.openCheckout(
  amount: amount,
  orderId: booking.id,
  name: userName,
  description: 'Booking for ${slot.fromLocation} to ${slot.toLocation}',
  email: userEmail ?? 'user@example.com',
  contact: userPhone ?? '9999999999',
  onSuccess: (response) {
    // Payment successful - money held in escrow
    final payment = PaymentRepository.instance.createEscrowPayment(
      bookingId: booking.id,
      userId: currentUser.id,
      providerId: slot.providerId,
      amount: slot.price,
      razorpayPaymentId: response.paymentId!,
      razorpayOrderId: response.orderId!,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment held in escrow')),
    );
  },
  onFailure: (response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message}')),
    );
  },
);
```

#### Step 2: Service Completion (OTP Verification)
After provider verifies OTP, release payment:

```dart
// When OTP is verified successfully
final payment = PaymentRepository.instance.getByBookingId(booking.id);
if (payment != null) {
  PaymentRepository.instance.releasePayment(payment.id);
  
  // TODO: Call Razorpay API to transfer money to provider
  // This requires backend integration
}
```

#### Step 3: Refund (if needed)
If booking is cancelled or service not provided:

```dart
final payment = PaymentRepository.instance.getByBookingId(booking.id);
if (payment != null) {
  PaymentRepository.instance.refundPayment(payment.id);
  
  // TODO: Call Razorpay Refund API
  // This requires backend integration
}
```

### 4. Backend Requirements

For production escrow, you need a backend server to:

1. **Create Razorpay Orders**
   ```
   POST https://api.razorpay.com/v1/orders
   ```

2. **Transfer to Provider (after OTP)**
   ```
   POST https://api.razorpay.com/v1/transfers
   ```

3. **Refund to User**
   ```
   POST https://api.razorpay.com/v1/payments/{payment_id}/refund
   ```

### 5. Testing

Use Razorpay test mode:
- Test Key ID: Get from dashboard
- Test cards: https://razorpay.com/docs/payments/payments/test-card-details/

### 6. Payment States

```
User Books → Payment Held (Escrow)
           ↓
    OTP Verified → Payment Released to Provider
           ↓
    OR Cancelled → Payment Refunded to User
```

### 7. Security Notes

- Never expose Key Secret in frontend
- Use backend for sensitive operations
- Implement webhook verification
- Store payment records securely

### 8. Next Steps

1. Set up Razorpay account
2. Add credentials to razorpay_service.dart
3. Initialize in main.dart
4. Test with test credentials
5. Build backend for production escrow
6. Implement webhook handlers
7. Add payment history UI

## Files Created

- `lib/services/razorpay_service.dart` - Razorpay integration
- `lib/services/payment_repository.dart` - Payment state management
- `RAZORPAY_INTEGRATION.md` - This guide
