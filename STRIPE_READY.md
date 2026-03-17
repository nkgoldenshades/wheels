# ✅ Stripe Escrow Payment System - READY TO USE

## What's Been Set Up

### 1. ✅ Stripe Keys Configured
- **Publishable Key**: Added to `lib/services/stripe_service.dart`
- **Secret Key**: Added to `functions/stripe-escrow.js`
- **Status**: Test mode active

### 2. ✅ Flutter App Updated
- Stripe service initialized in `main.dart`
- Escrow methods added to `StripeService`
- Booking details screen created with countdown timer
- OTP verification UI ready

### 3. ✅ Backend Functions Ready
- `createBooking` - Creates booking with escrow payment
- `verifyOtp` - Verifies OTP and releases funds
- `autoRefundExpired` - Auto-refunds expired bookings
- `refundPayment` - Manual refund (admin)
- `releaseFunds` - Manual release (admin)

### 4. ✅ Files Created/Updated

**Flutter Files:**
- `lib/services/stripe_service.dart` - Updated with your keys
- `lib/main.dart` - Added Stripe initialization
- `lib/screens/booking/booking_details_screen.dart` - New booking screen

**Backend Files:**
- `functions/stripe-escrow.js` - All escrow functions
- `functions/index.js` - Exports added

**Documentation:**
- `STRIPE_ESCROW_FLOW.md` - Complete flow diagram
- `STRIPE_ESCROW_SETUP.md` - Detailed setup guide
- `STRIPE_READY.md` - This file

## Next Steps to Deploy

### Step 1: Install Stripe Package in Functions

```bash
cd functions
npm install stripe
```

### Step 2: Deploy Backend Functions

```bash
firebase deploy --only functions
```

This will deploy:
- `createBooking`
- `verifyOtp`
- `autoRefundExpired` (scheduled function)
- `refundPayment`
- `releaseFunds`

### Step 3: Update Backend URL

After deployment, you'll get URLs like:
```
https://YOUR_PROJECT.cloudfunctions.net/createBooking
https://YOUR_PROJECT.cloudfunctions.net/verifyOtp
```

Update `lib/services/stripe_service.dart` line 15:
```dart
static const String backendUrl = 'https://YOUR_PROJECT.cloudfunctions.net';
```

### Step 4: Set Up Stripe Connect (For Providers)

Providers need Stripe Connect accounts to receive payments.

**For Testing:**
1. Go to https://dashboard.stripe.com/test/connect/accounts
2. Click "Add account"
3. Fill in test details
4. Copy account ID (starts with `acct_`)
5. Save to provider's profile

**For Production:**
Use Stripe Connect Onboarding (see STRIPE_ESCROW_SETUP.md)

### Step 5: Test the Flow

1. **Create a booking:**
```dart
final bookingData = await StripeService.instance.createBooking(
  userId: 'user_123',
  providerId: 'provider_456',
  postId: 'post_789',
  amount: 10000, // $100.00 in cents
  currency: 'usd',
  commissionAmount: 1500, // $15.00 commission
  countdownHours: 1, // 1 hour for testing
);
```

2. **Pay with test card:**
   - Card: `4242 4242 4242 4242`
   - Expiry: Any future date
   - CVV: Any 3 digits

3. **Provider enters OTP:**
   - OTP will be in function logs (for testing)
   - In production, send via SMS/notification

4. **Wait for timer or enter OTP:**
   - If OTP entered → Money released to provider
   - If timer expires → Money refunded to user

## How the Escrow Flow Works

```
USER BOOKS POST
    ↓
Pays $100 via Stripe
    ↓
Money held in YOUR Stripe account (escrow)
    ↓
Countdown timer starts (e.g., 24 hours)
    ↓
    ├─→ PROVIDER ENTERS OTP (before timer)
    │       ↓
    │   Transfer $85 to provider
    │   Keep $15 commission
    │   Status: "completed"
    │
    └─→ TIMER EXPIRES (no OTP)
            ↓
        Refund $100 to user
        Status: "refunded"
```

## Configuration Options

### Countdown Duration
In your booking creation:
```dart
countdownHours: 24,  // 24 hours
countdownHours: 48,  // 48 hours
countdownHours: 1,   // 1 hour (testing)
```

### Commission Rate
```dart
commissionAmount: (amount * 0.15).toInt(), // 15%
commissionAmount: (amount * 0.10).toInt(), // 10%
commissionAmount: (amount * 0.20).toInt(), // 20%
```

### Auto-Refund Schedule
In `functions/stripe-escrow.js` line 158:
```javascript
.schedule('every 1 minutes')  // Check every minute
.schedule('every 5 minutes')  // Check every 5 minutes
```

## Testing Checklist

- [ ] Deploy functions to Firebase
- [ ] Update backendUrl in stripe_service.dart
- [ ] Create test booking
- [ ] Pay with test card
- [ ] Verify countdown timer works
- [ ] Test OTP verification (success case)
- [ ] Test timer expiry (refund case)
- [ ] Check Stripe dashboard for payments/transfers
- [ ] Check Firebase logs for function execution

## Stripe Dashboard Links

- **Test Payments**: https://dashboard.stripe.com/test/payments
- **Test Transfers**: https://dashboard.stripe.com/test/transfers
- **Test Refunds**: https://dashboard.stripe.com/test/refunds
- **Connect Accounts**: https://dashboard.stripe.com/test/connect/accounts
- **API Keys**: https://dashboard.stripe.com/test/apikeys

## Support & Documentation

- **Stripe Docs**: https://stripe.com/docs
- **Stripe Connect**: https://stripe.com/docs/connect
- **Firebase Functions**: https://firebase.google.com/docs/functions

## Security Notes

✅ Secret keys are only in backend (never in Flutter app)
✅ All sensitive operations on server-side
✅ OTP is single-use and time-limited
✅ Server time used for countdown (not device time)
✅ Payment amounts validated on backend
✅ Webhook signatures verified

## Going Live

When ready for production:

1. Complete Stripe account verification
2. Get live keys from https://dashboard.stripe.com/apikeys
3. Replace test keys with live keys:
   - `pk_live_...`
   - `sk_live_...`
4. Test with real cards (small amounts)
5. Enable in production
6. Monitor first transactions closely

## Troubleshooting

**Functions not deploying?**
- Check `npm install stripe` was run
- Check Firebase billing is enabled (Blaze plan required)

**Payment fails?**
- Check test card number is correct
- Check amount is > 0
- Check Stripe keys are correct

**OTP verification fails?**
- Check OTP matches exactly
- Check timer hasn't expired
- Check booking status is "pending"

**Auto-refund not working?**
- Check Cloud Scheduler is enabled in Firebase
- Check function logs for errors
- Verify Firestore query is correct

## Current Status

🟢 **READY TO DEPLOY**

All code is written and configured. Just need to:
1. Run `npm install stripe` in functions folder
2. Deploy functions
3. Update backendUrl
4. Test!

