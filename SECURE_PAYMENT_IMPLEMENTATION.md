# Secure Payment Implementation Guide

## ⚠️ CRITICAL SECURITY ISSUES TO FIX

### 1. **Exposed API Keys**
Your test keys were exposed in chat. **Action required:**
- Go to Razorpay Dashboard → Settings → API Keys
- Click "Regenerate" to get new keys
- Never share keys in chat, docs, or commit to git

### 2. **Client-Side Order Creation** (Current Issue)
```dart
// ❌ INSECURE - Don't do this
final orderId = 'ORD_${DateTime.now().millisecondsSinceEpoch}';
```

**Problem:** Fake order IDs can be used to bypass payment

**Solution:** Create order via Firebase Function
```dart
// ✅ SECURE - Do this instead
final order = await PaymentService.instance.createOrder(
  amount: amountInPaise,
  slotId: widget.slot.id,
  seatKeys: _selectedSeats.toList(),
);
final orderId = order['orderId']; // Real Razorpay order ID
```

### 3. **No Payment Verification** (Current Issue)
```dart
// ❌ INSECURE - Booking confirmed without verification
onSuccess: (response) {
  Navigator.pop(context, BookingConfirmResult(...));
}
```

**Problem:** Malicious users can fake success callback

**Solution:** Verify signature on server before confirming
```dart
// ✅ SECURE - Verify first, then confirm
onSuccess: (response) async {
  try {
    // Verify payment on server
    final verified = await PaymentService.instance.verifyPayment(
      razorpayOrderId: response.orderId!,
      razorpayPaymentId: response.paymentId!,
      razorpaySignature: response.signature!,
    );
    
    if (verified['verified'] == true) {
      // NOW it's safe to confirm booking
      Navigator.pop(context, BookingConfirmResult(...));
    } else {
      // Verification failed - don't confirm
      showError('Payment verification failed');
    }
  } catch (e) {
    // Network error - don't confirm, show retry
    showError('Verification failed. Please contact support.');
  }
}
```

## Complete Secure Flow

### Step 1: Update booking_confirm_sheet.dart

Replace the payment section with:

```dart
// Calculate amount
final totalAmount = _calculateTotalPrice();
final amountInPaise = (totalAmount * 100).toInt();

final currentUser = AuthRepository.instance.currentUser;
if (currentUser == null) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Please login to continue')),
  );
  return;
}

// Show loading
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => const Center(
    child: CircularProgressIndicator(),
  ),
);

try {
  // 1. Create order on server (SECURE)
  final order = await PaymentService.instance.createOrder(
    amount: amountInPaise,
    receipt: 'booking_${DateTime.now().millisecondsSinceEpoch}',
    notes: {
      'slot_id': widget.slot.id,
      'user_id': currentUser.id,
      'seat_keys': _selectedSeats.join(','),
    },
  );

  if (!context.mounted) return;
  Navigator.pop(context); // Close loading

  // 2. Open Razorpay with server-generated order ID
  RazorpayService.instance.openCheckout(
    amount: order['amount'],
    orderId: order['orderId'], // Real Razorpay order ID
    name: firstForm.nameController.text.trim(),
    description: 'Booking for ${widget.slot.fromLocation ?? widget.slot.baseLocation}',
    email: email.isNotEmpty ? email : 'user@quickohunt.com',
    contact: phone.isNotEmpty ? phone : '9999999999',
    onSuccess: (response) async {
      if (!context.mounted) return;

      // Show verifying dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Verifying payment...'),
            ],
          ),
        ),
      );

      try {
        // 3. Verify payment on server (CRITICAL)
        final verified = await PaymentService.instance.verifyPayment(
          razorpayOrderId: response.orderId!,
          razorpayPaymentId: response.paymentId!,
          razorpaySignature: response.signature!,
        );

        if (!context.mounted) return;
        Navigator.pop(context); // Close verifying dialog

        if (verified['verified'] == true) {
          // 4. Payment verified - NOW confirm booking
          Navigator.pop(
            context,
            BookingConfirmResult(
              seatKey: _selectedSeats.isEmpty ? null : _selectedSeats.first,
              userGender: firstForm.gender,
              userName: firstForm.nameController.text.trim(),
              userAge: age,
              userPhone: phone.isEmpty ? null : phone,
              userEmail: email.isEmpty ? null : email,
            ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Payment verified! Booking confirmed.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Verification failed
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Payment verification failed. Contact support.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        // Network error during verification
        if (!context.mounted) return;
        Navigator.pop(context); // Close verifying dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification error: $e. Please contact support with payment ID: ${response.paymentId}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    },
    onFailure: (response) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${response.message}'),
          backgroundColor: Colors.red,
        ),
      );
    },
  );
} catch (e) {
  // Error creating order
  if (!context.mounted) return;
  Navigator.pop(context); // Close loading

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Failed to create order: $e'),
      backgroundColor: Colors.red,
    ),
  );
}
```

