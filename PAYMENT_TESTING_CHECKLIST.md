# Payment System Testing Checklist

## 🧪 Complete Testing Guide

---

## Part 1: Database Setup

### ✅ Task 1.1: Run SQL Migration
```bash
# Run this file
psql -U postgres -d your_database -f add_currency_type_to_posts.sql
```

**Verify:**
- [ ] Column `currency_type` exists in `posts` table
- [ ] Default value is 'INR'
- [ ] Comment is set correctly

**SQL Check:**
```sql
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'posts' AND column_name = 'currency_type';
```

---

## Part 2: Provider Setup Tests

### ✅ Task 2.1: Test WITHOUT Payment Account

**Steps:**
1. [ ] Open app as a provider
2. [ ] Navigate to Create Post
3. [ ] Fill in all required fields
4. [ ] Click "Post live"

**Expected Result:**
- [ ] ❌ Error dialog appears
- [ ] Dialog title: "Payment Account Required"
- [ ] Dialog shows explanation with:
  - Why it's required
  - Benefits of connecting
  - "Go to Settings" button
- [ ] Click "Go to Settings" navigates to profile page

**Screenshot:** 📸 _Take screenshot of error dialog_

---

### ✅ Task 2.2: Connect Razorpay (India)

**Steps:**
1. [ ] Go to Profile → Settings
2. [ ] Find "Payment Gateway" section
3. [ ] Select "Razorpay (India)"
4. [ ] Enter bank details:
   - Bank account holder name
   - Account number
   - Bank name
   - IFSC code
   - Account type (Savings/Current)
5. [ ] Save details

**Expected Result:**
- [ ] ✅ Details saved successfully
- [ ] `payment_provider` = 'razorpay'
- [ ] `razorpay_account_id` is set (or bank details stored)
- [ ] `bank_currency` = 'INR'

**SQL Verify:**
```sql
SELECT id, payment_provider, razorpay_account_id, bank_currency 
FROM profiles_private 
WHERE id = 'YOUR_USER_ID';
```

---

### ✅ Task 2.3: Connect Stripe (International)

**Steps:**
1. [ ] Go to Profile → Settings
2. [ ] Find "Payment Gateway" section
3. [ ] Select "Stripe (International)"
4. [ ] Complete Stripe onboarding:
   - Business information
   - Tax details
   - Identity verification
   - Bank connection
5. [ ] Complete onboarding

**Expected Result:**
- [ ] ✅ Stripe onboarding completed
- [ ] `payment_provider` = 'stripe'
- [ ] `stripe_account_id` = 'acct_xxxxxx'
- [ ] `bank_currency` = detected from bank (USD/GBP/EUR)

**SQL Verify:**
```sql
SELECT id, payment_provider, stripe_account_id, bank_currency 
FROM profiles_private 
WHERE id = 'YOUR_USER_ID';
```

---

## Part 3: Post Creation Tests

### ✅ Task 3.1: Create Post WITH Payment Account

**Steps:**
1. [ ] Connect payment account (Task 2.2 or 2.3)
2. [ ] Navigate to Create Post
3. [ ] Fill in all required fields
4. [ ] Click "Post live"

**Expected Result:**
- [ ] ✅ Post created successfully
- [ ] No error dialog
- [ ] Post appears in "My Posts"
- [ ] `currency_type` is set correctly

**SQL Verify:**
```sql
SELECT id, profile_id, currency_type, price 
FROM posts 
WHERE profile_id = 'YOUR_USER_ID' 
ORDER BY created_at DESC 
LIMIT 1;
```

**Debug Output:**
```
✅ Payment validation passed: razorpay (Currency: INR)
```

---

### ✅ Task 3.2: Verify Currency Auto-Detection

**Test Cases:**

#### Case A: Razorpay User
- **Setup:** User with Razorpay connected
- **Expected:** `currency_type` = 'INR'
- **Verify:** 
  ```sql
  SELECT currency_type FROM posts WHERE id = 'POST_ID';
  -- Expected: 'INR'
  ```

#### Case B: Stripe User (US Bank)
- **Setup:** User with Stripe + US bank
- **Expected:** `currency_type` = 'USD'
- **Verify:** 
  ```sql
  SELECT currency_type FROM posts WHERE id = 'POST_ID';
  -- Expected: 'USD'
  ```

#### Case C: Stripe User (UK Bank)
- **Setup:** User with Stripe + UK bank
- **Expected:** `currency_type` = 'GBP'
- **Verify:** 
  ```sql
  SELECT currency_type FROM posts WHERE id = 'POST_ID';
  -- Expected: 'GBP'
  ```

