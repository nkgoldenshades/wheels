# 💱 Currency Selector Implementation Guide

## ✅ What's Done

1. **Multi-currency enabled** in `lib/services/app_preferences.dart`
   - Removed India-only lock
   - Users can now select any supported currency
   
2. **Currency selector screen created** at `lib/screens/currency_selector_screen.dart`
   - Beautiful UI with flags and currency symbols
   - Supports 16+ major currencies
   - Instantly saves user selection

## 🔧 How to Add to Your App

### Option 1: Add to Settings Page (Recommended)

In your **SettingsPage** (or wherever you have settings), add this ListTile:

```dart
ListTile(
  leading: const Icon(Icons.currency_exchange),
  title: const Text('Currency'),
  subtitle: ValueListenableBuilder<String>(
    valueListenable: AppPreferences.instance.currencyCode,
    builder: (context, currency, _) {
      return Text('Current: $currency');
    },
  ),
  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CurrencySelectorScreen(),
      ),
    );
  },
),
```

### Option 2: Add to Profile Page

Add the same ListTile to your ProfilePage where other preferences are shown.

### Option 3: Add as Filter in Main Screen

If you want it as a filter button on the main booking/slot screen:

```dart
IconButton(
  icon: const Icon(Icons.currency_exchange),
  tooltip: 'Change Currency',
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CurrencySelectorScreen(),
      ),
    );
  },
)
```

## 💰 Supported Currencies

The following currencies are supported with Stripe:

- 🇮🇳 INR (Indian Rupee)
- 🇺🇸 USD (US Dollar)  
- 🇬🇧 GBP (British Pound)
- 🇪🇺 EUR (Euro)
- 🇦🇪 AED (UAE Dirham)
- 🇸🇬 SGD (Singapore Dollar)
- 🇦🇺 AUD (Australian Dollar)
- 🇨🇦 CAD (Canadian Dollar)
- 🇯🇵 JPY (Japanese Yen)
- 🇨🇳 CNY (Chinese Yuan)
- 🇸🇦 SAR (Saudi Riyal)
- 🇶🇦 QAR (Qatari Riyal)
- 🇵🇰 PKR (Pakistani Rupee)
- 🇧🇩 BDT (Bangladeshi Taka)
- 🇹🇭 THB (Thai Baht)
- 🇲🇾 MYR (Malaysian Ringgit)

## 🎯 How It Works

1. User selects their preferred currency from the selector
2. AppPreferences saves it to SharedPreferences
3. All prices throughout the app automatically display in the selected currency
4. Stripe processes payments in the selected currency
5. Currency symbol updates everywhere instantly (using ValueListenableBuilder)

## ✅ What This Solves

- ✅ Users can choose their preferred currency
- ✅ Stripe handles multi-currency payments automatically
- ✅ No need for manual conversion
- ✅ International users can use their local currency
- ✅ All prices display consistently throughout the app

## 🧪 Testing

1. Open the app
2. Navigate to Settings → Currency
3. Select different currencies
4. Verify prices update throughout the app
5. Test payment with different currencies

## 📝 Next Steps

To fully enable this:
1. Add the ListTile to your Settings page (see Option 1 above)
2. Make sure Stripe account supports multi-currency
3. Test with small amounts in different currencies
4. Deploy!

---

**Note:** Stripe automatically handles currency conversion and displays prices to users in their selected currency. No backend changes needed!
