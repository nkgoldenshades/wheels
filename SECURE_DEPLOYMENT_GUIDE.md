# Secure Stripe Escrow Deployment Guide

## 🔐 Security First - No Keys in Code!

All secrets are stored in environment variables, never in code.

## Step 1: Add Stripe Columns to Supabase

1. Go to: https://supabase.com/dashboard/project/uklltpopjovbhplbvltr/editor
2. Click **SQL Editor** → **New query**
3. Copy contents of `ADD_STRIPE_COLUMNS.sql`
4. Click **Run**

## Step 2: Set Up Environment Variables (SECURE)

### Option A: Using .env File (Local Development)

1. Copy the example file:
```bash
cd functions
cp .env.example .env
```

2. Edit `functions/.env` and add your keys:
```bash
# Get service_role key from:
# https://supabase.com/dashboard/project/uklltpopjovbhplbvltr/settings/api
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

3. **IMPORTANT**: Add `.env` to `.gitignore`:
```bash
echo "functions/.env" >> .gitignore
```

### Option B: Using Firebase Environment Config (Production)

```bash
# Set Supabase key
firebase functions:config:set supabase.service_key="YOUR_SERVICE_ROLE_KEY"

# Verify it's set
firebase functions:config:get
```

Then update `functions/stripe-escrow-supabase.js` line 7:
```javascript
process.env.SUPABASE_SERVICE_ROLE_KEY || functions.config().supabase.service_key
```

## Step 3: Update functions/index.js

Replace the Firestore version with Supabase version:

```javascript
// Remove or comment out the old Firestore-based functions
// const db = admin.firestore();

// Add Supabase-based functions
const stripeEscrowSupabase = require('./stripe-escrow-supabase');

// Update exports to use Supabase version
exports.createBooking = stripeEscrowSupabase.createBooking;
exports.verifyOtp = stripeEscrowSupabase.verifyOtp;
exports.autoRefundExpired = stripeEscrowSupabase.autoRefundExpired;
exports.refundPayment = stripeEscrowSupabase.refundPayment;
exports.releaseFunds = stripeEscrowSupabase.releaseFunds;
```

## Step 4: Deploy Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy specific functions
firebase deploy --only functions:createBooking,functions:verifyOtp,functions:autoRefundExpired
```

## Step 5: Verify Deployment

Check if functions are running:
```bash
firebase functions:list
```

Check logs:
```bash
firebase functions:log --only autoRefundExpired
```

## 🧪 Testing

### Test 1: Create a Test Booking

Run this SQL in Supabase:
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
  'pi_test_expired',
  NOW() - INTERVAL '1 hour',  -- Already expired
  'pending',
  '123456',
  FALSE
);
```

### Test 2: Wait for Auto-Refund

Wait 1-2 minutes, then check:
```bash
firebase functions:log --only autoRefundExpired
```

You should see:
```
🔄 Running auto refund check...
📦 Expired bookings found: 1
🔍 Checking Stripe for payment: pi_test_expired
💸 Creating refund...
✅ Booking refunded successfully
```

### Test 3: Check Supabase

Query the booking:
```sql
SELECT * FROM bookings WHERE stripe_payment_intent_id = 'pi_test_expired';
```

Should show:
- `status`: 'refunded'
- `stripe_refund_id`: 're_xxx'
- `refunded_at`: timestamp

## 🔒 Security Checklist

- [x] Service role key in environment variable (not in code)
- [x] `.env` file in `.gitignore`
- [x] Stripe secret key in environment variable
- [x] CORS headers configured
- [x] Idempotency checks in place
- [x] Transaction locking implemented
- [x] Structured logging for debugging

## 📊 Monitor Your System

### Firebase Console
- Functions: https://console.firebase.google.com/project/quickohunt-app/functions
- Logs: `firebase functions:log`

### Supabase Console
- Database: https://supabase.com/dashboard/project/uklltpopjovbhplbvltr/editor
- Logs: https://supabase.com/dashboard/project/uklltpopjovbhplbvltr/logs

### Stripe Dashboard
- Payments: https://dashboard.stripe.com/test/payments
- Refunds: https://dashboard.stripe.com/test/refunds

## 🚨 Troubleshooting

### "SUPABASE_SERVICE_ROLE_KEY is undefined"
- Check `.env` file exists in `functions/` folder
- Check key is set correctly
- Restart Firebase emulator if testing locally

### "Permission denied" errors
- Verify you're using service_role key (not anon key)
- Check Supabase RLS policies

### Auto-refund not working
- Check Cloud Scheduler is enabled
- Check function logs for errors
- Verify bookings table has expired records

## 🎯 Next Steps

1. ✅ Run `ADD_STRIPE_COLUMNS.sql`
2. ✅ Create `functions/.env` with your keys
3. ✅ Update `functions/index.js`
4. ✅ Deploy: `firebase deploy --only functions`
5. ✅ Test with expired booking
6. ✅ Integrate into your Flutter app

## 🔐 Never Commit Secrets!

Always check before committing:
```bash
git status
# Make sure .env is NOT listed

# If it is, add to .gitignore immediately:
echo "functions/.env" >> .gitignore
git rm --cached functions/.env
```

Your escrow system is now secure and production-ready! 🚀

