/// HS Code helper for parcel customs classification
/// Structure: First 6 digits (universal) + Country-specific (2-4 digits)
/// Example: India uses 8 digits (6 + 2), some countries use 10 digits (6 + 4)
library;

class HSCodeCategory {
  final String code; // 6-digit base code
  final String name;
  final String description;

  const HSCodeCategory({
    required this.code,
    required this.name,
    required this.description,
  });
}

/// Common HS Code categories (6-digit base - universal)
class HSCodeHelper {
  static const List<HSCodeCategory> commonCategories = [
    // Plastics & Containers
    HSCodeCategory(
      code: '392310',
      name: '🟦 Plastic Bottles',
      description: 'Plastic bottles, flasks, and containers',
    ),
    HSCodeCategory(
      code: '392340',
      name: '🟦 Plastic Cases',
      description: 'Plastic cases, boxes, containers for goods',
    ),

    // Textiles & Clothing
    HSCodeCategory(
      code: '620462',
      name: '👕 Women\'s Garments',
      description: 'Women\'s trousers, skirts, and garments',
    ),
    HSCodeCategory(
      code: '620443',
      name: '👔 Men\'s Garments',
      description: 'Men\'s trousers and garments',
    ),
    HSCodeCategory(
      code: '610910',
      name: '👕 T-Shirts',
      description: 'T-shirts and singlets',
    ),

    // Electronics
    HSCodeCategory(
      code: '851712',
      name: '📱 Mobile Phones',
      description: 'Mobile phones and parts',
    ),
    HSCodeCategory(
      code: '847130',
      name: '💻 Computer Parts',
      description: 'Computer parts and components',
    ),

    // Furniture
    HSCodeCategory(
      code: '940110',
      name: '🪑 Seats & Furniture',
      description: 'Seats and parts of furniture',
    ),

    // Books & Documents
    HSCodeCategory(
      code: '490191',
      name: '📚 Books & Publications',
      description: 'Printed books and publications',
    ),

    // Machinery & Tools
    HSCodeCategory(
      code: '730826',
      name: '🔧 Machinery Parts',
      description: 'Iron or steel machinery parts',
    ),

    // Food & Beverages
    HSCodeCategory(
      code: '210120',
      name: '🍗 Food Extracts',
      description: 'Food extracts and preparations',
    ),

    // Other
    HSCodeCategory(
      code: '961000',
      name: '📦 Other Goods',
      description: 'Other goods and miscellaneous items',
    ),
  ];

  /// Get country-specific HS code suffix examples
  static Map<String, String> getCountrySuffixes() {
    return {
      'IN': '00-99', // India: 8 digits total (6 + 2)
      'US': '0000-9999', // USA: 10 digits total (6 + 4)
      'GB': '00-99', // UK: 8 digits
      'EU': '00-99', // EU: 8 digits
      'CN': '00-99', // China: 10 digits
      'JP': '00-99', // Japan: 9 digits
      'AU': '00-99', // Australia: 10 digits
    };
  }

  /// Validate HS code format
  /// Returns true if valid (6+ digits)
  static bool isValidHSCode(String code) {
    final cleaned = code.replaceAll(RegExp(r'\D'), ''); // Remove non-digits
    return cleaned.length >= 6 && cleaned.length <= 10;
  }

  /// Format HS code with spaces
  /// Example: "39231000" -> "3923 10 00"
  static String formatHSCode(String code) {
    final cleaned = code.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length < 6) return cleaned;

    // Format as: 4 digits + 2 digits + rest
    if (cleaned.length == 6) return cleaned;
    if (cleaned.length == 8) {
      return '${cleaned.substring(0, 4)} ${cleaned.substring(4, 6)} ${cleaned.substring(6)}';
    }
    if (cleaned.length == 10) {
      return '${cleaned.substring(0, 4)} ${cleaned.substring(4, 6)} ${cleaned.substring(6, 8)} ${cleaned.substring(8)}';
    }
    return cleaned;
  }

  /// Get category by code
  static HSCodeCategory? getCategoryByCode(String code) {
    try {
      final cleaned = code.replaceAll(RegExp(r'\D'), '');
      final baseCode = cleaned.substring(0, 6);

      return commonCategories.firstWhere(
        (cat) => cat.code.startsWith(baseCode.substring(0, 4)),
        orElse: () => HSCodeCategory(
          code: baseCode,
          name: '📦 Custom Code',
          description: 'Custom HS code',
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Get all HS codes formatted
  static List<String> getAllFormattedCodes() {
    return commonCategories.map((cat) => '${cat.code} - ${cat.name}').toList();
  }
}
