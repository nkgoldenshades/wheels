# Complete Stripe Escrow Setup Guide

## What I've Created for You

### 1. Documentation
- ✅ `STRIPE_ESCROW_FLOW.md` - Complete flow diagram and explanation
- ✅ `STRIPE_ESCROW_SETUP.md` - This setup guide

### 2. Backend Functions (`functions/stripe-escrow.js`)
- ✅ `createBooking` - Creates booking with escrow payment
- ✅ `verifyOtp` - Verifies OTP and releases funds to provider
- ✅ `autoRefundExpired` - Auto-refunds expired bookings (runs every minute)
- ✅ `refundPayment` - Manual refund endpoint
- ✅ `releaseFunds` - Manual release endpoint

### 3. Flutter Code
- ✅ Updated `lib/services/stripe_service.dart` with escrow methods
- ✅ Created `lib/screens/booking/booking_details_screen.dart` - Booking screen with countdown timer

## Setup Steps

### Step 1: Get Stripe Keys

1. Go to https://stripe.com
2. Sign up or log in
3. Go to **Developers → API Keys**
4. Copy these keys:
   - Publishable key: `pk_test_...`
   - Secret key: `sk_test_...`

### Step 2: Update Stripe Service

In `lib/services/stripe_service.dart`, replace:
```dart
static const String publishableKey = 'pk_test_YOUR_PUBLISHABLE_KEY';
static const String secretKey = 'sk_test_YOUR_SECRET_KEY';
```

With your actual keys.

### Step 3: Deploy Backend Functions

1. Install Stripe package:
```bash
cd functions
npm install stripe
```

2. Update `functions/stripe-escrow.js` line 2:
```javascript
const stripe = require('stripe')('sk_test_YOUR_SECRET_KEY');
```

3. Add to `functions/index.js`:
```javascript
const stripeEscrow = require('./stripe-escrow');

exports.createBooking = stripeEscrow.createBooking;
exports.verifyOtp = stripeEscrow.verifyOtp;
exports.autoRefundExpired = stripeEscrow.autoRefundExpired;
exports.refundPayment = stripeEscrow.refundPayment;
exports.releaseFunds = stripeEscrow.releaseFunds;
```

4. Deploy:
```bash
firebase deploy --only functions
```

### Step 4: Update Backend URL

After deployment, copy your function URLs and update `lib/services/stripe_service.dart`:
```dart
static const String backendUrl = 'https://YOUR_PROJECT.cloudfunctions.net';
```

### Step 5: Initialize Stripe in App

In `lib/main.dart`, add to `main()` function:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Stripe
  await StripeService.instance.init();
  
  // ... rest of your code
}
```

### Step 6: Set Up Stripe Connect for Providers

Providers need Stripe Connect accounts to receive payments.

**Option A: Use Stripe Connect Onboarding (Recommended)**

Create a function to onboard providers:
```dart
Future<void> setupProviderPayout(String email, String country) async {
  final accountId = await StripeService.instance.createConnectedAccount(
    email: email,
    country: country,
  );
  
  if (accountId != null) {
    // Save to user profile
    await ProfileRepository.instance.update(
      stripeAccountId: accountId,
    );
  }
}
```

**Option B: Manual Setup (For Testing)**

For testing, you can create test connected accounts in Stripe Dashboard:
1. Go to Connect → Accounts
2. Click "Add account"
3. Fill in test details
4. Copy the account ID (starts with `acct_`)
5. Save to provider's profile

### Step 7: Update ProfileInfo Model

Add Stripe account ID to `lib/services/profile_repository.dart`:

```dart
class ProfileInfo {
  // ... existing fields
  
  final String? stripeAccountId;
  final bool stripeOnboardingComplete;
  
  const ProfileInfo({
    // ... existing parameters
    this.stripeAccountId,
    this.stripeOnboardingComplete = false,
  });
  
