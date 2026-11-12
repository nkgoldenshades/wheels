# 🌍 Multi-Currency Support Documentation

## Overview

The payment system now supports **automatic currency detection** from Stripe accounts. When a provider connects their Stripe account, the system automatically detects their bank's currency and uses it for all their posts.

---

## 🎯 Supported Currencies

### Razorpay (India Only)
- **Currency:** INR (Indian Rupee) only
- **Why:** Razorpay only operates in India
- **Auto-set:** Always `'INR'`

### Stripe (International)
Stripe supports **135+ currencies** including:

| Currency | Code | Countries |
|----------|------|-----------|
| US Dollar | USD | USA, many international |
| British Pound | GBP | United Kingdom |
| Euro | EUR | Eurozone (27 countries) |
| Australian Dollar | AUD | Australia |
| Canadian Dollar | CAD | Canada |
| Singapore Dollar | SGD | Singapore |
| UAE Dirham | AED | United Arab Emirates |
| Japanese Yen | JPY | Japan |
| Swiss Franc | CHF | Switzerland |
| Hong Kong Dollar | HKD | Hong Kong |
| ...and 125+ more | ... | See Stripe docs |

**Full list:** https://stripe.com/docs/currencies

---

## 🔧 How It Works

### 1. Provider Connects Stripe Account

```
User clicks "Setup Stripe Account"
  ↓
Firebase Function creates Stripe Connect account
  ↓
Stripe account created with country (e.g., 'GB' for UK)
  ↓
Stripe auto-sets default_currency based on country
  - UK → GBP
  - USA → USD
  - Eurozone → EUR
  ↓
Function fetches account.default_currency
  ↓
Returns { account_id, url, currency }
  ↓
App saves to profiles_private.bank_currency
```

### 2. Provider Creates Post

```
Provider clicks "Create Post"
  ↓
Validation: Has payment provider? ✓
  ↓
Auto-detect currency from bank_currency
  ↓
Post created with currency_type = bank_currency
  ↓
Post visible to customers
```

### 3. Customer Books Service

```
Customer selects post
  ↓
Check post.currency_type
  - INR → Razorpay
  - USD/GBP/EUR → Stripe
  ↓
Payment processed in correct currency
  ↓
Money held in escrow
  ↓
Service delivered → Money released to provider
```

---

## 💻 Implementation Details

### Backend (Firebase Function)

**File:** `functions/stripe-escrow.js`

```javascript
// Create Stripe account
const account = await stripe.accounts.create({
  type: 'express',
  country: countryCode, // e.g., 'GB', 'US', 'FR'
  email,
  capabilities: {
    card_payments: { requested: true },
    transfers: { requested: true },
  },
});

// Fetch account details to get currency
const accountDetails = await stripe.accounts.retrieve(account.id);
const defaultCurrency = accountDetails.default_currency // e.g., 'gbp', 'usd'
  ? accountDetails.default_currency.toUpperCase()
  : null;

// Return currency to app
res.json({
  account_id: account.id,
  url: accountLink.url,
  currency: defaultCurrency, // ← NEW!
});
```

### Frontend (Flutter)

**File:** `lib/main.dart`

```dart
// Receive currency from Firebase Function
final currency = result['currency'] as String?;

// Save to profile
await ProfileRepository.instance.updateStripeAccount(
  accountId,
  currency: currency, // ← Pass currency
);
```

**File:** `lib/services/profile_repository.dart`

```dart
Future<void> updateStripeAccount(String accountId, {String? currency}) async {
  final bankCurrency = currency ?? 
                      (accountId.startsWith('acct_test_') ? 'USD' : null);
  
  await saveProfile(p.copyWith(
    stripeAccountId: accountId,
    bank_currency: bankCurrency, // ← Save currency
  ));
}
```

**File:** `lib/screens/add_flow/create_post_screen.dart`

```dart
String _determineCurrencyType() {
  final currentUser = ProfileRepository.instance.profile.value;

  // Priority 1: Use bank account currency
  if (currentUser.bankCurrency != null) {
    return currentUser.bankCurrency!.toUpperCase(); // GBP, USD, EUR
  }

  // Priority 2: Fallback to payment provider
  if (currentUser.paymentProvider == 'razorpay') return 'INR';
  if (currentUser.paymentProvider == 'stripe') return 'USD';

  // Priority 3: Default
  return 'INR';
}
```

---

## 🌍 Country → Currency Mapping

Stripe automatically determines the default currency based on the account's country:

| Country | Code | Currency |
|---------|------|----------|
| United States | US | USD |
| United Kingdom | GB | GBP |
| Germany | DE | EUR |
| France | FR | EUR |
| Italy | IT | EUR |
| Spain | ES | EUR |
| Australia | AU | AUD |
| Canada | CA | CAD |
| Singapore | SG | SGD |
| UAE | AE | AED |
| Japan | JP | JPY |
| Switzerland | CH | CHF |
| India | IN | INR (via Razorpay) |

**Note:** Eurozone countries (DE, FR, IT, ES, etc.) all use EUR.

---

## 📊 Database Schema

### profiles_private Table
```sql
bank_currency TEXT  -- Currency of connected bank account
                    -- Examples: 'INR', 'USD', 'GBP', 'EUR', 'AUD'
                    -- Auto-populated from Stripe on account connection
```

