# Complete Backend Flow - QuickOHunt

## System Architecture Overview

```
┌─────────────────┐
│  Flutter App    │
│  (Frontend)     │
└────────┬────────┘
         │
         ├──────────────────────────────────────┐
         │                                      │
         ▼                                      ▼
┌─────────────────┐                   ┌─────────────────┐
│  Firebase Auth  │                   │    Supabase     │
│  (Auth Only)    │                   │  (Database)     │
└────────┬────────┘                   └────────┬────────┘
         │                                      │
         │                                      │
         ▼                                      ▼
┌─────────────────┐                   ┌─────────────────┐
│ Firebase        │                   │  PostgreSQL     │
│ Functions       │◄──────────────────┤  + Triggers     │
│ (9 Functions)   │    Webhooks       │  + RLS          │
└─────────────────┘                   └─────────────────┘
         │
         │
         ▼
┌─────────────────┐
│  Stripe API     │
│  (Payments)     │
└─────────────────┘
```

## 1. Authentication Flow

### User Sign Up/Login
```
1. User enters email/password in Flutter app
   ↓
2. Firebase Auth creates user account
   ↓
3. Firebase generates JWT token with claims:
   {
     "sub": "GbsFkKmcHCQFJ0ceVoBWz2punch1",  // Firebase UID
     "email": "user@example.com",
     "iat": 1234567890,
     "exp": 1234571490
   }
   ↓
4. Flutter app stores Firebase UID locally
   ↓
5. App syncs user to Supabase public.users table:
   INSERT INTO users (id, email, ...) 
   VALUES ('GbsFkKmcHCQFJ0ceVoBWz2punch1', 'user@example.com', ...)
```

### Every API Request
```
1. Flutter app gets current Firebase user
   ↓
2. Gets fresh JWT token: await user.getIdToken(true)
   ↓
3. Supabase client automatically includes JWT in request headers
   ↓
4. Supabase validates JWT signature
   ↓
5. RLS policies extract Firebase UID: auth.jwt() ->> 'sub'
   ↓
6. Database operation allowed/denied based on RLS rules
```

## 2. Database Flow (Supabase PostgreSQL)

### Tables Structure
```
public.users (id: TEXT)
  ├── public.vehicles (user_id: TEXT → users.id)
  ├── public.slots (user_id: TEXT → users.id, provider_id: TEXT → users.id)
  ├── public.bookings (user_id: TEXT → users.id, provider_id: TEXT → users.id)
  ├── public.seat_layouts (user_id: TEXT → users.id)
  └── public.reviews (user_id: TEXT → users.id, provider_id: TEXT → users.id)
```

### RLS Security
```sql
-- Example: Bookings table
CREATE POLICY "bookings_insert_self" ON bookings
  FOR INSERT WITH CHECK (
    (auth.jwt() ->> 'sub') = user_id  -- Only insert your own bookings
  );

CREATE POLICY "bookings_update_own" ON bookings
  FOR UPDATE USING (
    (auth.jwt() ->> 'sub') = user_id OR   -- User can update
    (auth.jwt() ->> 'sub') = provider_id  -- Provider can update
  );
```

### Database Triggers
```
1. booking_otp_trigger (BEFORE INSERT on bookings)
   - Generates 6-digit OTP (100000-999999)
   - Sets otp_attempts = 0
   - Sets otp_verified = false
   
2. update_updated_at_column (BEFORE UPDATE on all tables)
   - Automatically updates updated_at timestamp
```

## 3. Booking Creation Flow (Complete)