#### Case D: No Bank Currency (Fallback)
- **Setup:** User with payment provider but no `bank_currency`
- **Expected:** Falls back to provider default
  - Razorpay → 'INR'
  - Stripe → 'USD'
- **Verify:**
  ```sql
  SELECT p.currency_type, pp.payment_provider, pp.bank_currency
  FROM posts p
  JOIN profiles_private pp ON p.profile_id = pp.id
  WHERE p.id = 'POST_ID';
  ```

---

## Part 4: Customer Booking Tests

### ✅ Task 4.1: Book INR Post (Razorpay)

**Steps:**
1. [ ] Find post with `currency_type` = 'INR'
2. [ ] Click "Book" button
3. [ ] Fill passenger/sender details
4. [ ] Click "Confirm Booking"
5. [ ] Complete payment in Razorpay checkout

**Expected Result:**
- [ ] ✅ Razorpay checkout opens
- [ ] Payment amount shown in INR (₹)
- [ ] Payment options: UPI, Card, NetBanking
- [ ] After payment: Booking created
- [ ] Payment ID stored in booking

**Debug Output:**
```
[PaymentService] Routing to Razorpay (India)
[PaymentService] Order created: order_xxxxx
```

---

### ✅ Task 4.2: Book USD Post (Stripe)

**Steps:**
1. [ ] Find post with `currency_type` = 'USD'
2. [ ] Click "Book" button
3. [ ] Fill passenger/sender details
4. [ ] Click "Confirm Booking"
5. [ ] Complete payment in Stripe checkout

**Expected Result:**
- [ ] ✅ Stripe checkout opens
- [ ] Payment amount shown in USD ($)
- [ ] Payment options: Card, Apple Pay, Google Pay
- [ ] After payment: Booking created
- [ ] Payment ID stored in booking

**Debug Output:**
```
[PaymentService] Routing to Stripe (international)
[PaymentService] Payment intent created: pi_xxxxx
```

---

## Part 5: Edge Cases

### ✅ Task 5.1: Provider Disconnects Payment Account

**Steps:**
1. [ ] Create post with payment account
2. [ ] Disconnect payment account (remove Stripe/Razorpay)
3. [ ] Try to create another post

**Expected Result:**
- [ ] ❌ Error dialog appears
- [ ] Blocked from creating new post
- [ ] Existing posts remain visible

---

### ✅ Task 5.2: Customer Post (No Payment Required)

**Steps:**
1. [ ] Switch to "Customer Mode" (isUserMode=true)
2. [ ] Create a customer request post
3. [ ] Do NOT connect payment account

**Expected Result:**
- [ ] ✅ Post created successfully
- [ ] No payment validation
- [ ] Customer can post requests without payment account
- [ ] Payment happens when they book provider services

---

### ✅ Task 5.3: Currency Mismatch

**Steps:**
1. [ ] Provider with INR posts
2. [ ] Customer from US tries to book
3. [ ] Payment should still work

**Expected Result:**
- [ ] ✅ Payment processes correctly
- [ ] Razorpay accepts international cards for INR
- [ ] Stripe handles currency conversion if needed

---

## Part 6: Payment Flow Tests

### ✅ Task 6.1: Complete Razorpay Payment

**Test Flow:**
```
1. Create booking → 2. Razorpay opens → 3. Pay with UPI
→ 4. Verify signature → 5. Booking confirmed
```

**Checkpoints:**
- [ ] Order created successfully
- [ ] Razorpay checkout opens
- [ ] Payment completes
- [ ] Signature verified
- [ ] Booking status updated
- [ ] OTP generated

---

### ✅ Task 6.2: Complete Stripe Payment

**Test Flow:**
```
1. Create booking → 2. Stripe opens → 3. Pay with card
→ 4. Confirm payment → 5. Booking confirmed
```

**Checkpoints:**
- [ ] Payment intent created
- [ ] Stripe checkout opens
- [ ] Card payment accepted
- [ ] Payment confirmed
- [ ] Booking status updated
- [ ] Payment ID stored

---

### ✅ Task 6.3: Failed Payment

**Test Flow:**
```
1. Create booking → 2. Open checkout → 3. Cancel/fail payment
→ 4. Return to app
```

**Expected Result:**
- [ ] ❌ Booking NOT created
- [ ] Error message shown
- [ ] User can retry payment
- [ ] No ghost bookings in database

---

### ✅ Task 6.4: Escrow Flow (Customer Posts)

**Test Flow:**
```
1. Customer creates post → 2. Provider accepts → 3. Payment to escrow
→ 4. Service delivered → 5. Money released to provider
```

**Checkpoints:**
- [ ] Customer pays upfront (escrow)
- [ ] Money held by platform
- [ ] Provider delivers service
- [ ] Money released to provider
- [ ] Platform fee deducted (5%)

