import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildSection(
              'Terms of Service - VaultWheels',
              'Last Updated: August 2026\n\nVaultWheels is a social media platform. By using VaultWheels, you agree to these terms. If you don\'t agree, please don\'t use the app.',
            ),
            const SizedBox(height: 16),
            // ⚠️ IMPORTANT DISCLAIMER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'IMPORTANT CLARIFICATION',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'VaultWheels is a SOCIAL MEDIA & COMMUNITY PLATFORM',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• We are NOT a vehicle rental or leasing company\n'
                    '• We do NOT provide insurance services\n'
                    '• We are NOT a commercial transportation service\n'
                    '• We facilitate peer-to-peer community coordination\n'
                    '• Users voluntarily help each other through social connections\n'
                    '• All transactions are community tips/contributions, not commercial sales',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              '2. User Independence & Peer-to-Peer Nature',
              '''CRITICAL UNDERSTANDING: VaultWheels is NOT a rental, leasing, or transportation company.

YOU ARE AN INDEPENDENT USER, NOT OUR CUSTOMER:
• You are not our employee, contractor, or agent
• You make your own independent decisions
• You set your own terms when offering services/vehicles
• You accept your own risks when using services/vehicles
• You are responsible for your own legal compliance

PEER-TO-PEER PLATFORM:
• All transactions occur between User A and User B directly
• VaultWheels is NOT involved in the transaction
• We only provide technology to connect users
• Similar to: WhatsApp (connects people), OLX (connects buyers/sellers)

WHAT WE DO:
• Provide software platform and mobile app
• Facilitate communication between users
• Process payments on behalf of users
• Provide rating/review system
• Offer dispute mediation assistance

WHAT WE DO NOT DO:
• We do NOT own, rent, or lease vehicles
• We do NOT provide transportation services
• We do NOT provide insurance
• We do NOT guarantee service quality
• We do NOT control user decisions or pricing
• We are NOT responsible for user actions

BY USING THIS PLATFORM, YOU ACKNOWLEDGE:
• You are an independent individual making your own choices
• Transactions are peer-to-peer (user-to-user)
• VaultWheels is only a technology facilitator
• You accept all risks of peer-to-peer transactions''',
            ),
            const SizedBox(height: 16),
            _buildSection(
              '1. User Eligibility',
              '''• You must be 18 years or older to use VaultWheels
• You must provide accurate and truthful information
• You are responsible for maintaining account security
• You agree not to use the app for illegal activities''',
            ),
            const SizedBox(height: 16),
            _buildSection('2. User Conduct', '''You agree NOT to:
• Harass, threaten, or abuse other users
• Post false or misleading information
• Engage in fraud or deception
• Share other people's personal information without consent
• Violate any laws or regulations
• Attempt to hack or damage the app
• Spam or send unsolicited messages

Violations may result in account suspension or permanent ban.'''),
            const SizedBox(height: 16),
            _buildSection(
              '3. Peer-to-Peer Platform - User Decisions',
              '''VaultWheels is a PEER-TO-PEER social media platform where:

IMPORTANT: All transactions are BETWEEN USERS (User to User)
• VaultWheels does NOT provide, own, or rent any vehicles
• VaultWheels does NOT employ drivers or operators
• VaultWheels is NOT a party to any transaction between users
• We are ONLY a technology platform connecting community members

WHAT USERS DO (Their Own Decision):
• Users voluntarily post their vehicles for ride-sharing
• Users voluntarily offer to help others (with or without vehicle)
• Users decide their own prices, terms, and conditions
• Users decide whether to accept or reject bookings
• Users decide security deposit amounts (if any)
• All vehicle sharing is USER'S OWN DECISION, not ours

PLATFORM FEATURES (We Only Provide):
• Social networking and posts
• Communication tools (chat, AI assistance)
• Payment processing facilitation
• Rating and review system
• Dispute mediation assistance

YOUR RESPONSIBILITY AS USER:
• You are responsible for your own decisions
• You accept all risks when sharing/using vehicles
• You must follow traffic laws and safety regulations
• You handle vehicle insurance, maintenance, and legal compliance
• Disputes are between users (we only assist with mediation)
• VaultWheels is NOT liable for user decisions or actions''',
            ),
            const SizedBox(height: 16),
            _buildSection(
              '4. Payments - Peer-to-Peer Contributions Between Users',
              '''CRITICAL: VaultWheels does NOT provide services or rent vehicles. Users transact with each other.

HOW PEER-TO-PEER PAYMENTS WORK:
• User A (Helper) offers service/vehicle to User B (Seeker)
• User B voluntarily pays User A (we just facilitate payment)
• Platform takes 5% coordination fee for providing the technology
• Example: User A requests ₹100, User B pays ₹105 (₹100 to User A + ₹5 to platform)

IMPORTANT CLARIFICATIONS:
• Payment is between users, NOT between you and VaultWheels
• VaultWheels is NOT the service provider or vehicle owner
• VaultWheels is NOT responsible for service quality or vehicle condition
• We only facilitate payment processing (like PayPal, Venmo)
• Security deposits (if any) are decided by users, not by us

USER DECISIONS (Your Responsibility):
• Users set their own prices
• Users decide security deposit amounts
• Users decide refund terms with each other
• Users handle vehicle insurance, documentation
• Users resolve disputes with mediation assistance

PLATFORM'S ROLE (Limited):
• Commission: Currently 5% (may be adjusted with 30 days notice)
• Payment processing: Through approved payment gateways
• Refunds: Processed to original payment method (based on user agreement)
• Mediation: We assist with disputes but final decision is between users
• Tax: You are responsible for your own tax obligations

ALL TRANSACTIONS ARE VOLUNTARY USER-TO-USER COORDINATION''',
            ),
            const SizedBox(height: 16),
            _buildSection(
              '5. Profile & Content Sharing (Social Media)',
              '''OPTIONAL FEATURES - YOUR COMPLETE CHOICE:
• Profile photo - COMPLETELY OPTIONAL (skip if you want)
• Document upload - COMPLETELY OPTIONAL (NOT mandatory)
• You can browse without any documents - perfectly fine
• Not uploading documents is your right - NOT illegal
• You can use the app 100% without sharing documents
• You can delete documents anytime
• Documents are auto-deleted after 30 days
• We do NOT require verification to use VaultWheels

IF YOU CHOOSE TO UPLOAD (your voluntary choice):
• Uploaded documents are used for face matching only
• We do NOT perform official government ID verification
• By uploading, you consent to storage per DPDP 2023 Act
• Documents stored securely with encryption

CONTENT:
• Posts, photos, videos you share are social media content
• Other users can see your profile and content
• You can delete your content anytime
• Inappropriate content may result in account suspension

IMPORTANT: This is a social media platform. Uploading documents is OPTIONAL. Not uploading is PERFECTLY LEGAL and encouraged if you value privacy.''',
            ),
            const SizedBox(height: 16),
            _buildSection(
              '6. Platform Liability - Limited to Technology Service Only',
              '''VaultWheels is a technology platform connecting users. We provide software, not services.

WHAT WE ARE NOT LIABLE FOR:
• Accidents, injuries, or deaths during peer-to-peer transactions
• Vehicle damage, theft, or mechanical failures
• Lost, damaged, or stolen items during user transactions
• Disputes between users (we only provide mediation assistance)
• Actions, behavior, or decisions of other users
• Quality, safety, or legality of vehicles shared by users
• Fraudulent users (though we provide verification tools)
• Service interruptions or app downtime
• Data loss (though we maintain backups)
• Third-party payment gateway issues

WHY WE'RE NOT LIABLE:
• We don't own, operate, or provide vehicles
• We don't employ drivers or service providers
• We're not party to user-to-user transactions
• We only provide the technology platform
• Users make their own independent decisions

YOUR RESPONSIBILITY:
• Verify other users before transacting
• Ensure proper vehicle insurance and documentation
• Follow local laws and regulations
• Accept risks of peer-to-peer transactions
• Handle your own legal compliance

MAXIMUM LIABILITY:
If we are found liable for anything, our maximum liability is limited to the platform fees you paid us in the last 30 days (typically ₹0 to users, as commission is paid by the other party).

VaultWheels is provided "AS IS" without warranties of any kind.''',
            ),
            const SizedBox(height: 16),
            _buildSection(
              '7. Intellectual Property',
              '''• VaultWheels, logos, and content are our property
• You may not copy or reproduce without permission
• User-generated content (reviews, photos) remains yours
• We can use your content for marketing (with permission)''',
            ),
            const SizedBox(height: 16),
            _buildSection(
              '8. Privacy & Data',
              '''• Read our Privacy Policy for data handling details
• We comply with India's Digital Personal Data Protection Act (DPDP 2023)
• Your data is encrypted and secure
• You can delete your account anytime''',
            ),
            const SizedBox(height: 16),
            _buildSection(
              '9. Dispute Resolution',
              '''• First try resolving through our AI chat system
• If unresolved, escalate to our support team
• Further disputes can be taken to arbitration
• Governed by laws of India''',
            ),
            const SizedBox(height: 16),
            _buildSection('10. Termination', '''We reserve the right to:
• Suspend your account for violations
• Terminate service at any time with notice
• Refund prepaid credits if we close service
• You can delete your account anytime from Settings'''),
            const SizedBox(height: 16),
            _buildSection(
              '11. Changes to Terms',
              '''We may update these terms anytime. Continued use means you accept updated terms. Major changes will be notified in-app.''',
            ),
            const SizedBox(height: 16),
            _buildSection('12. Contact', '''For questions about these terms:
Email: legal@vaultwheels.com
Support: support@vaultwheels.com'''),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'By using VaultWheels, you agree to these terms and our Privacy Policy.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
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
