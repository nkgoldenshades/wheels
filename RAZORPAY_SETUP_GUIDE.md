# Razorpay Payment Integration Setup Guide

## Issue
Booking is failing because Firebase Cloud Functions for Razorpay payment processing are not deployed.

## What's Needed

### 1. Razorpay Account Setup
1. Go to https://razorpay.com/
2. Sign up for a Razorpay account
3. Complete KYC verification (required for live mode)
4. Get your API keys:
   - **Test Keys**: For development (already in code)
     - Key ID: `rzp_test_SMpj1xxJxAcT6K`
     - Key Secret: `PZKW95oZEjcavJ5flTEZVjeU`
   - **Live Keys**: For production (get after KYC)
     - Key ID: `rzp_live_XXXXXXXXXX`
     - Key Secret: `XXXXXXXXXXXXXXXXXX`

### 2. Firebase Functions Setup

#### Install Dependencies
```bash
cd firebase_functions
npm install
```

This will install:
- `firebase-admin`: Firebase Admin SDK
- `firebase-functions`: Cloud Functions SDK
- `razorpay`: Razorpay Node.js SDK (newly added)

#### Configure Razorpay Keys (Optional - for production)
```bash
# Set Razorpay keys as environment variables
firebase functions:config:set razorpay.key_id="rzp_test_SMpj1xxJxAcT6K"
firebase functions:config:set razorpay.key_secret="PZKW95oZEjcavJ5flTEZVjeU"

# For production, use live keys:
# firebase functions:config:set razorpay.key_id="rzp_live_XXXXXXXXXX"
# firebase functions:config:set razorpay.key_secret="XXXXXXXXXXXXXXXXXX"
```

Note: If you don't set these, the functions will use the test keys hardcoded in `index.js`.

#### Deploy Functions
```bash
# Make sure you're in the project root
firebase deploy --only functions

# Or deploy specific functions:
firebase deploy --only functions:createRazorpayOrder,functions:verifyRazorpayPayment
```

### 3. Verify Deployment
After deployment, you should see:
```
✔  functions[createRazorpayOrder(us-central1)] Successful create operation.
✔  functions[verifyRazorpayPayment(us-central1)] Successful create operation.
```

### 4. Test the Integration

#### Test Flow:
1. Open the app
2. Find a slot and click "Book Now"
3. Fill in passenger details
4. Click "Proceed to Payment"
5. Razorpay checkout should open
6. Use test card details:
   - Card: `4111 1111 1111 1111`
   - CVV: Any 3 digits
   - Expiry: Any future date
7. Payment should succeed and booking should be confirmed

## Functions Added

### 1. `createRazorpayOrder`
- **Purpose**: Creates a Razorpay order before opening checkout
- **Called by**: `PaymentService.createOrder()` in Flutter app
- **Parameters**:
  - `amount`: Amount in paise (e.g., 10000 = ₹100)
  - `currency`: Currency code (default: INR)
  - `receipt`: Receipt ID for tracking
  - `notes`: Additional metadata (slot_id, user_id, etc.)
- **Returns**: Order ID, amount, currency, receipt

### 2. `verifyRazorpayPayment`
- **Purpose**: Verifies payment signature after successful payment
- **Called by**: `PaymentService.verifyPayment()` in Flutter app
- **Parameters**:
  - `razorpay_order_id`: Order ID from Razorpay
  - `razorpay_payment_id`: Payment ID from Razorpay
  - `razorpay_signature`: Signature from Razorpay
- **Returns**: Verification status, payment details
- **Security**: Uses HMAC SHA256 to verify signature authenticity

## Security Features

1. **Server-side Order Creation**: Orders are created on the server to prevent amount tampering
2. **Signature Verification**: Payment signatures are verified server-side using Razorpay secret key
3. **Authentication Required**: All functions require Firebase authentication
4. **Amount Validation**: Minimum amount check (₹1 = 100 paise)

## Current Status

### ✅ Completed
- Razorpay Flutter SDK integrated (`razorpay_flutter: ^1.3.7`)
- Payment service created (`lib/services/payment_service.dart`)
- Razorpay service created (`lib/services/razorpay_service.dart`)
- Booking flow integrated with payment
- Firebase Functions code written (`firebase_functions/index.js`)
- Package.json updated with Razorpay dependency

### ⏳ Pending (You Need to Do)
1. Install Firebase Functions dependencies: `cd firebase_functions && npm install`
2. Deploy Firebase Functions: `firebase deploy --only functions`
3. Test payment flow with test cards
4. (Optional) Configure Razorpay keys as environment variables
5. (For production) Get live Razorpay keys after KYC

## Troubleshooting

### Error: "Failed to create order"
- Check if Firebase Functions are deployed
- Check Firebase Console > Functions for errors
- Verify Razorpay keys are correct

### Error: "Payment verification failed"
- Check if `verifyRazorpayPayment` function is deployed
- Check Firebase Functions logs: `firebase functions:log`
- Verify signature is being passed correctly

### Error: "Must be authenticated"
- User must be logged in to create orders/verify payments
- Check if Firebase Auth is working

## Test Cards (Razorpay Test Mode)

### Success
- Card: `4111 1111 1111 1111`
- CVV: Any 3 digits
- Expiry: Any future date

### Failure
- Card: `4000 0000 0000 0002`
- CVV: Any 3 digits
- Expiry: Any future date

## Production Checklist

Before going live:
- [ ] Complete Razorpay KYC verification
- [ ] Get live API keys from Razorpay dashboard
- [ ] Update keys in Firebase Functions config
- [ ] Set `testMode = false` in `lib/services/razorpay_service.dart` (already done)
- [ ] Test with real payment methods
- [ ] Set up webhooks for payment notifications (optional)
- [ ] Configure refund policies
- [ ] Add terms & conditions for payments

## Files Modified

1. `firebase_functions/index.js` - Added Razorpay functions
2. `firebase_functions/package.json` - Added Razorpay dependency
3. `RAZORPAY_SETUP_GUIDE.md` - This guide

## Next Steps

Run these commands:
```bash
# 1. Install dependencies
cd firebase_functions
npm install

# 2. Deploy functions
cd ..
firebase deploy --only functions

# 3. Test the booking flow
```

After deployment, bookings should work!
