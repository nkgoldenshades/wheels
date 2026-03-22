# Escrow Payment Flow - Visual Diagram

## 🔄 Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ESCROW PAYMENT SYSTEM                        │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────┐
│     USER     │
│  (Passenger) │
└──────┬───────┘
       │
       │ 1. Selects slot & fills details
       │
       ▼
┌──────────────────────────────┐
│  BookingConfirmSheet         │
│  - Shows total price         │
│  - "Pay & Confirm" button    │
└──────┬───────────────────────┘
       │
       │ 2. Clicks "Pay & Confirm"
       │
       ▼
┌──────────────────────────────┐
│  StripeService               │
│  .processPayment()           │
└──────┬───────────────────────┘
       │
       │ 3. Calls Firebase Function
       │
       ▼
┌──────────────────────────────────────────────────────────────┐
│  Firebase Cloud Function: createBooking                       │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ 1. Create PaymentIntent (manual capture)              │  │
│  │ 2. Generate 6-digit OTP                               │  │
│  │ 3. Calculate countdown (now + 1 hour)                 │  │
│  │ 4. Save to Supabase:                                  │  │
│  │    - stripe_payment_intent_id                         │  │
│  │    - otp                                              │  │
│  │    - countdown_end_time                               │  │
│  │    - status: 'pending'                                │  │
│  │ 5. Return booking details                             │  │
│  └────────────────────────────────────────────────────────┘  │
└──────┬───────────────────────────────────────────────────────┘
       │
       │ 4. Returns: { booking_id, client_secret, otp, countdown }
       │
       ▼
┌──────────────────────────────┐
│  Stripe Payment Sheet        │
│  - User enters card details  │
│  - Payment authorized        │
│  - Money HELD (not captured) │
└──────┬───────────────────────┘
       │
       │ 5. Payment authorized ✓
       │
       ▼
┌──────────────────────────────┐
│  BookingRepository           │
│  .createBooking()            │
│  - Saves locally with:       │
│    • stripePaymentIntentId   │
│    • otp                     │
│    • countdownEndTime        │
│    • paymentHeldInEscrow     │
└──────┬───────────────────────┘
       │
       │ 6. Navigate to BookingDetailsScreen
       │
       ▼
┌──────────────────────────────────────────────────────────────┐
│  BookingDetailsScreen                                         │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  💰 Payment Held in Escrow                            │  │
│  │  🔒 OTP: 123456                                       │  │
│  │  ⏱️  Countdown: 00:59:45                              │  │
│  │  📋 [Copy OTP]                                        │  │
│  │                                                        │  │
│  │  Share this OTP with your provider                    │  │
│  │  Auto-refund if not verified within 1 hour           │  │
│  └────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
       │
       │ 7. User shares OTP with provider
       │
       ▼
┌──────────────┐
│   PROVIDER   │
│   (Driver)   │
└──────┬───────┘
       │
       │ 8. Opens Requests tab (Provider view)
       │
       ▼
┌──────────────────────────────────────────────────────────────┐
│  RequestsPage (Provider View)                                 │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Booking #123456                                       │  │
│  │  Status: Pending                                       │  │
│  │  ─────────────────────────────────────────────────────│  │
│  │  👤 User: Jane Smith                                  │  │
│  │  📞 Contact: +1234567890                              │  │
│  │  ─────────────────────────────────────────────────────│  │
│  │  Enter OTP from user: [______]  [Verify]             │  │
│  └────────────────────────────────────────────────────────┘  │
└──────┬───────────────────────────────────────────────────────┘
       │
       │ 9. Provider enters OTP & clicks "Verify"
       │
       ▼
┌──────────────────────────────┐
│  StripeService               │
│  .verifyOtpAndRelease()      │
└──────┬───────────────────────┘
       │
       │ 10. Calls Firebase Function
       │
       ▼
┌──────────────────────────────────────────────────────────────┐
│  Firebase Cloud Function: verifyOtp                           │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ 1. Validate OTP matches                               │  │
│  │ 2. Check countdown not expired                        │  │
│  │ 3. Capture PaymentIntent (charge card)                │  │
│  │ 4. Calculate transfer amount:                         │  │
│  │    • Total: ₹1000                                     │  │
│  │    • Commission (10%): ₹100                           │  │
│  │    • Provider gets: ₹900                              │  │
│  │ 5. Create Stripe Transfer to provider                │  │
│  │ 6. Update Supabase:                                   │  │
│  │    - status: 'completed'                              │  │
│  │    - otp_verified: true                               │  │
│  │    - stripe_transfer_id                               │  │
│  │ 7. Return success                                     │  │
│  └────────────────────────────────────────────────────────┘  │
└──────┬───────────────────────────────────────────────────────┘
       │
       │ 11. Returns: { success: true, transfer_id }
       │
       ▼
