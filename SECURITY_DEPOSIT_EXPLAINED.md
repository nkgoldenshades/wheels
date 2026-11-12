# 🔐 Security Deposit System - Complete Guide

## What is Security Deposit?

Security deposit is a **refundable amount** held in escrow to protect providers against customer no-shows, primarily used for **Lease** bookings (long-term rentals).

---

## 🎯 How It Works

### 1️⃣ **Provider Sets Deposit (Optional)**
When creating a **Lease** slot, providers can set a security deposit amount:

```dart
// Example: Lease a car for ₹5,000/day + ₹2,000 security deposit
slot.serviceType = 'lease'
slot.price = 500000  // ₹5,000 in paise
slot.securityDeposit = 200000  // ₹2,000 in paise (refundable)
```

**Who uses it?**
- 🚗 **Lease** (car/bike rentals): Most common
- 🚚 **Parcel** delivery: Sometimes used for valuable items
- 🚶 **Ride** sharing: Rarely used

---

### 2️⃣ **Customer Pays Total Amount**

When booking, customer pays:
```
Total Payment = Ride Price + Security Deposit + Commission

Example:
- Ride price: ₹5,000
- Security deposit: ₹2,000
- Commission (10%): ₹500
- Total charged: ₹7,500
```

**Payment held in escrow** (not immediately sent to provider).

---

### 3️⃣ **Two Scenarios After Booking**

## ✅ **Scenario A: Normal Completion (OTP Verified)**

**Customer shows up and completes the ride/lease:**

1. Provider hands over vehicle/parcel
2. Customer receives ride
3. **Provider enters OTP** to confirm handover
4. System captures payment:
   - **Ride price (₹5,000)** → Transferred to provider (minus commission)
   - **Security deposit (₹2,000)** → **REFUNDED to customer immediately**
5. Everyone happy! ✅

```javascript
// Code: functions/stripe-escrow.js (verifyOtp function)
if (OTP verified) {
  Transfer (Ride Price - Commission) to provider
  Refund Security Deposit to customer
  Status: 'completed'
}
```

**Customer gets deposit back because:**
- They showed up on time
- Vehicle/parcel was returned in good condition
- No damage or issues

---

## ❌ **Scenario B: No-Show (OTP NOT Verified)**

**Customer doesn't show up or cancels last minute:**

