import 'package:flutter/material.dart';

/// Reusable widget that shows payment method recommendations and fees
/// Display this BEFORE payment UI to educate users about cost savings
class PaymentMethodInfo extends StatelessWidget {
  final String currency;
  final double amount;
  final bool showDetailed;

  const PaymentMethodInfo({
    super.key,
    required this.currency,
    required this.amount,
    this.showDetailed = true,
  });

  @override
  Widget build(BuildContext context) {
    final isINR = currency.toUpperCase() == 'INR';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Payment Method Guide',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Recommended method
          if (isINR) ...[
            _buildRecommendedMethod(
              icon: Icons.phone_android,
              title: 'UPI (Recommended) ⭐',
              subtitle: 'Google Pay, PhonePe, Paytm',
              fee: '₹${(amount * 0.0025).toStringAsFixed(2)}',
              percentage: '0.25%',
              highlight: true,
            ),
            if (showDetailed) ...[
              const SizedBox(height: 8),
              _buildPaymentMethod(
                icon: Icons.credit_card,
                title: 'Credit/Debit Card',
                fee: '₹${(amount * 0.02).toStringAsFixed(2)}',
                percentage: '2%',
              ),
              const SizedBox(height: 8),
              _buildPaymentMethod(
                icon: Icons.account_balance,
                title: 'Netbanking',
                fee: '₹5',
                percentage: 'Flat fee',
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.savings, color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Save ₹${((amount * 0.02) - (amount * 0.0025)).toStringAsFixed(2)} by choosing UPI!',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // International (Stripe)
            _buildRecommendedMethod(
              icon: Icons.account_balance,
              title: 'Bank Transfer (Recommended) ⭐',
              subtitle: 'ACH (USA) / SEPA (Europe)',
              fee: '\$${(amount * 0.008).toStringAsFixed(2)}',
              percentage: '0.8%',
              highlight: true,
            ),
            if (showDetailed) ...[
              const SizedBox(height: 8),
              _buildPaymentMethod(
                icon: Icons.credit_card,
                title: 'Credit/Debit Card',
                fee: '\$${(amount * 0.029 + 0.30).toStringAsFixed(2)}',
                percentage: '2.9% + \$0.30',
              ),
              const SizedBox(height: 8),
              _buildPaymentMethod(
                icon: Icons.apple,
                title: 'Apple Pay / Google Pay',
                fee: '\$${(amount * 0.029 + 0.30).toStringAsFixed(2)}',
                percentage: '2.9% + \$0.30',
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.savings, color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Save \$${((amount * 0.029 + 0.30) - (amount * 0.008)).toStringAsFixed(2)} with bank transfer!',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendedMethod({
    required IconData icon,
    required String title,
    required String subtitle,
    required String fee,
    required String percentage,
    required bool highlight,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? Colors.green.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? Colors.green.shade300 : Colors.grey.shade300,
          width: highlight ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fee,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              Text(
                percentage,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod({
    required IconData icon,
    required String title,
    required String fee,
    required String percentage,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fee,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                percentage,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
