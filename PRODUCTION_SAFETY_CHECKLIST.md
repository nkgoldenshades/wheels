# Production Safety Checklist - Stripe Escrow System

## ✅ Database Schema (Run SQL in Supabase)

### 1. Add Stripe Columns
```bash
# Run: ADD_STRIPE_COLUMNS.sql
```
- [x] Adds all Stripe-related columns to bookings table
- [x] Adds status constraint for valid booking states
- [x] Creates performance indexes
- [x] Adds stripe_account_id to users table
- [x] Adds foreign key constraints

### 2. Add Security Functions
```bash
# Run: SUPABASE_SECURITY_FUNCTIONS.sql
```
- [x] `create_booking_secure()` - Server-only booking creation with validation
- [x] `verify_otp_secure()` - OTP verification with business logic
- [x] `lock_booking_for_refund()` - Atomic refund locking
- [x] `mark_booking_completed()` - Mark booking as completed after transfer
- [x] `mark_booking_refunded()` - Mark booking as refunded
- [x] `mark_refund_failed()` - Handle refund failures
- [x] `get_expired_bookings_for_refund()` - Query expired bookings safely

---

## 🔒 Security Measures

### Row Level Security (RLS)
```sql
-- Enable RLS on bookings table
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- Users can only read their own bookings
CREATE POLICY "Users can view own bookings"
  ON public.bookings FOR SELECT
  USING (auth.uid() = user_id OR auth.uid() = provider_id);

-- Only service role can insert/update/delete
CREATE POLICY "Service role full access"
  ON public.bookings FOR ALL
  USING (auth.role() = 'service_role');
```

### Environment Variables
- [x] `SUPABASE_SERVICE_ROLE_KEY` - Stored in `functions/.env` (never in code)
- [x] `STRIPE_SECRET_KEY` - Hardcoded in functions (test key only)
- [x] `RAZORPAY_KEY_SECRET` - Stored in `functions/.env`

---

## 🛡️ Idempotency & Safety

### 1. Stripe Idempotency Keys
**Current Status:** ❌ Not implemented

**Implementation:**
```javascript
// In stripe-escrow-supabase.js

// For PaymentIntent creation
const paymentIntent = await stripe.paymentIntents.create({
  amount: amount,
  currency: currency,
  metadata: { user_id, provider_id, post_id },
}, {
  idempotencyKey: `booking_${user_id}_${post_id}_${Date.now()}`
});

// For Transfer creation
const transfer = await stripe.transfers.create({
  amount: transferAmount,
  currency: booking.currency,
  destination: provider.stripe_account_id,
}, {
  idempotencyKey: `transfer_${booking_id}_${Date.now()}`
});

// For Refund creation
const refund = await stripe.refunds.create({
  payment_intent: booking.stripe_payment_intent_id,
  amount: booking.amount,
}, {
  idempotencyKey: `refund_${booking.id}_${Date.now()}`
});
```

### 2. Transaction Locking
**Current Status:** ✅ Implemented in `autoRefundExpired`

- Uses `refund_processing` flag to prevent concurrent refunds
- Atomic update with WHERE clause ensures only one process wins

### 3. Stripe State Verification
**Current Status:** ✅ Implemented in `autoRefundExpired`

- Checks Stripe PaymentIntent status before refunding
- Prevents double refunds if already processed

---

## 🔄 Auto-Refund Worker Safety

### Current Implementation
```javascript
// Every 1 minute check
exports.autoRefundExpired = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    // 1. Query expired bookings
    // 2. Lock each booking atomically
    // 3. Check Stripe state (idempotency)
    // 4. Process refund
    // 5. Update booking status
  });
```

### Safety Features
- [x] Transaction locking (`refund_processing = true`)
- [x] Idempotency check (queries Stripe before refunding)
- [x] Structured logging with emojis
- [x] Error handling with `refund_failed` status
- [x] Atomic updates with WHERE clauses

### Recommended Improvements
- [ ] Add retry logic with exponential backoff
- [ ] Add dead letter queue for failed refunds
- [ ] Add monitoring/alerting (e.g., Sentry, CloudWatch)
- [ ] Add rate limiting (process max N bookings per run)

---

## 🔐 OTP Security

### Current Implementation
- OTP stored in plain text in database
- 6-digit numeric OTP
- Single-use (booking status changes after verification)
- Time-limited (countdown_end_time)

### Recommended Improvements
```sql
-- Hash OTP before storing
-- In create_booking_secure function:
p_otp_hash TEXT := encode(digest(p_otp, 'sha256'), 'hex')

-- Store hash instead of plain text
otp_hash = p_otp_hash

-- Verify by hashing input and comparing
IF v_booking.otp_hash != encode(digest(p_otp, 'sha256'), 'hex') THEN
  RETURN QUERY SELECT FALSE, 'Invalid OTP';
END IF;
```

### Additional Security
- [ ] Rate limit OTP verification attempts (max 3 per booking)
- [ ] Add OTP expiry separate from countdown (e.g., 15 minutes)
- [ ] Log failed OTP attempts for fraud detection
- [ ] Consider SMS/Email OTP delivery instead of returning in API

---

## 📊 Monitoring & Logging

### Current Logging
- [x] Emoji-based structured logs (🔄, 📦, 💸, ✅, ❌)
- [x] Logs all major operations (create, verify, refund)
- [x] Logs errors with stack traces

