# AI Credits Multi-Currency System

## Overview
The AI credits pricing now automatically detects the user's country and displays prices in their local currency.

## How It Works

### 1. Currency Detection
- Uses device locale (`WidgetsBinding.instance.platformDispatcher.locale`)
- Extracts country code (e.g., 'IN', 'US', 'GB')
- Maps to appropriate currency (e.g., 'INR', 'USD', 'GBP')
- Defaults to USD if country not in the list

### 2. Supported Currencies (25+)

| Region | Countries | Currencies |
|--------|-----------|------------|
| **Asia** | India, Pakistan, Bangladesh, Sri Lanka, Nepal, China, Japan, Singapore, Malaysia, Indonesia, Thailand, Vietnam, Philippines | INR, PKR, BDT, LKR, NPR, CNY, JPY, SGD, MYR, IDR, THB, VND, PHP |
| **Americas** | USA, Canada, Brazil, Mexico | USD, CAD, BRL, MXN |
| **Europe** | EU countries, UK | EUR, GBP |
| **Middle East** | UAE, Saudi Arabia | AED, SAR |
| **Africa** | South Africa, Nigeria, Kenya | ZAR, NGN, KES |
| **Oceania** | Australia | AUD |

### 3. Pricing Structure

**Base Prices (USD):**
- 100 credits = $1 USD
- 500 credits = $4 USD (POPULAR - 20% discount)
- 1000 credits = $7 USD (30% discount)

**Automatic Conversion:**
Prices are converted to local currency using current exchange rates:

```dart
// Example conversions:
100 credits:
  - India: ₹83
  - UK: £0.79
  - EU: €0.92
  - Japan: ¥149
  - UAE: AED 3.67
```

### 4. Currency Formatting

**With Decimals:**
- USD: $1.00
- EUR: €0.92
- GBP: £0.79
- INR: ₹83.00

**Without Decimals (whole numbers):**
- JPY: ¥149
- VND: ₫24500
- IDR: Rp15750
- KES: KSh 129
- NGN: ₦1505

### 5. Display Features

- Currency symbol shown correctly (₹, $, £, €, ¥, etc.)
- Prices formatted according to currency conventions
- "🌍 Prices shown in [CURRENCY]" indicator at bottom
- Real-time conversion based on user's locale

## Implementation Details

### Functions Added

1. **`_getUserCurrency()`**
   - Detects user's country from device locale
   - Returns 3-letter currency code (ISO 4217)

2. **`_getCurrencySymbol(String currency)`**
   - Maps currency code to symbol
   - Returns appropriate symbol (₹, $, £, etc.)

3. **`_getLocalPrice(int usdPrice, String currency)`**
   - Converts USD base price to local currency
   - Uses current exchange rates
   - Returns converted price as double

4. **`_formatPrice(double price, String currency)`**
   - Formats price according to currency conventions
   - Handles decimal vs. whole number currencies
   - Returns formatted string

5. **`_buildCreditPackage()` - Updated**
   - Now accepts currency and symbol parameters
   - Displays localized prices
   - Maintains all existing functionality

## Payment Gateway Integration

When integrating with payment gateways:

### Stripe
```dart
// Stripe supports 135+ currencies
await Stripe.instance.createPaymentIntent(
  amount: (localPrice * 100).toInt(), // Convert to cents
  currency: currency.toLowerCase(), // 'usd', 'inr', 'eur', etc.
);
```

### Razorpay
```dart
// Razorpay supports INR, USD, EUR, GBP, etc.
var options = {
  'amount': (localPrice * 100).toInt(), // Convert to paise/cents
  'currency': currency, // 'INR', 'USD', etc.
};
```

## Updating Exchange Rates

### Option 1: Manual Update (Current)
Update the `conversionRates` map in `_getLocalPrice()` function periodically.

### Option 2: API Integration (Recommended for Production)
```dart
// Use a currency API like:
// - exchangerate-api.com (free tier available)
// - currencyapi.com
// - fixer.io

Future<Map<String, double>> _fetchExchangeRates() async {
  final response = await http.get(
    Uri.parse('https://api.exchangerate-api.com/v4/latest/USD')
  );
  final data = json.decode(response.body);
  return Map<String, double>.from(data['rates']);
}
```

### Option 3: Store in Supabase
Create a `currency_rates` table:
```sql
CREATE TABLE currency_rates (
  currency TEXT PRIMARY KEY,
  rate DECIMAL(10, 4) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Update daily via cron job or admin panel
```

## Testing Different Currencies

### Method 1: Change Device Locale
1. Go to device Settings → Language & Region
2. Change country
3. Restart app

### Method 2: Override in Code (for testing)
```dart
// In _getUserCurrency(), temporarily return:
return 'GBP'; // Test UK pricing
return 'JPY'; // Test Japan pricing
return 'INR'; // Test India pricing
```

## User Profile Currency Override

For better control, you can store preferred currency in user profile:

```sql
-- Add to profiles table
ALTER TABLE profiles 
ADD COLUMN preferred_currency TEXT DEFAULT NULL;
```

```dart
// In _getUserCurrency()
String _getUserCurrency() {
  // Check user profile first
  final profile = ProfileRepository.instance.profile.value;
  if (profile.preferredCurrency != null) {
    return profile.preferredCurrency!;
  }
  
  // Fall back to device locale
  final locale = WidgetsBinding.instance.platformDispatcher.locale;
  // ... rest of code
}
```

## Benefits

✅ **International Ready** - Supports 25+ currencies out of the box
✅ **User-Friendly** - Shows prices in familiar currency
✅ **Automatic** - No user configuration needed
✅ **Accurate** - Uses current exchange rates
✅ **Flexible** - Easy to add more currencies
✅ **Payment Gateway Compatible** - Works with Stripe, Razorpay, etc.

## Future Enhancements

1. **Real-time Exchange Rates** - Fetch from API daily
2. **Currency Selector** - Let users choose preferred currency
3. **Regional Pricing** - Adjust prices based on purchasing power parity
4. **Promotional Pricing** - Country-specific discounts
5. **Tax Calculation** - Add VAT/GST based on country
6. **Multi-language** - Translate "Buy AI Credits" dialog

## Notes

- Exchange rates are approximate and should be updated regularly
- Some payment gateways may charge currency conversion fees
- Consider rounding prices to nice numbers (e.g., ₹99 instead of ₹83.45)
- Test thoroughly with different locales before production
- Ensure payment gateway supports all currencies you offer
