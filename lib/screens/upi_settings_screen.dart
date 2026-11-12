import 'package:flutter/material.dart';
import '../services/upi_repository.dart';

/// Simple UPI ID management screen
/// Collect UPI ID for Razorpay payouts - no noise!
class UPISettingsScreen extends StatefulWidget {
  const UPISettingsScreen({super.key});

  @override
  State<UPISettingsScreen> createState() => _UPISettingsScreenState();
}

class _UPISettingsScreenState extends State<UPISettingsScreen> {
  late TextEditingController _upiController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _upiController = TextEditingController();
    _loadUPI();
  }

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _loadUPI() async {
    await UPIRepository.instance.loadUPIId();
    if (mounted) {
      setState(() {
        _upiController.text = UPIRepository.instance.upiId.value ?? '';
      });
    }
  }

  Future<void> _saveUPI() async {
    final upi = _upiController.text.trim();

    if (upi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter UPI ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await UPIRepository.instance.saveUPIId(upi);

    if (mounted) {
      setState(() => _isSaving = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ UPI ID saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Invalid UPI format (e.g., user@okhdfcbank)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payout UPI ID'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💳 Instant Payouts via UPI',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your UPI ID to receive instant payouts of your earnings. We take 5% commission on each payout.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Instant delivery • 5% commission',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // UPI Input
            const Text(
              'UPI ID',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _upiController,
              enabled: !_isSaving,
              decoration: InputDecoration(
                hintText: 'user@okhdfcbank',
                prefixIcon: const Icon(Icons.account_balance),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                helperText: 'Format: username@bankname (e.g., john@upi)',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),

            // Examples
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Examples:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• john@upi\n'
                    '• user@okhdfcbank\n'
                    '• 8925021005@apl\n'
                    '• name@googleplay\n'
                    '• person@ybl',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveUPI,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Save UPI ID',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            // Current UPI Display
            if (UPIRepository.instance.hasUPIId()) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current UPI ID',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            UPIRepository.instance.upiId.value ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
