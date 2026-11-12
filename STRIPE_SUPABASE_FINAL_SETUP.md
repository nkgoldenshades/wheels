# Stripe Escrow with Supabase - Final Setup

## ✅ What's Ready:

1. **Supabase-based escrow functions** - `functions/stripe-escrow-supabase.js`
2. **Your existing bookings table** - Just needs Stripe columns added
3. **Production-safe auto-refund** - With idempotency and transaction locking

## 🔧 Setup Steps:

### Step 1: Add Stripe Columns to Supabase

1. Go to: https://supabase.com/dashboard/project/uklltpopjovbhplbvltr/editor
2. Click **"SQL Editor"** → **"New query"**
3. Copy and paste the contents of `ADD_STRIPE_COLUMNS.sql`
4. Click **"Run"**

This adds:
- `stripe_payment_intent_id` - Stripe payment ID
- `amount` - Payment amount in cents
- `countdown_end_time` - When booking expires
- `refund_processing` - Lock for concurrent processing
- `stripe_transfer_id` - Transfer ID when released
- `stripe_refund_id` - Refund ID when refunded
- Plus timestamps and error tracking

### Step 2: Get Supabase Service Role Key

1. Go to: https://supabase.com/dashboard/project/uklltpopjovbhplbvltr/settings/api
2. Scroll to **"Project API keys"**
3. Copy the **`service_role`** key (the long one, NOT anon)
4. Paste it here and I'll update the functions

### Step 3: Update Functions to Use Supabase

Once you provide the service key, I'll:
1. Update `functions/stripe-escrow-supabase.js` with your key
2. Update `functions/index.js` to use Supabase version
3. You deploy with: `firebase deploy --only functions`

## 📊 How It Works with Your Existing Schema:

### Your Current Bookings Table:
```
bookings:
  - id (uuid)
  - slot_id (uuid) 
  - user_id (text)
  - provider_id (text)
  - price (numeric)
  - status (text)
  - otp (text)
  - otp_verified (boolean)
```

### After Adding Stripe Columns:
```
bookings:
  - id (uuid)
  - slot_id (uuid)
  - user_id (text)
  - provider_id (text)
  - price (numeric)
  - status (text)
  - otp (text)
  - otp_verified (boolean)
  + stripe_payment_intent_id (text)  ← NEW
  + amount (integer)                  ← NEW
  + countdown_end_time (timestamptz)  ← NEW
  + refund_processing (boolean)       ← NEW
  + stripe_transfer_id (text)         ← NEW
  + stripe_refund_id (text)           ← NEW
```

## 🎯 Booking Flow:

### 1. User Books a Slot:
```dart
final bookingData = await StripeService.instance.createBooking(
  userId: currentUserId,
  providerId: slot.user_id,
  postId: slot.id,
  amount: (slot.price * 100).toInt(), // Convert to cents
  currency: 'usd',
  commissionAmount: (slot.price * 100 * 0.15).toInt(), // 15%
  countdownHours: 24,
);
```

### 2. Creates Record in Supabase:
```sql
INSERT INTO bookings (
  user_id,
  provider_id,
  slot_id,
  price,
  amount,
  stripe_payment_intent_id,
  countdown_end_time,
  status,
  otp
) VALUES (
  'user_123',
  'provider_456',
  'slot_789',
  100.00,
  10000,  -- $100 in cents
  'pi_xxx',
  NOW() + INTERVAL '24 hours',
  'pending',
  '123456'
);
```

### 3. Two Outcomes:

**A) Provider Enters OTP:**
- Money transferred to provider
- Status: `completed`
- `stripe_transfer_id` saved

**B) Timer Expires:**
- Auto-refund triggered
- Money refunded to user
- Status: `refunded`
- `stripe_refund_id` saved

## 🔐 Security Features:

1. **Idempotency** - Checks Stripe before refunding (prevents double refunds)
2. **Transaction Locking** - Uses `refund_processing` flag (prevents concurrent processing)
3. **Structured Logging** - Detailed logs with emojis for easy debugging

## 📝 Next Steps:

1. ✅ Run `ADD_STRIPE_COLUMNS.sql` in Supabase
2. ⏳ Provide Supabase service_role key
3. ⏳ I'll update the functions
4. ⏳ Deploy: `firebase deploy --only functions`
5. ⏳ Test the flow!

## 🧪 Testing:

After deployment, create a test booking in Supabase:

```sql
INSERT INTO bookings (
  user_id,
  provider_id,
  price,
  amount,
  stripe_payment_intent_id,
  countdown_end_time,
  status,
  otp,
  refund_processing
) VALUES (
  'test_user',
  'test_provider',
  100.00,
  10000,
  'pi_test_123',
  NOW() - INTERVAL '1 hour',  -- Already expired
  'pending',
  '123456',
  FALSE
);
```

Wait 1 minute, then check logs:
```bash
firebase functions:log --only autoRefundExpired
```

You should see:
```
🔄 Running auto refund check...
📦 Expired bookings found: 1
🔍 Checking Stripe for payment: pi_test_123
💸 Creating refund for booking xxx...
✅ Booking xxx refunded successfully
```

## Ready!

Just provide the Supabase service_role key and we're good to go! 🚀