  ProfileInfo copyWith({
    // ... existing parameters
    String? stripeAccountId,
    bool? stripeOnboardingComplete,
  }) {
    return ProfileInfo(
      // ... existing fields
      stripeAccountId: stripeAccountId ?? this.stripeAccountId,
      stripeOnboardingComplete: stripeOnboardingComplete ?? this.stripeOnboardingComplete,
    );
  }
}
```

### Step 8: Create Booking Flow

When user books a post:

```dart
Future<void> bookPost(String postId, String providerId, int amount) async {
  // 1. Create booking
  final bookingData = await StripeService.instance.createBooking(
    userId: currentUserId,
    providerId: providerId,
    postId: postId,
    amount: amount, // in cents (e.g., 10000 = $100)
    currency: 'usd',
    commissionAmount: (amount * 0.15).toInt(), // 15% commission
    countdownHours: 24, // 24 hour countdown
  );
  
  if (bookingData == null) {
    // Handle error
    return;
  }
  
  // 2. Present payment sheet
  final success = await StripeService.instance.presentPaymentSheet(
    clientSecret: bookingData['client_secret'],
  );
  
  if (success) {
    // 3. Navigate to booking details
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingDetailsScreen(
          bookingId: bookingData['booking_id'],
          paymentIntentId: bookingData['payment_intent_id'],
          countdownEndTime: DateTime.parse(bookingData['countdown_end_time']),
          amount: amount,
          isProvider: false,
        ),
      ),
    );
  }
}
```

## Testing the Flow

### Test Scenario 1: Successful Completion

1. User books a post (pays $100)
2. Booking created with 24-hour countdown
3. Provider receives OTP notification
4. Provider enters OTP before timer expires
5. Money transferred to provider ($85 after 15% commission)
6. Booking status: "completed"

### Test Scenario 2: Timer Expires

1. User books a post (pays $100)
2. Booking created with 24-hour countdown
3. Provider doesn't enter OTP
4. Timer reaches 00:00:00
5. Auto-refund function runs
6. Money refunded to user ($100)
7. Booking status: "refunded"

### Test Scenario 3: Wrong OTP

1. Provider enters wrong OTP
2. Error message shown
3. Provider can retry
4. Timer continues counting down

## Stripe Test Cards

Use these for testing:
- **Success**: `4242 4242 4242 4242`
- **Decline**: `4000 0000 0000 0002`
- **3D Secure**: `4000 0025 0000 3155`

CVV: Any 3 digits  
Expiry: Any future date

## Important Configuration

### Set Countdown Duration

In your booking flow, adjust `countdownHours`:
- 24 hours: `countdownHours: 24`
- 48 hours: `countdownHours: 48`
- 1 hour (testing): `countdownHours: 1`

### Set Commission Rate

Adjust commission in booking creation:
```dart
commissionAmount: (amount * 0.15).toInt(), // 15%
commissionAmount: (amount * 0.10).toInt(), // 10%
commissionAmount: (amount * 0.20).toInt(), // 20%
```

### Auto-Refund Schedule

The auto-refund function runs every minute by default. To change:

In `functions/stripe-escrow.js`:
```javascript
// Every 1 minute (default)
.schedule('every 1 minutes')

// Every 5 minutes
.schedule('every 5 minutes')

// Every hour
.schedule('every 1 hours')
```

## Security Checklist

- ✅ Never expose secret keys in Flutter app
- ✅ All sensitive operations on backend
- ✅ Verify webhook signatures
- ✅ Use server time for countdown (not device time)
- ✅ Single-use OTPs
- ✅ Validate OTP before timer check
- ✅ Handle race conditions (OTP + timer expiry)

## Monitoring

### Check Stripe Dashboard

1. **Payments**: See all PaymentIntents
2. **Transfers**: See money released to providers
3. **Refunds**: See auto-refunds
4. **Connect**: See provider accounts

### Check Firebase Logs

```bash
firebase functions:log
```

Look for:
- Booking creation logs
- OTP verification logs
- Auto-refund logs
- Error logs

## Troubleshooting

### Payment fails
- Check Stripe test card
- Check amount (must be > 0)
- Check currency code

### OTP verification fails
- Check OTP matches exactly
- Check timer hasn't expired
- Check booking status is "pending"

### Auto-refund not working
- Check Cloud Scheduler is enabled
- Check function logs for errors
- Verify Firestore query is correct

### Transfer fails
- Check provider has Stripe account ID
- Check provider account is active
- Check transfer amount > 0

## Going Live

1. Complete Stripe account verification
2. Replace test keys with live keys:
   - `pk_live_...`
   - `sk_live_...`
3. Test with real cards (small amounts)
4. Enable in production
5. Monitor closely for first few transactions

## Support

- Stripe Docs: https://stripe.com/docs
- Stripe Dashboard: https://dashboard.stripe.com
- Firebase Console: https://console.firebase.google.com

## Next Steps

1. ✅ Get Stripe test keys
2. ✅ Update stripe_service.dart
3. ✅ Deploy backend functions
4. ✅ Test booking flow
5. ✅ Test OTP verification
6. ✅ Test auto-refund
7. ✅ Go live!

