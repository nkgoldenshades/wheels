# 🐛 Currency Mismatch Issue - Analysis & Fix

## 📋 Problem Description

**Issue:** When creating a post for ₹100 (INR), the app is showing:
1. One post with **$100** (USD) in India location ❌
2. Another post with **₹100** (INR) in India location ✅

**Expected:** Only ONE post with ₹100 (INR) for Indian location

---

## 🔍 Root Cause Analysis

### **Possible Causes:**

#### **1. Default Currency Not Set (Most Likely)**
When you register or login, your profile might not have a currency set, so the app defaults to USD instead of INR.

**Check:**
- User profile `currency_type` field in database
- User location detected as India but currency defaults to USD

#### **2. Duplicate Post Creation**
The code might be creating the post twice:
- Once with USD (incorrect default)
- Once with INR (correct)

#### **3. Currency Display Bug**
One post exists but is displayed twice with different currencies due to a rendering bug.

---

## ✅ Solution 1: Set Default Currency Based on Location

### **Problem:**
When a new user registers, their `currency_type` is not set, defaulting to USD.

### **Fix:**
Update profile creation to auto-detect currency based on location.

**File:** `lib/services/profile_repository.dart`

**Add this function:**
```dart
String _getCurrencyFromLocation(String? location) {
  if (location == null || location.isEmpty) return 'INR'; // Default to INR
  
  final locationLower = location.toLowerCase();
  
  // India detection
  if (locationLower.contains('india') || 
      locationLower.contains('(in)') ||
      locationLower.contains('mumbai') ||
      locationLower.contains('delhi') ||
      locationLower.contains('bangalore') ||
      locationLower.contains('chennai') ||
      locationLower.contains('kolkata') ||
      locationLower.contains('hyderabad')) {
    return 'INR';
  }
  
  // US detection
  if (locationLower.contains('usa') ||
      locationLower.contains('united states') ||
      locationLower.contains('(us)')) {
    return 'USD';
  }
  
  // UK detection
  if (locationLower.contains('uk') ||
      locationLower.contains('united kingdom') ||
      locationLower.contains('london')) {
    return 'GBP';
  }
  
  // EU detection
  if (locationLower.contains('germany') ||
      locationLower.contains('france') ||
      locationLower.contains('spain') ||
      locationLower.contains('italy')) {
    return 'EUR';
  }
  
  // Default to INR for unlisted locations
  return 'INR';
}
```

**Usage in profile creation:**
```dart
final profile = {
  'id': userId,
  'profile_name': profileName,
  'email': email,
  'currency_type': _getCurrencyFromLocation(null), // Will default to INR
  'created_at': DateTime.now().toIso8601String(),
};
```

---

## ✅ Solution 2: Check Database for Duplicate Posts

### **SQL Query to Find Duplicates:**
```sql
SELECT 
  id,
  profile_id,
  vehicle_id,
  price,
  currency_type,
  from_location,
  created_at
FROM posts
WHERE profile_id = 'YOUR_USER_ID'
ORDER BY created_at DESC
LIMIT 10;
```

### **Delete Duplicate USD Post:**
```sql
-- First, find the duplicate posts
SELECT id, price, currency_type FROM posts 
WHERE profile_id = 'YOUR_USER_ID' 
AND price = 100;

-- Then delete the wrong one (USD)
DELETE FROM posts 
WHERE id = 'POST_ID_OF_USD_POST';
```

---

## ✅ Solution 3: Add Currency Validation

### **Prevent Mismatched Currency-Location**

**File:** `lib/services/slot_repository.dart`

**Add validation before insert:**
```dart
// Validate currency matches location
String _validateCurrency(String currencyType, String? location) {
  if (location == null) return currencyType;
  
  final isIndianLocation = location.toLowerCase().contains('india') || 
                          location.toLowerCase().contains('(in)');
  
  // If Indian location but non-INR currency, warn and correct
  if (isIndianLocation && currencyType != 'INR') {
    debugPrint('⚠️ Currency mismatch: Indian location with $currencyType currency. Correcting to INR.');
    return 'INR';
  }
  
  return currencyType;
}

// Use in createSlot:
final insertData = {
  // ... other fields ...
  'currency_type': _validateCurrency(slot.currencyType, slot.fromLocation),
  // ... rest of fields ...
};
```

