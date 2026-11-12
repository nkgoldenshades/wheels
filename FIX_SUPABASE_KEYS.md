# Fix Supabase Keys for Firebase Functions

## Problem
The subscription payment is failing with error "Can't create checkout session" because the Firebase Functions can't access Supabase. The error logs show:

```
Supabase insert booking error: {
  message: 'Invalid API key',
  hint: 'Double check your Supabase `anon` or `service_role` API key.'
}
```

## Root Cause
Firebase Functions need the Supabase **SERVICE_ROLE_KEY** (not the anon key) to perform backend operations like creating bookings. This key is not configured in Firebase Secret Manager.

## Solution Steps

### Step 1: Get Your Supabase Service Role Key

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project: `quickohunt-app` (uklltpopjovbhplbvltr)
3. Click **Settings** (gear icon in sidebar)
4. Click **API** 
5. Find **Service Role Key** (⚠️ Keep this secret!)
6. Copy the key (it starts with `eyJhbGc...`)

### Step 2: Set the Keys in Firebase Secret Manager

Open terminal and run these commands:

```bash
cd e:\quickohunt

# Set Supabase URL
firebase functions:secrets:set SUPABASE_URL
# When prompted, paste: https://uklltpopjovbhplbvltr.supabase.co

# Set Supabase Service Role Key
firebase functions:secrets:set SUPABASE_SERVICE_ROLE_KEY
# When prompted, paste your service role key from Step 1
```

### Step 3: Redeploy the Functions

The timeout issue we had earlier might prevent full deployment, but we can try deploying just the subscription function:

```bash
# Try deploying just the subscription function
firebase deploy --only functions:createSubscriptionCheckoutSession

# If that times out, deploy all functions
firebase deploy --only functions
```

**Note:** If deployment times out again, the secrets are still saved and will be used by the existing deployed functions. You can verify by checking the logs after trying the payment again.

### Step 4: Test the Payment Again

1. Open your app
2. Try purchasing the Premium subscription again
3. Check the logs to see if the error is resolved:
   ```bash
   firebase functions:log | Select-String -Pattern "createSubscriptionCheckoutSession|error" -Context 2,2 | Select-Object -First 20
   ```

## Alternative: Quick Test Without Deployment

Since deployment is timing out, you can test if the secrets work by checking them:

```bash
# Verify the secrets were saved
firebase functions:secrets:access SUPABASE_URL
firebase functions:secrets:access SUPABASE_SERVICE_ROLE_KEY
```

The existing deployed function should automatically pick up the new secrets on the next cold start (when it restarts). This happens automatically within a few minutes, or you can force it by waiting ~10 minutes and trying the payment again.

## Why This Happened

The Firebase Functions code has a fallback hardcoded anon key:
```javascript
const supabaseKey = process.env.SUPABASE_ANON_KEY || 
                    process.env.SUPABASE_SERVICE_ROLE_KEY || 
                    'eyJhbGc...[anon key]';
```

But for backend operations (inserting bookings), we need the **service_role key** which has full admin access to bypass Row Level Security policies.

## Expected Result

After setting the service role key, the payment should work and you'll see:
- Stripe Checkout opens in browser
- User can complete payment
- Success redirect back to app
- Subscription activated

## Still Not Working?

If it still fails after setting the keys, share the output of:
```bash
firebase functions:log | Select-String -Pattern "createSubscriptionCheckoutSession" -Context 3,3 | Select-Object -First 30
```