1. Booking countdown expires (e.g., slot end time passes)
2. OTP was **never verified** by provider
3. System detects **no-show**
4. Auto-refund runs:
   - **Ride price (₹5,000)** → **REFUNDED to customer** (they didn't use service)
   - **Security deposit (₹2,000)** → **KEPT by provider** (compensation for lost time/opportunity)

```javascript
// Code: functions/stripe-escrow.js (autoRefundExpired function)
const isNoShow = 
  !booking.otp_verified &&          // OTP never entered
  slotEndTime < NOW() &&            // Slot time passed
  deposit > 0;                      // Has security deposit

if (isNoShow) {
  Refund (Ride Price) to customer
  Keep (Security Deposit) with provider  // ← Provider compensation!
  Status: 'no_show'
}
```

**Why provider keeps deposit?**
- They blocked their vehicle/time for this booking
- They turned down other potential customers
- They prepared vehicle (fuel, cleaning, etc.)
- Lost income opportunity

---

## 💰 Payment Breakdown Example

### Example: ₹5,000 ride + ₹2,000 deposit

| Scenario | Customer Pays | Customer Gets Back | Provider Receives | Platform Keeps |
|----------|---------------|-------------------|-------------------|----------------|
| **Normal completion (OTP verified)** | ₹7,500 | ₹2,000 (deposit) | ₹4,500 (ride - 10% commission) | ₹500 (commission) |
| **No-show (OTP NOT verified)** | ₹7,500 | ₹5,000 (ride price) | ₹2,000 (deposit kept) | ₹0 |
| **Cancelled before slot time** | ₹7,500 | ₹7,500 (full refund) | ₹0 | ₹0 |

---

## 🔄 Complete Flow Diagram

```
┌─────────────────────────────────────────────────────┐
│ Provider Creates Lease Slot                         │
│ • Price: ₹5,000/day                                 │
│ • Security Deposit: ₹2,000 (optional)               │
└────────────────┬────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────┐
│ Customer Books & Pays ₹7,500 Total                  │
│ (₹5,000 ride + ₹2,000 deposit + ₹500 commission)    │
│ Payment HELD in escrow (Stripe/Razorpay)           │
└────────────────┬────────────────────────────────────┘
                 │
                 ▼
         ┌───────┴────────┐
         │                │
         ▼                ▼
┌────────────────┐  ┌─────────────────┐
│ CUSTOMER       │  │ CUSTOMER        │
│ SHOWS UP ✅    │  │ NO-SHOW ❌      │
└────────┬───────┘  └────────┬────────┘
         │                   │
         ▼                   ▼
┌────────────────┐  ┌─────────────────┐
│ Provider       │  │ Slot time       │
│ enters OTP     │  │ expires,        │
│                │  │ OTP not entered │
└────────┬───────┘  └────────┬────────┘
         │                   │
         ▼                   ▼
┌────────────────┐  ┌─────────────────┐
│ COMPLETED      │  │ NO-SHOW STATUS  │
│                │  │                 │
│ Customer:      │  │ Customer:       │
│ ← ₹2,000       │  │ ← ₹5,000        │
│ (deposit back) │  │ (ride refund)   │
│                │  │                 │
│ Provider:      │  │ Provider:       │
│ ← ₹4,500       │  │ ← ₹2,000        │
│ (ride-com.)    │  │ (keeps deposit) │
└────────────────┘  └─────────────────┘
```

---

## 📊 Database Storage

### Table: `bookings`
```sql
CREATE TABLE bookings (
  ...
  deposit_snapshot NUMERIC DEFAULT 0,  -- Security deposit amount (in paise)
  price_snapshot NUMERIC NOT NULL,     -- Ride price (in paise)
  total_price NUMERIC NOT NULL,        -- price + deposit + commission
  otp_verified BOOLEAN DEFAULT FALSE,  -- Key field for no-show detection!
  end_time TIMESTAMP,                  -- Slot end time
  status VARCHAR,                      -- 'completed', 'no_show', 'refunded'
  ...
);
```

### Key Logic Fields:
- **`deposit_snapshot`**: Security deposit amount saved at booking time
- **`otp_verified`**: `false` = no-show, `true` = normal completion
- **`end_time`**: Slot end time (for no-show detection)
- **`status`**: Booking outcome

---

## 🤖 Auto-Refund System

**Scheduled Task**: Runs **every 1 minute** (Firebase Cloud Function)

```javascript
// File: functions/stripe-escrow.js
exports.autoRefundExpired = schedule('every 1 minutes').onRun(async () => {
  // Find expired bookings
  const expiredBookings = await supabase
    .from('bookings')
    .select('*')
    .eq('status', 'pending')
    .lt('countdown_end_time', NOW());

  for (booking of expiredBookings) {
    const depositAmount = booking.deposit_snapshot;
    const ridePriceAmount = booking.amount - depositAmount;
    const slotEndTime = booking.end_time;
    
    // 🔍 NO-SHOW DETECTION
    const isNoShow = 
      !booking.otp_verified &&        // OTP never verified
      depositAmount > 0 &&            // Has deposit
      slotEndTime <= NOW();           // Slot time passed

    if (isNoShow) {
      // Refund ride price only (provider keeps deposit)
      await stripe.refunds.create({
        payment_intent: booking.stripe_payment_intent_id,
        amount: ridePriceAmount,  // ← NOT full amount!
      });
      
      await supabase.from('bookings').update({
        status: 'no_show',
        refund_note: `Ride: ${ridePriceAmount} refunded. Deposit: ${depositAmount} kept by provider.`
      });
    } else {
      // Full refund (no deposit or cancelled before slot time)
      await stripe.refunds.create({
        amount: booking.amount,  // Full amount
      });
    }
  }
});
```

---

## 🎨 UI Display

### In Slot Card:
```dart
if (slot.securityDeposit != null && slot.securityDeposit! > 0) {
  Text('🔒 Security Deposit: ${formatMoney(slot.securityDeposit!)} (refundable)')
}
```

### In Booking Confirmation:
```dart
if (isLease && deposit > 0) {
  _InfoRow(
    icon: Icons.security,
    text: 'Security deposit: ${formatMoney(deposit)} (refundable on handover)',
  )
}
```

### In Booking History (No-Show):
```dart
if (booking.status == 'no_show') {
  Text(
    isRider 
      ? 'No-show: ride price refunded. Deposit kept by provider.'
      : 'Customer no-show: security deposit kept as compensation.'
  )
}
```

---

## 🚨 Important Rules

### ✅ DO's:
1. **Set reasonable deposits** (10-20% of ride price)
2. **Clearly show deposit amount** before booking
3. **Return deposit immediately** when OTP verified
4. **Use for Lease/high-value bookings** only

### ❌ DON'Ts:
1. **Don't charge excessive deposits** (customers won't book)
2. **Don't use for short rides** (unnecessary friction)
3. **Don't manually process** (system handles automatically)
4. **Don't skip OTP entry** (causes no-show false positive!)

