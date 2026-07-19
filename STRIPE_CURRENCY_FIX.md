# 💳 Stripe Multi-Currency Fix

## 🎯 The Real Issue

**How Currency Works:**
1. **Razorpay** → Always **INR** (India only)
2. **Stripe** → Multi-currency (USD, EUR, GBP, INR, etc.)
   - Currency is stored in Stripe account's `default_currency` field
   - App should **fetch** this from Stripe API
   - Currently, app **guesses** USD for test accounts

**Current Bug:**
```dart
// Current code (WRONG):
final bankCurrency = 
    (accountId.startsWith('acct_test_') ? 'USD' : null);
    // ❌ Assumes all test accounts = USD!
```

**Problem:**
- You connect Stripe account with INR currency
- App sees test account → Assumes USD
- Creates posts with wrong currency symbol

---

## ✅ Fix Applied

### **What I Changed:**

**File:** `lib/services/profile_repository.dart`

**Before:**
```dart
final bankCurrency =
    currency ??
    (accountId.startsWith('acct_test_') ? 'USD' : null) ??
    p.bankCurrency;
```

**After:**
```dart
// Priority system:
// 1. Use explicitly provided currency
// 2. Keep existing currency (don't override)
// 3. Default to USD only if nothing else set
```

**Benefits:**
- ✅ Won't override your existing currency
- ✅ Respects manually set currency
- ✅ Better logging to debug issues
- ✅ Adds TODO for Stripe API integration

---

## 🚀 Proper Solution (Full Fix)

### **Fetch Currency from Stripe API**

When user connects Stripe account, fetch the actual currency:

```dart
Future<String> fetchStripeAccountCurrency(String accountId) async {
  try {
    // Call Stripe API to get account details
    final response = await http.get(
      Uri.parse('https://api.stripe.com/v1/accounts/$accountId'),
      headers: {
        'Authorization': 'Bearer $stripeSecretKey',
      },
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final currency = data['default_currency'] as String?;
      
      if (currency != null) {
        return currency.toUpperCase(); // INR, USD, EUR, GBP, etc.
      }
    }
  } catch (e) {
    debugPrint('❌ Failed to fetch Stripe currency: $e');
  }
  
  // Fallback to USD
  return 'USD';
}

// Use when connecting Stripe:
Future<void> updateStripeAccount(String accountId) async {
  // Fetch currency from Stripe
  final currency = await fetchStripeAccountCurrency(accountId);
  
  // Save with correct currency
  await saveProfile(
    p.copyWith(
      stripeAccountId: accountId,
      bankCurrency: currency, // ✅ Actual currency from Stripe!
    ),
  );
}
```

---

## 🎯 Alternative: Manual Currency Selection

### **Let Users Choose Currency**

Add a currency selector when connecting Stripe:

**UI Flow:**
```
1. User clicks "Connect Stripe"
2. User connects Stripe account
3. App shows: "Select your currency"
   - Dropdown: INR, USD, EUR, GBP
4. Save Stripe ID + selected currency
```

**Code:**
```dart
// In settings screen:
ElevatedButton(
  onPressed: () async {
    // 1. Connect Stripe (existing flow)
    final stripeId = await connectStripeAccount();
    
    // 2. Show currency selector
    final currency = await showDialog<String>(
      context: context,
      builder: (context) => CurrencySelectionDialog(),
    );
    
    // 3. Save with selected currency
    if (currency != null) {
      await ProfileRepository.instance.updateStripeAccount(
        stripeId,
        currency: currency,
      );
    }
  },
  child: Text('Connect Stripe Account'),
);

// Currency selection dialog:
class CurrencySelectionDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select Your Currency'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Text('₹'),
            title: Text('Indian Rupee (INR)'),
            onTap: () => Navigator.pop(context, 'INR'),
          ),
          ListTile(
            leading: Text('\$'),
            title: Text('US Dollar (USD)'),
            onTap: () => Navigator.pop(context, 'USD'),
          ),
          ListTile(
            leading: Text('£'),
            title: Text('British Pound (GBP)'),
            onTap: () => Navigator.pop(context, 'GBP'),
          ),
          ListTile(
            leading: Text('€'),
            title: Text('Euro (EUR)'),
            onTap: () => Navigator.pop(context, 'EUR'),
          ),
        ],
      ),
    );
  }
}
```

---

## 📊 Your Current Situation

### **Diagnosis:**

**Scenario 1: Both Posts Are Yours**
```
Post 1: $100 (Created when Stripe connected, defaulted to USD)
Post 2: ₹100 (Created after currency corrected to INR)

Fix: Delete Post 1, keep Post 2
```

**Scenario 2: Browsing Feed**
```
Post 1: $100 (Someone else with Stripe USD)
Post 2: ₹100 (You with Razorpay/Stripe INR)

No action needed - this is normal!
```

---

## 🔧 Immediate Actions

### **Step 1: Check Your Profile**

Run in Supabase:
```sql
SELECT 
    id,
    profile_name,
    payment_provider,
    bank_currency,
    stripe_account_id,
    razorpay_account_id
FROM profiles_private
WHERE email = 'your@email.com';
```

### **Step 2: Check Your Posts**

```sql
SELECT 
    id,
    price,
    currency_type,
    from_location,
    created_at
FROM posts
WHERE profile_id = 'YOUR_USER_ID'
ORDER BY created_at DESC;
```

### **Step 3: Fix Currency (If Wrong)**

```sql
-- Set correct currency in profile
UPDATE profiles_private
SET bank_currency = 'INR'  -- or USD, EUR, GBP
WHERE id = 'YOUR_USER_ID';

-- Delete wrong currency posts (if duplicates)
DELETE FROM posts
WHERE id = 'WRONG_POST_ID';
```

---

## ✅ Recommended Implementation Priority

### **Priority 1 (Now):**
1. ✅ Fix applied to `profile_repository.dart`
2. ✅ Won't override existing currency
3. ✅ Better logging

### **Priority 2 (Soon):**
1. ⏳ Add currency selector when connecting Stripe
2. ⏳ Let users manually change currency in settings
3. ⏳ Prevent posts until currency is set

### **Priority 3 (Later):**
1. ⏳ Integrate Stripe API to fetch currency automatically
2. ⏳ Add currency conversion for cross-currency bookings
3. ⏳ Show exchange rates in multi-currency posts

---

## 🎯 Expected Behavior After Fix

### **For New Users:**

```
1. Register → Profile created
2. Connect Stripe → Stripe ID saved
3. App prompts: "Select your currency" → User chooses INR
4. bank_currency set to INR
5. Create posts → All posts use INR ✅
```

### **For Existing Users:**

```
1. Already have Stripe connected
2. bank_currency might be wrong/null
3. Go to Settings → Manually select currency
4. Future posts use correct currency ✅
```

---

## 💡 Summary

**Problem:** Stripe accounts defaulting to USD regardless of actual currency

**Root Cause:** App guesses currency instead of fetching from Stripe API

**Quick Fix:** Manual currency selection in settings

**Proper Fix:** Integrate Stripe API to fetch `default_currency`

**Current Status:** 
- ✅ Code updated to respect existing currency
- ⏳ Manual currency selector (not yet implemented)
- ⏳ Stripe API integration (future enhancement)

---

## 🚀 Want Me To:

1. ✅ Implement manual currency selector? (Settings screen)
2. ✅ Add currency prompt when connecting Stripe?
3. ✅ Integrate Stripe API for auto-detection?
4. ✅ Help fix your database?

Let me know which you want first! 😊
