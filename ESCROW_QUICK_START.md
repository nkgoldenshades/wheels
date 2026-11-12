# Escrow System - Quick Start Guide

## 🎯 For Developers

### Payment Flow (3 Steps)

#### 1️⃣ User Books & Pays
```dart
// In booking_confirm_sheet.dart
final bookingResult = await StripeService.instance.processPayment(
  amount: amountInPaise,
  currency: 'inr',
  providerId: widget.providerId,
  userId: currentUser.id,
  applicationFee: commissionAmount,
  slotId: widget.slot.id,
);

// Create local booking with escrow data
final localBooking = await BookingRepository.instance.createBooking(
  // ... booking details
  stripePaymentIntentId: paymentIntentId,
  countdownEndTime: countdownEnd,
  otp: otp,
);
```

#### 2️⃣ Provider Verifies OTP
```dart
// In main.dart (RequestsPage)
final success = await StripeService.instance.verifyOtpAndRelease(
  bookingId: b.id,
  otp: otpText,
);

if (success) {
  await BookingRepository.instance.updateBookingAfterPayment(
    bookingId: b.id,
    status: BookingStatus.completed,
    otpVerified: true,
  );
}
```

#### 3️⃣ Auto-Refund (Backend)
```javascript
// Firebase Cloud Function runs every minute
exports.autoRefundExpired = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    // Find expired bookings
    // Cancel/refund PaymentIntent
    // Update booking status
  });
```

---

## 🔑 Key Components

### Models
- **Booking** (`lib/models/booking.dart`)
  - `stripePaymentIntentId` - Stripe payment ID
  - `countdownEndTime` - Auto-refund deadline
  - `paymentHeldInEscrow` - Boolean flag
  - `otp` - 6-digit verification code

### Services
- **StripeService** (`lib/services/stripe_service.dart`)
  - `processPayment()` - Create escrow payment
  - `verifyOtpAndRelease()` - Release funds to provider
  
- **BookingRepository** (`lib/services/booking_repository.dart`)
  - `createBooking()` - Save booking with escrow data
  - `updateBookingAfterPayment()` - Update after OTP verification

### Backend
- **Firebase Functions** (`functions/stripe-escrow.js`)
  - `createBooking` - Create PaymentIntent with manual capture
  - `verifyOtp` - Capture payment & transfer to provider
  - `autoRefundExpired` - Scheduled refund job

---

## 🧪 Testing

### Test Cards (Stripe)
```
Success: 4242 4242 4242 4242
Decline: 4000 0000 0000 0002
3D Secure: 4000 0025 0000 3155
```

### Test Flow
1. Book a ride with test card
2. Check OTP in user's Requests tab
3. Enter OTP in provider's Requests tab
4. Verify funds released

---

## 📊 Data Flow

```
User Payment
    ↓
Stripe PaymentIntent (manual capture)
    ↓
Firebase Function creates booking
    ↓
App saves local booking with escrow data
    ↓
Provider enters OTP
    ↓
Firebase Function captures & transfers
    ↓
App updates booking to completed
```

---

## ⚙️ Configuration

### Environment Variables (Firebase)
```bash
firebase functions:config:set \
  stripe.secret_key="sk_test_..." \
  supabase.url="https://..." \
  supabase.service_key="eyJ..."
```

### App Configuration
```dart
// lib/services/stripe_service.dart
static const String publishableKey = 'pk_test_...';
static const String backendUrl = 'https://us-central1-...';
```

---

## 🚨 Important Notes

1. **Always check `mounted`** before using `BuildContext` after async calls
2. **OTP is 6 digits** - validate length before submission
3. **Countdown is 1 hour** - configurable in `createBooking` call
4. **Commission is 10%** - deducted before transfer to provider
5. **Auto-refund runs every minute** - ensure scheduled function is enabled

---

## 📱 UI States

### User View
- **Pending**: Shows OTP, countdown, "Payment Held in Escrow"
- **Completed**: Shows "Trip completed"

### Provider View
- **Pending**: Shows OTP input field, "Verify" button
- **Completed**: Shows "OTP verified" badge

---

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| Payment succeeds but no booking | Check Firebase logs |
| OTP verification fails | Verify OTP matches, countdown not expired |
| Auto-refund not working | Check scheduled function enabled |
| BuildContext errors | Add `if (!mounted) return;` checks |

---

## 📚 Related Files

- `lib/models/booking.dart` - Booking model with escrow fields
- `lib/services/booking_repository.dart` - Booking CRUD operations
- `lib/services/stripe_service.dart` - Stripe integration
- `lib/widgets/booking_confirm_sheet.dart` - Payment UI
- `lib/screens/booking/booking_details_screen.dart` - Countdown screen
- `lib/main.dart` (RequestsPage) - OTP verification UI
- `functions/stripe-escrow.js` - Backend escrow logic

---

**Ready to use! All components are integrated and tested.** ✅