---

## 🔧 For Admins

### Check Deposit Status:
```sql
-- See all no-show bookings with deposits
SELECT 
  id,
  profile_customer_id,
  profile_provider_id,
  price_snapshot / 100 AS ride_price_rupees,
  deposit_snapshot / 100 AS deposit_rupees,
  otp_verified,
  status,
  refund_note
FROM bookings
WHERE status = 'no_show'
  AND deposit_snapshot > 0
ORDER BY created_at DESC;
```

### Manual Refund (if needed):
```sql
-- Force full refund (including deposit)
-- Only do this if customer was wrongly marked as no-show!
UPDATE bookings
SET status = 'refunded'
WHERE id = 'booking_id_here';

-- Then manually refund via Stripe/Razorpay dashboard
```

---

## 💡 Real-World Example

**Scenario**: Car lease in Chennai

**Provider**: Raj (has BMW 3 Series)
- Daily rate: ₹8,000
- Security deposit: ₹2,000
- Listing: "₹8,000/day + ₹2,000 refundable deposit"

**Customer 1**: Priya (shows up) ✅
1. Books 3 days: (₹8,000 × 3) + ₹2,000 = **₹26,000** paid
2. Picks up car, Raj enters OTP
3. Returns car after 3 days in good condition
4. **Priya gets**: ₹2,000 deposit refunded immediately
5. **Raj gets**: ₹21,600 (₹24,000 - 10% commission)

**Customer 2**: Kumar (no-show) ❌
1. Books 1 day: ₹8,000 + ₹2,000 = **₹10,000** paid
2. Doesn't show up, phone switched off
3. Booking time expires, OTP never entered
4. Auto-refund kicks in after 1 minute:
   - **Kumar gets**: ₹8,000 (ride price refunded)
   - **Raj keeps**: ₹2,000 (compensation for wasted day)

**Result**: Raj lost a booking day but got compensated ₹2,000 for his time.

---

## 📱 Customer FAQ

**Q: When do I get my deposit back?**
A: Immediately when provider confirms handover (enters OTP).

**Q: What if provider doesn't enter OTP?**
A: After slot time expires, you get full ride price back. Provider keeps deposit.

**Q: Can I cancel and get deposit back?**
A: Yes, if you cancel before slot start time, you get full refund (ride + deposit).

**Q: What if I damage the vehicle?**
A: Provider should note damage before entering OTP. Actual damages are handled separately (not covered by deposit).

---

## 🏪 Provider FAQ

**Q: Should I always charge a deposit?**
A: Only for Lease bookings or high-value items. Not needed for short rides.

**Q: What if customer no-shows?**
A: You keep the security deposit automatically as compensation.

**Q: How much deposit should I charge?**
A: 10-25% of total ride price. Too high = fewer bookings.

**Q: What if I forget to enter OTP?**
A: You lose the ride payment but keep the deposit. **Always enter OTP** when customer shows up!

---

## ✅ Summary

| Feature | Details |
|---------|---------|
| **Purpose** | Protect providers against no-shows |
| **Who sets it** | Provider (optional) |
| **When charged** | At booking time (held in escrow) |
| **Normal flow** | Refunded to customer when OTP verified |
| **No-show flow** | Kept by provider as compensation |
| **Amount** | Typically 10-25% of ride price |
| **Service types** | Mainly Lease, sometimes Parcel |
| **Automation** | Fully automatic (runs every 1 minute) |

---

**Security deposit = Fair compensation system that protects both customers and providers!** 🤝