---

## 🔧 Immediate Fix (Manual)

### **Step 1: Check Your Profile Currency**

**Run this SQL in Supabase:**
```sql
SELECT id, profile_name, currency_type 
FROM profiles 
WHERE id = 'YOUR_USER_ID';
```

**If `currency_type` is NULL or 'USD':**
```sql
UPDATE profiles 
SET currency_type = 'INR' 
WHERE id = 'YOUR_USER_ID';
```

### **Step 2: Delete Duplicate USD Posts**

**Find duplicate posts:**
```sql
SELECT id, price, currency_type, from_location, created_at
FROM posts
WHERE profile_id = 'YOUR_USER_ID'
AND price = 100
ORDER BY created_at DESC;
```

**Delete the USD post (keep the INR one):**
```sql
DELETE FROM posts 
WHERE id = 'THE_USD_POST_ID';
```

### **Step 3: Restart App**

After fixing the database, restart the app to see the correct posts.

---

## 🎯 Quick Fix for New Posts

### **Set Currency When Creating Post**

**Ensure user's profile has correct currency:**

1. **On Registration:** Auto-detect based on location
2. **On First Post:** Ask user to confirm currency
3. **On Every Post:** Validate currency matches location

---

## 📊 Expected vs Actual

### **Expected Flow:**
```
User in India → Profile currency: INR → Creates post for ₹100 → Shows ₹100
```

### **Current Issue:**
```
User in India → Profile currency: NULL/USD → Creates post → Shows $100 (wrong!)
                                                            → Also shows ₹100 (correct?)
```

### **After Fix:**
```
User in India → Profile currency: INR (auto-set) → Creates post for ₹100 → Shows ₹100 only ✅
```

---

## 🚀 Recommended Actions

### **Priority 1 (Immediate):**
1. ✅ Check your profile's `currency_type` in Supabase
2. ✅ Set it to 'INR' if NULL or wrong
3. ✅ Delete duplicate USD posts
4. ✅ Restart app

### **Priority 2 (Code Fix):**
1. ✅ Add `_getCurrencyFromLocation()` function
2. ✅ Auto-set currency on profile creation
3. ✅ Add currency validation in post creation
4. ✅ Prevent currency-location mismatches

### **Priority 3 (Testing):**
1. ✅ Test new registration → Should default to INR for India
2. ✅ Test post creation → Should match profile currency
3. ✅ Test with different locations → Should auto-detect currency

---

## 💡 Why This Happens

### **Root Cause:**
When a new user registers, their profile is created without a `currency_type` value:

```dart
// Current code (MISSING currency_type):
final profile = {
  'id': userId,
  'profile_name': profileName,
  'email': email,
  // ❌ currency_type: MISSING!
  'created_at': DateTime.now().toIso8601String(),
};
```

**Result:** App defaults to USD, creating posts with wrong currency.

### **Fix:**
```dart
// Fixed code (WITH currency_type):
final profile = {
  'id': userId,
  'profile_name': profileName,
  'email': email,
  'currency_type': 'INR', // ✅ Default to INR
  'created_at': DateTime.now().toIso8601String(),
};
```

---

## 🎯 Summary

**Problem:** Posts created with wrong currency (USD instead of INR)

**Cause:** Profile `currency_type` not set, defaults to USD

**Solution:**
1. Set profile `currency_type` to 'INR' in database (immediate fix)
2. Add auto-currency detection in code (permanent fix)
3. Delete duplicate USD posts

**Expected Behavior:** 
- Indian users → INR currency by default
- US users → USD currency by default
- Other countries → Correct currency based on location

---

## 📞 Need Help?

If you want me to:
1. ✅ Check your database for duplicate posts
2. ✅ Write the SQL to fix it
3. ✅ Implement the code fix

Just let me know! I can help you fix this issue completely. 🚀
