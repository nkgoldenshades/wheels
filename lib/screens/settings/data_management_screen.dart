import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Data & Privacy'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMPORTANT: Optional Documents Notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                border: Border.all(color: Colors.green, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✓ Document Upload is OPTIONAL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You can use VaultWheels without uploading any documents. Not uploading is perfectly legal and your right. Documents are only requested if YOU want to verify.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Data Summary Section
            _buildDataSummaryCard(),
            const SizedBox(height: 20),

            // What Data We Have
            _buildSectionTitle('📊 Data We Have'),
            const SizedBox(height: 12),
            _buildDataItem(
              'Profile Information',
              'Name, email, phone, location',
              Icons.person,
            ),
            _buildDataItem(
              'Documents (Optional - NOT Required)',
              'Aadhaar, PAN, License, RC - Auto-delete after 30 days. You can skip this.',
              Icons.description,
            ),
            _buildDataItem(
              'Profile Photo',
              'Your display picture',
              Icons.photo,
            ),
            _buildDataItem(
              'Booking History',
              'All trips, rides, and transactions',
              Icons.history,
            ),
            _buildDataItem(
              'Reviews & Ratings',
              'Community feedback you gave',
              Icons.star,
            ),

            const SizedBox(height: 24),

            // Your Rights
            _buildSectionTitle('✅ Your Rights (DPDP 2023)'),
            const SizedBox(height: 12),
            _buildRightItem('Access', 'Download all your data'),
            _buildRightItem('Correct', 'Update your information'),
            _buildRightItem('Delete', 'Remove your account permanently'),
            _buildRightItem(
              'Portability',
              'Export your data to another service',
            ),

            const SizedBox(height: 24),

            // Data Deletion Section
            _buildSectionTitle('🗑️ Delete Your Data'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                border: Border.all(color: Colors.orange, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Deletion Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Deleted data cannot be recovered\n'
                    '• Processing takes up to 24 hours\n'
                    '• Your account will be permanently closed\n'
                    '• Existing bookings will be cancelled',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Delete Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isDeleting ? null : _showDeleteConfirmation,
                icon: _isDeleting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.delete_outline),
                label: Text(
                  _isDeleting ? 'Deleting...' : 'Delete My Account & Data',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Document Auto-Deletion Info
            _buildSectionTitle('⏰ Automatic Document Deletion'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                border: Border.all(color: Colors.blue, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your documents are automatically deleted:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Aadhaar: Auto-delete after 30 days\n'
                    '• PAN: Auto-delete after 30 days\n'
                    '• Driving License: Auto-delete after 30 days\n'
                    '• RC: Auto-delete after 30 days\n\n'
                    'You can manually delete anytime from your Profile.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Data Storage Location
            _buildSectionTitle('☁️ Where Your Data is Stored'),
            const SizedBox(height: 12),
            _buildStorageInfo(
              'Profile & Documents',
              'Supabase (Secure Cloud Database)',
              'Encrypted, auto-backup',
            ),
            _buildStorageInfo(
              'Payments',
              'Razorpay/Stripe (Never stored by us)',
              'PCI-DSS compliant',
            ),
            _buildStorageInfo(
              'AI Services',
              'Google Cloud (for face matching)',
              'Ephemeral, not stored long-term',
            ),

            const SizedBox(height: 24),

            // Help Section
            _buildSectionTitle('❓ Need Help?'),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.blue),
              title: const Text('Privacy Questions?'),
              subtitle: const Text('Email: privacy@vaultwheels.com'),
              trailing: const Icon(Icons.arrow_forward, size: 16),
              onTap: () {
                // In real app, open email or browser
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email: privacy@vaultwheels.com'),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Data Summary',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStat('Profile', 'Complete'),
                _buildStat('Documents', 'Optional'),
                _buildStat('Retention', '30 days'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildDataItem(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        tileColor: Colors.grey.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildRightItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageInfo(String title, String location, String note) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              location,
              style: const TextStyle(fontSize: 12, color: Colors.blue),
            ),
            const SizedBox(height: 2),
            Text(
              note,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account & Data?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This action will:'),
            SizedBox(height: 12),
            Text('• Delete your profile permanently'),
            Text('• Cancel all active bookings'),
            Text('• Remove all your data from servers'),
            Text('• This CANNOT be undone'),
            SizedBox(height: 16),
            Text(
              'Are you absolutely sure?',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteAccountAndData();
            },
            child: const Text('Yes, Delete Everything'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccountAndData() async {
    setState(() => _isDeleting = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Not logged in'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isDeleting = false);
        return;
      }

      // Mark user as deleted (soft delete first)
      await supabase
          .from('profiles')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', userId);

      // Schedule hard delete of sensitive data
      await supabase.from('document_retention').delete().eq('user_id', userId);

      // Sign out
      await supabase.auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Account deleted. Your data will be permanently removed within 24 hours.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to login
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isDeleting = false);
    }
  }
}
