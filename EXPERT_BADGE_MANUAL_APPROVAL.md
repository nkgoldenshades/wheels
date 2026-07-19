# 💎 Expert Badge - Manual Approval System

## ✅ IMPLEMENTED: Expert is Now Admin-Controlled

### What Changed:

**Before** (Automatic):
- Users with 50+ trips + 4.5+ rating got expert badge automatically
- No payment required
- No control over who gets it

**After** (Manual Approval):
- Expert badge ONLY given by admin after payment
- Users must apply and get approved
- Requires higher subscription fee
- Full control over who gets expert status

---

## How It Works Now:

### 1. **User Side** (Application):

When users click "Expert Plan":
```
╔═══════════════════════════════════════╗
║  💎 Expert Plan                       ║
║                                       ║
║  Expert plan requires manual approval ║
║                                       ║
║  Requirements:                        ║
║  • 50+ completed trips with 4.5+ rating║
║  • Or special credentials/expertise   ║
║                                       ║
║  Price: $49.99/month (or ₹4,999)     ║
║                                       ║
║  Contact us to apply:                 ║
║  vaultwheelsin@gmail.com             ║
║                                       ║
║  [Close]  [📧 Contact Us]            ║
╚═══════════════════════════════════════╝
```

### 2. **Admin Side** (Approval Process):

**Step 1**: Receive email application
```
From: user@example.com
Subject: Expert Plan Application

Hi, I'd like to apply for Expert plan.
My stats: 75 trips, 4.8 rating
```

**Step 2**: Review user qualifications
```sql
-- Check user stats
SELECT 
  pub.id,
  pub.full_name,
  pub.provider_total_trips,
  pub.provider_rating,
  pub.customer_total_trips,
  pub.customer_rating,
  priv.subscription_plan
FROM profiles_public pub
LEFT JOIN profiles_private priv ON pub.id = priv.profile_id
WHERE pub.id = 'user_id_here';
```

**Step 3**: Request payment
- Send payment link (Razorpay/Stripe)
- Price: ₹4,999/month or $49.99/month (5x premium)
- Can offer annual discount: ₹49,999/year or $499/year

**Step 4**: After payment received, grant expert status
```sql
-- Grant expert status
UPDATE profiles_private
SET 
  subscription_plan = 'expert',
  subscription_expires_at = NOW() + INTERVAL '365 days',
  subscription_payment_id = 'pay_abc123'
WHERE profile_id = 'user_id_here';
```

---

## Database Changes:

### Expert Badge Logic (Updated):

**File**: `lib/services/profile_repository.dart`

```dart
// OLD (Automatic):
bool get isExpert {
  final providerQualifies = providerTotalTrips >= 50 && providerRating >= 4.5;
  final customerQualifies = customerTotalTrips >= 50 && customerRating >= 4.5;
  return providerQualifies || customerQualifies;
}

// NEW (Manual):
bool get isExpert {
  // Expert is now subscription-based (not auto-earned)
  return subscriptionPlan == 'expert' && hasActiveSubscription;
}
```

### Helper for Finding Candidates:

```dart
/// Returns true if profile has enough experience to potentially qualify
/// (50+ trips with 4.5+ rating) - for admin reference only
bool get hasExpertLevelExperience {
  final providerQualifies = providerTotalTrips >= 50 && providerRating >= 4.5;
  final customerQualifies = customerTotalTrips >= 50 && customerRating >= 4.5;
  return providerQualifies || customerQualifies;
}
```

---

## SQL Commands for Admin:

### Find Qualified Candidates:
```sql
-- See manage_expert_users.sql for full query
SELECT 
  pub.id,
  pub.full_name,
  pub.provider_total_trips,
  pub.provider_rating,
  CASE 
    WHEN (pub.provider_total_trips >= 50 AND pub.provider_rating >= 4.5)
    THEN '✅ Qualifies'
    ELSE '❌ Not Yet'
  END as qualification
FROM profiles_public pub
LEFT JOIN profiles_private priv ON pub.id = priv.profile_id
WHERE priv.subscription_plan != 'expert'
ORDER BY pub.provider_total_trips DESC;
```

### Grant Expert Status:
```sql
UPDATE profiles_private
SET 
  subscription_plan = 'expert',
  subscription_expires_at = NOW() + INTERVAL '365 days',
  subscription_payment_id = 'pay_xyz'
WHERE profile_id = 'USER_ID';
```

### View All Experts:
```sql
SELECT 
  pub.full_name,
  priv.subscription_expires_at,
  pub.provider_total_trips,
  pub.provider_rating
FROM profiles_public pub
JOIN profiles_private priv ON pub.id = priv.profile_id
WHERE priv.subscription_plan = 'expert'
  AND priv.subscription_expires_at > NOW()
ORDER BY priv.subscription_expires_at ASC;
```

---

## Pricing Recommendations:

### Basic Plan:
- **Free**
- All basic features

### Premium Plan:
- **India**: ₹999/month or ₹9,999/year
- **International**: $12.99/month or $129/year
- Features: Premium badge, verification, priority

### Expert Plan (Manual Approval):
- **India**: ₹4,999/month or ₹49,999/year (5x premium)
- **International**: $49.99/month or $499/year (4x premium)
- Features:
  - 💎 Expert badge
  - Top priority listings
  - Featured profile
  - All premium features
  - Dedicated support

---

## Application Process:

### For Users:
1. Click "Expert Plan" in subscription screen
2. See requirements and price
3. Click "Contact Us" → opens email to vaultwheelsin@gmail.com
4. Write application with stats
5. Wait for admin review
6. Receive payment link
7. Pay subscription
8. Get expert badge activated

### For Admin (You):
1. Receive application email
2. Check user stats in database
3. Decide: approve or reject
4. If approved: send payment link
5. After payment: run SQL to grant expert status
6. User gets expert badge immediately

---

## Auto-Downgrade:

Expert subscriptions still auto-downgrade when expired:

```sql
-- Runs daily at 2 AM UTC
UPDATE profiles_private
SET subscription_plan = 'basic'
WHERE subscription_plan = 'expert'
  AND subscription_expires_at < NOW();
```

---

## Benefits of Manual Approval:

### For You:
✅ **Full control** - decide who gets expert status
✅ **Higher revenue** - charge premium price (5x)
✅ **Quality control** - only best users get badge
✅ **Exclusivity** - expert badge means something special

### For Users:
✅ **Prestige** - expert badge is rare and valuable
✅ **Top visibility** - featured in all listings
✅ **Better bookings** - customers trust experts more
✅ **Premium support** - dedicated account manager

---

## Current Status:

### Badge System Summary:

| Badge | How to Get | Duration | Cost |
|-------|-----------|----------|------|
| ✓ **Verified** | Upload documents | Permanent | Free |
| ⭐ **Premium** | Pay subscription | 30 days | ₹999 or $13 |
| 💎 **Expert** | Apply + get approved + pay | 365 days | ₹4,999 or $50 |

---

## Files Modified:

1. ✅ `lib/services/profile_repository.dart`
   - Changed `isExpert` logic from automatic to subscription-based
   - Added `hasExpertLevelExperience` helper

2. ✅ `lib/main.dart`
   - Changed Expert plan from "Coming Soon" to available
   - Added application dialog with contact info
   - Shows requirements and pricing

3. ✅ `manage_expert_users.sql`
   - SQL queries for finding candidates
   - Commands for granting/revoking expert status
   - Reporting queries for admin

---

## Status: ✅ READY TO USE

Expert badge is now **manually controlled by you**! 

Users can apply, you review, and after payment you grant them expert status. 🎉

No one gets expert badge automatically anymore - you have full control! 💎