```
┌─────────────────────────────────────────────────────────────┐
│ STEP 1: User Creates Booking (Flutter App)                 │
└─────────────────────────────────────────────────────────────┘
1. User selects slot and confirms booking
2. App calls BookingRepository.createBooking()
3. Creates local booking object with:
   - id: timestamp
   - user_id: Firebase UID
   - provider_id: Firebase UID (from vehicle owner)
   - slot_id: slot ID
   - price: calculated price
   - status: 'pending' (if payment) or 'accepted' (if free)

┌─────────────────────────────────────────────────────────────┐
│ STEP 2: Sync to Supabase (Flutter → Supabase)              │
└─────────────────────────────────────────────────────────────┘
4. App calls _syncBookingToSupabase()
5. Supabase client includes Firebase JWT in request
6. INSERT INTO bookings (...) VALUES (...)
   
┌─────────────────────────────────────────────────────────────┐
│ STEP 3: Database Processing (Supabase)                     │
└─────────────────────────────────────────────────────────────┘
7. RLS policy checks: (auth.jwt() ->> 'sub') = user_id ✓
8. BEFORE INSERT trigger fires: booking_otp_trigger
9. Trigger generates OTP and sets fields:
   NEW.otp = random 6-digit number
   NEW.otp_attempts = 0
   NEW.otp_verified = false
10. Row inserted into bookings table

┌─────────────────────────────────────────────────────────────┐
│ STEP 4: Return OTP (Supabase → Flutter)                    │
└─────────────────────────────────────────────────────────────┘
11. Supabase returns: { id: '...', otp: '123456' }
12. Flutter updates local booking with OTP
13. User sees OTP on screen

┌─────────────────────────────────────────────────────────────┐
│ STEP 5: Payment Flow (if required)                         │
└─────────────────────────────────────────────────────────────┘
14. If payment required, app calls Stripe API
15. Creates PaymentIntent with amount
16. User completes payment
17. Stripe webhook → Firebase Function
18. Function updates booking status to 'accepted'
```

## 4. Firebase Functions (9 Functions)

### Function 1: createPaymentIntent
```
Trigger: HTTPS callable
Purpose: Create Stripe PaymentIntent for booking
Flow:
  1. Receives booking details from app
  2. Validates user authentication
  3. Calls Stripe API to create PaymentIntent
  4. Returns client_secret to app
  5. Updates booking with payment_intent_id
```

### Function 2: capturePayment
```
Trigger: HTTPS callable
Purpose: Capture held payment after OTP verification
Flow:
  1. Receives booking_id and otp
  2. Verifies OTP in Supabase
  3. Calls Stripe API to capture payment
  4. Updates booking status to 'completed'
```

### Function 3: refundPayment
```
Trigger: HTTPS callable
Purpose: Refund payment for cancelled/rejected bookings
Flow:
  1. Receives booking_id
  2. Gets payment_intent_id from Supabase
  3. Calls Stripe API to refund
  4. Updates booking status to 'refunded'
```

### Function 4: handleStripeWebhook
```
Trigger: HTTPS webhook (from Stripe)
Purpose: Handle Stripe payment events
Flow:
  1. Receives webhook from Stripe
  2. Verifies webhook signature
  3. Processes events:
     - payment_intent.succeeded
     - payment_intent.payment_failed
     - charge.refunded
  4. Updates booking status in Supabase
```

### Function 5: verifyOTP
```
Trigger: HTTPS callable
Purpose: Verify booking OTP and complete booking
Flow:
  1. Receives booking_id and otp
  2. Queries Supabase for booking
  3. Checks otp_attempts < 4
  4. Compares OTP
  5. If valid:
     - Sets otp_verified = true
     - Updates status to 'completed'
  6. If invalid:
     - Increments otp_attempts
     - If attempts >= 4: marks as 'fraud_suspected'
```

### Function 6: autoRefundFraudBookings
```
Trigger: Scheduled (every 5 minutes)
Purpose: Auto-refund bookings marked as fraud
Flow:
  1. Queries Supabase for fraud_suspected bookings
  2. For each booking:
     - Calls Stripe API to refund
     - Updates status to 'refunded'
```

### Function 7: releaseExpiredSlots
```
Trigger: Scheduled (every 1 minute)
Purpose: Release slots with expired countdown timers
Flow:
  1. Queries Supabase for pending bookings with expired countdown
  2. For each booking:
     - Refunds payment
     - Updates status to 'expired'
     - Increments slot capacity
```

