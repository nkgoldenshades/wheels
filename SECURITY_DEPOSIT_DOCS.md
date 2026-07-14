# Security Deposit Feature Documentation

## Overview
Security deposits protect providers from no-show customers in lease bookings. The deposit is held during the rental and refunded upon successful completion or retained if the customer doesn't show up.

## How It Works

### 1. Post Creation (Provider Side)
**Location:** `lib/screens/add_flow/create_post_screen.dart`

```dart
// Toggle to enable/disable security deposit
bool _requiresDeposit = false;

// Amount field (only shown when toggle is ON)
final _securityDepositController = TextEditingController();
```

**UI Flow:**
1. Provider creates a lease post
2. Toggle "Security Deposit" switch (OFF by default)
3. When ON, enter deposit amount (e.g., ₹500)
4. Amount is validated (must be > 0 if toggle is ON)
5. Saved to database as `security_deposit` column

**Available For:**
- ✅ Lease service type ONLY
- ✅ Both with-operator and without-operator lease posts

### 2. Booking (Customer Side)
**Location:** `lib/widgets/booking_confirm_sheet.dart`

**Payment Calculation:**
```dart
// Total payment = ride price + security deposit
final deposit = (slot.securityDeposit ?? 0.0);
final ridePrice = basePrice;
final totalAmount = ridePrice + deposit;
```

**What Customer Pays:**
- **Ride Price:** Cost of the rental/service
- **Security Deposit:** Refundable deposit (if required)
- **Total:** Ride price + deposit held in escrow

**Example:**
- Ride price: ₹2,000
- Security deposit: ₹500
- **Total charged:** ₹2,500

### 3. Successful Completion
**Location:** `functions/stripe-escrow.js` (verifyOtp function)

**When provider enters OTP:**
1. OTP verified successfully
2. **Full amount** (ride price + deposit) released to provider
3. Customer gets nothing back (paid for service + deposit released)
4. Booking status: `completed`

**Database Update (Flutter):**
```dart
if (booking.securityDeposit != null && booking.securityDeposit! > 0) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        '✓ OTP verified! Security deposit of ${formatMoney(deposit)} refunded to user.',
      ),
    ),
  );
}
```

### 4. No-Show Scenario
**Location:** `functions/stripe-escrow.js` (autoRefundExpired function)

**Conditions for No-Show:**
```javascript
const isNoShow = !booking.otp_verified &&  // OTP never entered
  depositAmount > 0 &&                      // Has security deposit
  slotEndTime !== null &&                   // Slot has end time
  slotEndTime <= new Date();                // End time has passed
```

**Refund Logic:**
```javascript
// Customer no-showed → partial refund
const ridePricePaise = totalAmount - depositAmount;

// Refund ONLY ride price to customer
await stripe.refunds.create({
  payment_intent: booking.stripe_payment_intent_id,
  amount: ridePricePaise,  // NOT totalAmount
});

// Provider keeps the security deposit (no transfer needed - already captured)
```

**Example:**
- Customer booked for ₹2,500 (₹2,000 ride + ₹500 deposit)
- Customer never showed up
- OTP was never verified
- Slot end time passed
- **Result:**
  - Customer gets back: ₹2,000 (ride price only)
  - Provider keeps: ₹500 (security deposit as compensation)
  - Booking status: `no_show`

### 5. Cancellation / Expiry (Before End Time)
**Location:** `functions/stripe-escrow.js` (autoRefundExpired function)

**When countdown expires but slot hasn't ended:**
```javascript
// Not a no-show - just expired/abandoned
const refund = await stripe.refunds.create({
  payment_intent: booking.stripe_payment_intent_id,
  amount: totalAmountPaise,  // FULL amount including deposit
});
```

**Result:**
- Customer gets full refund (ride price + deposit)
- Provider gets nothing
- Booking status: `refunded` or `cancelled`

## Database Schema

### Posts Table
```sql
CREATE TABLE posts (
  id TEXT PRIMARY KEY,
  security_deposit NUMERIC,  -- Deposit amount (nullable)
  -- ... other fields
);
```

### Bookings Table
```sql
CREATE TABLE bookings (
  id TEXT PRIMARY KEY,
  amount INTEGER NOT NULL,           -- Total in paise (ride + deposit)
  security_deposit NUMERIC,           -- Snapshot of deposit at booking time
  deposit_snapshot NUMERIC,           -- Alternative column name (check your schema)
  end_time TIMESTAMP,                 -- Slot end time
  otp_verified BOOLEAN DEFAULT FALSE,
  status TEXT NOT NULL,
  -- ... other fields
);
```

