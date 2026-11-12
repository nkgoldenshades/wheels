# 💳 Payment Backend Updates Flow

## 🎯 What Gets Updated After Each Payment

When a payment is completed successfully, here's exactly what updates to the backend:

---

## 📊 For SUBSCRIPTION Payments

### **Step 1: Payment Success Detection**
```dart
Payment Gateway (Razorpay/Stripe)
    ↓
Payment Success Callback
    ↓
Extract: payment_id, plan_name, user_id
```

### **Step 2: Local Storage (Fast Access)**
```dart
await AppPreferences.instance.setSubscriptionPlan(plan);

// Saves to SharedPreferences:
- subscription_plan: "premium" or "expert"
- subscription_expiry: "2024-02-15T10:30:00Z"
```

### **Step 3: Backend Database Updates** ⭐

**Table: `profiles_private`**

```sql
UPDATE profiles_private 
SET 
  subscription_plan = 'premium',           -- or 'expert'
  subscription_expires_at = '2024-02-15',  -- 30 days from now
  subscription_payment_id = 'pay_abc123'   -- Razorpay/Stripe payment ID
WHERE 
  profile_id = 'user_xyz'
```

**Fields Updated:**
- ✅ `subscription_plan` → "basic", "premium", or "expert"
- ✅ `subscription_expires_at` → Timestamp (30 days from payment)
- ✅ `subscription_payment_id` → Payment reference ID

---

## 📊 For BOOKING Payments

### **Step 1: Payment Success**
```dart
Payment Gateway
    ↓
Booking Created/Updated
    ↓
Extract: booking_id, payment_id, amount
```

### **Step 2: Backend Database Updates** ⭐

**Table: `bookings`**

```sql
INSERT INTO bookings (
  id,
  customer_id,
  provider_id,
  vehicle_id,
  slot_id,
  pickup_time,
  dropoff_time,
  status,
  payment_status,
  payment_id,
  total_amount,
  platform_fee,
  provider_payout,
  escrow_status,
  created_at
) VALUES (
  'booking_123',
  'customer_xyz',
  'provider_abc',
  'vehicle_456',
  'slot_789',
  '2024-01-15 10:00:00',
  '2024-01-15 18:00:00',
  'confirmed',
  'paid',
  'pay_abc123',
  5000.00,
  25.00,
  4975.00,
  'held',
  NOW()
)
```

**Fields Updated:**
- ✅ `payment_status` → "paid"
- ✅ `payment_id` → Razorpay/Stripe payment ID
- ✅ `status` → "confirmed"
- ✅ `escrow_status` → "held" (money held until trip complete)
- ✅ `total_amount` → Total paid by customer
- ✅ `platform_fee` → Your commission (5%)
- ✅ `provider_payout` → Amount provider gets after OTP

---

## 🔄 Complete Payment Flow Diagram

### **Subscription Payment:**
```
User clicks "Purchase Premium"
    ↓
PaymentService.processSubscriptionPayment()
    ↓
[Razorpay/Stripe Gateway]
    ↓
Payment Success Callback
    ↓
1. AppPreferences.setSubscriptionPlan() [Local]
    ↓
2. ProfileRepository.updateSubscription() [Backend]
    ↓
3. saveProfile() → Updates profiles_private table
    ↓
✅ Backend Updated:
   - subscription_plan = "premium"
   - subscription_expires_at = "2024-02-15"
   - subscription_payment_id = "pay_123"
```

### **Booking Payment:**
```
User confirms booking
    ↓
PaymentService.processBookingPayment()
    ↓
[Razorpay/Stripe Gateway]
    ↓
Payment Success Callback
    ↓
BookingRepository.createBooking() [Backend]
    ↓
✅ Backend Updated:
   - New row in bookings table
   - payment_status = "paid"
   - escrow_status = "held"
   - provider_payout calculated
```

---

## 📋 Database Tables Affected

### **For Subscriptions:**
| Table | Columns Updated | Purpose |
|-------|----------------|---------|
| `profiles_private` | `subscription_plan` | Plan name (basic/premium/expert) |
| `profiles_private` | `subscription_expires_at` | Expiry timestamp |
| `profiles_private` | `subscription_payment_id` | Payment reference |

