/// Predefined credit packages users can purchase
class CreditPackage {
  final String id;
  final int credits;
  final double priceUSD;
  final double savingsPercent; // Discount vs base rate
  final bool isPopular;

  const CreditPackage({
    required this.id,
    required this.credits,
    required this.priceUSD,
    this.savingsPercent = 0.0,
    this.isPopular = false,
  });

  // Base rate: 1 credit = $0.06 (100 credits = $5.99)
  static const double _baseRate = 0.06;

  // Predefined packages
  static const List<CreditPackage> packages = [
    CreditPackage(
      id: 'starter',
      credits: 50,
      priceUSD: 2.99,
      savingsPercent: 0.0,
      isPopular: false,
    ),
    CreditPackage(
      id: 'basic',
      credits: 100,
      priceUSD: 4.99,
      savingsPercent: 17.0,
      isPopular: true,
    ),
    CreditPackage(
      id: 'pro',
      credits: 500,
      priceUSD: 19.99,
      savingsPercent: 33.0,
      isPopular: false,
    ),
    CreditPackage(
      id: 'enterprise',
      credits: 1000,
      priceUSD: 34.99,
      savingsPercent: 42.0,
      isPopular: false,
    ),
  ];

  factory CreditPackage.fromJson(Map<String, dynamic> json) {
    return CreditPackage(
      id: json['id'] as String,
      credits: json['credits'] as int,
      priceUSD: (json['price_usd'] as num).toDouble(),
      savingsPercent: (json['savings_percent'] as num?)?.toDouble() ?? 0.0,
      isPopular: json['is_popular'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'credits': credits,
    'price_usd': priceUSD,
    'savings_percent': savingsPercent,
    'is_popular': isPopular,
  };

  /// Get price per credit for this package
  double get pricePerCredit => priceUSD / credits;
}
