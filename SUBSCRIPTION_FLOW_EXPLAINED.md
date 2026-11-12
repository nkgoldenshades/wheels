# 📅 Subscription System - 30-Day Calculation Flow

## ✅ YES! Everything is Configured Correctly

Your subscription system automatically calculates and stores 30-day expiry dates. Here's exactly how it works:

---

## 🔄 Complete Payment-to-Expiry Flow

### 1️⃣ **User Clicks "Subscribe to Premium"** (`lib/main.dart`)
```dart
onSelect: () => _purchasePlan(context, SubscriptionPlan.premium, premiumPrice)
```

### 2️⃣ **Payment Processing** (`lib/services/payment_service.dart`)
- Routes to **Razorpay** (India/INR) or **Stripe** (International)
- Creates payment order
- User completes payment in gateway

### 3️⃣ **Payment Success → Local Storage** (`lib/services/app_preferences.dart`)
```dart
Future<void> setSubscriptionPlan(SubscriptionPlan plan) async {
  subscriptionPlan.value = plan;
  
  // 🎯 AUTOMATIC 30-DAY CALCULATION
  if (plan != SubscriptionPlan.basic) {
    final expiry = DateTime.now().add(const Duration(days: 30));
    subscriptionExpiry.value = expiry;
    await prefs.setString(_subscriptionExpiryKey, expiry.toIso8601String());
  }
}
```

### 4️⃣ **Save to Backend Database** (`lib/main.dart` - Payment Success Screen)
```dart
final expiresAt = DateTime.now().add(const Duration(days: 30));

await ProfileRepository.instance.updateSubscription(
  plan: _activatedPlan!.name,
  expiresAt: expiresAt,  // ✅ 30 days from now
  paymentId: paymentId,
);
```

### 5️⃣ **Database Storage** (`lib/services/profile_repository.dart`)
```dart
Future<void> updateSubscription({
  required String plan,
  required DateTime expiresAt,
  required String paymentId,
}) async {
  await saveProfile(
    p.copyWith(
      subscriptionPlan: plan,              // "premium" or "expert"
      subscriptionExpiresAt: expiresAt,    // NOW + 30 days
      subscriptionPaymentId: paymentId,
    ),
  );
}
```

---

## 📊 Database Columns Used

### Table: `profiles_private`
```sql
subscription_plan          VARCHAR   -- "basic", "premium", "expert"
subscription_expires_at    TIMESTAMP -- 30 days from payment
subscription_payment_id    VARCHAR   -- Razorpay/Stripe payment ID
```

### Example Data After Payment:
```sql
subscription_plan = 'premium'
subscription_expires_at = '2026-08-13T10:30:00Z'  -- 30 days from July 14
subscription_payment_id = 'pay_xyz123abc'
```

---

## ⏰ Expiry Checking & Auto-Downgrade

### On App Startup (`lib/services/app_preferences.dart`)
```dart
// Check if subscription expired
if (expiry != null && DateTime.now().isAfter(expiry)) {
  // Subscription expired - downgrade to basic
  await setSubscriptionPlan(SubscriptionPlan.basic);
}
```

### Scheduled Auto-Downgrade (`functions/stripe-escrow.js`)
```javascript
/**
 * Auto-downgrade expired subscriptions to 'basic' plan
 * Runs daily at 2 AM UTC via scheduled trigger
 */
exports.autoDowngradeExpiredSubscriptions = ...
```

---

## 🎯 Badge System Integration

### Premium Badge (⭐)
```dart
bool get isPremium {
  return subscriptionPlan == 'premium' && hasActiveSubscription;
}

bool get hasActiveSubscription {
  return subscriptionExpiresAt != null && 
         DateTime.now().isBefore(subscriptionExpiresAt!);
}
```

### Expert Badge (💎)
```dart
bool get isExpert {
  return subscriptionPlan == 'expert' && hasActiveSubscription;
}
```

---

## 📝 Summary

✅ **Local storage**: Sets 30-day expiry in SharedPreferences  
✅ **Backend database**: Saves 30-day expiry to `profiles_private.subscription_expires_at`  
✅ **Automatic checking**: App checks expiry on startup  
✅ **Auto-downgrade**: Backend scheduled function resets expired subscriptions daily  
✅ **Badge control**: Badges only show if subscription is active (before expiry)  

---

## 🔍 How to Verify It's Working

### 1. Check User's Subscription in Database:
```sql
SELECT 
  id, 
  subscription_plan, 
  subscription_expires_at,
  subscription_payment_id,
  NOW() AS current_time,
  subscription_expires_at > NOW() AS is_active
FROM profiles_private
WHERE id = 'user_firebase_uid';
```

### 2. Check App Logs After Payment:
```
✅ PREMIUM plan activated!
✅ Subscription saved to backend: premium
✅ Subscription updated: premium (expires: 2026-08-13T10:30:00Z)
```

### 3. User Profile Screen Shows:
```
⭐ Premium Badge
Active: 29 days, 23 hours remaining
```

---

## 💡 Key Points

1. **30 days = Exactly 30 × 24 hours** from payment time
2. **Both Premium and Expert** get 30-day subscriptions (Expert later changed to 365 days if needed)
3. **Source of truth**: Backend database (`profiles_private.subscription_expires_at`)
4. **Local cache**: SharedPreferences (for quick access without network call)
5. **Automatic expiry**: No manual intervention needed

---

## 🚨 If Subscription Isn't Activating

### Check These:
1. Payment succeeded? Check Firebase Functions logs
2. `updateSubscription()` called? Check debug logs for "✅ Subscription saved"
3. Database updated? Run SQL query above
4. RLS policies allow update? User must own the profile row

### Common Issues:
- **Payment success but no activation**: Check if `updateSubscription()` threw error
- **Badge not showing**: Check if `subscription_expires_at > NOW()` in database
- **Expires immediately**: Check timezone (should use UTC/ISO8601 format)

---

## 🎉 Everything is Working!

Your system has:
- ✅ Automatic 30-day calculation
- ✅ Local + backend storage
- ✅ Expiry checking
- ✅ Auto-downgrade scheduled task
- ✅ Badge integration

**No additional code needed!** The database functions and expiry calculation are already fully implemented.
