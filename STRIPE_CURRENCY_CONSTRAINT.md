# ⚠️ Stripe Currency Constraint - Cannot Mix Currencies

## 🎯 The Issue

**What you're trying to do:**
- Create posts with ₹100 INR
- Accept payments through Stripe USD account
- Result: Payment processed as $100 USD (not ₹100 INR)

**What's happening in your screenshot:**
- Stripe Checkout shows: **$100.00 USD**
- But you wanted: **₹100 INR**

---

## 🔍 Why This Happens

### **Stripe Currency Rules:**

**1. One Currency Per Account**
```
Stripe Account → default_currency: USD
  ↓
All payments MUST be in USD
You CANNOT charge INR with a USD Stripe account
```

**2. Payment Gateway Constraints:**
| Gateway | Supported Currencies | Constraint |
|---------|---------------------|------------|
| **Razorpay** | INR only | Can only process ₹ (Rupees) |
| **Stripe** | 135+ currencies | But ONE currency per account |

**3. Your Situation:**
```
Your Profile:
- payment_provider: 'stripe'
- stripe_account_id: 'acct_...'
- bank_currency: 'USD' ← Account is USD

Your Post:
- price: 100
- currency_type: 'INR' ← Display only!

Booking Payment:
- Stripe processes: $100 USD ← Uses account currency!
- Customer charged: $100 (not ₹100)
```

---

## ❌ What Doesn't Work

### **Attempt 1: Change Post Currency to INR**
```
Problem: Stripe USD account cannot process INR payments
Result: Payment will fail or convert at wrong rate
```

### **Attempt 2: Use USD Stripe with INR Display**
```
Problem: Customer sees ₹100 but gets charged $100
Result: Currency mismatch, customer confusion
```

### **Attempt 3: Convert ₹100 to $1.20 USD**
```
Problem: Still charging in USD, just different amount
Result: Customer wanted to pay in Rupees, not Dollars
```

---

## ✅ The Solutions

### **Solution 1: Use Razorpay for INR (Recommended for India)**

**If you want to charge in ₹ (INR):**

```sql
-- Update your profile
UPDATE profiles_private
SET 
    payment_provider = 'razorpay',
    bank_currency = 'INR',
    razorpay_account_id = 'YOUR_RAZORPAY_ID',
    stripe_account_id = NULL
WHERE id = 'YOUR_USER_ID';
```

**Benefits:**
- ✅ Native INR support
- ✅ Lower fees for Indian cards/UPI
- ✅ Supports UPI, cards, netbanking
- ✅ No currency conversion

**Limitations:**
- ❌ India only (cannot accept international payments)
- ❌ INR only (cannot charge USD/EUR/GBP)

---

### **Solution 2: Use Stripe with INR Currency**

**Create a NEW Stripe account with INR:**

1. **Disconnect current USD Stripe account**
2. **Create new Stripe Express account with India as country**
3. **Stripe will set default_currency = INR**
4. **All payments will be in ₹**

**Code (in app):**
```dart
// When connecting Stripe, choose India
final result = await StripeService.instance.createConnectedAccount(
    email: email,
    country: 'India', // ← Must be India for INR
    userId: userId,
);

// Result will have currency: 'INR'
```

**Benefits:**
- ✅ Charge in INR
- ✅ Can still accept international cards
- ✅ Stripe's global infrastructure

**Limitations:**
- ❌ Need Indian bank account
- ❌ Cannot switch currency later
- ❌ Cannot charge in multiple currencies

---

### **Solution 3: Keep USD, Price in Dollars**

**Accept that you're a USD merchant:**

```
Post price: $100 USD (not ₹100)
Customer pays: $100 USD
You receive: $97-98 USD (after fees)
```

**Change your posts to USD:**
```sql
UPDATE posts
SET 
    price = 100,
    currency_type = 'USD'
WHERE profile_id = 'YOUR_USER_ID';
```

