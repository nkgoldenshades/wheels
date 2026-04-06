import 'package:flutter/material.dart';
import '../services/profile_repository.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  String _status = 'idle'; // idle, verifying, processing
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw Earnings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<ProfileInfo?>(
        valueListenable: ProfileRepository.instance.profile,
        builder: (context, profile, _) {
          if (profile == null) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Wallet balance card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.account_balance_wallet, size: 48, color: Colors.green),
                        const SizedBox(height: 12),
                        const Text(
                          'Available Balance',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${profile.walletBalance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 32,
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
                
                // Withdraw button
                _buildWithdrawButton(profile),
                
                const SizedBox(height: 16),
                
                // Info text
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
    if (profile.walletBalance <= 0) {
      return ElevatedButton(
        onPressed: null,
        child: const Text('No balance to withdraw'),
      );
    }
    
    switch (_status) {
      case 'verifying':
        return ElevatedButton(
          onPressed: null,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Verifying details...'),
            ],
          ),
        );
        
      case 'processing':
        return ElevatedButton(
          onPressed: null,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
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
          child: Text(
            'Withdraw ₹${profile.walletBalance.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        );
    }
  }
  
  Future<void> _initiateWithdraw(ProfileInfo profile) async {
    // Route to correct payment provider
    if (profile.paymentProvider == 'razorpay') {
      await _withdrawViaRazorpay(profile);
    } else {
      await _withdrawViaStripe(profile);
    }
  }
  
  Future<void> _withdrawViaRazorpay(ProfileInfo profile) async {
    // Check if Razorpay account exists
    if (profile.razorpayAccountId == null) {
      _showBankDetailsDialog();
      return;
    }
    
    // Process payout
    await _processRazorpayPayout(profile);
  }
  
  Future<void> _withdrawViaStripe(ProfileInfo profile) async {
    // Check if Stripe account exists
    if (profile.stripeAccountId == null) {
      _showStripeSetupDialog();
      return;
    }
    
    // Process payout
    await _processStripePayout(profile);
  }
  
  void _showBankDetailsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bank Details'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('To withdraw your earnings, please add your bank account details.'),
            SizedBox(height: 16),
            Text(
              'We\'ll verify your details securely through Razorpay.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Bank details screen will be implemented later
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('To withdraw your earnings, please complete Stripe account setup.'),
            SizedBox(height: 16),
            Text(
              'You\'ll be redirected to Stripe to verify your identity and add payout details.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Stripe Connect onboarding will be implemented later
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
      // Razorpay payout implementation will be added later
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call
      
      // Update wallet balance
      await ProfileRepository.instance.updateWalletBalance(0.0);
      
      _showMessage('Payout initiated! You\'ll receive ₹${profile.walletBalance.toStringAsFixed(0)} within 2-4 hours.');
      
    } catch (e) {
      _showMessage('Payout failed: $e');
    } finally {
      setState(() => _status = 'idle');
    }
  }
  
  Future<void> _processStripePayout(ProfileInfo profile) async {
    setState(() => _status = 'processing');
    
    try {
      // Stripe payout implementation will be added later
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call
      
      // Update wallet balance
      await ProfileRepository.instance.updateWalletBalance(0.0);
      
      _showMessage('Payout initiated! You\'ll receive \$${profile.walletBalance.toStringAsFixed(2)} within 2-7 business days.');
      
    } catch (e) {
      _showMessage('Payout failed: $e');
    } finally {
      setState(() => _status = 'idle');
    }
  }
  
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}