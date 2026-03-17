import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'firebase_options.dart';
import 'config/supabase_config.dart';
import 'models/booking.dart';
import 'models/service_type.dart';
import 'models/slot.dart';
import 'models/slot_entry.dart';
import 'models/slot_type.dart';
import 'models/vehicle.dart';
import 'models/pickup_mode.dart';
import 'screens/slot_detail_screen.dart';
import 'screens/vehicle/vehicle_list_screen.dart';
import 'services/booking_repository.dart';
import 'services/slot_repository.dart';
import 'services/vehicle_repository.dart';
import 'services/auth_repository.dart';
import 'screens/verification/profile_photo_verification_screen.dart';
import 'screens/verification/document_verification_screen.dart';
import 'screens/verification/web_camera_screen.dart';
import 'services/seat_layout_repository.dart';
import 'services/user_vehicle_repository.dart';
import 'services/user_slot_repository.dart';
import 'services/user_post_repository.dart';
import 'widgets/slot_card.dart';
import 'widgets/booking_confirm_sheet.dart';
import 'services/profile_repository.dart';
import 'services/app_preferences.dart';
import 'services/passenger_repository.dart';
import 'services/stripe_service.dart';
import 'screens/booking_map_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'app_tab_controller.dart';

// Global Supabase client
final supabase = Supabase.instance.client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? startupError;
  try {
    // Initialize Firebase (for authentication)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Supabase (for database) with Firebase Auth integration
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      // CRITICAL: Pass Firebase JWT to Supabase on every request
      // This makes auth.uid() return Firebase UID as TEXT
      // Note: No authOptions needed - accessToken callback is sufficient
      accessToken: () async {
        final user = firebase_auth.FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (kDebugMode) print('🔑 No Firebase user - returning null token');
          return null;
        }

        try {
          // Get Firebase ID token (cached if valid, fresh if expired)
          final token = await user.getIdToken(false);
          if (kDebugMode) {
            print('🔑 Firebase UID: ${user.uid}');
            print(
              '🔑 Access token provided to Supabase: ${token?.substring(0, 20)}...',
            );
          }
          return token;
        } catch (e) {
          if (kDebugMode) print('❌ Failed to get Firebase ID token: $e');
          return null;
        }
      },
    );

    await AuthRepository.instance.init();
    await AppPreferences.instance.init();
    await ProfileRepository.instance.init();
    await VehicleRepository.instance.init();
    await SlotRepository.instance.init();
    await UserVehicleRepository.instance.init();
    await UserSlotRepository.instance.init();
    await UserPostRepository.instance.init();
    await SeatLayoutRepository.instance.init();
    await BookingRepository.instance.init();
    await PassengerRepository.instance.init();

    // Initialize Stripe for payments
    await StripeService.instance.init();
  } catch (e) {
    startupError = 'App init failed: $e';
  }

  runApp(MyApp(startupError: startupError));
}

class EditUserPostPage extends StatefulWidget {
  final UserPost post;
  const EditUserPostPage({super.key, required this.post});

  @override
  State<EditUserPostPage> createState() => _EditUserPostPageState();
}

class _EditUserPostPageState extends State<EditUserPostPage> {
  late ServiceType _serviceType;
  late SlotType _slotType;

  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  late final TextEditingController _baseController;
  late final TextEditingController _radiusController;
  late final TextEditingController _budgetController;
  late final TextEditingController _notesController;

  int _persons = 1;
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    _serviceType = p.serviceType;
    _slotType = p.slotType;
    _fromController = TextEditingController(text: p.fromLocation ?? '');
    _toController = TextEditingController(text: p.toLocation ?? '');
    _baseController = TextEditingController(text: p.baseLocation ?? '');
    _radiusController = TextEditingController(
      text: (p.radius ?? 10).toString(),
    );
    _budgetController = TextEditingController(text: p.budget.toString());
    _notesController = TextEditingController(text: p.notes ?? '');
    _persons = p.persons;
    _startTime = p.startTime;
    _endTime = p.endTime;
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _baseController.dispose();
    _radiusController.dispose();
    _budgetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = TimeOfDay.fromDateTime(isStart ? _startTime! : _endTime!);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final date = isStart ? _startTime! : _endTime!;
    final newDt = DateTime(
      date.year,
      date.month,
      date.day,
      picked.hour,
      picked.minute,
    );
    setState(() {
      if (isStart) {
        _startTime = newDt;
        if (_endTime != null && _endTime!.isBefore(_startTime!)) {
          _endTime = _startTime!.add(const Duration(hours: 2));
        }
      } else {
        _endTime = newDt;
      }
    });
  }

  void _save() {
    if (_slotType == SlotType.fromTo) {
      if (_fromController.text.trim().isEmpty ||
          _toController.text.trim().isEmpty) {
        _showError('Please enter both from and to locations');
        return;
      }
    } else {
      if (_baseController.text.trim().isEmpty) {
        _showError('Please enter base location');
        return;
      }
    }

    final budget = double.tryParse(_budgetController.text.trim());
    if (budget == null || budget <= 0) {
      _showError('Please enter a valid budget');
      return;
    }

    final radius = _slotType == SlotType.fromRange
        ? double.tryParse(_radiusController.text)
        : null;

    final updated = widget.post.copyWith(
      serviceType: _serviceType,
      slotType: _slotType,
      fromLocation: _slotType == SlotType.fromTo
          ? _fromController.text.trim()
          : null,
      toLocation: _slotType == SlotType.fromTo
          ? _toController.text.trim()
          : null,
      baseLocation: _slotType == SlotType.fromRange
          ? _baseController.text.trim()
          : null,
      radius: radius,
      startTime: _startTime,
      endTime: _endTime,
      budget: budget,
      persons: _persons,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    UserPostRepository.instance.update(updated);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Post updated')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<ServiceType>(
            initialValue: _serviceType,
            decoration: const InputDecoration(
              labelText: 'Service',
              border: OutlineInputBorder(),
            ),
            items: ServiceType.values
                .map(
                  (s) => DropdownMenuItem(value: s, child: Text(s.displayName)),
                )
                .toList(growable: false),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _serviceType = v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<SlotType>(
            initialValue: _slotType,
            decoration: const InputDecoration(
              labelText: 'Route type',
              border: OutlineInputBorder(),
            ),
            items: SlotType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                .toList(growable: false),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _slotType = v);
            },
          ),
          const SizedBox(height: 12),
          if (_slotType == SlotType.fromTo) ...[
            TextField(
              controller: _fromController,
              decoration: const InputDecoration(
                labelText: 'From',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _toController,
              decoration: const InputDecoration(
                labelText: 'To',
                border: OutlineInputBorder(),
              ),
            ),
          ] else ...[
            TextField(
              controller: _baseController,
              decoration: const InputDecoration(
                labelText: 'Base location',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _radiusController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Radius (km)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(isStart: true),
                  child: Text('Start: ${_fmtTime(_startTime!)}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(isStart: false),
                  child: Text('End: ${_fmtTime(_endTime!)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Budget ()',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Persons'),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _persons > 1
                    ? () => setState(() => _persons -= 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_persons'),
              IconButton(
                onPressed: () => setState(() => _persons += 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Terms (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save Changes')),
        ],
      ),
    );
  }

  String _fmtTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

ImageProvider? _profileAvatarProvider(ProfileInfo info) {
  final avatar = info.avatarUrl;
  if (avatar == null || avatar.trim().isEmpty) return null;

  final a = avatar.trim();
  if (a.startsWith('http://') || a.startsWith('https://')) {
    return NetworkImage(a);
  }

  try {
    return MemoryImage(base64Decode(a));
  } catch (_) {
    return null;
  }
}

Future<void> _pickAndSaveAvatar(BuildContext context) async {
  // Step 1: Ask user if they want verified or normal upload
  final uploadType = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Upload Profile Photo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Choose how you want to upload your profile photo:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 20),

          // Option 1: Verified Upload
          InkWell(
            onTap: () => Navigator.pop(context, 'verified'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: Colors.green.withValues(alpha: 0.1),
              ),
              child: const Column(
                children: [
                  Icon(Icons.verified_user, color: Colors.green, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'Verified Upload',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Upload + Live verification\n(Recommended for trust)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Option 2: Normal Upload
          InkWell(
            onTap: () => Navigator.pop(context, 'normal'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.photo_library, color: Colors.grey, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'Normal Upload',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Quick upload from gallery\n(No verification)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );

  if (uploadType == null || !context.mounted) return;

  // Step 2: Pick image from gallery
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 85,
  );

  if (file == null) return;

  try {
    final uploadedBytes = await file.readAsBytes();

    if (!context.mounted) return;

    // If normal upload, save directly without verification
    if (uploadType == 'normal') {
      final base64 = base64Encode(uploadedBytes);
      await ProfileRepository.instance.setLocalAvatarBase64(base64);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Profile photo uploaded successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    // Verified upload - show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify This Photo?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                uploadedBytes,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Next, we\'ll verify this is really you using liveness detection.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Text(
                    '📸 You\'ll need to:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Show your face to camera',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text('• Turn left and right', style: TextStyle(fontSize: 12)),
                  Text(
                    '• Smile for verification',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start Verification'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // Step 3: Live verification with face matching
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => kIsWeb
            ? const WebCameraVerificationScreen(
                title: 'Verify Your Face',
                isProfilePhoto: true,
              )
            : ProfilePhotoVerificationScreen(
                referencePhotoBytes: uploadedBytes,
              ),
      ),
    );

    if (result == null || !context.mounted) return;

    // Step 4: Check if face matched
    final faceMatched = result['faceMatched'] ?? false;
    final matchScore = result['matchScore'] ?? 0.0;

    if (!faceMatched) {
      // Face didn't match - show error
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Verification Failed'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The live photo doesn\'t match the uploaded photo.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                'Match score: ${matchScore.toStringAsFixed(1)}%\n'
                'Required: 25%',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Tips:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Use a clear, recent photo',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Ensure good lighting',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Face the camera directly',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Remove glasses/mask if in photo',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
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
                // Retry the whole flow
                _pickAndSaveAvatar(context);
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
      return;
    }

    // Step 5: Face matched - save the uploaded photo
    final base64 = base64Encode(uploadedBytes);
    await ProfileRepository.instance.setLocalAvatarBase64(base64);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.verified_user, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Profile photo verified! ✓\nMatch score: ${matchScore.toStringAsFixed(1)}%',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not upload photo: $e')));
  }
}

Widget _buildDocumentUploadCard(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
  required String documentType,
}) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _uploadDocument(context, documentType, 'front'),
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Upload Front'),
                ),
              ),
              if (documentType == 'aadhaar' || documentType == 'dl') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _uploadDocument(context, documentType, 'back'),
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Upload Back'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

Future<void> _uploadDocument(
  BuildContext context,
  String documentType,
  String side,
) async {
  // Step 1: Upload document photo from gallery
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );

  if (file == null) return;

  try {
    // Show the uploaded document preview
    final uploadedBytes = await file.readAsBytes();

    if (!context.mounted) return;

    // Determine if this document has a face (PAN, Aadhaar, DL have faces; RC, Insurance don't)
    final hasFace =
        documentType == 'pan' ||
        documentType == 'aadhaar' ||
        documentType == 'dl';

    // Ask user to confirm they want to verify this document
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Verify ${documentType.toUpperCase()} ($side)?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                uploadedBytes,
                width: 300,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFace
                  ? 'Next, we\'ll verify this is really you using liveness detection and face matching.'
                  : 'This document will be saved for verification.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            if (hasFace) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Text(
                      '📸 You\'ll need to:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Show your face to camera',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Turn left and right',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Smile for verification',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Match face with document',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(hasFace ? 'Start Verification' : 'Save Document'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // Step 2: If document has face, do live verification with face matching
    if (hasFace) {
      // Determine document type for verification screen
      DocumentType docType;
      switch (documentType) {
        case 'aadhaar':
          docType = DocumentType.aadhaar;
          break;
        case 'pan':
          docType = DocumentType.pan;
          break;
        case 'dl':
          docType = DocumentType.dl;
          break;
        default:
          docType = DocumentType.aadhaar;
      }

      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => kIsWeb
              ? const WebCameraVerificationScreen(
                  title: 'Verify Your Face',
                  isProfilePhoto: false,
                )
              : DocumentVerificationScreen(
                  documentType: docType,
                  referenceDocumentBytes: uploadedBytes,
                ),
        ),
      );

      if (result == null || !context.mounted) return;

      // Step 3: Check if face matched
      final faceMatched = result['faceMatched'] ?? false;
      final matchScore = result['matchScore'] ?? 0.0;

      if (!faceMatched) {
        // Face didn't match - show error
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Verification Failed'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'The live photo doesn\'t match the ${documentType.toUpperCase()} photo.',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  'Match score: ${matchScore.toStringAsFixed(1)}%\n'
                  'Required: 70%',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 Tips:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Use a clear document photo',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        '• Ensure good lighting',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        '• Face the camera directly',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        '• Remove glasses/mask if in document',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
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
                  // Retry the whole flow
                  _uploadDocument(context, documentType, side);
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        );
        return;
      }

      // Step 4: Face matched - save the uploaded document
      final base64Image = base64Encode(uploadedBytes);
      await ProfileRepository.instance.saveDocument(
        documentType,
        side,
        base64Image,
        isVerified: true,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified_user, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${documentType.toUpperCase()} ($side) verified! ✓\nMatch score: ${matchScore.toStringAsFixed(1)}%',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      // No face in document (RC, Insurance) - just save it
      final base64Image = base64Encode(uploadedBytes);
      await ProfileRepository.instance.saveDocument(
        documentType,
        side,
        base64Image,
        isVerified: false, // No face to verify
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${documentType.toUpperCase()} ($side) uploaded successfully!',
          ),
        ),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not verify document: $e')));
  }
}