### Function 8: sendBookingNotification
```
Trigger: Firestore onCreate (bookings collection)
Purpose: Send push notification to provider
Flow:
  1. Triggered when new booking created
  2. Gets provider FCM token
  3. Sends notification via Firebase Cloud Messaging
```

### Function 9: cleanupOldData
```
Trigger: Scheduled (daily at midnight)
Purpose: Archive old completed bookings
Flow:
  1. Queries Supabase for bookings older than 90 days
  2. Moves to archive table
  3. Deletes from main table
```

## 5. Payment Flow (Stripe Escrow)

### Create Booking with Payment
```
1. User confirms booking
   ↓
2. App calls Firebase Function: createPaymentIntent
   ↓
3. Function creates Stripe PaymentIntent (capture_method: manual)
   ↓
4. Returns client_secret to app
   ↓
5. App shows Stripe payment sheet
   ↓
6. User enters card details
   ↓
7. Stripe authorizes payment (holds funds, doesn't capture)
   ↓
8. Booking created with status: 'pending'
   ↓
9. Countdown timer starts (15 minutes)
```

### OTP Verification & Payment Capture
```
10. Provider shares OTP with user
    ↓
11. User enters OTP in app
    ↓
12. App calls Firebase Function: verifyOTP
    ↓
13. Function verifies OTP in Supabase
    ↓
14. If valid:
    - Calls capturePayment function
    - Stripe captures held funds
    - Updates booking status: 'completed'
    - Provider receives payment (minus platform fee)
```

### Refund Flow
```
15. If booking cancelled/rejected/fraud:
    ↓
16. App calls Firebase Function: refundPayment
    ↓
17. Function calls Stripe API to refund
    ↓
18. Stripe returns funds to user
    ↓
19. Booking status updated: 'refunded'
```

## 6. Security Layers

### Layer 1: Firebase Auth
- Email/password authentication
- JWT token generation
- Token refresh handling

### Layer 2: Supabase RLS
- Row-level security policies
- JWT validation: auth.jwt() ->> 'sub'
- User can only access own data

### Layer 3: Firebase Functions
- Validates user authentication
- Checks business logic rules
- Prevents direct Stripe API access from app

### Layer 4: Stripe
- PCI-compliant payment processing
- Webhook signature verification
- Fraud detection

## 7. Data Sync Strategy

### Local-First Approach
```
1. All data stored locally in SharedPreferences
2. App works offline
3. Sync to Supabase when online
4. Supabase is source of truth for:
   - OTP generation
   - Payment status
   - Cross-device sync
```

### Sync Points
```
- User signup/login → Sync user to Supabase
- Create vehicle → Sync to Supabase
- Create slot → Sync to Supabase
- Create booking → Sync to Supabase (triggers OTP generation)
- Update booking → Sync to Supabase
- Create review → Sync to Supabase
```

## 8. Error Handling

### Network Errors
```
- App continues working with local data
- Shows "Offline" indicator
- Retries sync when connection restored
```

### Authentication Errors
```
- JWT expired → Auto-refresh token
- User logged out → Redirect to login
- Invalid token → Clear session, show login
```

### Payment Errors
```
- Payment failed → Show error, allow retry
- Insufficient funds → Show specific message
- Card declined → Suggest alternative payment
```

### Database Errors
```
- RLS policy violation → Show "Permission denied"
- Constraint violation → Show validation error
- Timeout → Retry with exponential backoff
```

## Summary

**Backend Components:**
1. Firebase Auth (authentication only)
2. Supabase PostgreSQL (database with RLS)
3. Firebase Functions (9 serverless functions)
4. Stripe API (payment processing)

**Key Features:**
- Secure JWT-based authentication
- Row-level security with RLS
- Server-side OTP generation
- Escrow payment system
- Fraud detection (4-attempt limit)
- Auto-refund for fraud cases
- Local-first data sync

**No Supabase Auth Used:**
- Firebase handles all authentication
- Supabase only validates Firebase JWTs
- RLS policies use `auth.jwt() ->> 'sub'` to extract Firebase UID