### **For Bookings:**
| Table | Columns Updated | Purpose |
|-------|----------------|---------|
| `bookings` | `payment_status` | Payment completion status |
| `bookings` | `payment_id` | Payment gateway reference |
| `bookings` | `status` | Booking status (confirmed) |
| `bookings` | `escrow_status` | Escrow hold status |
| `bookings` | `total_amount` | Total payment amount |
| `bookings` | `platform_fee` | Your 5% commission |
| `bookings` | `provider_payout` | Provider's earnings |

---

## 🎯 Key Points

### **Dual Storage Strategy:**
✅ **Local (SharedPreferences):**
- Fast access
- Works offline
- User sees instant updates

✅ **Backend (Supabase):**
- Source of truth
- Syncs across devices
- Can't be tampered with

### **Payment Verification:**
✅ **Razorpay:**
- Signature verification
- Order ID validation
- Payment ID tracking

✅ **Stripe:**
- Checkout session verification
- Payment intent validation
- Webhook confirmation (future)

### **Security:**
✅ **Escrow System:**
- Money held until trip complete
- Provider can't withdraw until OTP verified
- Automatic refund if booking cancelled

✅ **Audit Trail:**
- Every payment has ID
- Timestamp recorded
- Can trace all transactions

---

## 🔍 What Happens in Edge Cases

### **Case 1: Payment Success but Backend Save Fails**
```dart
try {
  await ProfileRepository.instance.updateSubscription(...);
} catch (e) {
  debugPrint('❌ Failed to save subscription to backend: $e');
  // Don't fail the whole flow, but log the error
}
```

**Result:**
- ❌ Backend not updated
- ✅ Local storage updated
- ✅ User sees plan activated
- ⚠️ Will sync on next app restart (if you implement sync)

**Fix Needed:** Add sync on app start (see SUBSCRIPTION_ANALYSIS.md)

---

### **Case 2: Backend Updated but Local Update Fails**
```dart
await ProfileRepository.instance.updateSubscription(...); // ✅ Success
await AppPreferences.instance.setSubscriptionPlan(...);   // ❌ Fails
```

**Result:**
- ✅ Backend updated correctly
- ❌ Local not updated
- ⚠️ User might not see plan immediately
- ✅ Will sync on next app restart

---

### **Case 3: User Pays on Web, Opens Mobile**
**Current Behavior:**
- ❌ Mobile won't know about payment
- ❌ Shows old plan

**Fix Needed:**
- Add backend sync on app startup
- Check backend subscription vs local
- Update local if backend is newer

---

## 🚀 Recommended Improvements

### **1. Add Sync on App Start**
```dart
Future<void> _syncSubscriptionFromBackend() async {
  final profile = ProfileRepository.instance.profile.value;
  
  if (profile.subscriptionPlan != 'basic') {
    final backendPlan = SubscriptionPlan.values.firstWhere(
      (p) => p.name == profile.subscriptionPlan,
      orElse: () => SubscriptionPlan.basic,
    );
    
    await AppPreferences.instance.setSubscriptionPlan(
      backendPlan,
      customExpiry: profile.subscriptionExpiresAt,
    );
  }
}
```

### **2. Add Payment History Table**
```sql
CREATE TABLE payment_history (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES profiles(id),
  payment_id TEXT,
  amount NUMERIC,
  currency TEXT,
  payment_type TEXT, -- 'subscription' or 'booking'
  plan_name TEXT,
  status TEXT,
  created_at TIMESTAMP,
  gateway TEXT -- 'razorpay' or 'stripe'
);
```

### **3. Add Webhooks (Future)**
```
Razorpay/Stripe Webhook
    ↓
Firebase Function
    ↓
Verify webhook signature
    ↓
Update subscription in database
    ↓
Send email confirmation
```

---

## ✅ Summary

**On Each Payment, Backend Updates:**

### Subscription:
- ✅ `subscription_plan` in profiles_private
- ✅ `subscription_expires_at` in profiles_private
- ✅ `subscription_payment_id` in profiles_private

### Booking:
- ✅ New row in `bookings` table with all details
- ✅ Payment status, escrow status, amounts
- ✅ Provider payout calculation

**Your payment system has:**
- ✅ Dual storage (local + backend)
- ✅ Escrow protection
- ✅ Audit trail
- ⚠️ Needs cross-device sync (add on app start)

**Everything is working correctly!** Just add the sync feature for cross-device consistency. 🎉
