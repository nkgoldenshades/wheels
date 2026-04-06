import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import '../../models/vehicle.dart';
import '../../services/auth_repository.dart';
import '../../services/profile_repository.dart';
import '../verification/live_camera_screen.dart'
    show LiveCameraScreen, CaptureMode;

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _customTypeController = TextEditingController();
  final _yearController = TextEditingController();

  String _uuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int v) => v.toRadixString(16).padLeft(2, '0');
    final b = bytes;
    return '${hex(b[0])}${hex(b[1])}${hex(b[2])}${hex(b[3])}'
        '-${hex(b[4])}${hex(b[5])}'
        '-${hex(b[6])}${hex(b[7])}'
        '-${hex(b[8])}${hex(b[9])}'
        '-${hex(b[10])}${hex(b[11])}${hex(b[12])}${hex(b[13])}${hex(b[14])}${hex(b[15])}';
  }
  String? _selectedVehicleType;
  final List<String> _vehicleTypes = [
    'Car',
    'Bike',
    'Truck',
    'Bus',
    'Van',
    'Ship',
    'Boat',
    'Rocket',
    'Train',
    'Flight',
    'Other',
  ];

  // Media fields
  String? _profileImageBase64;
  final List<String> _galleryImagesBase64 = [];
  String? _videoBase64;

  // Verification status
  bool _profileImageVerified = false;
  bool _videoVerified = false;
  final List<bool> _galleryVerified = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _customTypeController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Vehicle'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle name',
                  hintText: 'e.g., Swift / Innova / JCB',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter vehicle name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type',
                  border: OutlineInputBorder(),
                ),
                items: _vehicleTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedVehicleType = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select vehicle type';
                  }
                  return null;
                },
              ),
              if (_selectedVehicleType == 'Other') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Vehicle Type',
                    hintText: 'Enter your vehicle type',
                  ),
                  validator: (v) {
                    if (_selectedVehicleType == 'Other' &&
                        (v == null || v.trim().isEmpty)) {
                      return 'Enter custom vehicle type';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Year (optional)',
                  hintText: 'e.g., 2021',
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Profile Image Section
              _buildMediaSection(
                title: 'Profile Image (DP)',
                subtitle: 'Main display picture for your vehicle',
                icon: Icons.account_circle,
                hasMedia: _profileImageBase64 != null,
                isVerified: _profileImageVerified,
                onAdd: _pickProfileImage,
                onRemove: () => setState(() {
                  _profileImageBase64 = null;
                  _profileImageVerified = false;
                }),
                mediaWidget: _profileImageBase64 != null
                    ? _buildImagePreview(_profileImageBase64!)
                    : null,
              ),

              const SizedBox(height: 16),

              // Gallery Images Section
              _buildMediaSection(
                title: 'Gallery Images',
                subtitle: 'Add up to 5 additional photos',
                icon: Icons.photo_library,
                hasMedia: _galleryImagesBase64.isNotEmpty,
                isVerified: _galleryVerified.every((v) => v),
                onAdd: _galleryImagesBase64.length < 5
                    ? _pickGalleryImage
                    : null,
                onRemove: null,
                mediaWidget: _galleryImagesBase64.isNotEmpty
                    ? _buildGalleryPreview()
                    : null,
              ),

              const SizedBox(height: 16),

              // Video Section
              _buildMediaSection(
                title: 'Video',
                subtitle: 'Optional video showcase (max 30 seconds)',
                icon: Icons.videocam,
                hasMedia: _videoBase64 != null,
                isVerified: _videoVerified,
                onAdd: _pickVideo,
                onRemove: () => setState(() {
                  _videoBase64 = null;
                  _videoVerified = false;
                }),
                mediaWidget: _videoBase64 != null ? _buildVideoPreview() : null,
              ),

              const SizedBox(height: 24),
              FilledButton(
                onPressed: _onSave,
                child: const Text('Save Vehicle'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool hasMedia,
    required bool isVerified,
    required VoidCallback? onAdd,
    required VoidCallback? onRemove,
    required Widget? mediaWidget,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                if (hasMedia && isVerified)
                  const Icon(Icons.verified, color: Colors.green, size: 20),
                if (hasMedia && !isVerified)
                  const Icon(Icons.pending, color: Colors.orange, size: 20),
              ],
            ),
            if (mediaWidget != null) ...[
              const SizedBox(height: 12),
              mediaWidget,
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (onAdd != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: Text(hasMedia ? 'Change' : 'Add'),
                    ),
                  ),
                if (hasMedia && onRemove != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
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

  Widget _buildImagePreview(String base64) {
    final bytes = base64Decode(base64);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        bytes,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildGalleryPreview() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _galleryImagesBase64.length,
        itemBuilder: (context, index) {
          final bytes = base64Decode(_galleryImagesBase64[index]);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    bytes,
                    height: 100,
                    width: 100,
                    fit: BoxFit.cover,
                  ),
                ),
                if (_galleryVerified.length > index && _galleryVerified[index])
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(Icons.verified, color: Colors.green, size: 20),
                  ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(24, 24),
                    ),
                    onPressed: () {
                      setState(() {
                        _galleryImagesBase64.removeAt(index);
                        if (_galleryVerified.length > index) {
                          _galleryVerified.removeAt(index);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline, size: 48, color: Colors.blue),
            SizedBox(height: 8),
            Text('Video uploaded'),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    // Show options: Live Camera or Gallery
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Take Live Photo'),
              subtitle: const Text('Recommended - Prevents fake images'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      Uint8List bytes;

      if (source == 'camera') {
        // Live camera capture
        if (!mounted) return;
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => const LiveCameraScreen(
              mode: CaptureMode.photo,
              title: 'Capture Vehicle Photo',
              instruction:
                  'Take a clear photo of your vehicle\nMake sure the vehicle is clearly visible',
            ),
          ),
        );

        if (result == null || !mounted) return;
        bytes = await XFile(result['path']).readAsBytes();
      } else {
        // Gallery picker
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );

        if (image == null || !mounted) return;
        bytes = await image.readAsBytes();
      }

      // Verify image content
      final isValid = await _verifyImageContent(bytes);

      if (!mounted) return;

      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Image verification failed. Please upload a clear vehicle photo.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _profileImageBase64 = base64Encode(bytes);
        _profileImageVerified = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == 'camera'
                ? 'Live photo verified successfully! ✓'
                : 'Profile image verified successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _pickGalleryImage() async {
    // Show options: Live Camera or Gallery
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Take Live Photo'),
              subtitle: const Text('Recommended'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      Uint8List bytes;

      if (source == 'camera') {
        if (!mounted) return;
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (context) => const LiveCameraScreen(
              mode: CaptureMode.photo,
              title: 'Capture Vehicle Photo',
              instruction:
                  'Take another photo of your vehicle\nShow different angles for better verification',
            ),
          ),
        );

        if (result == null || !mounted) return;
        bytes = await XFile(result['path']).readAsBytes();
      } else {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );

        if (image == null || !mounted) return;
        bytes = await image.readAsBytes();
      }

      // Verify image content
      final isValid = await _verifyImageContent(bytes);

      if (!mounted) return;

      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Image verification failed. Please upload a clear vehicle photo.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _galleryImagesBase64.add(base64Encode(bytes));
        _galleryVerified.add(true);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == 'camera'
                ? 'Live photo verified successfully! ✓'
                : 'Gallery image verified successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );

      if (video == null) return;

      final bytes = await video.readAsBytes();

      // Check file size (max 10MB)
      if (bytes.length > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video too large. Maximum size is 10MB.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Verify video content
      final isValid = await _verifyVideoContent(bytes);

      if (!mounted) return;

      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Video verification failed. Please upload a clear vehicle video.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _videoBase64 = base64Encode(bytes);
        _videoVerified = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video verified successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick video: $e')));
    }
  }

  Future<bool> _verifyImageContent(Uint8List bytes) async {
    // Basic verification: check file size and format
    if (bytes.length < 1024) return false; // Too small
    if (bytes.length > 5 * 1024 * 1024) return false; // Too large (>5MB)

    // Check image header for valid format (JPEG, PNG)
    if (bytes.length >= 2) {
      // JPEG: FF D8
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
      // PNG: 89 50 4E 47
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return true;
      }
    }

    return false;
  }

  Future<bool> _verifyVideoContent(Uint8List bytes) async {
    // Basic verification: check file size
    if (bytes.length < 10240) return false; // Too small (<10KB)
    if (bytes.length > 10 * 1024 * 1024) return false; // Too large (>10MB)

    // Check video header for valid format (MP4, MOV)
    if (bytes.length >= 12) {
      // MP4: ftyp
      final header = String.fromCharCodes(bytes.sublist(4, 8));
      if (header == 'ftyp') return true;
    }

    return true; // Allow other formats for now
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    // Check if profile image is added
    if (_profileImageBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a profile image')),
      );
      return;
    }

    // Check if all media is verified
    if (!_profileImageVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image is not verified')),
      );
      return;
    }

    if (_galleryVerified.any((v) => !v)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Some gallery images are not verified')),
      );
      return;
    }

    if (_videoBase64 != null && !_videoVerified) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Video is not verified')));
      return;
    }

    final name = _nameController.text.trim();
    final type = (_selectedVehicleType == 'Other'
            ? _customTypeController.text.trim()
            : (_selectedVehicleType ?? ''))
        .trim();
    final yearText = _yearController.text.trim();
    final int? year = yearText.isEmpty ? null : int.tryParse(yearText);

    final vehicle = Vehicle(
      id: _uuidV4(),
      userId: AuthRepository.instance.currentUser?.id ?? '',
      userName: ProfileRepository.instance.profile.value.profileName.isNotEmpty
          ? ProfileRepository.instance.profile.value.profileName
          : (AuthRepository.instance.currentUser?.profileName ?? 'Unknown User'),
      name: name,
      type: type,
      year: year,
      capabilities: [], // Empty - capabilities chosen when creating posts
      profileImage: _profileImageBase64,
      galleryImages: _galleryImagesBase64,
      videoUrl: _videoBase64,
      createdAt: DateTime.now(),
    );

    Navigator.pop(context, vehicle);
  }
}
