# 💰 Currency Mismatch Issue - Simple Explanation

## 🎯 The Problem

You created a post for **₹100 (INR)** but the app is showing:
1. One post with **$100 (USD)** ❌
2. Another post with **₹100 (INR)** ✅

**This means either:**
- Your profile's `bank_currency` is not set (so app creates USD by default, then INR)
- Posts are being created twice due to a bug

---

## 🔍 How Currency Works in VaultWheels

### **Currency is determined by your bank account:**

1. **Razorpay** (Indian bank) → **INR** ₹
2. **Stripe** (International bank) → **USD/GBP/EUR** $

### **Where currency is stored:**
```
Profile → bank_currency field → Used for all posts
```

### **When you create a post:**
```dart
// Code checks your profile:
String _determineCurrencyType() {
    // 1. Check bank_currency (from your bank account)
    if (bankCurrency != null) {
        return bankCurrency; // ✅ Use this!
    }
    
    // 2. Check payment provider
    if (paymentProvider == 'razorpay') {
        return 'INR'; // ✅ Razorpay = India = INR
    }
    
    if (paymentProvider == 'stripe') {
        return 'USD'; // ⚠️ Stripe defaults to USD
    }
    
    // 3. Default fallback
    return 'INR'; // Default to INR
}
```

---

## ❓ Questions for You

### **1. Have you added bank details in the app?**
- Settings → Bank Details → Add Account
- Did you complete this step?

### **2. Which payment provider did you choose?**
- Razorpay (for Indian bank)
- Stripe (for international bank)

### **3. When did you create these posts?**
- Was it right after registration?
- Or after adding bank details?

---

## 🔧 Quick Fix Steps

### **Step 1: Check Your Database**

Run this SQL in Supabase (I created the file for you):
```sql
-- Open: diagnose_currency_duplicates.sql
-- Replace 'YOUR_USER_ID' with your actual user ID
-- Run each section
```

### **Step 2: What You'll Find**

**Option A: bank_currency is NULL**
```sql
-- Your profile:
bank_currency: NULL
payment_provider: NULL

-- Fix:
UPDATE profiles
SET bank_currency = 'INR',
    payment_provider = 'razorpay'
WHERE id = 'YOUR_USER_ID';
```

**Option B: Duplicate posts exist**
```sql
-- You have:
Post 1: price=100, currency_type='USD'
Post 2: price=100, currency_type='INR'

-- Fix: Delete the USD post
DELETE FROM posts
WHERE id = 'USD_POST_ID';
```

---

## 🎯 Root Cause (My Analysis)

### **What I Think Happened:**

1. **You registered** → Profile created with:
   ```json
   {
     "bank_currency": null,
     "payment_provider": null
   }
   ```

2. **You created a post for ₹100:**
   - App checks: `bank_currency` → **NULL**
   - App checks: `payment_provider` → **NULL**
   - App defaults to: **INR** (fallback)
   - Post created: **₹100 INR** ✅

3. **BUT... why is there a $100 USD post?**
   
   **Possible reasons:**
   
   **A) You created it twice:**
   - First time: Before setting bank details → USD default
   - Second time: After setting details → INR correct
   
   **B) App bug:**
   - Post creation triggered twice
   - First trigger: USD (wrong default)
   - Second trigger: INR (correct)
   
   **C) Currency conversion:**
   - App tried to "convert" ₹100 to $100
   - Created separate post (BUG!)

---

## ✅ Permanent Fix (Code Change)

I should update the code to:

### **1. NEVER create duplicate posts**

Add unique constraint:
```sql
-- Prevent duplicate posts
CREATE UNIQUE INDEX unique_active_post 
ON posts(profile_id, vehicle_id, start_time, end_time)
WHERE is_active = true;
```

### **2. Force currency to match bank_currency**

Update `_determineCurrencyType()`:
```dart
String _determineCurrencyType() {
    final currentUser = ProfileRepository.instance.profile.value;
    final bankCurrency = currentUser.bankCurrency;

    // ✅ MUST have bank currency set!
    if (bankCurrency == null || bankCurrency.isEmpty) {
        throw Exception(
            'Bank currency not set! Please add bank details first.'
        );
    }

    return bankCurrency.toUpperCase();
}
```

### **3. Validate before post creation**

```dart
void _validateBeforeCreate() {
    final profile = ProfileRepository.instance.profile.value;
    
    // Check bank currency is set
    if (profile.bankCurrency == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Please add bank details first! '
                    'Go to Settings → Bank Details'
                ),
            ),
        );
        return;
    }
    
    // Proceed with post creation...
}
```

---

## 🎯 What You Should Do Now

### **Option 1: Quick Manual Fix**

1. Open Supabase
2. Go to **profiles** table
3. Find your profile
4. Set `bank_currency` = `'INR'`
5. Set `payment_provider` = `'razorpay'`
6. Go to **posts** table
7. Delete the USD post (keep the INR one)
8. Restart app

### **Option 2: Let Me Fix It**

Tell me:
1. Your user ID (or email)
2. Which currency you want (INR/USD/GBP/EUR)
3. Which payment provider (Razorpay/Stripe)

I'll write the exact SQL to fix it.

### **Option 3: Code Fix**

I can update the code to:
- Require bank details before creating posts
- Prevent duplicate posts
- Show error if currency not set

---

## 📊 Expected Behavior

### **Correct Flow:**
```
1. Register → Profile created
2. Go to Settings → Add Bank Details
   - Choose Razorpay → bank_currency set to 'INR'
   - Choose Stripe → bank_currency set to 'USD/GBP/EUR'
3. Create post → Uses bank_currency from profile
4. Post shows correct currency symbol ✅
```

### **Your Flow (What Happened):**
```
1. Register → Profile created (bank_currency = NULL)
2. Create post → Currency defaults/guesses
3. Posts show wrong currency or duplicates ❌
```

---

## 💡 Summary

**Problem:** Posts showing wrong currency or duplicates

**Cause:** `bank_currency` not set in profile

**Fix:** 
1. Set `bank_currency` in database
2. Delete duplicate posts
3. Restart app

**Prevention:**
- Force users to add bank details before creating posts
- Add validation in code

---

## 🚀 What Do You Want Me To Do?

**Option A:** Help me check/fix the database ✅  
**Option B:** Update code to prevent this ✅  
**Option C:** Explain how bank details work ✅  
**Option D:** All of the above! ✅  

Just let me know! I'm here to help! 😊
