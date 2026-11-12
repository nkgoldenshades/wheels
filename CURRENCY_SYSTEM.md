# Currency System Documentation

## Overview
QuickOhunt implements a dynamic currency system tied to payment providers:
- **Razorpay (Current)**: India-only, always INR (₹)
- **Stripe (Future)**: Multi-currency based on connected bank account

## Current State (Razorpay Only)

### Default Currency
- **Default**: INR (₹)
- **Display**: All prices show in `₹` symbol
- **Locked**: Cannot be changed (Razorpay only supports INR)

### How It Works

```
App Startup
    ↓
AppPreferences.init()
    ↓
Load currency from SharedPreferences
    ↓
Default to INR if not set
    ↓
App UI builds with ₹ symbol
    ↓
Firebase auth fires
    ↓
ProfileRepository.loadProfile()
    ↓
Profile has Razorpay? → Force INR
Profile has no provider? → Default INR
    ↓
AppPreferences.setCurrencyCode('INR')
    ↓
UI updates with ₹ symbol everywhere
```

### UI Components Using Dynamic Currency

1. **Booking Details** - Shows `₹${amount}`
2. **Buy Credits** - Shows `₹${price}`
3. **AI Chat Prices** - Shows `₹${price}`
4. **Create Slot** - Shows `₹ price`
5. **Create Post** - Shows `₹ budget`
6. **Settings** - Shows `₹ INR` (locked)

All components use `AppPreferences.instance.currencySymbol` which respects the current currency code.

## Future State (When Stripe is Enabled)

### Multi-Currency Support

```
User Selects Stripe
    ↓
Stripe Account Linking Flow
    ↓
Get bank account currency from Stripe API
    ↓
updateStripeAccount(accountId, currency: 'USD') 
    or currency: 'GBP', 'EUR', etc.
    ↓
Save profile with bankCurrency = 'USD'
    ↓
ProfileRepository.loadProfile()
    ↓
Profile has Stripe + bankCurrency? → Use bankCurrency
    ↓
AppPreferences.setCurrencyCode('USD')
    ↓
UI updates with $ symbol everywhere
```

### Currency Rules

| Provider | Currency | Symbol | Rules |
|----------|----------|--------|-------|
| **Razorpay** | INR | ₹ | Always INR, cannot change |
| **Stripe** | Dynamic | Varies | Based on connected bank account currency |
| **None** | INR | ₹ | Default for new users |

## Technical Implementation

### AppPreferences
```dart
// Location: lib/services/app_preferences.dart
ValueNotifier<String> currencyCode = ValueNotifier<String>('INR');

String get currencySymbol {
  // Returns: ₹ for INR, $ for USD, £ for GBP, etc.
}

Future<void> setCurrencyCode(String code) async {
  currencyCode.value = code;
  // Saves to SharedPreferences
}
```

### ProfileRepository
```dart
// Location: lib/services/profile_repository.dart

Future<ProfileInfo> loadProfile(String userId) async {
  // 1. Load profile from Supabase
  // 2. Sync currency based on payment provider
  if (profileInfo.paymentProvider == 'razorpay') {
    await AppPreferences.instance.setCurrencyCode('INR');
  } else if (profileInfo.bankCurrency != null) {
    await AppPreferences.instance.setCurrencyCode(profileInfo.bankCurrency!);
  } else {
    await AppPreferences.instance.setCurrencyCode('INR');
  }
}

Future<void> updateRazorpayAccount(String accountId) async {
  // Force INR for Razorpay
  await saveProfile(
    profile.copyWith(
      razorpayAccountId: accountId,
      bankCurrency: 'INR',
    ),
  );
  await AppPreferences.instance.setCurrencyCode('INR');
}

Future<void> updateStripeAccount(String accountId, {String? currency}) async {
  // Allow currency flexibility for Stripe
  String? bankCurrency = currency ?? 'USD';
  await saveProfile(
    profile.copyWith(
      stripeAccountId: accountId,
      bankCurrency: bankCurrency,
    ),
  );
}
```

## UI Pattern

All price displays use `ValueListenableBuilder` to watch for currency changes:

```dart
ValueListenableBuilder<String>(
  valueListenable: AppPreferences.instance.currencyCode,
  builder: (context, currency, _) {
    return Text(
      '${AppPreferences.instance.currencySymbol}${price.toStringAsFixed(2)}',
    );
  },
)
```

This ensures that when currency changes (e.g., user switches from Razorpay to Stripe), all UI automatically updates.

## Database Schema

### ProfileInfo.bankCurrency Field
```dart
final String? bankCurrency; // INR for Razorpay, USD/GBP/EUR for Stripe
```

Stored in `profiles_private` table:
```sql
bank_currency VARCHAR(3) -- ISO 4217 currency code (INR, USD, GBP, EUR, etc.)
```

## Initialization Sequence

### Current Implementation
1. ✅ Firebase init
2. ✅ AuthRepository init
3. ✅ **AppPreferences init** (BEFORE app builds)
4. ✅ App UI builds
5. ✅ Background services init (ProfileRepository, etc.)
6. ✅ Currency sync when profile loads

This ensures currency is available before UI builds.

## Future Enhancements

When Stripe is enabled:
1. Uncomment Stripe initialization in `main.dart` (line ~336)
2. Uncomment Stripe UI options in settings
3. Implement Stripe account linking flow
4. Add currency selector in Stripe setup
5. Test multi-currency transactions

## Testing Checklist

- [x] Razorpay only → INR shows everywhere
- [x] Settings page → Shows INR locked
- [x] Booking details → Shows ₹
- [x] Buy credits → Shows ₹
- [x] AI chat → Shows ₹
- [x] Create post/slot → Shows ₹
- [x] App restart → Persists INR
- [ ] Future: Stripe enabled → Shows $ (when Stripe is enabled)