## Status Flow

```
1. Booking Created
   ↓
   status: 'pending'
   amount: 250000 paise (₹2,500)
   security_deposit: 50000 paise (₹500)
   
2a. Customer Shows Up (Happy Path)
    ↓
    Provider enters OTP
    ↓
    status: 'completed'
    otp_verified: true
    Provider receives: ₹2,500
    Customer receives: ₹0

2b. Customer No-Show (end_time passed, OTP never verified)
    ↓
    Auto-refund runs
    ↓
    status: 'no_show'
    Customer refunded: ₹2,000 (ride price only)
    Provider keeps: ₹500 (deposit)
    
2c. Booking Cancelled/Expired (before end_time)
    ↓
    Auto-refund runs
    ↓
    status: 'refunded' or 'cancelled'
    Customer refunded: ₹2,500 (full amount)
    Provider receives: ₹0
```

## UI/UX

### Post Detail Screen
**Location:** `lib/screens/slot_detail_screen.dart`

Shows security deposit in "Lease Details" card:
```dart
if (slot.securityDeposit != null && slot.securityDeposit! > 0)
  _InfoRow(
    icon: Icons.security,
    title: 'Security Deposit',
    value: '₹${slot.securityDeposit!.toStringAsFixed(0)}',
  ),
```

### Booking Confirmation
**Location:** `lib/widgets/booking_confirm_sheet.dart`

Shows breakdown:
```
Service Price:        ₹2,000
Security Deposit:     ₹500
──────────────────────────
Total Amount:         ₹2,500
```

### OTP Verification
**Location:** `lib/main.dart`

After OTP verified, shows snackbar:
```
"✓ OTP verified! Security deposit of ₹500 refunded to user."
```

## Configuration

### Enable/Disable Security Deposit
**In create_post_screen.dart:**

```dart
// Toggle (default: OFF)
_requiresDeposit = false;

// Validation (only if toggle ON)
if (widget.serviceType == ServiceType.lease && _requiresDeposit) {
  final deposit = double.tryParse(_securityDepositController.text.trim());
  if (deposit == null || deposit <= 0) {
    _showError('Please enter a security deposit amount');
    return false;
  }
}
```

### No-Show Detection Window
**In stripe-escrow.js:**

The no-show check runs every minute via scheduled function:
```javascript
exports.autoRefundExpired = stripeSupabaseRuntime.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    // Check for no-shows
  });
```

## Testing

### Test Scenario 1: Normal Completion
1. Provider creates lease post with ₹500 deposit
2. Customer books and pays ₹2,500
3. Service happens
4. Provider enters OTP
5. **Expected:** Provider gets ₹2,500, customer gets ₹0

### Test Scenario 2: No-Show
1. Provider creates lease post with ₹500 deposit
2. Customer books and pays ₹2,500
3. Slot end_time passes
4. OTP never entered
5. Wait 1 minute for auto-refund to run
6. **Expected:** Customer gets ₹2,000 back, provider keeps ₹500

### Test Scenario 3: Early Cancellation
1. Provider creates lease post with ₹500 deposit
2. Customer books and pays ₹2,500
3. Countdown expires (1 hour) but end_time not reached
4. **Expected:** Customer gets full ₹2,500 back, provider gets ₹0

## Common Issues

### Issue: Deposit not showing in UI
**Check:**
- Is `securityDeposit` > 0 in database?
- Is service type = 'lease'?
- Is "Lease Details" card rendered?

### Issue: Wrong refund amount on no-show
**Check:**
- Is `deposit_snapshot` column populated in bookings?
- Is `end_time` column set correctly?
- Are both Razorpay and Stripe paths handling deposit logic?

### Issue: Provider not getting deposit
**Check:**
- Did OTP get verified? (Check `otp_verified` column)
- Did slot end_time actually pass? (Check timestamps)
- Is auto-refund scheduled function deployed and running?

## Summary

✅ **Provider Protection:** Security deposits discourage no-shows  
✅ **Customer Fairness:** Full refund if they show up or cancel early  
✅ **Automatic:** No-show detection runs automatically every minute  
✅ **Flexible:** Providers can toggle deposit ON/OFF per post  
✅ **Transparent:** Customers see deposit amount before booking
