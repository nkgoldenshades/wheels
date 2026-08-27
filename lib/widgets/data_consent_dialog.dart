import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataConsentDialog extends StatefulWidget {
  final VoidCallback onConsent;
  final VoidCallback? onDecline;
  final String documentType; // 'profile_photo', 'aadhaar', 'pan', etc.

  const DataConsentDialog({
    super.key,
    required this.onConsent,
    this.onDecline,
    required this.documentType,
  });

  @override
  State<DataConsentDialog> createState() => _DataConsentDialogState();
}

class _DataConsentDialogState extends State<DataConsentDialog> {
  bool _acceptedConsent = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Data Usage Consent'),
      icon: const Icon(Icons.info, color: Colors.blue),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMPORTANT: This is optional
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                border: Border.all(color: Colors.green, width: 1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '✓ This is OPTIONAL - You can skip this anytime',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'We\'d like to store your document:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getDocumentDisplayName(widget.documentType),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '✓ Stored securely on our servers\n'
                    '✓ Encrypted during transfer\n'
                    '✓ Used only for community trust\n'
                    '✓ Auto-deleted after 30 days\n'
                    '✓ You can delete anytime\n'
                    '✓ NOT mandatory to use the app',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'What we do with it:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _buildBullet('Face matching to recognize you'),
            _buildBullet('Community trust building'),
            _buildBullet('Fraud prevention'),
            const SizedBox(height: 16),
            const Text(
              'What we DON\'T do:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            _buildBulletRed('Verify government IDs officially'),
            _buildBulletRed('Share with third parties'),
            _buildBulletRed('Sell your information'),
            _buildBulletRed('Store longer than 30 days'),
            _buildBulletRed('Require it to use the app'),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _acceptedConsent,
              onChanged: (value) {
                setState(() => _acceptedConsent = value ?? false);
              },
              title: const Text(
                'I agree to store this document',
                style: TextStyle(fontSize: 12),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/privacy-policy');
              },
              child: const Text(
                'Read Privacy Policy',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onDecline?.call();
          },
          child: const Text('Don\'t Upload'),
        ),
        FilledButton(
          onPressed: _acceptedConsent
              ? () {
                  _recordConsent();
                  Navigator.pop(context);
                  widget.onConsent.call();
                }
              : null,
          child: const Text('Upload & Continue'),
        ),
      ],
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Text('✓ ', style: TextStyle(color: Colors.green)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildBulletRed(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Text('✗ ', style: TextStyle(color: Colors.red)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  String _getDocumentDisplayName(String type) {
    switch (type) {
      case 'profile_photo':
        return '📷 Profile Photo';
      case 'aadhaar':
        return '🆔 Aadhaar Card';
      case 'pan':
        return '📄 PAN Card';
      case 'dl':
        return '🚗 Driving License';
      case 'rc':
        return '🏎️ Registration Certificate';
      default:
        return '📄 Document';
    }
  }

  Future<void> _recordConsent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final consentKey = 'data_consent_${widget.documentType}';
      await prefs.setBool(consentKey, true);
      await prefs.setString(
        '${consentKey}_timestamp',
        DateTime.now().toIso8601String(),
      );

      debugPrint('✅ Consent recorded for ${widget.documentType}');
    } catch (e) {
      debugPrint('❌ Error recording consent: $e');
    }
  }
}

/// Show consent dialog before uploading document
Future<bool> showDataConsentDialog(
  BuildContext context, {
  required String documentType,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => DataConsentDialog(
      documentType: documentType,
      onConsent: () {},
      onDecline: () {},
    ),
  );

  return result ?? false;
}
