# Stripe Escrow - Quick Start Guide

## 🚀 Deploy in 3 Steps

### Step 1: Install Stripe Package
```bash
cd functions
npm install stripe
```

### Step 2: Deploy Functions
```bash
firebase deploy --only functions
```

Wait for deployment to complete. You'll see URLs like:
```
✔  functions[createBooking]: https://YOUR_PROJECT.cloudfunctions.net/createBooking
✔  functions[verifyOtp]: https://YOUR_PROJECT.cloudfunctions.net/verifyOtp
✔  functions[autoRefundExpired]: Scheduled function deployed
```

### Step 3: Update Backend URL

Copy your project URL and update `lib/services/stripe_service.dart` line 15:

**Before:**
```dart
static const String backendUrl = 'YOUR_BACKEND_URL';
```

**After:**
```dart
static const String backendUrl = 'https://YOUR_PROJECT.cloudfunctions.net';
```

## ✅ That's It!

Your escrow system is now live and ready to use.

## 🧪 Test It

### 1. Create a Test Booking

```dart
final bookingData = await StripeService.instance.createBooking(
  userId: 'test_user',
  providerId: 'test_provider',
  postId: 'test_post',
  amount: 10000, // $100.00
  currency: 'usd',
  commissionAmount: 1500, // $15 commission
  countdownHours: 1, // 1 hour for testing
);
```

### 2. Pay with Test Card

- **Card Number**: `4242 4242 4242 4242`
- **Expiry**: Any future date (e.g., 12/25)
- **CVV**: Any 3 digits (e.g., 123)

### 3. Check OTP in Logs

```bash
firebase functions:log
```

Look for: `OTP for booking xxx: 123456`

### 4. Test Two Scenarios

**Scenario A: Provider Enters OTP**
- Enter OTP before timer expires
- Money released to provider
- Status: "completed"

**Scenario B: Timer Expires**
- Don't enter OTP
- Wait for timer to reach 00:00:00
- Money auto-refunded to user
- Status: "refunded"

## 📊 Monitor in Stripe Dashboard

- **Payments**: https://dashboard.stripe.com/test/payments
- **Transfers**: https://dashboard.stripe.com/test/transfers
- **Refunds**: https://dashboard.stripe.com/test/refunds

## 🔧 Common Issues

### "Function not found"
- Make sure you deployed: `firebase deploy --only functions`
- Check function names match exactly

### "Payment fails"
- Use test card: `4242 4242 4242 4242`
- Check amount is > 0
- Check Stripe keys are correct

### "OTP verification fails"
- Check OTP is exactly 6 digits
- Check timer hasn't expired
- Check booking status is "pending"

### "Auto-refund not working"
- Wait 1-2 minutes after timer expires
- Check Firebase logs: `firebase functions:log`
- Verify Cloud Scheduler is enabled

## 📱 Integrate in Your App

### When User Books a Post

```dart
// In your booking flow
final success = await _createBookingWithEscrow(
  postId: post.id,
  providerId: post.providerId,
  amount: post.price * 100, // Convert to cents
);

if (success) {
  // Navigate to booking details screen
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => BookingDetailsScreen(
        bookingId: bookingId,
        paymentIntentId: paymentIntentId,
        countdownEndTime: countdownEndTime,
        amount: amount,
        isProvider: false,
      ),
    ),
  );
}
```

### When Provider Views Booking

```dart
// Show booking details with OTP entry
BookingDetailsScreen(
  bookingId: booking.id,
  paymentIntentId: booking.paymentIntentId,
  countdownEndTime: booking.countdownEndTime,
  amount: booking.amount,
  isProvider: true, // Shows OTP entry field
)
```

## 🎯 Production Checklist

Before going live:

- [ ] Complete Stripe account verification
- [ ] Get live API keys (pk_live_..., sk_live_...)
- [ ] Replace test keys with live keys
- [ ] Test with real card (small amount)
- [ ] Set up Stripe Connect for providers
- [ ] Configure webhook endpoints
- [ ] Set appropriate countdown duration (24-48 hours)
- [ ] Set commission rate (10-20%)
- [ ] Test refund flow
- [ ] Monitor first transactions

## 📚 Full Documentation

- **Complete Flow**: See `STRIPE_ESCROW_FLOW.md`
- **Detailed Setup**: See `STRIPE_ESCROW_SETUP.md`
- **Status**: See `STRIPE_READY.md`

## 🆘 Need Help?

Check the logs:
```bash
# Firebase function logs
firebase functions:log

# Specific function
firebase functions:log --only createBooking
```

Check Stripe dashboard:
- https://dashboard.stripe.com/test/logs

## 🎉 You're Ready!

Your escrow payment system is configured and ready to deploy. Just run the 3 commands above and you're live!

