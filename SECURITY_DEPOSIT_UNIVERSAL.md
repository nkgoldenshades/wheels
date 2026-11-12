# Security Deposit - Now Universal for All Service Types ✅

## What Changed

Security deposit is now **available for ALL service types**, not just lease!

### Before (Lease Only)
- ❌ Only lease posts could set security deposit
- ❌ Filter only showed for lease service
- ❌ Passenger/Parcel/Working had no deposit option

### After (Universal)
- ✅ **ALL service types** can now have security deposit
- ✅ Filter available for all services in feed
- ✅ Optional field - providers can choose to require deposit or not

---

## 1. Post Creation (All Services)

### UI Location
**Create Post Screen → Security Deposit Section**

Shows for: **Passenger | Parcel | Lease | Working**

```
🔒 Security Deposit
─────────────────────────────────
Deposit Amount (₹): [________]

💡 Refundable deposit held until service completion
   Leave empty if not required.
```

### Validation
```dart
// Optional for all service types
// If entered, must be > 0
if (depositText.isNotEmpty) {
  if (deposit == null || deposit <= 0) {
    error: "Security deposit must be a positive number"
  }
}
```

### Examples by Service Type

**Passenger Service:**
- Deposit: ₹200
- Use case: Protect against customer no-show on shared rides

**Parcel Service:**
- Deposit: ₹500  
- Use case: Ensure customer picks up parcel on time

**Lease Service:**
- Deposit: ₹2,000
- Use case: Protect against damage or late return

**Working Service:**
- Deposit: ₹1,000
- Use case: Ensure task completion by customer

---

## 2. Feed Filter (All Services)

### UI Location
**Feed Filters → Security Deposit**

Shows for: **All service types selected in filter**

```
Security Deposit
─────────────────────────────────
[With Deposit] [Without] [Both✓]

When "With Deposit" selected:
─────────────────────────────────
Deposit Amount Range

Min Deposit: [____]  Max Deposit: [____]
```

### Filter Options

**☑ With Deposit**
- Shows only posts that have `security_deposit > 0`
- Reveals min/max amount range fields
- Example: Find rides with ₹100-₹500 deposit

**☐ Without**
- Shows only posts with `security_deposit = null OR = 0`
- No deposit required
- Example: Budget-friendly options

**☑ Both (Default)**
- Shows all posts regardless of deposit
- No filtering applied

---

## 3. No-Show Protection (All Services)

### How It Works

**When Deposit is Set:**

1. **Customer Books**
   - Pays: Service Price + Security Deposit
   - Example: ₹1,000 ride + ₹200 deposit = **₹1,200 total**

2. **Service Completed (Normal)**
   - Provider enters OTP
   - Provider receives: **₹1,200** (full amount)
   - Customer receives: **₹0**

3. **Customer No-Show**
   - OTP never verified
   - Slot end_time passes
   - Customer refunded: **₹1,000** (ride price only)
   - Provider keeps: **₹200** (deposit as compensation)

4. **Early Cancellation**
   - Before end_time
   - Customer refunded: **₹1,200** (full amount)
   - Provider receives: **₹0**

---

## 4. Database Schema

### Posts Table
```sql
-- Security deposit available for ALL service types
security_deposit NUMERIC  -- Can be null (no deposit) or > 0
```

### Bookings Table
```sql
security_deposit NUMERIC,      -- Snapshot of deposit at booking time
deposit_snapshot NUMERIC,      -- Alternative column (check your schema)
end_time TIMESTAMP,            -- Service end time
otp_verified BOOLEAN,
status TEXT
```

---

## 5. Use Cases by Service Type

### Passenger Service 🚗
**Why deposit helps:**
- Multi-hour shared rides
- Long-distance intercity trips
- Premium/charter bookings

**Example:**
- 6-hour Chennai → Bangalore ride
- Deposit: ₹300
- Protects provider if customer cancels last minute

### Parcel Service 📦
**Why deposit helps:**
- High-value items
- Same-day delivery commitments
- Perishable goods

**Example:**
- Electronics delivery worth ₹50,000
- Deposit: ₹1,000
- Ensures customer is serious and will receive

### Lease Service 🚗💼
**Why deposit helps:**
- Long-term vehicle rental
- Damage protection
- Late return prevention

**Example:**
- 3-day car rental
- Deposit: ₹5,000
- Covers potential damage or late fees

### Working Service 🔧
**Why deposit helps:**
- Task-based services
- Material costs
- Time commitment

**Example:**
- 4-hour plumbing job
- Deposit: ₹500
- Ensures customer provides access and materials

---

## 6. Provider Benefits

✅ **Flexibility:** Choose whether to require deposit per post  
✅ **Risk Reduction:** Compensation if customer no-shows  
✅ **Quality Signal:** Deposits attract serious customers  
✅ **Auto-Processing:** No manual refund handling needed

---

## 7. Customer Benefits

✅ **Transparency:** See deposit amount before booking  
✅ **Auto-Refund:** Deposit returned on completion  
✅ **Fair Protection:** Only lose deposit if you no-show  
✅ **Choice:** Can filter for posts without deposits

---

## 8. Technical Implementation

### Files Modified

**1. `lib/screens/add_flow/create_post_screen.dart`**
- Added `_buildSecurityDepositSection()` (separate from lease)
- Shows for all service types
- Optional validation (if filled, must be > 0)

**2. `lib/main.dart`**
- Security deposit filter shows for all services
- Filter logic applies to all service types
- Toggle: With / Without / Both

**3. `functions/stripe-escrow.js`**
- No-show detection works for all service types
- Checks `deposit_snapshot` from any booking
- Partial refund logic universal

### Key Code Changes

**Before:**
```dart
// Only for lease
if (widget.serviceType == ServiceType.lease) {
  securityDeposit: double.tryParse(_securityDepositController.text)
}
```

**After:**
```dart
// For ALL service types
securityDeposit: double.tryParse(_securityDepositController.text)
```

**Before:**
```dart
// Filter only lease posts
if (e.slot.serviceType != ServiceType.lease) return true;
```

**After:**
```dart
// Filter ALL service types
final hasDeposit = e.slot.securityDeposit != null && e.slot.securityDeposit! > 0;
```

---

## 9. Migration Notes

### For Existing Posts
- All existing posts have `security_deposit = null` (no deposit)
- No migration needed
- Providers can edit posts to add deposits

### For Existing Code
- No breaking changes
- Backward compatible
- Old posts still work normally

---

## 10. Testing Checklist

**Provider Side:**
- [ ] Create passenger post with deposit
- [ ] Create parcel post with deposit
- [ ] Create lease post with deposit
- [ ] Create working post with deposit
- [ ] Create post WITHOUT deposit (leave field empty)

**Customer Side:**
- [ ] Book post with deposit (pay extra)
- [ ] Complete service (OTP verified) → no refund
- [ ] No-show scenario → partial refund (ride only)
- [ ] Cancel early → full refund

**Feed Filter:**
- [ ] Filter passenger posts: With Deposit
- [ ] Filter parcel posts: Without Deposit
- [ ] Filter lease posts: Deposit ₹1000-₹5000
- [ ] Filter working posts: Both

---

## Summary

🎉 **Security deposit is now a universal feature!**

- ✅ All service types supported
- ✅ Optional per post
- ✅ Feed filter available
- ✅ No-show protection active
- ✅ Backward compatible

Providers now have **maximum flexibility** to protect themselves across all service types, not just lease!
