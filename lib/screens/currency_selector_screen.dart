import 'package:flutter/material.dart';
import '../services/app_preferences.dart';

class CurrencySelectorScreen extends StatefulWidget {
  const CurrencySelectorScreen({super.key});

  @override
  State<CurrencySelectorScreen> createState() => _CurrencySelectorScreenState();
}

class _CurrencySelectorScreenState extends State<CurrencySelectorScreen> {
  // Supported currencies with country associations
  static const Map<String, String> _currencies = {
    'INR': '🇮🇳 Indian Rupee (₹)',
    'USD': '🇺🇸 US Dollar (\$)',
    'GBP': '🇬🇧 British Pound (£)',
    'EUR': '🇪🇺 Euro (€)',
    'AED': '🇦🇪 UAE Dirham (د.إ)',
    'SGD': '🇸🇬 Singapore Dollar (S\$)',
    'AUD': '🇦🇺 Australian Dollar (A\$)',
    'CAD': '🇨🇦 Canadian Dollar (C\$)',
    'JPY': '🇯🇵 Japanese Yen (¥)',
    'CNY': '🇨🇳 Chinese Yuan (¥)',
    'SAR': '🇸🇦 Saudi Riyal (﷼)',
    'QAR': '🇶🇦 Qatari Riyal (ر.ق)',
    'PKR': '🇵🇰 Pakistani Rupee (₨)',
    'BDT': '🇧🇩 Bangladeshi Taka (৳)',
    'THB': '🇹🇭 Thai Baht (฿)',
    'MYR': '🇲🇾 Malaysian Ringgit (RM)',
  };

  String? _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = AppPreferences.instance.currencyCode.value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Currency'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _currencies.length,
        itemBuilder: (context, index) {
          final code = _currencies.keys.elementAt(index);
          final name = _currencies[code]!;
          final isSelected = _selectedCurrency == code;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            elevation: isSelected ? 4 : 1,
            color: isSelected ? Colors.blue.shade50 : null,
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.blue : Colors.grey.shade200,
                ),
                child: Center(
                  child: Text(
                    code.substring(0, 1),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              title: Text(
                name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text('Currency: $code'),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.blue)
                  : null,
              onTap: () async {
                setState(() {
                  _selectedCurrency = code;
                });
                await AppPreferences.instance.setCurrencyCode(code);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Currency changed to $code'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Close the screen after selection
                  Navigator.pop(context);
                }
              },
            ),
          );
        },
      ),
    );
  }
}
