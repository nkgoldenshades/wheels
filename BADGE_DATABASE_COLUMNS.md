# 🏅 Badge System - Database Columns Reference

## Overview

Your app has **3 types of badges** determined by different database columns.

---

## 1. ✓ Verified Badge (Document-Based)

### Criteria:
At least **ONE** of these documents must be verified.

### Database Columns (Table: `profiles_private`):

| Column Name | Type | Description |
|-------------|------|-------------|
| `aadhaar_verified` | boolean | Aadhaar card verified |
| `pan_verified` | boolean | PAN card verified |
| `driving_license_verified` | boolean | Driving license verified |

### Logic:
```dart
bool get isVerified {
  return aadhaarVerified || panVerified || dlVerified;
}
```

### Status:
- ✅ **Permanent** - Once set to `true`, stays forever
- 🎯 **Purpose** - Proves identity/KYC compliance

### How to Set:
```sql
-- Verify user's Aadhaar (example)
UPDATE profiles_private 
SET aadhaar_verified = true 
WHERE profile_id = 'user_id_here';

-- Verify user's PAN
UPDATE profiles_private 
SET pan_verified = true 
WHERE profile_id = 'user_id_here';

-- Verify user's Driving License
UPDATE profiles_private 
SET dl_verified = true 
WHERE profile_id = 'user_id_here';
```

---

## 2. ⭐ Premium Badge (Subscription-Based)

### Criteria:
- Subscription plan = `'premium'`
- Subscription NOT expired

### Database Columns (Table: `profiles_private`):

| Column Name | Type | Description |
|-------------|------|-------------|
| `subscription_plan` | text | Plan name: 'basic', 'premium', or 'expert' |
| `subscription_expires_at` | timestamptz | When subscription expires |
| `subscription_payment_id` | text | Payment reference (optional) |

### Logic:
```dart
bool get isPremium {
  return subscriptionPlan == 'premium' && hasActiveSubscription;
}

bool get hasActiveSubscription {
  if (subscriptionPlan == 'basic') return false;
  if (subscriptionExpiresAt == null) return false;
  return subscriptionExpiresAt!.isAfter(DateTime.now());
}
```

### Status:
- ⏰ **Temporary** - Expires after 30 days
- 🔄 **Auto-downgrade** - Database function resets to 'basic' when expired
- 💰 **Paid feature** - Requires payment to activate

### How to Set:
```sql
-- Give user Premium for 30 days
UPDATE profiles_private 
SET 
  subscription_plan = 'premium',
  subscription_expires_at = NOW() + INTERVAL '30 days',
  subscription_payment_id = 'pay_xyz123'
WHERE profile_id = 'user_id_here';

-- Check if expired
SELECT 
  profile_id,
  subscription_plan,
  subscription_expires_at,
  subscription_expires_at < NOW() as is_expired
FROM profiles_private
WHERE subscription_plan != 'basic';
```

### Auto-Downgrade System:
```sql
-- Runs daily at 2 AM UTC (Firebase scheduled function)
-- File: auto_downgrade_expired_subscriptions.sql
CREATE OR REPLACE FUNCTION auto_downgrade_expired_subscriptions()
RETURNS void AS $$
BEGIN
  UPDATE profiles_private
  SET subscription_plan = 'basic'
  WHERE subscription_plan != 'basic'
    AND subscription_expires_at < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 3. 💎 Expert Badge (Experience-Based)

### Criteria:
Either provider OR customer stats meet requirements:
- **50+ completed trips** (providerTotalTrips or customerTotalTrips)
- **4.5+ rating** (providerRating or customerRating)

### Database Columns (Table: `profiles_public`):

| Column Name | Type | Description |
|-------------|------|-------------|
| `provider_rating` | numeric | Average rating as provider (0-5) |
| `provider_total_reviews` | integer | Total reviews received as provider |
| `provider_total_trips` | integer | Total trips completed as provider |
| `customer_rating` | numeric | Average rating as customer (0-5) |
| `customer_total_reviews` | integer | Total reviews received as customer |
| `customer_total_trips` | integer | Total trips completed as customer |

### Logic:
```dart
bool get isExpert {
  // Check provider stats
  final providerQualifies = providerTotalTrips >= 50 && providerRating >= 4.5;
  
  // Check customer stats
  final customerQualifies = customerTotalTrips >= 50 && customerRating >= 4.5;
  
  return providerQualifies || customerQualifies;
}
```

### Status:
- ✅ **Earned** - Not paid, earned through usage
- 📈 **Automatic** - Updates when trip count/rating changes
- 🎖️ **Reputation-based** - Shows expertise/experience

### How It Updates:
```sql
-- Automatically updated after each booking completion
-- Example: Provider completes a trip
UPDATE profiles_public 
SET 
  provider_total_trips = provider_total_trips + 1,
  provider_rating = (
    SELECT AVG(rating) 
    FROM reviews 
    WHERE reviewed_profile_id = 'provider_id'
  )
