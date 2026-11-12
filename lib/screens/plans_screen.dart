import 'package:flutter/material.dart';

/// Clean pricing plans screen
/// Separates Premium features from Optional Verification
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  String _selectedBillingCycle = 'monthly'; // 'monthly' or 'yearly'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Billing Cycle Selector
            _buildBillingToggle(),
            const SizedBox(height: 24),

            // Free Plan
            _buildPlanCard(
              name: 'Free',
              price: '₹0',
              description: 'Get started',
              isFeatured: false,
              features: const [
                'Browse all listings',
                'Create basic posts',
                'Limited visibility',
                'Standard support',
                'Basic analytics',
              ],
              buttonText: 'Current Plan',
              onTap: null, // Can't downgrade if on premium
            ),
            const SizedBox(height: 16),

            // Premium Plan (Featured)
            _buildPlanCard(
              name: 'Premium',
              price: _selectedBillingCycle == 'monthly' ? '₹999' : '₹9,999',
              period: _selectedBillingCycle == 'monthly' ? '/month' : '/year',
              description: 'Best for growing',
              isFeatured: true,
              features: const [
                'Everything in Free',
                'Priority listing placement',
                'Featured badge on posts',
                'Advanced analytics',
                'Priority customer support',
                'Better visibility (2x reach)',
                'Custom post descriptions',
              ],
              buttonText: 'Upgrade Now',
              onTap: () => _showUpgradeDialog(),
              badge: 'POPULAR',
            ),
            const SizedBox(height: 32),

            // Optional Verification Section
            _buildVerificationSection(),
            const SizedBox(height: 32),

            // Feature Comparison
            _buildFeatureComparison(),
            const SizedBox(height: 32),

            // FAQ
            _buildFAQ(),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedBillingCycle = 'monthly'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedBillingCycle == 'monthly'
                      ? Colors.blue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Monthly',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _selectedBillingCycle == 'monthly'
                        ? Colors.white
                        : Colors.grey[700],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedBillingCycle = 'yearly'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedBillingCycle == 'yearly'
                      ? Colors.blue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      'Yearly',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _selectedBillingCycle == 'yearly'
                            ? Colors.white
                            : Colors.grey[700],
                      ),
                    ),
                    if (_selectedBillingCycle == 'yearly')
                      Text(
                        'Save 17%',
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      )
                    else
                      Text(
                        'Save 17%',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String name,
    required String price,
    String? period,
    required String description,
    required bool isFeatured,
    required List<String> features,
    required String buttonText,
    required VoidCallback? onTap,
    String? badge,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isFeatured ? Colors.blue : Colors.grey[300]!,
          width: isFeatured ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        color: isFeatured ? Colors.blue[50] : Colors.white,
        boxShadow: isFeatured
            ? [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Price
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: price,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isFeatured ? Colors.blue : Colors.black,
                      ),
                    ),
                    if (period != null)
                      TextSpan(
                        text: period,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Features
              ...features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: isFeatured ? Colors.blue : Colors.green,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          feature,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: isFeatured
                        ? Colors.blue
                        : Colors.grey[300],
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: Text(
                    buttonText,
                    style: TextStyle(
                      color: isFeatured ? Colors.white : Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, color: Colors.green[700], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unlock Optional Verification',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Available with Premium - Upload documents to get verified badge ✓',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'All documents are completely optional. Upload what you\'re comfortable with:',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDocumentBadge('🚗 RC Book'),
              _buildDocumentBadge('🛡️ Insurance'),
              _buildDocumentBadge('🪪 Driving License'),
              _buildDocumentBadge('📝 National ID'),
              _buildDocumentBadge('💼 Tax ID'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Get verified badge after uploading 2+ documents',
            style: TextStyle(
              fontSize: 11,
              color: Colors.green[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.green[300]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
      ),
    );
  }

  Widget _buildFeatureComparison() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Feature Comparison',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildComparisonRow(
          'Post Visibility',
          'Limited',
          'Priority (2x reach)',
        ),
        _buildComparisonRow('Featured Badge', '❌', '✓'),
        _buildComparisonRow('Advanced Analytics', '❌', '✓'),
        _buildComparisonRow('Customer Support', 'Standard', 'Priority'),
        _buildComparisonRow('Custom Descriptions', '❌', '✓'),
        _buildComparisonRow('Optional Verification', '❌', '✓'),
      ],
    );
  }

  Widget _buildComparisonRow(String feature, String free, String premium) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              free,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              premium,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQ() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frequently Asked Questions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildFAQItem(
          'Is document verification required?',
          'No. Verification is completely optional. You can use Premium features without uploading any documents.',
        ),
        _buildFAQItem(
          'Can I cancel my subscription?',
          'Yes, cancel anytime from Settings → Billing. You\'ll keep Premium benefits until the end of your billing cycle.',
        ),
        _buildFAQItem(
          'What happens to my documents?',
          'Your documents are stored securely and only accessible by you. You can delete them anytime.',
        ),
        _buildFAQItem(
          'Is my payment information safe?',
          'All payments are processed securely through Razorpay. We never store your card details.',
        ),
      ],
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade to Premium'),
        content: const Text(
          'Get priority listing, advanced analytics, and more. You\'ll also unlock optional document verification.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to payment screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Navigate to payment')),
              );
            },
            child: const Text('Continue to Payment'),
          ),
        ],
      ),
    );
  }
}
