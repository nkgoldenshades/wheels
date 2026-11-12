# Secure Payment Integration - Complete Setup

## What Changed?

**Before (Insecure):**
- ❌ Order ID generated in app
- ❌ Key secret in app code
- ❌ No signature verification
- ❌ Booking confirmed on client-side

**After (Secure):**
- ✅ Order created on Firebase server
- ✅ Key secret stays on server
- ✅ Signature verified on server
- ✅ Booking confirmed only after verification

## Setup Steps:

### 1. Install Dependencies

```bash
flutter pub get
cd functions
npm install
```

### 2. Configure Razorpay Keys in Firebase

```bash
firebase functions:config:set razorpay.key_id="YOUR_KEY_ID_HERE"
firebase functions:config:set razorpay.key_secret="YOUR_KEY_SECRET_HERE"
firebase functions:config:set razorpay.webhook_secret="YOUR_WEBHOOK_SECRET_HERE"
```

⚠️ **IMPORTANT:** 
- Get fresh keys from Razorpay Dashboard → Settings → API Keys
- NEVER commit keys to git or share in chat
- Use test keys for development, live keys for production

### 3. Deploy Firebase Functions

```bash
firebase deploy --only functions
```

### 4. Update Flutter App

The app now uses `PaymentService` which calls Firebase Functions:

```dart
// 1. Create order (server-side)
final order = await PaymentService.instance.createOrder(
  amount: 10000, // ₹100 in paise
);

// 2. Open Razorpay with server-generated order_id
RazorpayService.instance.openCheckout(
  orderId: order['orderId'], // Real Razorpay order ID
  ...
);

// 3. Verify payment (server-side)
final verified = await PaymentService.instance.verifyPayment(
  razorpayOrderId: response.orderId,
  razorpayPaymentId: response.paymentId,
  razorpaySignature: response.signature,
);

// 4. Only confirm booking if verified
if (verified['verified'] == true) {
  // Create booking
}
```

## Security Benefits:

1. **Key Secret Protected**
   - Never exposed to app
   - Stays on Firebase server

2. **Signature Verification**
   - Prevents fake payments
   - Server validates authenticity

3. **Amount Validation**
   - Server checks amount
   - Prevents tampering

4. **User Authentication**
   - Functions require Firebase Auth
   - Only logged-in users can pay

## Testing:

1. Run app: `flutter run`
2. Try booking with test card: `4111 1111 1111 1111`
3. Check Firebase Functions logs: `firebase functions:log`

## Production Checklist:

- [ ] Replace test keys with live keys
- [ ] Enable Firebase Blaze plan (pay-as-you-go)
- [ ] Set up Razorpay webhooks
- [ ] Add error monitoring
- [ ] Test refund flow
- [ ] Set up payment reconciliation

## Cost Estimate (Free Tier):

- Firebase Functions: 2M invocations/month FREE
- Typical booking: 2 function calls (create + verify)
- Can handle: 1M bookings/month FREE
- After that: $0.40 per million invocations

## Support:

If payment fails, check:
1. Firebase Functions logs
2. Razorpay dashboard
3. Network connectivity
4. User authentication status