### Step 2: Add Server-Side Amount Validation

In `functions/index.js`, implement Supabase validation:

```javascript
// Add at top
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  functions.config().supabase.url,
  functions.config().supabase.service_key
);

// In createRazorpayOrder function
if (slotId) {
  // Fetch slot from Supabase
  const { data: slot, error } = await supabase
    .from('slots')
    .select('price, seat_layout_id')
    .eq('id', slotId)
    .single();

  if (error || !slot) {
    throw new functions.https.HttpsError(
      'not-found',
      'Slot not found'
    );
  }

  // Calculate expected amount
  let expectedAmount = slot.price * 100; // Convert to paise

  if (seatKeys.length > 0 && slot.seat_layout_id) {
    // Fetch seat prices from layout
    const { data: layout } = await supabase
      .from('seat_layouts')
      .select('cells')
      .eq('id', slot.seat_layout_id)
      .single();

    if (layout) {
      expectedAmount = seatKeys.reduce((total, key) => {
        const cell = layout.cells[key];
        return total + (cell?.price || 0) * 100;
      }, 0);
    }
  }

  // Verify amount matches
  if (Math.abs(expectedAmount - amount) > 1) { // Allow 1 paise tolerance
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Amount mismatch. Expected: ${expectedAmount}, Got: ${amount}`
    );
  }
}
```

### Step 3: Configure Supabase in Firebase

```bash
firebase functions:config:set supabase.url="YOUR_SUPABASE_URL"
firebase functions:config:set supabase.service_key="YOUR_SUPABASE_SERVICE_KEY"
```

### Step 4: Set Up Webhook

1. Deploy functions: `firebase deploy --only functions`
2. Get webhook URL from Firebase Console
3. Go to Razorpay Dashboard → Settings → Webhooks
4. Add webhook URL: `https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/razorpayWebhook`
5. Select events: `payment.captured`, `payment.failed`, `refund.created`
6. Copy webhook secret
7. Configure: `firebase functions:config:set razorpay.webhook_secret="YOUR_SECRET"`

## Testing Checklist

- [ ] Order created via Firebase Function (not client)
- [ ] Payment verified before booking confirmed
- [ ] Amount validated on server
- [ ] Webhook handles missed payments
- [ ] Error handling for network failures
- [ ] Retry mechanism for verification failures
- [ ] Support contact info shown on errors

## Security Checklist

- [ ] API keys regenerated after exposure
- [ ] Keys stored in Firebase config (not code)
- [ ] Signature verification implemented
- [ ] Amount validation on server
- [ ] User authentication required
- [ ] Webhook signature verified
- [ ] Error messages don't expose internals

## Production Readiness

- [ ] Replace test keys with live keys
- [ ] Enable Firebase Blaze plan
- [ ] Set up monitoring/alerts
- [ ] Test refund flow
- [ ] Document support procedures
- [ ] Set up payment reconciliation
