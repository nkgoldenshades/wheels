# Get Supabase Service Role Key

## Step 1: Get Your Service Role Key

1. Go to: https://supabase.com/dashboard/project/uklltpopjovbhplbvltr/settings/api
2. Scroll down to **"Project API keys"**
3. Copy the **`service_role`** key (NOT the anon key)
   - It starts with: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
   - This key has admin privileges

## Step 2: Add to Firebase Functions

Create a `.env` file in the `functions` folder:

```bash
# functions/.env
SUPABASE_SERVICE_KEY=your_service_role_key_here
```

## Step 3: Update functions/stripe-escrow-supabase.js

Replace line 9:
```javascript
process.env.SUPABASE_SERVICE_KEY || 'YOUR_SUPABASE_SERVICE_ROLE_KEY'
```

With your actual key:
```javascript
process.env.SUPABASE_SERVICE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
```

## Step 4: Create Bookings Table in Supabase

Run this SQL in Supabase SQL Editor:

```sql
-- Create bookings table
CREATE TABLE IF NOT EXISTS bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL,
  provider_id TEXT NOT NULL,
  post_id TEXT,
  
  -- Payment details
  stripe_payment_intent_id TEXT NOT NULL,
  amount INTEGER NOT NULL,
  currency TEXT DEFAULT 'usd',
  commission_amount INTEGER NOT NULL,
  
  -- Escrow details
  otp TEXT NOT NULL,
  countdown_end_time TIMESTAMPTZ NOT NULL,
  status TEXT DEFAULT 'pending',
  refund_processing BOOLEAN DEFAULT FALSE,
  
  -- Stripe IDs
  stripe_transfer_id TEXT,
  stripe_refund_id TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  refunded_at TIMESTAMPTZ,
  refund_failed_at TIMESTAMPTZ,
  
  -- Error tracking
  refund_error TEXT
);

-- Create index for expired bookings query
CREATE INDEX idx_bookings_expired 
ON bookings(status, countdown_end_time) 
WHERE status = 'pending';

-- Create index for user bookings
CREATE INDEX idx_bookings_user 
ON bookings(user_id);

-- Create index for provider bookings
CREATE INDEX idx_bookings_provider 
ON bookings(provider_id);
```

## Step 5: Update functions/index.js

Replace the Firestore imports with Supabase:

```javascript
// Remove this line:
const db = admin.firestore();

// Add Supabase escrow functions
const stripeEscrowSupabase = require('./stripe-escrow-supabase');

// Update exports
exports.createBooking = stripeEscrowSupabase.createBooking;
exports.verifyOtp = stripeEscrowSupabase.verifyOtp;
exports.autoRefundExpired = stripeEscrowSupabase.autoRefundExpired;
exports.refundPayment = stripeEscrowSupabase.refundPayment;
exports.releaseFunds = stripeEscrowSupabase.releaseFunds;
```

## Step 6: Deploy

```bash
firebase deploy --only functions
```

## Done!

Your Stripe escrow system now uses Supabase instead of Firestore!