WHERE id = 'provider_id';
```

---

## Badge Hierarchy / Priority

When multiple badges apply, show them in this order:

### Option 1: Show All Badges
```
💎 Expert  +  ⭐ Premium  +  ✓ Verified
```

### Option 2: Show Highest Only (Recommended)
```
Priority:
1. 💎 Expert (hardest to earn)
2. ⭐ Premium (paid subscription)
3. ✓ Verified (basic identity check)
```

---

## Database Schema Summary

### Table: `profiles_private`
```sql
-- Verified Badge
aadhaar_verified        boolean DEFAULT false
pan_verified            boolean DEFAULT false
driving_license_verified boolean DEFAULT false

-- Premium/Expert Subscription Badge
subscription_plan        text DEFAULT 'basic'
subscription_expires_at  timestamptz
subscription_payment_id  text
```

### Table: `profiles_public`
```sql
-- Expert Badge (Provider side)
provider_rating         numeric DEFAULT 0.0
provider_total_reviews  integer DEFAULT 0
provider_total_trips    integer DEFAULT 0

-- Expert Badge (Customer side)
customer_rating         numeric DEFAULT 0.0
customer_total_reviews  integer DEFAULT 0
customer_total_trips    integer DEFAULT 0
```

---

## Badge Logic Flow

### User Journey Example:

1. **New User** (No badge)
   - All verification flags = `false`
   - subscription_plan = `'basic'`
   - provider_total_trips = `0`

2. **Uploads Document** → ✓ Verified Badge
   ```sql
   UPDATE profiles_private 
   SET aadhaar_verified = true 
   WHERE profile_id = 'user_123';
   ```

3. **Pays for Premium** → ⭐ Premium Badge
   ```sql
   UPDATE profiles_private 
   SET 
     subscription_plan = 'premium',
     subscription_expires_at = NOW() + INTERVAL '30 days'
   WHERE profile_id = 'user_123';
   ```

4. **Completes 50 Trips with 4.5+ Rating** → 💎 Expert Badge
   ```sql
   -- Auto-updated after reviews
   -- No manual query needed
   ```

---

## Quick Reference Table

| Badge | Database Table | Key Columns | Criteria | Duration |
|-------|---------------|-------------|----------|----------|
| **✓ Verified** | profiles_private | aadhaar_verified, pan_verified, dl_verified | At least 1 = true | Permanent |
| **⭐ Premium** | profiles_private | subscription_plan, subscription_expires_at | plan = 'premium' AND not expired | 30 days |
| **💎 Expert** | profiles_public | provider_total_trips, provider_rating | 50+ trips AND 4.5+ rating | Permanent (earned) |

---

## SQL Queries for Admin

### Check User Badges:
```sql
SELECT 
  pub.id,
  pub.full_name,
  
  -- Verified badge
  CASE 
    WHEN priv.aadhaar_verified OR priv.pan_verified OR priv.driving_license_verified 
    THEN '✓ Verified' 
    ELSE '' 
  END as verified_badge,
  
  -- Premium badge
  CASE 
    WHEN priv.subscription_plan = 'premium' 
         AND priv.subscription_expires_at > NOW() 
    THEN '⭐ Premium' 
    ELSE '' 
  END as premium_badge,
  
  -- Expert badge
  CASE 
    WHEN (pub.provider_total_trips >= 50 AND pub.provider_rating >= 4.5)
         OR (pub.customer_total_trips >= 50 AND pub.customer_rating >= 4.5)
    THEN '💎 Expert' 
    ELSE '' 
  END as expert_badge
  
FROM profiles_public pub
LEFT JOIN profiles_private priv ON pub.id = priv.profile_id
WHERE pub.id = 'user_id_here';
```

### Find All Premium Users:
```sql
SELECT 
  pub.full_name,
  priv.subscription_plan,
  priv.subscription_expires_at,
  priv.subscription_expires_at > NOW() as is_active
FROM profiles_public pub
JOIN profiles_private priv ON pub.id = priv.profile_id
WHERE priv.subscription_plan != 'basic'
ORDER BY priv.subscription_expires_at DESC;
```

### Find All Expert Users:
```sql
SELECT 
  id,
  full_name,
  provider_total_trips,
  provider_rating,
  customer_total_trips,
  customer_rating
FROM profiles_public
WHERE (provider_total_trips >= 50 AND provider_rating >= 4.5)
   OR (customer_total_trips >= 50 AND customer_rating >= 4.5)
ORDER BY provider_total_trips DESC;
```

---

## Status: ✅ Current Implementation

All badge logic is implemented and working! 🎉