---

## Part 7: Multi-Currency Tests

### ✅ Task 7.1: Multiple Providers, Multiple Currencies

**Scenario:**
- Provider A (India): Posts in INR
- Provider B (USA): Posts in USD
- Provider C (UK): Posts in GBP

**Steps:**
1. [ ] View all posts in feed
2. [ ] Check currency display for each
3. [ ] Book from each provider
4. [ ] Verify payment gateway routing

**Expected Result:**
- [ ] Prices shown in respective currencies
- [ ] INR → ₹, USD → $, GBP → £
- [ ] Razorpay for INR posts
- [ ] Stripe for USD/GBP posts

---

### ✅ Task 7.2: Currency Filters

**Steps:**
1. [ ] Open post filter/search
2. [ ] Filter by currency
3. [ ] Verify results

**Expected Result:**
- [ ] Filter by INR shows only INR posts
- [ ] Filter by USD shows only USD posts
- [ ] Mixed filter shows all selected currencies

---

## Part 8: Database Integrity

### ✅ Task 8.1: Check Post Currency

```sql
-- All posts should have currency_type
SELECT COUNT(*) as total, 
       COUNT(currency_type) as with_currency,
       COUNT(CASE WHEN currency_type IS NULL THEN 1 END) as null_currency
FROM posts;

-- Expected: null_currency = 0
```

---

### ✅ Task 8.2: Currency Distribution

```sql
-- Check currency distribution
SELECT currency_type, COUNT(*) as count
FROM posts
GROUP BY currency_type
ORDER BY count DESC;

-- Expected: Shows INR, USD, GBP, EUR counts
```

---

### ✅ Task 8.3: Provider Payment Setup

```sql
-- Providers without payment setup
SELECT id, full_name, payment_provider, bank_currency
FROM profiles_public pp
LEFT JOIN profiles_private priv ON pp.id = priv.id
WHERE payment_provider IS NULL
  OR (stripe_account_id IS NULL AND razorpay_account_id IS NULL);

-- These users cannot create provider posts
```

---

## Part 9: User Experience Tests

### ✅ Task 9.1: Error Message Clarity

**Check:**
- [ ] Error messages are clear
- [ ] Actionable guidance provided
- [ ] "Go to Settings" button works
- [ ] No confusing technical jargon

---

### ✅ Task 9.2: Payment Flow Smoothness

**Check:**
- [ ] No unnecessary steps
- [ ] Loading indicators shown
- [ ] Success/failure messages clear
- [ ] Can retry failed payments easily

---

### ✅ Task 9.3: Currency Display

**Check:**
- [ ] Correct currency symbols (₹, $, £, €)
- [ ] Proper decimal places (2 for most)
- [ ] Consistent formatting throughout app

---

## Part 10: Production Readiness

### ✅ Task 10.1: Security Checks

- [ ] Payment IDs not exposed in logs
- [ ] Stripe/Razorpay secrets secure
- [ ] HTTPS for all payment endpoints
- [ ] No sensitive data in error messages

---

### ✅ Task 10.2: Error Handling

- [ ] Network failures handled gracefully
- [ ] Payment gateway timeouts handled
- [ ] Invalid payment states detected
- [ ] User-friendly error messages

---

### ✅ Task 10.3: Performance

- [ ] Payment page loads quickly
- [ ] No blocking operations on UI thread
- [ ] Smooth checkout experience
- [ ] No lag during payment flow

---

## 📊 Final Checklist

### Database
- [ ] currency_type column exists
- [ ] All posts have currency set
- [ ] Proper indexes on currency_type

### Provider Features
- [ ] Payment validation works
- [ ] Error dialog functional
- [ ] Currency auto-detection correct
- [ ] Can create posts with payment account

### Customer Features
- [ ] Can book INR posts (Razorpay)
- [ ] Can book USD posts (Stripe)
- [ ] Can book GBP posts (Stripe)
- [ ] Payment flow smooth

### Payment Gateways
- [ ] Razorpay integration working
- [ ] Stripe integration working
- [ ] Payment verification working
- [ ] Escrow flow working

### Edge Cases
- [ ] Customer posts work without payment account
- [ ] Provider validation blocks correctly
- [ ] Failed payments handled
- [ ] Multi-currency display correct

---

## 🎉 Sign-Off

**Tester Name:** _________________
**Date:** _________________
**All Tests Passed:** ☐ Yes ☐ No

**Issues Found:**
1. _________________
2. _________________
3. _________________

**Notes:**
_______________________________________________________
_______________________________________________________
_______________________________________________________

---

**Testing Complete!** 🚀✅
