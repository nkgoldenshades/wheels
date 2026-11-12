# Auto-Downgrade Expired Subscriptions Setup

This document explains how to set up automatic downgrading of expired subscriptions.

---

## ✅ **What You Have Now**

1. **Database columns added** to `profiles_private`:
   - `subscription_plan` (text, default 'basic')
   - `subscription_expires_at` (timestamptz, nullable)
   - `subscription_payment_id` (text, nullable)

2. **Flutter code updated**:
   - ProfileInfo model includes subscription fields
   - ProfileRepository saves subscriptions to backend
   - PaymentSuccessScreen saves subscription after payment

3. **Auto-downgrade SQL function created**:
   - File: `auto_downgrade_expired_subscriptions.sql`
   - Function: `auto_downgrade_expired_subscriptions()`

4. **Firebase scheduled function created**:
   - File: `functions/stripe-escrow.js`
   - Function: `autoDowngradeExpiredSubscriptions`
   - Runs daily at 2 AM UTC

---

## 🚀 **Deployment Steps**

### **Step 1: Deploy Database Function**

1. Open Supabase dashboard: https://supabase.com/dashboard
2. Navigate to: **SQL Editor** (left sidebar)
3. Click: **New Query**
4. Copy the entire contents of `auto_downgrade_expired_subscriptions.sql`
5. Paste into the SQL editor
6. Click: **Run** button (bottom right)

**Expected output**: 
```
Success. No rows returned
```

---

### **Step 2: Test Database Function**

In Supabase SQL Editor, run:

```sql
SELECT * FROM auto_downgrade_expired_subscriptions();
```

**Expected output**:
```
downgraded_count
----------------
0
```

(0 is correct if no subscriptions are expired yet)

---

### **Step 3: Deploy Firebase Function**

In your terminal, run:

```bash
cd e:\quickohunt
firebase deploy --only functions:autoDowngradeExpiredSubscriptions
```

**Expected output**:
```
✔ functions[autoDowngradeExpiredSubscriptions(us-central1)] Successful create operation.
Function URL: https://us-central1-quickohunt-app.cloudfunctions.net/autoDowngradeExpiredSubscriptions
```

---

### **Step 4: Verify Scheduled Function**

1. Check Firebase Console: https://console.firebase.google.com/
2. Navigate to: **Functions** → **Dashboard**
3. Look for: `autoDowngradeExpiredSubscriptions`
4. Status should show: **Active** ✅

---

## 🔍 **How It Works**

### **Daily Schedule**
```
Every day at 2:00 AM UTC (6:00 AM IST):
```

1. Firebase Cloud Scheduler triggers the function
2. Function calls Supabase RPC: `auto_downgrade_expired_subscriptions()`
3. Database function finds all expired subscriptions:
   - `subscription_plan != 'basic'`
   - `subscription_expires_at < NOW()`
4. Database resets them to:
   - `subscription_plan = 'basic'`
   - `subscription_expires_at = NULL`
5. Returns count of downgraded subscriptions

### **Security**
- ✅ **Server-side only**: Users cannot manipulate this logic
- ✅ **Indexed query**: Fast performance even with millions of users
- ✅ **Atomic operation**: Database transaction ensures consistency

---

## 🧪 **Testing**

### **Manual Test (Create Expired Subscription)**

```sql
-- 1. Update your profile with expired subscription
UPDATE profiles_private
SET 
  subscription_plan = 'premium',
  subscription_expires_at = '2024-01-01 00:00:00+00'  -- Past date
WHERE profile_id = 'YOUR_USER_ID';

-- 2. Run the function manually
SELECT * FROM auto_downgrade_expired_subscriptions();

-- 3. Check if it was downgraded
SELECT subscription_plan, subscription_expires_at
FROM profiles_private
WHERE profile_id = 'YOUR_USER_ID';
```

**Expected result**: 
- `downgraded_count` = 1
- `subscription_plan` = 'basic'
- `subscription_expires_at` = NULL

---

## 📊 **Monitoring**

### **Check Logs (Firebase Console)**

1. Go to: **Functions** → **Logs**
2. Filter by: `autoDowngradeExpiredSubscriptions`
3. Look for daily executions:

```
✅ Successfully downgraded 5 expired subscription(s) to basic
```

### **Check Logs (Supabase Dashboard)**

1. Go to: **Logs** → **Postgres Logs**
2. Look for:

```
NOTICE:  Auto-downgraded 5 expired subscriptions to basic
```

---

## 💰 **Costs**

### **Firebase Functions**
- **Scheduled executions**: 1/day = 30/month
- **Free tier**: 120,000 invocations/month
- **Cost**: $0 (well within free tier)

### **Supabase Database**
- **Function execution**: ~10ms per run
- **Database queries**: Indexed, very fast
- **Cost**: $0 (included in free/pro plans)

---

## ❓ **FAQ**

### **Q: What if I want to change the schedule?**
Edit `functions/stripe-escrow.js` line with cron expression:
```javascript
.schedule('0 2 * * *')  // Daily at 2 AM UTC

// Examples:
'0 2 * * *'    // Daily at 2 AM
'0 */6 * * *'  // Every 6 hours
'0 0 * * 0'    // Weekly on Sunday at midnight
```

Then redeploy:
```bash
firebase deploy --only functions:autoDowngradeExpiredSubscriptions
```

### **Q: Can users extend their subscription?**
Yes! When they pay again, `PaymentSuccessScreen` calls:
```dart
ProfileRepository.instance.updateSubscription(
  plan: 'premium',
  expiresAt: DateTime.now().add(Duration(days: 30)),
  paymentId: 'pay_xyz123',
);
```

### **Q: What happens if the function fails?**
- Firebase automatically retries failed scheduled functions
- Check logs in Firebase Console → Functions → Logs
- Database transaction ensures no partial updates

---

## ✅ **Verification Checklist**

- [ ] Database function deployed to Supabase
- [ ] Database function tested manually (returns count)
- [ ] Firebase function deployed successfully
- [ ] Firebase function shows as "Active" in console
- [ ] Test subscription expiry works correctly

---

## 🎯 **Next Steps**

After setting this up, you're ready for production:

1. ✅ **Subscription backend**: Complete
2. ✅ **Auto-downgrade**: Complete
3. ⏳ **Enable live keys**: Next step
4. ⏳ **Update Stripe URLs**: Next step
5. ⏳ **Deploy to production**: Final step

**Ready to proceed with production deployment?** 🚀