### posts Table
```sql
currency_type TEXT DEFAULT 'INR'  -- Currency for this post
                                  -- Auto-set from bank_currency
                                  -- Used for payment routing
```

---

## ✅ Testing Multi-Currency

### Test Case 1: UK Provider (GBP)

**Setup:**
1. User selects country: United Kingdom
2. Connects Stripe account
3. Stripe creates account with country='GB'
4. Stripe sets default_currency='gbp'
5. App saves bank_currency='GBP'

**Expected:**
- Profile: `bank_currency = 'GBP'`
- Post: `currency_type = 'GBP'`
- Payment: Routes to Stripe with GBP

### Test Case 2: USA Provider (USD)

**Setup:**
1. User selects country: United States
2. Connects Stripe account
3. Stripe creates account with country='US'
4. Stripe sets default_currency='usd'
5. App saves bank_currency='USD'

**Expected:**
- Profile: `bank_currency = 'USD'`
- Post: `currency_type = 'USD'`
- Payment: Routes to Stripe with USD

### Test Case 3: Germany Provider (EUR)

**Setup:**
1. User selects country: Germany
2. Connects Stripe account
3. Stripe creates account with country='DE'
4. Stripe sets default_currency='eur'
5. App saves bank_currency='EUR'

**Expected:**
- Profile: `bank_currency = 'EUR'`
- Post: `currency_type = 'EUR'`
- Payment: Routes to Stripe with EUR

### Test Case 4: India Provider (INR)

**Setup:**
1. User selects payment provider: Razorpay
2. Enters bank details
3. App saves bank_currency='INR'

**Expected:**
- Profile: `bank_currency = 'INR'`
- Post: `currency_type = 'INR'`
- Payment: Routes to Razorpay with INR

---

## 🔍 Verification Queries

### Check Provider Currency
```sql
SELECT 
  id,
  full_name,
  payment_provider,
  bank_currency,
  stripe_account_id
FROM profiles_private
WHERE stripe_account_id IS NOT NULL
ORDER BY created_at DESC
LIMIT 10;
```

### Check Post Currency Distribution
```sql
SELECT 
  currency_type,
  COUNT(*) as post_count,
  AVG(price) as avg_price
FROM posts
GROUP BY currency_type
ORDER BY post_count DESC;
```

### Check Multi-Currency Posts
```sql
SELECT 
  p.id,
  p.currency_type,
  p.price,
  pp.bank_currency,
  pp.payment_provider
FROM posts p
JOIN profiles_private pp ON p.profile_id = pp.id
WHERE p.currency_type != 'INR'
LIMIT 10;
```

---

## 🎯 Currency Display

### Frontend Display
```dart
// Use AppPreferences for currency formatting
final formattedPrice = AppPreferences.instance.formatMoney(price);

// Currency symbol mapping
final symbols = {
  'INR': '₹',
  'USD': '$',
  'GBP': '£',
  'EUR': '€',
  'AUD': 'A$',
  'CAD': 'C$',
  'SGD': 'S$',
  'AED': 'د.إ',
  'JPY': '¥',
  'CHF': 'CHF',
};
```

---

## 🚨 Edge Cases

### 1. Currency Not Set
**Scenario:** Old Stripe accounts without currency  
**Fallback:** Default to 'USD'

### 2. Test Accounts
**Scenario:** Test Stripe accounts  
**Solution:** Auto-set to 'USD'

### 3. Currency Mismatch
**Scenario:** Provider changes bank but currency not updated  
**Solution:** Re-fetch from Stripe periodically

### 4. Unsupported Currency
**Scenario:** Stripe returns currency we don't handle  
**Solution:** Accept any currency code, Stripe will handle conversion

---

## 📈 Benefits

### For Providers
✅ **Accurate Currency:** Auto-detected from their actual bank  
✅ **No Manual Entry:** Currency set automatically  
✅ **Global Reach:** Support customers worldwide  
✅ **Correct Payouts:** Money transferred in their currency

### For Customers
✅ **Clear Pricing:** See prices in provider's currency  
✅ **No Confusion:** Currency clearly displayed  
✅ **Fair Exchange:** Stripe handles conversion at fair rates  
✅ **Multi-Currency Support:** Book from anywhere

### For Platform
✅ **Scalable:** Supports 135+ currencies automatically  
✅ **Low Maintenance:** No manual currency mapping  
✅ **Accurate Data:** Currency from source of truth (Stripe)  
✅ **Global Expansion:** Easy to support new countries

---

## 🔗 Related Documentation

- **Stripe Currencies:** https://stripe.com/docs/currencies
- **Stripe Connect:** https://stripe.com/docs/connect
- **Currency Conversion:** https://stripe.com/docs/currencies/conversions

---

## 📝 Summary

### How Currency is Determined:

1. **Provider Connects Stripe** → Stripe detects country → Sets default_currency
2. **App Fetches Currency** → Saves to `bank_currency` field
3. **Provider Creates Post** → Currency auto-set from `bank_currency`
4. **Customer Pays** → Payment processed in correct currency

### Supported Scenarios:

- ✅ India (INR) via Razorpay
- ✅ UK (GBP) via Stripe
- ✅ USA (USD) via Stripe
- ✅ Eurozone (EUR) via Stripe
- ✅ 130+ other currencies via Stripe

---

**Last Updated:** July 7, 2026  
**Version:** 1.0  
**Status:** ✅ Multi-Currency Support Active