### Recommended Additions
```javascript
// Add structured logging with context
const logger = {
  info: (msg, data) => console.log(JSON.stringify({ level: 'info', msg, ...data })),
  error: (msg, data) => console.error(JSON.stringify({ level: 'error', msg, ...data })),
};

// Example usage
logger.info('Booking created', {
  booking_id: booking.id,
  user_id: user_id,
  amount: amount,
  timestamp: new Date().toISOString(),
});
```

### Monitoring Metrics
- [ ] Track refund success/failure rate
- [ ] Track average time to OTP verification
- [ ] Track expired bookings per day
- [ ] Alert on high refund failure rate
- [ ] Alert on Stripe API errors

---

## 🧪 Testing Checklist

### Unit Tests
- [ ] Test OTP generation (6 digits, unique)
- [ ] Test countdown calculation (24 hours default)
- [ ] Test commission calculation
- [ ] Test status transitions

### Integration Tests
- [ ] Test full booking flow (create → pay → verify OTP → complete)
- [ ] Test auto-refund flow (create → pay → wait → refund)
- [ ] Test concurrent refund attempts (should only process once)
- [ ] Test invalid OTP rejection
- [ ] Test expired booking OTP rejection
- [ ] Test provider without Stripe account rejection

### Stripe Test Cards
```javascript
// Success
4242 4242 4242 4242

// Decline
4000 0000 0000 0002

// Insufficient funds
4000 0000 0000 9995

// Requires authentication (3D Secure)
4000 0025 0000 3155
```

---

## 🚀 Deployment Steps

### 1. Database Setup
```bash
# 1. Run schema changes
# Supabase Dashboard → SQL Editor → New Query
# Paste ADD_STRIPE_COLUMNS.sql → Run

# 2. Run security functions
# Paste SUPABASE_SECURITY_FUNCTIONS.sql → Run

# 3. Verify
SELECT * FROM information_schema.columns 
WHERE table_name = 'bookings' AND column_name LIKE '%stripe%';
```

### 2. Environment Variables
```bash
# functions/.env (already set)
SUPABASE_SERVICE_ROLE_KEY=your_key_here
RAZORPAY_KEY_ID=rzp_test_SMpj1xxJxAcT6K
RAZORPAY_KEY_SECRET=PZKW95oZEjcavJ5flTEZVjeU
```

### 3. Deploy Functions
```bash
firebase deploy --only functions
```

### 4. Test End-to-End
```bash
# 1. Create test booking
curl -X POST https://us-central1-quickohunt-app.cloudfunctions.net/createBooking \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test-user-uuid",
    "provider_id": "test-provider-uuid",
    "post_id": "test-post-uuid",
    "amount": 10000,
    "currency": "usd",
    "commission_amount": 1500,
    "countdown_hours": 24
  }'

# 2. Verify OTP (use OTP from response)
curl -X POST https://us-central1-quickohunt-app.cloudfunctions.net/verifyOtp \
  -H "Content-Type: application/json" \
  -d '{
    "booking_id": "booking-uuid-from-step-1",
    "otp": "123456"
  }'
```

---

## 📋 Production Readiness Score

| Category | Status | Score |
|----------|--------|-------|
| Database Schema | ✅ Complete | 10/10 |
| Security Functions | ✅ Complete | 10/10 |
| Idempotency | ⚠️ Partial | 7/10 |
| Transaction Locking | ✅ Complete | 10/10 |
| OTP Security | ⚠️ Plain text | 6/10 |
| Error Handling | ✅ Complete | 9/10 |
| Logging | ✅ Good | 8/10 |
| Monitoring | ❌ None | 0/10 |
| Testing | ❌ None | 0/10 |
| Documentation | ✅ Complete | 10/10 |

**Overall: 70/100** - Ready for staging/testing, needs improvements for production

---

## 🎯 Next Steps (Priority Order)

1. **Run SQL scripts** in Supabase (ADD_STRIPE_COLUMNS.sql)
2. **Test booking flow** with test Stripe keys
3. **Add Stripe idempotency keys** to all API calls
4. **Hash OTP** before storing in database
5. **Add monitoring** (Sentry, CloudWatch, or Firebase Monitoring)
6. **Write integration tests** for critical flows
7. **Set up staging environment** for testing
8. **Add rate limiting** on OTP verification
9. **Configure Stripe webhooks** for payment events
10. **Production deployment** with real Stripe keys

---

## 🆘 Troubleshooting

### Issue: "Booking not found"
- Check booking_id is valid UUID
- Check booking exists in database
- Check user has permission to access booking

### Issue: "Provider has not set up payout account"
- Provider needs to complete Stripe Connect onboarding
- Check `users.stripe_account_id` is not NULL
- Verify Stripe account is active

### Issue: "Booking expired"
- Check `countdown_end_time` hasn't passed
- Increase countdown_hours if needed
- Check auto-refund hasn't already processed

### Issue: "Invalid OTP"
- Check OTP is exactly 6 digits
- Check OTP hasn't been used already
- Check booking status is still 'pending'

### Issue: Double refunds
- Check `refund_processing` flag is working
- Check Stripe idempotency is implemented
- Check logs for concurrent processing

---

## 📞 Support Resources

- **Stripe Docs:** https://stripe.com/docs/api
- **Supabase Docs:** https://supabase.com/docs
- **Firebase Functions:** https://firebase.google.com/docs/functions
- **Your Backend:** https://us-central1-quickohunt-app.cloudfunctions.net
