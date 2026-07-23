import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import '../../models/credit_package.dart';
import '../../services/credit_payment_service.dart';
import '../../services/credit_repository.dart';

class BuyCreditsScreen extends StatefulWidget {
  const BuyCreditsScreen({super.key});

  @override
  State<BuyCreditsScreen> createState() => _BuyCreditsScreenState();
}

class _BuyCreditsScreenState extends State<BuyCreditsScreen> {
  String? _selectedPackageId;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy Credits'), elevation: 0),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current balance
              ValueListenableBuilder<int>(
                valueListenable: CreditRepository.instance.creditBalance,
                builder: (context, balance, _) {
                  return Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Credit Balance',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                            ],
                          ),
                          Text(
                            '$balance',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Pricing explanation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '1 credit = \$0.06\n'
                        'Average message: ~0.04 credits\n'
                        'Cost shown in real-time',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Credit packages
              const Text(
                'Choose Your Package',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ..._buildPackageCards(),
              const SizedBox(height: 24),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Purchase button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedPackageId == null || _isProcessing
                      ? null
                      : _handlePurchase,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Buy Credits',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Transaction history link
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreditHistoryScreen(),
                      ),
                    );
                  },
                  child: const Text('View Transaction History'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPackageCards() {
    return CreditPackage.packages.map((package) {
      final isSelected = _selectedPackageId == package.id;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedPackageId = package.id);
          },
          child: Card(
            elevation: isSelected ? 4 : 1,
            color: isSelected ? Colors.blue.shade50 : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
              side: BorderSide(
                color: isSelected ? Colors.blue : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Radio<String>(
                    value: package.id,
                    groupValue: _selectedPackageId,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPackageId = value);
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${package.credits} Credits',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${package.priceUSD.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (package.isPopular)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Most Popular',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (package.savingsPercent > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Save ${package.savingsPercent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Future<void> _handlePurchase() async {
    if (_selectedPackageId == null) return;

    final package = CreditPackage.packages.firstWhere(
      (p) => p.id == _selectedPackageId,
    );

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Create payment intent
      final intentResult = await CreditPaymentService.instance
          .createPaymentIntent(
            amountCents: (package.priceUSD * 100).toInt(),
            credits: package.credits,
            packageId: package.id,
          );

      if (intentResult.containsKey('error')) {
        throw Exception(intentResult['error']);
      }

      final clientSecret = intentResult['clientSecret'] as String;

      // Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'QuickOHunt',
          customFlow: false,
        ),
      );

      // Show payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Payment succeeded - confirm it
      final confirmResult = await CreditPaymentService.instance.confirmPayment(
        paymentIntentId: intentResult['paymentIntentId'],
        credits: package.credits,
        amountUSD: package.priceUSD,
      );

      if (confirmResult.containsKey('error')) {
        throw Exception(confirmResult['error']);
      }

      // Success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Successfully purchased ${package.credits} credits!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh credit balance
        await CreditRepository.instance.refreshFromSupabase();

        // Pop back to previous screen
        Navigator.pop(context);
      }
    } on StripeException catch (_) {
      setState(() {
        _errorMessage = 'Payment cancelled';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Transaction History Screen
// ═══════════════════════════════════════════════════════════════════════════

class CreditHistoryScreen extends StatefulWidget {
  const CreditHistoryScreen({super.key});

  @override
  State<CreditHistoryScreen> createState() => _CreditHistoryScreenState();
}

class _CreditHistoryScreenState extends State<CreditHistoryScreen> {
  @override
  void initState() {
    super.initState();
    CreditRepository.instance.refreshFromSupabase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: ValueListenableBuilder<List<dynamic>>(
        valueListenable: CreditRepository.instance.transactions,
        builder: (context, transactions, _) {
          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final txn = transactions[index];
              final isIncome = txn.creditsChanged > 0;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isIncome
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  child: Icon(
                    isIncome ? Icons.add : Icons.remove,
                    color: isIncome ? Colors.green : Colors.red,
                  ),
                ),
                title: Text(txn.displayName),
                subtitle: Text(
                  txn.createdAt.toString().substring(0, 16),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                trailing: Text(
                  '${isIncome ? '+' : ''}${txn.creditsChanged} credits',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isIncome ? Colors.green : Colors.red,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