┌──────────────────────────────┐
│  BookingRepository           │
│  .updateBookingAfterPayment()│
│  - status: completed         │
│  - otpVerified: true         │
└──────┬───────────────────────┘
       │
       │ 12. Update UI
       │
       ▼
┌──────────────────────────────────────────────────────────────┐
│  Success Messages                                             │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  PROVIDER:                                             │  │
│  │  ✅ Payment released! Funds transferred to account    │  │
│  │                                                        │  │
│  │  USER:                                                 │  │
│  │  ✅ Trip completed                                     │  │
│  └────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════

                    ALTERNATIVE PATH: AUTO-REFUND

┌──────────────────────────────────────────────────────────────┐
│  Firebase Scheduled Function (runs every minute)              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ 1. Find bookings where:                               │  │
│  │    - status = 'pending'                               │  │
│  │    - countdown_end_time < NOW                         │  │
│  │                                                        │  │
│  │ 2. For each expired booking:                          │  │
│  │    - Cancel PaymentIntent (if not captured)           │  │
│  │    - OR Refund (if already captured)                  │  │
│  │    - Update status: 'refunded' or 'cancelled'         │  │
│  │                                                        │  │
│  │ 3. User gets money back automatically                 │  │
│  └────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
       │
       │ User receives refund
       │
       ▼
┌──────────────────────────────┐
│  User's Bank Account         │
│  💰 Refund: ₹1000           │
└──────────────────────────────┘

═══════════════════════════════════════════════════════════════

                        MONEY FLOW DIAGRAM

┌─────────────┐
│    USER     │
│  Bank Card  │
└──────┬──────┘
       │
       │ ₹1000 authorized (not charged yet)
       │
       ▼
┌──────────────────────┐
│  STRIPE ESCROW       │
│  (Payment Intent)    │
│  Status: authorized  │
│  Capture: manual     │
└──────┬───────────────┘
       │
       │ OTP Verified?
       │
       ├─── YES ──────────────────────────────────────┐
       │                                              │
       │ Capture ₹1000                                │
       │                                              │
       ▼                                              │
┌──────────────────────┐                             │
│  STRIPE BALANCE      │                             │
│  ₹1000 captured      │                             │
└──────┬───────────────┘                             │
       │                                              │
       │ Split payment                                │
       │                                              │
       ├─────────────────┬────────────────────────────┤
       │                 │                            │
       │ ₹100 (10%)      │ ₹900 (90%)                │
       │                 │                            │
       ▼                 ▼                            │
┌──────────────┐  ┌──────────────────┐               │
│  PLATFORM    │  │    PROVIDER      │               │
│  Commission  │  │  Stripe Account  │               │
└──────────────┘  └──────────────────┘               │
                                                      │
       ├─── NO (Expired) ─────────────────────────────┘
       │
       │ Cancel/Refund
       │
       ▼
┌──────────────────────┐
│    USER              │
│  Bank Card           │
│  ₹1000 refunded      │
└──────────────────────┘

═══════════════════════════════════════════════════════════════

                        TIMELINE EXAMPLE

00:00 - User books ride, pays ₹1000
        💰 Money authorized (held)
        🔒 OTP: 123456 generated
        ⏱️  Countdown: 1 hour

00:15 - User shares OTP with provider
        📱 "Your OTP is 123456"

00:20 - Provider enters OTP
        ✅ OTP verified
        💸 ₹900 transferred to provider
        💰 ₹100 platform commission
        ✓ Booking completed

═══════════════════════════════════════════════════════════════

                    ALTERNATIVE TIMELINE

00:00 - User books ride, pays ₹1000
        💰 Money authorized (held)
        🔒 OTP: 123456 generated
        ⏱️  Countdown: 1 hour

00:30 - Provider doesn't show up
        ⏱️  Countdown: 30 minutes left

01:00 - Countdown expires
        ⚠️  Auto-refund triggered
        💸 ₹1000 refunded to user
        ✓ Booking cancelled

═══════════════════════════════════════════════════════════════
```

## 🔐 Security Features

1. **Payment Authorization**: Card charged only after OTP verification
2. **Time-Limited Hold**: Auto-refund after 1 hour
3. **OTP Verification**: Ensures service was provided
4. **Stripe Security**: PCI-compliant payment processing
5. **Backend Validation**: All critical operations on server

## 💡 Key Benefits

- **For Users**: Money protected until service confirmed
- **For Providers**: Guaranteed payment after service
- **For Platform**: Automated commission collection
- **For Everyone**: Dispute prevention through OTP system

---

**This is how the escrow system works end-to-end!** 🎉
