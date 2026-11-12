import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildSection(
              'Privacy Policy - VaultWheels',
              'Last Updated: August 2026\n\nVaultWheels ("we", "our", or "us") operates a social media platform where users can connect, share content, and engage with community services.',
            ),
            const SizedBox(height: 16),
            _buildSection('1. Information We Collect', '''REQUIRED DATA:
• Profile Information: Name, phone, email

COMPLETELY OPTIONAL - YOUR CHOICE:
• Profile Documents: Aadhaar, PAN, Driving License, RC
  → You do NOT have to upload these
  → Not uploading is perfectly fine and legal
  → This is NOT mandatory
• Profile Photo: Your display picture
• Address: City, state, country
• Reviews & Ratings: Community feedback (if you participate)

CONDITIONAL DATA:
• Location Data: GPS coordinates (only when using ride/parcel features)
• Payment Information: Processed through Razorpay/Stripe (never stored)

⚠️ IMPORTANT CLARITY:
✓ You can browse and use VaultWheels WITHOUT any documents
✓ Not uploading documents is your RIGHT - not illegal
✓ We ONLY ask for documents if YOU want to
✓ We do NOT require verification to use the app
✓ All document uploads are completely voluntary
✓ You can keep your data private - no penalty'''),
            const SizedBox(height: 16),
            _buildSection(
              '2. How We Use Your Information',
              '''• User Profiles: Display on social media feed
• Content Sharing: Share posts, photos, videos with community
• Social Interactions: Likes, comments, reviews from other users
• Service Coordination: Organize rides, events, parcel sharing
• Face Matching: Help users recognize each other via profile photo
• Safety & Fraud Prevention: Prevent fake accounts
• Customer Support: Help with issues
• Platform Improvement: Enhance app features

WHAT WE DON'T DO:
✗ We do NOT verify government IDs officially
✗ We do NOT share data with advertisers or 3rd parties
✗ We do NOT sell your information
✗ We do NOT share personal data with external services''',
            ),
            const SizedBox(height: 16),
            _buildSection('3. Data Storage & Retention', '''BACKEND STORAGE:
• Your documents are stored on secure servers (Supabase)
• Encrypted during transfer
• Auto-deleted after 30 days if not manually deleted
• You can delete anytime from Settings

LOCAL STORAGE:
• You can choose to save locally on your phone
• Not synced to backend unless you explicitly choose

HOW TO DELETE:
1. Go to Settings → My Data → Delete All
2. Or delete individual documents from Profile
3. Deleted data is permanently removed in 24 hours'''),
            const SizedBox(height: 16),
            _buildSection(
              '4. Your Rights (DPDP 2023 Compliance)',
              '''Under India's Digital Personal Data Protection Act (DPDP), you have the right to:

✓ Access: Download all your data anytime
✓ Delete: Request deletion (processed in 24 hours)
✓ Correct: Update your profile information
✓ Portability: Export your data
✓ Withdraw Consent: Stop using document features anytime

To exercise these rights:
Contact: support@vaultwheels.com''',
            ),
            const SizedBox(height: 16),
            _buildSection(
              '5. Data Security',
              '''• SSL encryption for all data transfers
• Secure password storage (bcrypt hashing)
• Limited access to sensitive data
• Regular security audits
• Automatic logout after inactivity

We take security seriously, but no system is 100% secure. Report security issues to: security@vaultwheels.com''',
            ),
            const SizedBox(height: 16),
            _buildSection(
              '6. Third-Party Services',
              '''• Razorpay/Stripe: Payment processing (view their privacy policy)
• Supabase: Cloud database (view their privacy policy)
• Google Cloud: For AI services (view their privacy policy)

We do NOT share personal data with these services.''',
            ),
            const SizedBox(height: 16),
            _buildSection(
              '7. Children\'s Privacy',
              '''QuickOHunt is not intended for users under 18 years old. If we become aware that a child has created an account, we will delete it immediately.''',
            ),
            const SizedBox(height: 16),
            _buildSection(
              '8. Policy Changes',
              '''We may update this policy periodically. Continued use of the app means you accept the updated terms. Major changes will be notified in-app.''',
            ),
            const SizedBox(height: 16),
            _buildSection(
              '9. Contact Us',
              '''Questions about this Privacy Policy?
Email: privacy@vaultwheels.com
Address: [Your Business Address]
Phone: [Your Support Number]''',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
