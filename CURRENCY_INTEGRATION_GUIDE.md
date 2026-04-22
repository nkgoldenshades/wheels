# 💰 Currency Auto-Detection Integration Guide

## ✅ How It Works:

### **Automatic Currency Detection**
- **Device Locale**: Detects user's country from device settings
- **Auto-Assignment**: 
  - 🇺🇸 US users → USD ($)
  - 🇮🇳 Indian users → INR (₹)
  - 🇬🇧 UK users → GBP (£)
  - 🇪🇺 EU users → EUR (€)
  - And 25+ more countries supported

### **Manual Override Available**
Users can change currency if needed (e.g., US tourist in India can use INR)

## 🔧 Implementation:

### **1. Currency Service**
```dart
// Auto-detect currency
final currency = CurrencyService().getDeviceCurrency();
// Returns: "INR" for Indian users, "USD" for US users

// Format prices
final formatted = CurrencyService().formatPrice(500, "INR");
// Returns: "₹500" for Indian format
```

### **2. Slot Data with Auto-Currency**
```dart
// Passenger slots with auto-currency
final passengerConfig = SlotConfiguration.passenger(
  slots: [
    PassengerSlotData(
      slotType: 'seat',
      price: 500,
      currencyCode: 'INR', // Auto-detected
      securityPrice: 100,
    ),
    PassengerSlotData(
      slotType: 'berth',
      price: 800,
      currencyCode: 'INR', // Auto-detected
      securityPrice: 150,
    ),
  ],
);

// Parcel slots with auto-currency
final parcelConfig = SlotConfiguration.parcel(
  slots: [
    ParcelSlotData(
      length: 20,
      breadth: 15,
      height: 10,
      weight: 5,
      price: 300,
      currencyCode: 'INR', // Auto-detected
      securityPrice: 50,
    ),
  ],
);
```

## 📊 JSON Output Examples:

### **Passenger (Indian User)**
```json
{
  "grid": [
    {
      "row": 1,
      "col": 1,
      "data": {
        "slot_type": "seat",
        "price": 500,
        "currency_code": "INR",
        "security_price": 100,
        "gender_preference": "any"
      }
    },
    {
      "row": 1,
      "col": 2,
      "data": {
        "slot_type": "berth",
        "price": 800,
        "currency_code": "INR",
        "security_price": 150,
        "gender_preference": "female"
      }
    }
  ]
}
```

### **Parcel (US User)**
```json
{
  "grid": [
    {
      "row": 1,
      "col": 1,
      "data": {
        "length": 20,
        "breadth": 15,
        "height": 10,
        "weight": 5,
        "price": 15.99,
        "currency_code": "USD",
        "security_price": 2.50
      }
    }
  ]
}
```

## 🎯 Usage in Your App:

### **1. Create Slots Screen**
```dart
class CreateSlotScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    // Auto-detect user's currency
    final userCurrency = CurrencyService().getDeviceCurrency();
    final currencySymbol = CurrencyService().getCurrencySymbol(userCurrency);
    
    return Column(
      children: [
        Text('Price ($currencySymbol)'),
        TextField(
          decoration: InputDecoration(
            prefixText: currencySymbol,
            hintText: 'Enter price',
          ),
        ),
        // Currency override dropdown (optional)
        DropdownButton<String>(
          value: userCurrency,
          items: CurrencyService().getSupportedCurrencies()
              .map((currency) => DropdownMenuItem(
                    value: currency['code'],
                    child: Text(currency['display']!),
                  ))
              .toList(),
          onChanged: (newCurrency) {
            // Update currency
          },
        ),
      ],
    );
  }
}
```

### **2. Display Formatted Prices**
```dart
class SlotCard extends StatelessWidget {
  final SlotData slotData;
  
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text('Price: ${slotData.getFormattedPrice()}'),
          Text('Security: ${slotData.getFormattedSecurityPrice()}'),
          if (slotData is ParcelSlotData) ...[
            Text('Dimensions: ${(slotData as ParcelSlotData).getFormattedDimensions()}'),
            Text('Weight: ${(slotData as ParcelSlotData).getFormattedWeight()}'),
          ],
        ],
      ),
    );
  }
}
```

## 🌍 Supported Countries & Currencies:

| Country | Currency | Symbol | Format Example |
|---------|----------|--------|----------------|
| 🇺🇸 United States | USD | $ | $1,500.00 |
| 🇮🇳 India | INR | ₹ | ₹1,500 |
| 🇬🇧 United Kingdom | GBP | £ | £1,500.00 |
| 🇪🇺 European Union | EUR | € | €1.500,00 |
| 🇯🇵 Japan | JPY | ¥ | ¥1500 |
| 🇨🇦 Canada | CAD | C$ | C$1,500.00 |
| 🇦🇺 Australia | AUD | A$ | A$1,500.00 |
| 🇸🇬 Singapore | SGD | S$ | S$1,500.00 |
| 🇦🇪 UAE | AED | د.إ | د.إ1,500.00 |
| 🇸🇦 Saudi Arabia | SAR | ﷼ | ﷼1,500.00 |

*And 15+ more countries supported*

## 🔄 Integration Steps:

### **Step 1: Add Currency Service**
✅ `lib/services/currency_service.dart` - Auto-detection logic

### **Step 2: Add Slot Data Models**
✅ `lib/models/slot_data.dart` - Structured slot data with currency

### **Step 3: Update Create Slot Screen**
```dart
// In your slot creation screen
final currency = CurrencyService().getDeviceCurrency();
final slotConfig = SlotConfiguration.passenger(
  slots: yourSlots,
  currencyCode: currency, // Auto-detected
);
```

### **Step 4: Save to Database**
```dart
// Save slot configuration as JSON
final jsonData = slotConfig.toJson();
await supabase.from('slots').insert({
  'vehicle_id': vehicleId,
  'slot_data': jsonData, // JSON with currency_code
  'service_type': 'passenger', // or 'parcel'
});
```

## ✨ Benefits:

1. **User-Friendly**: No manual currency selection needed
2. **Global Ready**: Supports 25+ countries automatically
3. **Proper Formatting**: Currency-specific number formatting
4. **Override Option**: Users can change currency if needed
5. **Consistent Data**: All prices stored with currency_code
6. **Easy Display**: Formatted prices with correct symbols

Your slot system now automatically handles currencies based on user location! 🎉
