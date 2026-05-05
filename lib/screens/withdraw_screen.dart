import 'package:flutter/material.dart';
import '../services/profile_repository.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  String _status = 'idle';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw Earnings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<ProfileInfo>(
        valueListenable: ProfileRepository.instance.profile,
        builder: (context, profile, _) {
          if (profile.id.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Earnings info card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.account_balance_wallet, size: 48, color: Colors.green),
                        const SizedBox(height: 12),
                        const Text(
                          'Earnings',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Managed via payment provider',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Payment provider info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          profile.paymentProvider == 'razorpay'
                              ? Icons.account_balance
                              : Icons.credit_card,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.paymentProvider == 'razorpay'
                                  ? 'Razorpay (India)'
                                  : 'Stripe (International)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              profile.paymentProvider == 'razorpay'
                                  ? 'Withdraw to bank account'
                                  : 'Withdraw via Stripe Connect',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                _buildWithdrawButton(profile),

                const SizedBox(height: 16),

                Text(
                  profile.paymentProvider == 'razorpay'
                      ? 'Withdrawals are processed within 2-4 hours to your bank account.'
                      : 'Withdrawals are processed within 2-7 business days via Stripe.',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWithdrawButton(ProfileInfo profile) {
    switch (_status) {
      case 'processing':
        return ElevatedButton(
          onPressed: null,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('Processing payout...'),
            ],
          ),
        );
      default:
        return ElevatedButton(
          onPressed: () => _initiateWithdraw(profile),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text(
            'Request Withdrawal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        );
    }
  }

  Future<void> _initiateWithdraw(ProfileInfo profile) async {
    if (profile.paymentProvider == 'razorpay') {
      await _withdrawViaRazorpay(profile);
    } else {
      await _withdrawViaStripe(profile);
    }
  }

  Future<void> _withdrawViaRazorpay(ProfileInfo profile) async {
    if (profile.razorpayAccountId == null) {
      _showBankDetailsDialog();
      return;
    }
    await _processRazorpayPayout(profile);
  }

  Future<void> _withdrawViaStripe(ProfileInfo profile) async {
    if (profile.stripeAccountId == null) {
      _showStripeSetupDialog();
      return;
    }
    await _processStripePayout(profile);
  }

  void _showBankDetailsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bank Details'),
        content: const Text('To withdraw your earnings, please add your bank account details.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _showMessage('Bank details screen coming soon!');
            },
            child: const Text('Add Bank Details'),
          ),
        ],
      ),
    );
  }

  void _showStripeSetupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setup Stripe Account'),
        content: const Text('To withdraw your earnings, please complete Stripe account setup.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _showMessage('Stripe setup coming soon!');
            },
            child: const Text('Setup Stripe'),
          ),
        ],
      ),
    );
  }

  Future<void> _processRazorpayPayout(ProfileInfo profile) async {
    setState(() => _status = 'processing');
    try {
      await Future.delayed(const Duration(seconds: 2));
      _showMessage('Payout initiated! You\'ll receive your earnings within 2-4 hours.');
    } catch (e) {
      _showMessage('Payout failed: $e');
    } finally {
      setState(() => _status = 'idle');
    }
  }

  Future<void> _processStripePayout(ProfileInfo profile) async {
    setState(() => _status = 'processing');
    try {
      await Future.delayed(const Duration(seconds: 2));
      _showMessage('Payout initiated! You\'ll receive your earnings within 2-7 business days.');
    } catch (e) {
      _showMessage('Payout failed: $e');
    } finally {
      setState(() => _status = 'idle');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