**Benefits:**
- ✅ Matches your Stripe account
- ✅ No currency mismatch
- ✅ Can accept global payments

**Limitations:**
- ❌ Indian users might prefer INR
- ❌ Higher for Indians (₹8,400 vs ₹100)

---

### **Solution 4: Multi-Currency (Advanced)**

**Have BOTH Razorpay and Stripe:**

```
For Indian customers → Use Razorpay (INR)
For international customers → Use Stripe (USD/EUR/GBP)
```

**Implementation:**
1. Connect both Razorpay and Stripe accounts
2. Store both in profile
3. At booking time, ask customer:
   - "Pay in ₹ INR (Razorpay)" or
   - "Pay in $ USD (Stripe)"
4. Route payment to correct gateway

**Code (pseudo):**
```dart
// In booking flow
if (customerCountry == 'India' && post.currency == 'INR') {
    // Use Razorpay
    processPayment(gateway: 'razorpay', amount: 100, currency: 'INR');
} else {
    // Use Stripe
    processPayment(gateway: 'stripe', amount: 100, currency: 'USD');
}
```

**Benefits:**
- ✅ Support both INR and foreign currencies
- ✅ Best rates for each region
- ✅ Maximum flexibility

**Limitations:**
- ❌ Complex to implement
- ❌ Manage two accounts
- ❌ Two sets of fees/payouts

---

## 🎯 Recommended Action

### **For You (India-based):**

**Best Option: Switch to Razorpay**

```
1. Disconnect Stripe USD account
2. Connect Razorpay account
3. All posts automatically use INR
4. Customers pay in ₹ Rupees
5. You receive in ₹ Rupees
```

**Steps:**
1. Go to Settings → Payment Provider
2. Click "Disconnect Stripe"
3. Click "Connect Razorpay"
4. Complete Razorpay onboarding
5. Your `bank_currency` → 'INR'
6. Future posts → ₹ symbol

---

## 📊 Comparison Table

| Option | Currency | Gateway | Best For |
|--------|----------|---------|----------|
| **Razorpay** | INR only | Razorpay | 🇮🇳 India customers |
| **Stripe (INR)** | INR only | Stripe | 🇮🇳 India + global cards |
| **Stripe (USD)** | USD only | Stripe | 🌍 International |
| **Both** | INR + USD | Both | 🌍 Global platform |

---

## 🔧 Quick Fix (Right Now)

### **If you want to charge ₹100 INR:**

**Option A: Use Razorpay**
```sql
-- Switch to Razorpay
UPDATE profiles_private
SET 
    payment_provider = 'razorpay',
    bank_currency = 'INR'
WHERE id = 'YOUR_USER_ID';
```

**Option B: New Stripe Account (India)**
- Disconnect current Stripe (USD)
- Create new Stripe account with India as country
- Currency will be INR automatically

### **If you want to keep charging $100 USD:**

```sql
-- Fix your posts to show USD
UPDATE posts
SET currency_type = 'USD'
WHERE profile_id = 'YOUR_USER_ID';
```

---

## ⚠️ Important Notes

### **Cannot Do:**
- ❌ Charge INR through USD Stripe account
- ❌ Charge USD through Razorpay
- ❌ Mix currencies in single payment
- ❌ Change Stripe account currency after creation

### **Must Remember:**
- ✅ Stripe account currency = payment currency
- ✅ One gateway = one currency (usually)
- ✅ Customer must pay in account currency
- ✅ Display currency must match payment currency

---

## 🚀 Next Steps

**Tell me what you want:**

1. **"I want to charge in INR (Rupees)"**
   → I'll help you switch to Razorpay or Stripe INR

2. **"I want to charge in USD (Dollars)"**
   → I'll help you fix posts to show USD correctly

3. **"I want both INR and USD"**
   → I'll help you implement multi-currency system

**Which one do you prefer?** 🎯