class MyApp extends StatelessWidget {
  final String? startupError;
  const MyApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    if (startupError != null && startupError!.trim().isNotEmpty) {
      return MaterialApp(
        title: 'Quickohunt',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        home: StartupErrorScreen(message: startupError!),
      );
    }

    return MaterialApp(
      title: 'Quickohunt',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const Splashscreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/main': (context) => const MainScreen(),
        '/plans': (context) => const PlansScreen(),
        '/expert-support': (context) => const ExpertSupportScreen(),
      },
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  final String message;

  const StartupErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final display = kReleaseMode
        ? 'Something went wrong while starting the app.'
        : message;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.red),
              const SizedBox(height: 12),
              const Text(
                'Startup error',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(display, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plans'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ValueListenableBuilder<SubscriptionPlan>(
            valueListenable: AppPreferences.instance.subscriptionPlan,
            builder: (context, plan, _) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Current plan: ${plan.name.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _PlanCard(
            title: 'Basic',
            priceLabel: 'BASIC',
            bullets: const [
              'Add images to vehicle',
              'Post requests & book trips',
              'Standard support',
            ],
            isRecommended: false,
            onSelect: () {
              AppPreferences.instance.setSubscriptionPlan(
                SubscriptionPlan.basic,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Basic plan selected')),
              );
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 12),
          _PlanCard(
            title: 'Premium',
            priceLabel: 'PREMIUM',
            bullets: const [
              'Everything in Basic',
              'Verify PAN / Aadhaar',
              'Verify RC / Driving License',
            ],
            isRecommended: true,
            onSelect: () {
              AppPreferences.instance.setSubscriptionPlan(
                SubscriptionPlan.premium,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Premium plan selected')),
              );
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 12),
          _PlanCard(
            title: 'Expert',
            priceLabel: 'EXPERT',
            bullets: const [
              'Everything in Premium',
              'Expert connection',
              'Priority customer support',
            ],
            isRecommended: false,
            onSelect: () {
              AppPreferences.instance.setSubscriptionPlan(
                SubscriptionPlan.expert,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Expert plan selected')),
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class ExpertSupportScreen extends StatelessWidget {
  const ExpertSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expert Support'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Expert support will be available here.'),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String priceLabel;
  final List<String> bullets;
  final bool isRecommended;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.title,
    required this.priceLabel,
    required this.bullets,
    required this.isRecommended,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRecommended ? Colors.blue : Colors.grey;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    priceLabel,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (isRecommended) ...[
              const SizedBox(height: 8),
              Text(
                'Recommended',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue[700],
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: color),
                    const SizedBox(width: 10),
                    Expanded(child: Text(b)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onSelect,
                child: const Text('Choose'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openExternalMapForSlot(BuildContext context, Slot slot) async {
  String? origin;
  String? destination;

  if (slot.fromLocation != null && slot.fromLocation!.trim().isNotEmpty) {
    origin = slot.fromLocation!.trim();
  } else if (slot.baseLocation != null &&
      slot.baseLocation!.trim().isNotEmpty) {
    origin = slot.baseLocation!.trim();
  }

  if (slot.toLocation != null && slot.toLocation!.trim().isNotEmpty) {
    destination = slot.toLocation!.trim();
  }

  if (origin == null && destination == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Location not available')));
    return;
  }

  final uri = Uri.https('www.google.com', '/maps/dir/', {
    if (origin != null) 'origin': origin,
    if (destination != null) 'destination': destination,
    'api': '1',
    'travelmode': 'driving',
  });

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open maps')));
  }
}

class CreateUserPostPage extends StatefulWidget {
  const CreateUserPostPage({super.key});

  @override
  State<CreateUserPostPage> createState() => _CreateUserPostPageState();
}

class _CreateUserPostPageState extends State<CreateUserPostPage> {
  ServiceType _serviceType = ServiceType.passenger;
  SlotType _slotType = SlotType.fromTo;

  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _baseController = TextEditingController();
  final _radiusController = TextEditingController(text: '10');
  final _budgetController = TextEditingController();
  int _persons = 1;
  final _notesController = TextEditingController();

  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startTime = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    _endTime = DateTime(now.year, now.month, now.day, now.hour + 3, 0);
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _baseController.dispose();
    _radiusController.dispose();
    _budgetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = TimeOfDay.fromDateTime(isStart ? _startTime! : _endTime!);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final date = isStart ? _startTime! : _endTime!;
    final newDt = DateTime(
      date.year,
      date.month,
      date.day,
      picked.hour,
      picked.minute,
    );
    setState(() {
      if (isStart) {
        _startTime = newDt;
        if (_endTime != null && _endTime!.isBefore(_startTime!)) {
          _endTime = _startTime!.add(const Duration(hours: 2));
        }
      } else {
        _endTime = newDt;
      }
    });
  }

  void _create() {
    if (_slotType == SlotType.fromTo) {
      if (_fromController.text.trim().isEmpty ||
          _toController.text.trim().isEmpty) {
        _showError('Please enter both from and to locations');
        return;
      }
    } else {
      if (_baseController.text.trim().isEmpty) {
        _showError('Please enter base location');
        return;
      }
    }
    final budget = double.tryParse(_budgetController.text.trim());
    if (budget == null || budget <= 0) {
      _showError('Please enter a valid budget');
      return;
    }

    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) {
      _showError('User not authenticated');
      return;
    }

    final post = UserPost(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      userId: currentUser.id,
      serviceType: _serviceType,
      slotType: _slotType,
      fromLocation: _slotType == SlotType.fromTo
          ? _fromController.text.trim()
          : null,
      toLocation: _slotType == SlotType.fromTo
          ? _toController.text.trim()
          : null,
      baseLocation: _slotType == SlotType.fromRange
          ? _baseController.text.trim()
          : null,
      radius: _slotType == SlotType.fromRange
          ? double.tryParse(_radiusController.text)
          : null,
      startTime: _startTime!,
      endTime: _endTime!,
      budget: budget,
      persons: _persons,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: DateTime.now(),
      status: UserPostStatus.active,
      isOnline: true,
    );

    UserPostRepository.instance.add(post);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Posted ')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<ServiceType>(
            initialValue: _serviceType,
            decoration: const InputDecoration(
              labelText: 'Service',
              border: OutlineInputBorder(),
            ),
            items: ServiceType.values
                .map(
                  (s) => DropdownMenuItem(value: s, child: Text(s.displayName)),
                )
                .toList(growable: false),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _serviceType = v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<SlotType>(
            initialValue: _slotType,
            decoration: const InputDecoration(
              labelText: 'Route type',
              border: OutlineInputBorder(),
            ),
            items: SlotType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                .toList(growable: false),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _slotType = v);
            },
          ),
          const SizedBox(height: 12),
          if (_slotType == SlotType.fromTo) ...[
            TextField(
              controller: _fromController,
              decoration: const InputDecoration(
                labelText: 'From',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _toController,
              decoration: const InputDecoration(
                labelText: 'To',
                border: OutlineInputBorder(),
              ),
            ),
          ] else ...[
            TextField(
              controller: _baseController,
              decoration: const InputDecoration(
                labelText: 'Base location',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _radiusController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Radius (km)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(isStart: true),
                  child: Text('Start: ${_fmtTime(_startTime!)}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(isStart: false),
                  child: Text('End: ${_fmtTime(_endTime!)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Budget ()',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Persons'),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _persons > 1
                    ? () => setState(() => _persons -= 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_persons'),
              IconButton(
                onPressed: () => setState(() => _persons += 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Terms (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _create, child: const Text('Post')),
        ],
      ),
    );
  }

  String _fmtTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class UserMyPostsPage extends StatelessWidget {
  const UserMyPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<UserPost>>(
        valueListenable: UserPostRepository.instance.posts,
        builder: (context, allPosts, _) {
          final userPosts = UserPostRepository.instance.userPosts;
          final active = userPosts
              .where((p) => p.status == UserPostStatus.active)
              .toList(growable: false);
          if (active.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('You have not posted anything yet'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: active.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final p = active[index];
              return Card(
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    child: const Icon(Icons.post_add, color: Colors.blue),
                  ),
                  title: Text(
                    _userPostTitle(p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userPostTime(p)),
                      const SizedBox(height: 4),
                      Text('Budget: ()'),
                      if (p.notes?.isNotEmpty == true)
                        Text(
                          p.notes!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: p.isOnline ? 'Online' : 'Offline',
                        child: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: p.isOnline,
                            onChanged: (v) {
                              UserPostRepository.instance.update(
                                p.copyWith(isOnline: v),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    v
                                        ? 'Post is now online'
                                        : 'Post is now offline',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Actions',
                        onSelected: (value) {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditUserPostPage(post: p),
                              ),
                            );
                            return;
                          }

                          if (value == 'delete') {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Post'),
                                content: const Text(
                                  'Are you sure you want to delete this post?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      UserPostRepository.instance.archive(p.id);
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Post deleted'),
                                        ),
                                      );
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }

                          if (value == 'history') {
                            UserPostRepository.instance.archive(p.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Moved to history')),
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                          PopupMenuItem(
                            value: 'history',
                            child: Text('Move to history'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateUserPostPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _userPostTitle(UserPost p) {
    if (p.fromLocation != null && p.toLocation != null) {
      return '${p.fromLocation} ${p.toLocation}';
    }
    if (p.baseLocation != null) return p.baseLocation!;
    return 'Post';
  }

  String _userPostTime(UserPost p) {
    String fmt(DateTime d) {
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    return '${p.startTime.day}/${p.startTime.month} ${fmt(p.startTime)} - ${fmt(p.endTime)}';
  }
}

class UserPostHistoryPage extends StatelessWidget {
  const UserPostHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<UserPost>>(
        valueListenable: UserPostRepository.instance.posts,
        builder: (context, posts, _) {
          final history = posts
              .where((p) => p.status == UserPostStatus.archived)
              .toList(growable: false);
          if (history.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('No history yet'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final p = history[index];
              return Card(
                elevation: 1,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.withValues(alpha: 0.15),
                    child: const Icon(Icons.history, color: Colors.black54),
                  ),
                  title: Text(
                    _userPostTitle(p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('Budget: ()'),
                  trailing: IconButton(
                    tooltip: 'Restore',
                    onPressed: () {
                      UserPostRepository.instance.restore(p.id);
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Restored')));
                    },
                    icon: const Icon(Icons.restore),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _userPostTitle(UserPost p) {
    if (p.fromLocation != null && p.toLocation != null) {
      return '${p.fromLocation} ${p.toLocation}';
    }
    if (p.baseLocation != null) return p.baseLocation!;
    return 'Post';
  }
}

class MyPostsPage extends StatelessWidget {
  const MyPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<SlotEntry>>(
        valueListenable: SlotRepository.instance.slotsListenable,
        builder: (context, slots, _) {
          if (slots.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('You have not posted any rides yet'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: slots.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = slots[index];
              final slot = entry.slot;
              final title = _slotTitle(slot);
              final time = _fmtRange(slot.startTime, slot.endTime);
              return Card(
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    child: const Icon(Icons.local_offer, color: Colors.blue),
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(time),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            slot.pickupOption.icon,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            slot.pickupOption.shortLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      if (slot.notes?.isNotEmpty == true)
                        Text(
                          slot.notes!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('()'),
                      const SizedBox(height: 4),
                      Chip(
                        label: Text(_serviceLabel(slot.serviceType)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _slotTitle(Slot slot) {
    if (slot.fromLocation != null && slot.toLocation != null) {
      return '${slot.fromLocation} ${slot.toLocation}';
    }
    if (slot.baseLocation != null) return slot.baseLocation!;
    return 'Posted ride';
  }

  String _fmtRange(DateTime start, DateTime end) {
    String fmt(DateTime d) {
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    return '${start.day}/${start.month} ${fmt(start)} - ${fmt(end)}';
  }

  String _serviceLabel(ServiceType type) {
    switch (type) {
      case ServiceType.passenger:
        return 'Passenger';
      case ServiceType.parcel:
        return 'Parcel';
      case ServiceType.working:
        return 'Working';
      case ServiceType.lease:
        return 'Lease';
    }
  }
}

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<Booking>>(
        valueListenable: BookingRepository.instance.bookings,
        builder: (context, allBookings, _) {
          final currentUser = AuthRepository.instance.currentUser;
          if (currentUser == null) {
            return const Center(child: Text('Please login to view earnings'));
          }

          // Get bookings where current user is the provider
          final providerBookings = allBookings
              .where(
                (b) =>
                    b.providerId == currentUser.id &&
                    b.status == BookingStatus.completed,
              )
              .toList();

          // Calculate total earnings
          final totalEarnings = providerBookings.fold<double>(
            0,
            (sum, booking) => sum + booking.price,
          );

          // Get slots to determine service types
          final slotRepo = SlotRepository.instance;
          final allSlots = slotRepo.allSlotsRaw;

          // Group by service type
          double passengerEarnings = 0;
          double parcelEarnings = 0;
          double leaseEarnings = 0;

          for (var booking in providerBookings) {
            try {
              final slot = allSlots.firstWhere((s) => s.id == booking.slotId);
              if (slot.serviceType == ServiceType.passenger) {
                passengerEarnings += booking.price;
              } else if (slot.serviceType == ServiceType.parcel) {
                parcelEarnings += booking.price;
              } else if (slot.serviceType == ServiceType.lease ||
                  slot.serviceType == ServiceType.working) {
                leaseEarnings += booking.price;
              }
            } catch (e) {
              // Slot not found, skip
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Total Earnings Card
              Card(
                elevation: 4,
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        'Total Earnings',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${totalEarnings.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${providerBookings.length} completed trips',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Earnings by Service Type
              const Text(
                'Earnings by Service',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              _buildServiceEarningCard(
                'Passenger',
                passengerEarnings,
                Icons.people,
                Colors.blue,
              ),
              const SizedBox(height: 8),

              _buildServiceEarningCard(
                'Parcel',
                parcelEarnings,
                Icons.local_shipping,
                Colors.orange,
              ),
              const SizedBox(height: 8),

              _buildServiceEarningCard(
                'Lease/Working',
                leaseEarnings,
                Icons.car_rental,
                Colors.purple,
              ),

              const SizedBox(height: 24),

              // Recent Transactions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to full transaction history
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (providerBookings.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No completed bookings yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                )
              else
                ...providerBookings.take(10).map((booking) {
                  final allSlots = SlotRepository.instance.allSlotsRaw;
                  Slot? slot;
                  try {
                    slot = allSlots.firstWhere((s) => s.id == booking.slotId);
                  } catch (e) {
                    // Slot not found
                  }
                  return _buildTransactionCard(booking, slot);
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildServiceEarningCard(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Booking booking, Slot? slot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withValues(alpha: 0.1),
          child: const Icon(Icons.check_circle, color: Colors.green),
        ),
        title: Text(
          slot != null ? '${slot.serviceType.displayName} Service' : 'Service',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${booking.createdAt.day}/${booking.createdAt.month}/${booking.createdAt.year}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          '₹${booking.price.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ProfileSection({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileRepository.instance.profile;
    final nameController = TextEditingController(
      text: profile.value.profileName,
    );
    final phoneController = TextEditingController(
      text: profile.value.phone ?? '',
    );
    final aadhaarController = TextEditingController(
      text: profile.value.aadhaar ?? '',
    );
    final panController = TextEditingController(text: profile.value.pan ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<ProfileInfo>(
        valueListenable: profile,
        builder: (context, info, _) {
          return ValueListenableBuilder<SubscriptionPlan>(
            valueListenable: AppPreferences.instance.subscriptionPlan,
            builder: (context, plan, _) {
              final canVerifyDocs =
                  plan == SubscriptionPlan.premium ||
                  plan == SubscriptionPlan.expert;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _profileAvatarProvider(info),
                          child: info.avatarUrl == null
                              ? const Icon(
                                  Icons.person,
                                  size: 44,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: FloatingActionButton.small(
                            heroTag: 'edit-dp',
                            onPressed: () => _pickAndSaveAvatar(context),
                            child: const Icon(Icons.edit),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Profile sections with navigation
                  _ProfileSection(
                    title: 'My Posts',
                    icon: Icons.article,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PostsPage()),
                      );
                    },
                  ),
                  _ProfileSection(
                    title: 'My Vehicles',
                    icon: Icons.directions_car,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VehicleListScreen(),
                        ),
                      );
                    },
                  ),
                  _ProfileSection(
                    title: 'Booking History',
                    icon: Icons.history,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RequestsPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _ProfileSection(
                    title: 'Plans',
                    icon: Icons.workspace_premium,
                    onTap: () {
                      Navigator.pushNamed(context, '/plans');
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Account Settings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: info.businessType,
                    decoration: const InputDecoration(
                      labelText: 'Branding type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'solo', child: Text('Solo')),
                      DropdownMenuItem(
                        value: 'private',
                        child: Text('Private'),
                      ),
                      DropdownMenuItem(value: 'llc', child: Text('LLC')),
                    ],
                    onChanged: (value) async {
                      await ProfileRepository.instance.update(
                        businessType: value,
                        setBusinessTypeNull: value == null,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (canVerifyDocs) ...[
                    TextField(
                      controller: aadhaarController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Aadhaar number (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDocumentUploadCard(
                      context,
                      title: 'National ID',
                      subtitle: 'Upload front and back',
                      icon: Icons.credit_card,
                      documentType: 'aadhaar',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: panController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'PAN number (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDocumentUploadCard(
                      context,
                      title: 'Tax ID',
                      subtitle: 'Upload tax identification',
                      icon: Icons.badge,
                      documentType: 'pan',
                    ),
                    const SizedBox(height: 12),
                    _buildDocumentUploadCard(
                      context,
                      title: 'Driving License',
                      subtitle: 'Upload front and back',
                      icon: Icons.drive_eta,
                      documentType: 'dl',
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Document verification'),
                      subtitle: const Text(
                        'Upgrade to Premium to add Tax ID/National ID/Vehicle Docs',
                      ),
                      trailing: TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/plans'),
                        child: const Text('Upgrade'),
                      ),
                    ),
                  ],
                  ValueListenableBuilder<String>(
                    valueListenable: AppPreferences.instance.currencyCode,
                    builder: (context, selectedCode, _) {
                      return DropdownButtonFormField<String>(
                        initialValue: selectedCode,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'INR',
                            child: Text('INR (₹)'),
                          ),
                          DropdownMenuItem(
                            value: 'USD',
                            child: Text('USD (\$)'),
                          ),
                          DropdownMenuItem(
                            value: 'EUR',
                            child: Text('EUR (€)'),
                          ),
                          DropdownMenuItem(
                            value: 'GBP',
                            child: Text('GBP (£)'),
                          ),
                        ],
                        onChanged: (code) {
                          if (code == null) return;
                          AppPreferences.instance.setCurrencyCode(code);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<String>(
                    valueListenable: AppPreferences.instance.preferredCountry,
                    builder: (context, selectedCountry, _) {
                      return DropdownButtonFormField<String>(
                        initialValue: selectedCountry,
                        decoration: const InputDecoration(
                          labelText: 'Preferred country',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'India',
                            child: Text('India'),
                          ),
                          DropdownMenuItem(
                            value: 'United States',
                            child: Text('United States'),
                          ),
                          DropdownMenuItem(
                            value: 'United Kingdom',
                            child: Text('United Kingdom'),
                          ),
                          DropdownMenuItem(
                            value: 'Germany',
                            child: Text('Germany'),
                          ),
                          DropdownMenuItem(
                            value: 'France',
                            child: Text('France'),
                          ),
                        ],
                        onChanged: (country) {
                          if (country == null) return;
                          AppPreferences.instance.setPreferredCountry(country);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Bank Details Section (for providers to receive payments)
                  Text(
                    'Bank Details (For Receiving Payments)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your bank details to receive earnings from completed trips',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Account Holder Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Account Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Bank Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'IFSC Code / SWIFT Code',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.code),
                      hintText: 'e.g., SBIN0001234',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Account Type',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'savings',
                        child: Text('Savings'),
                      ),
                      DropdownMenuItem(
                        value: 'current',
                        child: Text('Current'),
                      ),
                    ],
                    onChanged: (value) {},
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your bank details are encrypted and secure. They will only be used to transfer your earnings.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await ProfileRepository.instance.update(
                          profileName: nameController.text.trim().isEmpty
                              ? info.profileName
                              : nameController.text.trim(),
                          phone: phoneController.text.trim().isEmpty
                              ? null
                              : phoneController.text.trim(),
                          aadhaar: aadhaarController.text.trim().isEmpty
                              ? null
                              : aadhaarController.text.trim(),
                          pan: panController.text.trim().isEmpty
                              ? null
                              : panController.text.trim(),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile updated')),
                        );
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(child: Text('Wallet coming soon')),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const PostsPage(),
    const RequestsPage(),
    const WalletPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = mainTabIndex.value;
    mainTabIndex.addListener(_onTabIndexChanged);
  }

  @override
  void dispose() {
    mainTabIndex.removeListener(_onTabIndexChanged);
    super.dispose();
  }

  void _onTabIndexChanged() {
    if (!mounted) return;
    if (_currentIndex == mainTabIndex.value) return;
    setState(() {
      _currentIndex = mainTabIndex.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quickohunt'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          mainTabIndex.value = index;
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Posts'),
          BottomNavigationBarItem(
            icon: Icon(Icons.request_page),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class SlotFeedItem {
  final Slot slot;
  final Vehicle vehicle;
  final String providerName;
  final String providerAvatar;
  final double providerRating;
  final bool isOffer;
  final bool
  isUserPost; // true = user post (looking for service), false = provider post (offering service)

  SlotFeedItem({
    required this.slot,
    required this.vehicle,
    required this.providerName,
    required this.providerAvatar,
    required this.providerRating,
    required this.isOffer,
    required this.isUserPost,
  });
}

class PostsPage extends StatefulWidget {
  const PostsPage({super.key});

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  ServiceType?
  _selectedServiceType; // null = show all, otherwise filter by service type

  // Operator filter (only for Lease)
  bool?
  _withOperator; // null = both, true = with operator, false = without operator

  final TextEditingController _searchController = TextEditingController();
  bool _nearestEnabled = false;
  bool _showUserPosts = false; // Toggle between provider and user posts

  double? _minPrice;
  double? _maxPrice;
  DateTime? _fromDateTime;
  DateTime? _toDateTime;

  final VehicleRepository _vehicleRepository = VehicleRepository.instance;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        SlotRepository.instance.slotsListenable,
        UserSlotRepository.instance.slotsListenable,
        _vehicleRepository.onlineStatusListenable,
        UserVehicleRepository.instance.onlineStatusListenable,
      ]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Posts'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              // Debug button to show repository status
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  final providerSlots = SlotRepository.instance.allSlots.length;
                  final userSlots = UserSlotRepository.instance.allSlots.length;
                  final providerVehicles =
                      VehicleRepository.instance.allVehicles.length;
                  final userVehicles =
                      UserVehicleRepository.instance.allVehicles.length;

                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Repository Status'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Provider Vehicles: $providerVehicles'),
                          Text('Provider Posts: $providerSlots'),
                          const SizedBox(height: 8),
                          Text('User Vehicles: $userVehicles'),
                          Text('User Posts: $userSlots'),
                          const SizedBox(height: 8),
                          Text('Total Posts: ${providerSlots + userSlots}'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: _showUserPosts
                              ? 'Search user requests'
                              : 'Search by location',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                    });
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _openFiltersSheet(context),
                      icon: const Icon(Icons.tune),
                      label: const Text('Filters'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Toggle between Provider and User posts
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showUserPosts = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_showUserPosts
                                  ? Colors.blue
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Providers Posts',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !_showUserPosts
                                    ? Colors.white
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showUserPosts = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _showUserPosts
                                  ? Colors.blue
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Users Posts',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _showUserPosts
                                    ? Colors.white
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Service type filter chips (Passenger, Parcel, Lease) - Show on both tabs
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ...ServiceType.values
                        .where(
                          (service) => service != ServiceType.working,
                        ) // Exclude Working
                        .map(
                          (service) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(_serviceLabel(service)),
                              selected: _selectedServiceType == service,
                              onSelected: (_) {
                                setState(() {
                                  // Toggle: click to select, click again to unselect
                                  _selectedServiceType =
                                      _selectedServiceType == service
                                      ? null
                                      : service;
                                  _withOperator = null; // Reset operator filter
                                });
                              },
                            ),
                          ),
                        ),
                    // Operator filter chips (show ONLY when Lease is selected)
                    if (_selectedServiceType == ServiceType.lease) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('With Operator'),
                          selected: _withOperator == true,
                          onSelected: (_) {
                            setState(() {
                              _withOperator = _withOperator == true
                                  ? null
                                  : true;
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('Without Operator'),
                          selected: _withOperator == false,
                          onSelected: (_) {
                            setState(() {
                              _withOperator = _withOperator == false
                                  ? null
                                  : false;
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _showUserPosts
                    ? _buildUserPostsList()
                    : _buildProviderPostsList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProviderPostsList() {
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: BookingRepository.instance.remainingCapacityBySlotId,
      builder: (context, capacityMap, child) {
        final allSlotItems = _filteredSlotItems();
        debugPrint('=== POSTS DEBUG ===');
        debugPrint(
          'Provider slots: ${SlotRepository.instance.allSlots.length}',
        );
        debugPrint(
          'User slots: ${UserSlotRepository.instance.allSlots.length}',
        );
        debugPrint('Total slot items: ${allSlotItems.length}');

        // Debug each slot's capacity
        for (final item in allSlotItems) {
          final remaining = BookingRepository.instance.getRemainingCapacity(
            item.slot.id,
            item.slot.capacity,
          );
          debugPrint(
            'Slot ${item.slot.id}: capacity=${item.slot.capacity}, remaining=$remaining',
          );
        }

        final filteredSlots = allSlotItems
            .where(
              (item) =>
                  BookingRepository.instance.getRemainingCapacity(
                    item.slot.id,
                    item.slot.capacity,
                  ) >
                  0,
            )
            .toList(growable: false);

        debugPrint('Filtered slots with capacity > 0: ${filteredSlots.length}');
        debugPrint('==================');

        if (filteredSlots.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                _selectedServiceType == null
                    ? 'No services available'
                    : 'No ${_serviceLabel(_selectedServiceType!)} services available',
              ),
            ),
          );
        }

        return ListView(
          children: [
            ...filteredSlots.map(
              (item) => SlotCard(
                slot: item.slot,
                vehicle: item.vehicle,
                providerName: item.providerName,
                providerAvatar: item.providerAvatar,
                providerRating: item.providerRating,
                isOffer: item.isOffer,
                isUserPost: item.isUserPost,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SlotDetailScreen(
                        slot: item.slot,
                        vehicle: item.vehicle,
                        providerName: item.providerName,
                        providerAvatar: item.providerAvatar,
                        providerRating: item.providerRating,
                        isOffer: item.isOffer,
                      ),
                    ),
                  );
                },
                onAction: () {
                  final currentUser = AuthRepository.instance.currentUser;
                  if (currentUser == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please login to book')),
                    );
                    return;
                  }

                  _handleBookingAction(
                    slot: item.slot,
                    providerId: item.vehicle.userId,
                    userId: currentUser.id,
                    isOffer: item.isOffer,
                    providerName: item.providerName,
                    providerAvatar: item.providerAvatar,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildUserPostsList() {
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: BookingRepository.instance.remainingCapacityBySlotId,
      builder: (context, capacityMap, child) {
        final allSlotItems = _filteredSlotItems();

        debugPrint('=== USER POSTS DEBUG ===');
        debugPrint(
          'User slots (looking for services): ${UserSlotRepository.instance.allSlots.length}',
        );
        debugPrint('Filtered user slot items: ${allSlotItems.length}');
        debugPrint('========================');

        // Filter by capacity
        final filteredSlots = allSlotItems
            .where(
              (item) =>
                  BookingRepository.instance.getRemainingCapacity(
                    item.slot.id,
                    item.slot.capacity,
                  ) >
                  0,
            )
            .toList(growable: false);

        if (filteredSlots.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                _selectedServiceType == null
                    ? 'No user posts available'
                    : 'No ${_serviceLabel(_selectedServiceType!)} requests available',
              ),
            ),
          );
        }

        return ListView(
          children: [
            ...filteredSlots.map(
              (item) => SlotCard(
                slot: item.slot,
                vehicle: item.vehicle,
                providerName: 'Looking for service',
                providerAvatar: '',
                providerRating: 0.0,
                isOffer: false, // User is looking, not offering
                isUserPost: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SlotDetailScreen(
                        slot: item.slot,
                        vehicle: item.vehicle,
                        providerName: 'User Request',
                        providerAvatar: '',
                        providerRating: 0.0,
                        isOffer: false,
                      ),
                    ),
                  );
                },
                onAction: () {
                  final currentUser = AuthRepository.instance.currentUser;
                  if (currentUser == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please login to respond')),
                    );
                    return;
                  }

                  // Provider can respond to user's request
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contact user to provide service'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  String _serviceLabel(ServiceType type) {
    switch (type) {
      case ServiceType.passenger:
        return 'Passenger';
      case ServiceType.parcel:
        return 'Parcel';
      case ServiceType.working:
        return 'Working';
      case ServiceType.lease:
        return 'Lease';
    }
  }

  List<SlotFeedItem> _filteredSlotItems() {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) {
      debugPrint('❌ No current user, returning empty list');
      return [];
    }

    // Get posts based on active tab
    final List<SlotFeedItem> repoItems;

    if (_showUserPosts) {
      // User Posts tab - show ONLY user posts from ONLINE vehicles
      final currentUserName =
          ProfileRepository.instance.profile.value.profileName;
      repoItems = UserSlotRepository.instance.allSlots
          .where(
            (e) => UserVehicleRepository.instance.isOnline(e.vehicle.id),
          ) // Only show posts from online vehicles
          .map(
            (e) => SlotFeedItem(
              slot: e.slot,
              vehicle: e.vehicle,
              providerName: currentUserName, // Use current profile name
              providerAvatar: '',
              providerRating: 5.0,
              isOffer: true,
              isUserPost: true,
            ),
          )
          .toList();
      debugPrint('📊 User posts mapped: ${repoItems.length}');
    } else {
      // Provider Posts tab - show ONLY provider posts from ONLINE vehicles
      final currentUser = AuthRepository.instance.currentUser;
      repoItems = SlotRepository.instance.allSlots
          .where(
            (e) => _vehicleRepository.isOnline(e.vehicle.id),
          ) // Only show posts from online vehicles
          .map((e) {
            // Use current profile name if it's the current user's vehicle, otherwise use stored userName
            final providerName =
                (currentUser != null && e.vehicle.userId == currentUser.id)
                ? ProfileRepository.instance.profile.value.profileName
                : e.vehicle.userName;

            return SlotFeedItem(
              slot: e.slot,
              vehicle: e.vehicle,
              providerName: providerName,
              providerAvatar: '',
              providerRating: 5.0,
              isOffer: true,
              isUserPost: false,
            );
          })
          .toList();
      debugPrint('📊 Provider posts mapped: ${repoItems.length}');
    }

    final query = _searchController.text.trim().toLowerCase();
    final searched = query.isEmpty
        ? repoItems
        : repoItems
              .where((e) {
                final from = (e.slot.fromLocation ?? '').toLowerCase();
                final to = (e.slot.toLocation ?? '').toLowerCase();
                final base = (e.slot.baseLocation ?? '').toLowerCase();
                return from.contains(query) ||
                    to.contains(query) ||
                    base.contains(query);
              })
              .toList(growable: false);
    debugPrint('📊 After search filter: ${searched.length}');

    final dateTimeFiltered = searched
        .where((e) {
          if (_fromDateTime == null && _toDateTime == null) return true;
          final st = e.slot.startTime;
          if (_fromDateTime != null && st.isBefore(_fromDateTime!)) {
            return false;
          }
          if (_toDateTime != null && st.isAfter(_toDateTime!)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    debugPrint('📊 After date/time filter: ${dateTimeFiltered.length}');

    // Apply price filter
    final priceFiltered = dateTimeFiltered
        .where((e) {
          final p = e.slot.price;
          if (_minPrice != null && p < _minPrice!) return false;
          if (_maxPrice != null && p > _maxPrice!) return false;
          return true;
        })
        .toList(growable: false);
    debugPrint(
      '📊 After price filter (${_minPrice ?? "any"}-${_maxPrice ?? "any"}): ${priceFiltered.length}',
    );

    // Apply service type filter
    final serviceFiltered = _selectedServiceType == null
        ? priceFiltered
        : priceFiltered
              .where((e) => e.slot.serviceType == _selectedServiceType)
              .toList();

    // Apply operator filter
    final operatorFiltered = _withOperator == null
        ? serviceFiltered
        : serviceFiltered
              .where((e) => e.slot.withOperator == _withOperator)
              .toList();

    if (!_nearestEnabled) return operatorFiltered;

    return _sortByDistance(operatorFiltered);
  }

  List<SlotFeedItem> _sortByDistance(List<SlotFeedItem> items) {
    final userPos = _currentUserPosition;
    if (userPos == null) return items;

    final withDist = items.map((e) {
      final vehiclePos = _vehicleResolvedLatLng(e.vehicle);
      final distance = vehiclePos != null
          ? _haversineKm(userPos.$1, userPos.$2, vehiclePos.$1, vehiclePos.$2)
          : double.infinity;
      return (item: e, distance: distance);
    }).toList();

    withDist.sort((a, b) => a.distance.compareTo(b.distance));
    return withDist.map((e) => e.item).toList();
  }

  (double, double)? _currentUserPosition;

  (double, double)? _vehicleResolvedLatLng(Vehicle vehicle) {
    switch (vehicle.gpsMode) {
      case VehicleGpsMode.manual:
        if (vehicle.manualLat == null || vehicle.manualLng == null) return null;
        return (vehicle.manualLat!, vehicle.manualLng!);
      case VehicleGpsMode.externalLink:
      case VehicleGpsMode.deviceLive:
        if (vehicle.lastKnownLat == null || vehicle.lastKnownLng == null) {
          return null;
        }
        return (vehicle.lastKnownLat!, vehicle.lastKnownLng!);
    }
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            (math.sin(dLon / 2) * math.sin(dLon / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * (3.14159265359 / 180.0);

  Future<void> _requestUserLocation() async {
    final status = await Permission.locationWhenInUse.request();
    if (status != PermissionStatus.granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (mounted) {
        setState(() {
          _currentUserPosition = (pos.latitude, pos.longitude);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not get location')));
      }
    }
  }

  Future<void> _openFiltersSheet(BuildContext context) async {
    final minPriceController = TextEditingController(
      text: _minPrice?.toInt().toString() ?? '',
    );
    final maxPriceController = TextEditingController(
      text: _maxPrice?.toInt().toString() ?? '',
    );
    DateTime? from = _fromDateTime;
    DateTime? to = _toDateTime;
    bool nearest = _nearestEnabled;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: nearest,
                    onChanged: (v) async {
                      if (v && _currentUserPosition == null) {
                        // Capture messenger before async gap
                        final messenger = ScaffoldMessenger.of(context);

                        // Close the sheet first to avoid freezing
                        if (context.mounted) {
                          Navigator.pop(context);
                        }

                        // Request location
                        await _requestUserLocation();

                        if (!mounted) return;

                        if (_currentUserPosition != null) {
                          // Location obtained, enable nearest filter
                          setState(() {
                            _nearestEnabled = true;
                          });
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Nearest first enabled'),
                            ),
                          );
                        } else {
                          // Location not obtained
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Location permission required'),
                            ),
                          );
                        }
                        return;
                      }
                      setSheetState(() => nearest = v);
                    },
                    title: const Text('Nearest first'),
                    subtitle: Text(
                      _currentUserPosition == null
                          ? 'Requires location permission'
                          : 'Sort by distance from your location',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Min Price',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.currency_rupee),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Max Price',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.currency_rupee),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month),
                    title: const Text('From date/time'),
                    subtitle: Text(from == null ? 'Any' : _fmtDateTime(from!)),
                    trailing: TextButton(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: from ?? DateTime.now(),
                        );
                        if (!context.mounted) return;
                        if (pickedDate == null) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            from ?? DateTime.now(),
                          ),
                        );
                        if (!context.mounted) return;
                        if (pickedTime == null) return;
                        setSheetState(() {
                          from = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      },
                      child: const Text('Pick'),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month),
                    title: const Text('To date/time'),
                    subtitle: Text(to == null ? 'Any' : _fmtDateTime(to!)),
                    trailing: TextButton(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: to ?? (from ?? DateTime.now()),
                        );
                        if (!context.mounted) return;
                        if (pickedDate == null) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            to ?? DateTime.now(),
                          ),
                        );
                        if (!context.mounted) return;
                        if (pickedTime == null) return;
                        setSheetState(() {
                          to = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      },
                      child: const Text('Pick'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _minPrice = null;
                              _maxPrice = null;
                              _fromDateTime = null;
                              _toDateTime = null;
                              _nearestEnabled = false;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _minPrice = double.tryParse(
                                minPriceController.text,
                              );
                              _maxPrice = double.tryParse(
                                maxPriceController.text,
                              );
                              _fromDateTime = from;
                              _toDateTime = to;
                              _nearestEnabled = nearest;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _fmtDateTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $h:$m';
  }

  Future<void> _handleBookingAction({
    required Slot slot,
    required String providerId,
    required String userId,
    required bool isOffer,
    String? providerName,
    String? providerPhone,
    String? providerEmail,
    String? providerAvatar,
  }) async {
    debugPrint('🎫 Booking action started for slot: ${slot.id}');

    final canBook = BookingRepository.instance.canBook(slot.id, slot.capacity);
    if (!canBook) {
      debugPrint('❌ Cannot book: No capacity remaining');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No capacity remaining')));
      return;
    }

    debugPrint(
      '✅ Capacity check passed, looking for vehicle: ${slot.vehicleId}',
    );

    final vehicle = VehicleRepository.instance.getById(slot.vehicleId);
    if (vehicle == null) {
      debugPrint('❌ Vehicle not found in VehicleRepository: ${slot.vehicleId}');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vehicle not found')));
      return;
    }

    debugPrint('✅ Vehicle found, showing booking sheet');

    final result = await showModalBottomSheet<BookingConfirmResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => BookingConfirmSheet(slot: slot, isOffer: isOffer),
    );

    if (result == null) {
      debugPrint('❌ Booking cancelled by user');
      return;
    }

    if (!mounted) return;

    // Use fallback provider info if not provided
    final finalProviderName = providerName ?? vehicle.userName;
    final finalProviderPhone = providerPhone ?? _providerPhone(vehicle.userId);

    debugPrint('=== BOOKING DEBUG ===');
    debugPrint('Vehicle userId: ${vehicle.userId}');
    debugPrint('Current user ID: ${AuthRepository.instance.currentUser?.id}');
    debugPrint('Provider ID for booking: ${vehicle.userId}');
    debugPrint('====================');

    final booking = await BookingRepository.instance.createBooking(
      slotId: slot.id,
      providerId: vehicle.userId,
      providerName: finalProviderName,
      providerPhone: finalProviderPhone,
      providerEmail: providerEmail,
      providerAvatar: providerAvatar,
      userId: AuthRepository.instance.currentUser?.id ?? 'guest',
      defaultCapacity: slot.capacity,
      price: (() {
        final seatKey = result.seatKey;
        final ownerId = slot.seatLayoutOwnerId;
        if (seatKey == null || ownerId == null) return slot.price;
        final p = SeatLayoutRepository.instance
            .getLayout(ownerId)
            ?.cells[seatKey]
            ?.price;
        return (p ?? slot.price.toInt()).toDouble();
      })(),
      seatKey: result.seatKey,
      userName: result.userName,
      userAge: result.userAge,
      userGender: result.userGender,
      userPhone: result.userPhone,
      userEmail: result.userEmail,
    );

    if (booking == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to book. Seat may be taken.')),
      );
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Booking request sent!')));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingMapScreen(
          booking: booking,
          slot: slot,
          vehicle: vehicle,
          isProviderView: false,
          autoCloseSeconds: 3,
        ),
      ),
    );
  }

  String _providerPhone(String providerId) {
    // Use current profile phone if it's the current user or 'user1', otherwise use default
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser != null &&
        (providerId == currentUser.id || providerId == 'user1')) {
      return ProfileRepository.instance.profile.value.phone ??
          '+91 90000 00000';
    }
    return '+91 98765 43210';
  }
}

class RequestsPage extends StatelessWidget {
  const RequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requests'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const _RequestsBody(),
    );
  }
}

class _RequestsBody extends StatefulWidget {
  const _RequestsBody();

  @override
  State<_RequestsBody> createState() => _RequestsBodyState();
}

class _RequestsBodyState extends State<_RequestsBody> {
  bool _isRiderView = true;
  final Map<String, TextEditingController> _otpControllers = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    for (final c in _otpControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _otpControllerFor(String bookingId) {
    return _otpControllers.putIfAbsent(
      bookingId,
      () => TextEditingController(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isRiderView = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isRiderView ? Colors.blue : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'User',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isRiderView ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isRiderView = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isRiderView ? Colors.blue : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Provider',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !_isRiderView ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ValueListenableBuilder<List<Booking>>(
            valueListenable: BookingRepository.instance.bookings,
            builder: (context, bookings, _) {
              final currentUser = AuthRepository.instance.currentUser;
              if (currentUser == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('Please login to view requests'),
                  ),
                );
              }

              final filtered = bookings
                  .where((b) {
                    if (_isRiderView) {
                      return b.userId == currentUser.id;
                    } else {
                      // Provider view: show if providerId matches OR if it's 'user1' (legacy)
                      return b.providerId == currentUser.id ||
                          b.providerId == 'user1';
                    }
                  })
                  .toList(growable: false);

              // Debug: Print booking info
              debugPrint('=== REQUESTS DEBUG ===');
              debugPrint('Current User ID: ${currentUser.id}');
              debugPrint('Is Provider View: ${!_isRiderView}');
              debugPrint('Total Bookings: ${bookings.length}');
              debugPrint('Filtered Bookings: ${filtered.length}');
              for (var b in bookings) {
                debugPrint(
                  'Booking ${b.id}: userId=${b.userId}, providerId=${b.providerId}',
                );
              }
              debugPrint('=====================');

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isRiderView
                              ? 'No user bookings yet'
                              : 'No provider bookings yet',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your ID: ${currentUser.id}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (bookings.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Total bookings: ${bookings.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Clear All Bookings?'),
                                  content: const Text(
                                    'This will delete all bookings. This action cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Clear All'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                BookingRepository.instance.bookings.value = [];
                                BookingRepository
                                        .instance
                                        .remainingCapacityBySlotId
                                        .value =
                                    {};
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.remove('bookings_data');
                                await prefs.remove('remaining_capacity');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('All bookings cleared'),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.delete_sweep),
                            label: const Text('Clear All Bookings'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final b = filtered[index];
                  return _buildBookingCard(
                    context,
                    b,
                    isRiderView: _isRiderView,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBookingCard(
    BuildContext context,
    Booking b, {
    required bool isRiderView,
  }) {
    final status = _statusLabel(b.status);
    final color = _statusColor(b.status);
    Slot? bookingSlot;
    for (final e in SlotRepository.instance.allSlots) {
      if (e.slot.id == b.slotId) {
        bookingSlot = e.slot;
        break;
      }
    }
    final Slot? slotForMap = b.status == BookingStatus.accepted
        ? bookingSlot
        : null;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Booking #${b.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, size: 16, color: Colors.blue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.userName ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${b.userAge ?? '?'} yrs · ${b.userGender?.name ?? 'Any'}${b.seatKey != null ? ' · Seat: ${b.seatKey}' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Slot: ${b.slotId}',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Time: ${_fmtDateTime(b.createdAt)}',
              style: TextStyle(color: Colors.grey[700]),
            ),
            if (slotForMap != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (slotForMap.fromLocation != null &&
                              slotForMap.toLocation != null)
                          ? '${slotForMap.fromLocation!} → ${slotForMap.toLocation!}'
                          : (slotForMap.baseLocation ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open map',
                    onPressed: () =>
                        _openExternalMapForSlot(context, slotForMap),
                    icon: const Icon(Icons.map_outlined),
                  ),
                ],
              ),
            ],
            if (b.status == BookingStatus.accepted ||
                b.status == BookingStatus.completed) ...[
              const SizedBox(height: 12),
              if (isRiderView) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_pin,
                        size: 20,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Provider: ${b.providerName ?? _providerName(b.providerId)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Contact: ${b.providerPhone ?? _providerPhone(b.providerId)}',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  tooltip: 'Copy contact',
                                  onPressed: () {
                                    final phone =
                                        b.providerPhone ??
                                        _providerPhone(b.providerId);
                                    Clipboard.setData(
                                      ClipboardData(text: phone),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Provider contact copied',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            if ((b.providerEmail ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Email: ${b.providerEmail}',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 18),
                                    tooltip: 'Copy email',
                                    onPressed: () {
                                      final email = b.providerEmail ?? '';
                                      Clipboard.setData(
                                        ClipboardData(text: email),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Provider email copied',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, size: 18, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          b.status == BookingStatus.completed
                              ? 'Trip completed'
                              : 'OTP: ${b.otp ?? '—'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_pin_circle,
                        size: 20,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User: ${b.userName ?? _userName(b.userId)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Contact: ${b.userPhone ?? _userPhone(b.userId)}',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  tooltip: 'Copy contact',
                                  onPressed: () {
                                    final phone =
                                        b.userPhone ?? _userPhone(b.userId);
                                    Clipboard.setData(
                                      ClipboardData(text: phone),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('User contact copied'),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            if ((b.userEmail ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Email: ${b.userEmail}',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 18),
                                    tooltip: 'Copy email',
                                    onPressed: () {
                                      final email = b.userEmail ?? '';
                                      Clipboard.setData(
                                        ClipboardData(text: email),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('User email copied'),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (b.status == BookingStatus.completed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified, size: 18, color: Colors.green),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'OTP verified',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _otpControllerFor(b.id),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Enter OTP from user',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final otpText = _otpControllerFor(b.id).text;
                          final otpOk = BookingRepository.instance.isOtpValid(
                            bookingId: b.id,
                            otp: otpText,
                          );

                          if (!otpOk) {
                            if (!context.mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Invalid OTP')),
                            );
                            return;
                          }

                          // Payment will be implemented after Supabase setup
                          // Will be handled through Razorpay with escrow

                          final ok = await BookingRepository.instance.verifyOtp(
                            bookingId: b.id,
                            otp: otpText,
                          );
                          if (!context.mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Paid & OTP verified ✅'
                                    : 'OTP verify failed',
                              ),
                            ),
                          );
                        },
                        child: const Text('Verify'),
                      ),
                    ],
                  ),
              ],
              if (isRiderView) ...[const SizedBox(height: 12)],
            ],
          ],
        ),
      ),
    );
  }

  static String _statusLabel(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.accepted:
        return 'Accepted';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.rejected:
        return 'Rejected';
    }
  }

  static Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.accepted:
        return Colors.green;
      case BookingStatus.completed:
        return Colors.blue;
      case BookingStatus.rejected:
        return Colors.red;
    }
  }

  static String _fmtDateTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $h:$m';
  }

  String _providerName(String providerId) {
    // Try to find vehicle by userId and get userName
    try {
      final vehicle = VehicleRepository.instance.allVehicles.firstWhere(
        (v) => v.userId == providerId,
      );
      return vehicle.userName;
    } catch (_) {
      // Try user vehicles
      try {
        final vehicle = UserVehicleRepository.instance.allVehicles.firstWhere(
          (v) => v.userId == providerId,
        );
        return vehicle.userName;
      } catch (_) {
        return 'Unknown User';
      }
    }
  }

  String _providerPhone(String providerId) {
    // Use current profile phone if it's the current user or 'user1', otherwise use default
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser != null &&
        (providerId == currentUser.id || providerId == 'user1')) {
      return ProfileRepository.instance.profile.value.phone ??
          '+91 90000 00000';
    }
    return '+91 98765 43210';
  }

  String _userName(String userId) {
    // Use current profile name if it's the current user, otherwise use userId
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser != null && userId == currentUser.id) {
      return ProfileRepository.instance.profile.value.profileName;
    }
    return userId.isEmpty ? 'User' : userId;
  }

  String _userPhone(String userId) {
    // Use current profile phone if it's the current user, otherwise use default
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser != null && userId == currentUser.id) {
      return ProfileRepository.instance.profile.value.phone ??
          '+91 90000 00000';
    }
    return '+91 90000 00000';
  }
}

class SpendingPage extends StatefulWidget {
  const SpendingPage({super.key});

  @override
  State<SpendingPage> createState() => _SpendingPageState();
}

class _SpendingPageState extends State<SpendingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<Booking>>(
        valueListenable: BookingRepository.instance.bookings,
        builder: (context, allBookings, _) {
          final currentUser = AuthRepository.instance.currentUser;
          if (currentUser == null) {
            return const Center(child: Text('Please login to view spending'));
          }

          // Get bookings where current user is the customer
          final userBookings = allBookings
              .where(
                (b) =>
                    b.userId == currentUser.id &&
                    b.status == BookingStatus.completed,
              )
              .toList();

          // Calculate total spending
          final totalSpending = userBookings.fold<double>(
            0,
            (sum, booking) => sum + booking.price,
          );

          // Get slots to determine service types
          final slotRepo = SlotRepository.instance;
          final allSlots = slotRepo.allSlotsRaw;

          // Group by service type
          double passengerSpending = 0;
          double parcelSpending = 0;
          double leaseSpending = 0;

          for (var booking in userBookings) {
            try {
              final slot = allSlots.firstWhere((s) => s.id == booking.slotId);
              if (slot.serviceType == ServiceType.passenger) {
                passengerSpending += booking.price;
              } else if (slot.serviceType == ServiceType.parcel) {
                parcelSpending += booking.price;
              } else if (slot.serviceType == ServiceType.lease ||
                  slot.serviceType == ServiceType.working) {
                leaseSpending += booking.price;
              }
            } catch (e) {
              // Slot not found, skip
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Total Spending Card
              Card(
                elevation: 4,
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        'Total Spending',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<String>(
                        valueListenable: AppPreferences.instance.currencyCode,
                        builder: (context, currencyCode, child) {
                          return Text(
                            AppPreferences.instance.formatMoney(
                              totalSpending.toInt(),
                            ),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${userBookings.length} completed trips',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Spending by Service Type
              const Text(
                'Spending by Service',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              _buildServiceSpendingCard(
                'Passenger',
                passengerSpending,
                Icons.people,
                Colors.blue,
              ),
              const SizedBox(height: 8),

              _buildServiceSpendingCard(
                'Parcel',
                parcelSpending,
                Icons.local_shipping,
                Colors.orange,
              ),
              const SizedBox(height: 8),

              _buildServiceSpendingCard(
                'Lease',

                leaseSpending,
                Icons.car_rental,
                Colors.purple,
              ),

              const SizedBox(height: 24),

              // Recent Transactions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to full transaction history
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (userBookings.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No spending yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                )
              else
                ...userBookings.take(10).map((booking) {
                  final allSlots = SlotRepository.instance.allSlotsRaw;
                  Slot? slot;
                  try {
                    slot = allSlots.firstWhere((s) => s.id == booking.slotId);
                  } catch (e) {
                    // Slot not found
                  }
                  return _buildTransactionCard(booking, slot);
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildServiceSpendingCard(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: ValueListenableBuilder<String>(
          valueListenable: AppPreferences.instance.currencyCode,
          builder: (context, _, _) {
            return Text(
              AppPreferences.instance.formatMoney(amount.toInt()),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Booking booking, Slot? slot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withValues(alpha: 0.1),
          child: const Icon(Icons.payment, color: Colors.blue),
        ),
        title: Text(
          slot != null ? '${slot.serviceType.displayName} Service' : 'Service',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${booking.createdAt.day}/${booking.createdAt.month}/${booking.createdAt.year}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: ValueListenableBuilder<String>(
          valueListenable: AppPreferences.instance.currencyCode,
          builder: (context, _, _) {
            return Text(
              AppPreferences.instance.formatMoney(booking.price.toInt()),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            );
          },
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isUserMode = true;

  @override
  Widget build(BuildContext context) {
    final profileListenable = ProfileRepository.instance.profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<ProfileInfo>(
        valueListenable: profileListenable,
        builder: (context, info, _) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Profile Header
              Row(
                children: [
                  // Profile Picture
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _profileAvatarProvider(info),
                    child: info.avatarUrl == null
                        ? const Icon(Icons.person, size: 40, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.profileName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (info.businessType != null &&
                            info.businessType!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            info.businessType!.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'online',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Passionate about transportation and helping others move efficiently.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // User/Rider Toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isUserMode = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isUserMode
                                ? Colors.blue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'User',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isUserMode ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isUserMode = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isUserMode
                                ? Colors.blue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Provider',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: !_isUserMode ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Mode-specific content
              if (_isUserMode) ...[
                ListTile(
                  leading: const Icon(Icons.directions_car_filled),
                  title: const Text('Needed Vehicles'),
                  subtitle: const Text('Vehicles you need'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            VehicleListScreen(isUserMode: true),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet),
                  title: const Text('Spending'),
                  subtitle: const Text('View your trip spending'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SpendingPage()),
                    );
                  },
                ),
                ValueListenableBuilder<SubscriptionPlan>(
                  valueListenable: AppPreferences.instance.subscriptionPlan,
                  builder: (context, plan, _) {
                    if (plan != SubscriptionPlan.expert) {
                      return const SizedBox();
                    }
                    return ListTile(
                      leading: const Icon(Icons.support_agent),
                      title: const Text('Expert Support'),
                      subtitle: const Text('Priority customer support'),
                      onTap: () {
                        Navigator.pushNamed(context, '/expert-support');
                      },
                    );
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: const Text('Providing Vehicles'),
                  subtitle: const Text('Manage your vehicles and services'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            VehicleListScreen(isUserMode: false),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Earnings'),
                  subtitle: const Text('View your riding earnings'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EarningsPage()),
                    );
                  },
                ),
              ],
              const Divider(),
              // Menu Items
              ListTile(
                leading: const Icon(Icons.workspace_premium),
                title: const Text('Plans'),
                onTap: () {
                  Navigator.pushNamed(context, '/plans');
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              ),
              const ListTile(
                leading: Icon(Icons.help_outline),
                title: Text('Help & Support'),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  await AuthRepository.instance.logout();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: _isUserMode
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VehicleListScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Post'),
            )
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VehicleListScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Vehicle'),
            ),
    );
  }
}

// User Posts List Page - Shows all posts from UserSlotRepository
class UserPostsListPage extends StatelessWidget {
  const UserPostsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts (Looking)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<SlotEntry>>(
        valueListenable: UserSlotRepository.instance.slotsListenable,
        builder: (context, slots, _) {
          if (slots.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.post_add, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'No posts yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create posts for services you\'re looking for',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              VehicleListScreen(isUserMode: true),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Post'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: slots.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = slots[index];
              return SlotCard(
                slot: entry.slot,
                vehicle: entry.vehicle,
                providerName: 'You',
                providerAvatar: '',
                providerRating: 5.0,
                isOffer: true,
                isUserPost: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SlotDetailScreen(
                        slot: entry.slot,
                        vehicle: entry.vehicle,
                        providerName: 'You',
                        providerAvatar: '',
                        providerRating: 5.0,
                        isOffer: true,
                      ),
                    ),
                  );
                },
                onAction: () {},
              );
            },
          );
        },
      ),
    );
  }
}

// Provider Posts List Page - Shows all posts from SlotRepository
class ProviderPostsListPage extends StatelessWidget {
  const ProviderPostsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts (Offering)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<SlotEntry>>(
        valueListenable: SlotRepository.instance.slotsListenable,
        builder: (context, slots, _) {
          if (slots.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.post_add, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'No posts yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create posts for services you\'re offering',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              VehicleListScreen(isUserMode: false),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Post'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: slots.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = slots[index];
              return SlotCard(
                slot: entry.slot,
                vehicle: entry.vehicle,
                providerName: 'You',
                providerAvatar: '',
                providerRating: 5.0,
                isOffer: true,
                isUserPost: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SlotDetailScreen(
                        slot: entry.slot,
                        vehicle: entry.vehicle,
                        providerName: 'You',
                        providerAvatar: '',
                        providerRating: 5.0,
                        isOffer: true,
                      ),
                    ),
                  );
                },
                onAction: () {},
              );
            },
          );
        },
      ),
    );
  }
}
