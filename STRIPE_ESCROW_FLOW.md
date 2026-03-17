# Stripe Escrow Flow for Quickohunt

## How It Works

### Step 1: User Books a Post
- User selects a vehicle/service post
- User pays via Stripe
- Money is held in YOUR Stripe account (escrow)
- Booking record created with:
  - Payment ID
  - Countdown timer (e.g., 24 hours)
  - OTP generated for provider
  - Status: "pending"

### Step 2: Countdown Timer Active
- Provider has X hours to complete service
- Provider must enter OTP to confirm completion
- Timer counts down in real-time

### Step 3A: Provider Enters OTP (Success)
- Provider enters correct OTP before timer expires
- Money automatically transferred from escrow to provider's Stripe account
- Your commission deducted (e.g., 15%)
- Status: "completed"

### Step 3B: Timer Expires (Refund)
- Timer reaches 00:00 without OTP entry
- Money automatically refunded to user
- Status: "refunded"

## Technical Implementation

### Database Schema (Supabase)

```sql
CREATE TABLE bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  provider_id UUID REFERENCES auth.users(id),
  post_id UUID REFERENCES posts(id),
  
  -- Payment details
  stripe_payment_intent_id TEXT NOT NULL,
  amount INTEGER NOT NULL, -- in cents
  currency TEXT DEFAULT 'usd',
  commission_amount INTEGER NOT NULL,
  
  -- Escrow details
  otp TEXT NOT NULL,
  countdown_end_time TIMESTAMPTZ NOT NULL,
  status TEXT DEFAULT 'pending', -- pending, completed, refunded, cancelled
  
  -- Stripe Connect
  provider_stripe_account_id TEXT,
  stripe_transfer_id TEXT, -- set when money released
  stripe_refund_id TEXT, -- set when refunded
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  refunded_at TIMESTAMPTZ
);

-- Index for finding expired bookings
CREATE INDEX idx_bookings_pending_expired 
ON bookings(status, countdown_end_time) 
WHERE status = 'pending';
```

### Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    USER BOOKS POST                          │
│  User pays $100 → Stripe PaymentIntent created             │
│  Money held in YOUR Stripe account                         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│              BOOKING CREATED IN DATABASE                    │
│  - Generate OTP (e.g., 6-digit code)                       │
│  - Set countdown_end_time (now + 24 hours)                 │
│  - Status: "pending"                                        │
│  - Send OTP to provider via notification                   │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                  COUNTDOWN TIMER ACTIVE                     │
│  App shows countdown: 23:59:58... 23:59:57...              │
└─────────────────┬───────────────────────────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
        ▼                   ▼
┌──────────────┐    ┌──────────────┐
│ OTP ENTERED  │    │ TIMER EXPIRES│
│ (Success)    │    │ (Refund)     │
└──────┬───────┘    └──────┬───────┘
       │                   │
       ▼                   ▼
┌──────────────┐    ┌──────────────┐
│ Transfer $85 │    │ Refund $100  │
│ to Provider  │    │ to User      │
│ (Keep $15)   │    │              │
└──────────────┘    └──────────────┘
```

## Code Implementation

### 1. Stripe Service (Updated)

The service handles:
- Creating payment intents (holding money)
- Transferring to provider (OTP success)
- Refunding to user (timer expired)

### 2. Backend Functions (Firebase/Supabase)

You need 3 cloud functions:

**Function 1: Create Booking**
- Called when user books
- Creates Stripe PaymentIntent
- Saves booking to database
- Generates OTP

**Function 2: Verify OTP & Release Funds**
- Called when provider enters OTP
- Validates OTP
- Transfers money to provider via Stripe
- Updates booking status

**Function 3: Auto-Refund Expired Bookings**
- Runs every minute (cron job)
- Finds bookings where timer expired
- Refunds money to user
- Updates booking status

### 3. Flutter App Changes

**Booking Screen:**
- Show countdown timer
- Display OTP entry field for provider
- Real-time status updates

**Payment Flow:**
- Integrate Stripe payment sheet
- Handle payment confirmation
- Navigate to booking details

## Security Considerations

1. **OTP Security:**
   - Generate cryptographically secure random OTP
   - OTP valid only for specific booking
   - Single-use only

2. **Timer Accuracy:**
   - Use server time, not device time
   - Check timer on every OTP attempt
   - Prevent race conditions

3. **Stripe Webhooks:**
   - Verify webhook signatures
   - Handle payment failures
   - Handle refund failures

## Next Steps

1. Get your Stripe test keys
2. Set up Stripe Connect for providers
3. Implement the 3 backend functions
4. Update Flutter app with payment flow
5. Test complete flow end-to-end

## Testing Scenarios

1. ✅ Happy path: User pays → Provider enters OTP → Money released
2. ✅ Timeout: User pays → Timer expires → Money refunded
3. ✅ Wrong OTP: Provider enters wrong OTP → Rejected, can retry
4. ✅ Payment fails: Stripe payment fails → No booking created
5. ✅ Refund fails: Handle gracefully, retry, notify admin

