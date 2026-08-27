import 'package:flutter/material.dart';
import '../services/profile_repository.dart';
import '../services/verification_service.dart';

/// Optional Document Verification Screen
/// ALL fields are completely OPTIONAL - no forced KYC
class VerificationDocumentsScreen extends StatefulWidget {
  const VerificationDocumentsScreen({super.key});

  @override
  State<VerificationDocumentsScreen> createState() =>
      _VerificationDocumentsScreenState();
}

class _VerificationDocumentsScreenState
    extends State<VerificationDocumentsScreen> {
  bool _isLoading = true;
  Map<String, bool> _uploadedDocs = {};

  final List<VerificationDoc> _documents = [
    VerificationDoc(
      id: 'rc_book',
      icon: Icons.directions_car,
      iconColor: Colors.blue,
      title: 'RC Book',
      subtitle: 'Registration Certificate',
      hint: 'Upload clear photos of both pages',
      benefit: 'Get verified badge',
    ),
    VerificationDoc(
      id: 'insurance',
      icon: Icons.shield_outlined,
      iconColor: Colors.green,
      title: 'Insurance',
      subtitle: 'Vehicle Insurance',
      hint: 'Upload current insurance policy',
      benefit: 'Get verified badge',
    ),
    VerificationDoc(
      id: 'driving_license',
      icon: Icons.credit_card,
      iconColor: Colors.orange,
      title: 'Driving License',
      subtitle: 'Valid driving license',
      hint: 'Upload clear photos of both sides',
      benefit: 'Increases trust',
    ),
    VerificationDoc(
      id: 'national_id',
      icon: Icons.assignment,
      iconColor: Colors.red,
      title: 'National ID',
      subtitle: 'Identity verification',
      hint: 'Upload Aadhaar or PAN',
      benefit: 'Increases trust',
    ),
    VerificationDoc(
      id: 'tax_id',
      icon: Icons.receipt,
      iconColor: Colors.purple,
      title: 'Tax ID',
      subtitle: 'Tax identification',
      hint: 'Upload PAN or GST',
      benefit: 'Business listings',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUploadStatus();
  }

  Future<void> _loadUploadStatus() async {
    try {
      final profile = ProfileRepository.instance.profile.value;
      setState(() {
        _uploadedDocs = {
          'rc_book': profile.aadhaarFrontImage?.isNotEmpty ?? false,
          'insurance': profile.panFrontImage?.isNotEmpty ?? false,
          'driving_license': profile.dlFrontImage?.isNotEmpty ?? false,
          'national_id': profile.aadhaar?.isNotEmpty ?? false,
          'tax_id': profile.pan?.isNotEmpty ?? false,
        };
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _uploadDocument(VerificationDoc doc) async {
    try {
      final userId = ProfileRepository.instance.profile.value.id;
      final imageUrl = await VerificationService.instance.uploadDocumentImage(
        documentType: doc.id,
        userId: userId,
      );

      if (imageUrl == null) return;

      await VerificationService.instance.updateVerificationDocuments(
        documentType: doc.id,
        imageUrl: imageUrl,
      );

      setState(() => _uploadedDocs[doc.id] = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${doc.title} uploaded'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _skipAllDocuments() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Verification?'),
        content: const Text(
          'You can use Premium without documents. Adding documents increases bookings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Optional Verification')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Optional Verification'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLegalCard(),
            const SizedBox(height: 24),
            _buildHeaderCard(),
            const SizedBox(height: 24),
            _buildStatusBadge(),
            const SizedBox(height: 24),
            const Text(
              'Optional Documents',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._documents.map((doc) => _buildDocumentCard(doc)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Saved'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Colors.green,
              ),
              child: const Text('Save & Continue'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _skipAllDocuments,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Skip All'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '✓ All documents optional. Use Premium without uploading.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green[900],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, color: Colors.blue[700], size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Build Trust Voluntarily',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Get verified badge to increase bookings',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You decide what to share.',
                    style: TextStyle(fontSize: 11, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final uploadedCount = _uploadedDocs.values.where((v) => v).length;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up, color: Colors.amber[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              uploadedCount == 0
                  ? 'No documents yet'
                  : '✅ $uploadedCount of 5 uploaded',
              style: TextStyle(fontSize: 12, color: Colors.amber[900]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(VerificationDoc doc) {
    final isUploaded = _uploadedDocs[doc.id] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isUploaded ? Colors.green[300]! : Colors.grey[300]!,
          width: isUploaded ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isUploaded ? Colors.green[50] : Colors.white,
      ),
      child: InkWell(
        onTap: () => _uploadDocument(doc),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: doc.iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(doc.icon, color: doc.iconColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              doc.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'OPTIONAL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doc.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isUploaded
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isUploaded
                          ? Icons.check_circle
                          : Icons.cloud_upload_outlined,
                      color: isUploaded ? Colors.green : Colors.grey[600],
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                doc.hint,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up, size: 12, color: Colors.blue[700]),
                    const SizedBox(width: 6),
                    Text(
                      doc.benefit,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VerificationDoc {
  final String id;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String hint;
  final String benefit;

  VerificationDoc({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.benefit,
  });
}
