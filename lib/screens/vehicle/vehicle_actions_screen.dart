import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/booking.dart';
import '../../models/exceptions.dart';
import '../../models/review.dart';
import '../../models/service_type.dart';
import '../../models/slot_entry.dart';
import '../../models/vehicle.dart';
import '../../services/auth_repository.dart';
import '../../services/booking_repository.dart';
import '../../services/profile_repository.dart';
import '../../services/review_repository.dart';
import '../../services/slot_repository.dart';
import '../../services/vehicle_repository.dart';
import '../../services/customer_vehicle_repository.dart';
import '../../services/customer_slot_repository.dart';
import '../reviews_screen.dart';
import '../slot_detail_screen.dart';
import '../add_flow/create_post_screen.dart';
import '../verification/document_verification_screen.dart';
import '../../widgets/slot_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/location_autocomplete_service.dart';
import '../../services/app_preferences.dart';
import '../../services/payment_service.dart';
import '../../utils/image_compression_helper.dart';

/// Upload a vehicle sensitive document to vehicle_sensitive_media bucket
/// Returns the public URL or null on failure
Future<String?> _uploadVehicleSensitiveDoc({
  required String vehicleId,
  required String docType,
  required Uint8List bytes,
  required String extension,
}) async {
  try {
    final userId = AuthRepository.instance.currentUser?.id;
    if (userId == null) return null;

    // Compress image documents (800x800)
    final finalBytes =
        await ImageCompressionHelper.compressImageBytes(
          bytes,
          targetWidth: 800,
          targetHeight: 800,
        ) ??
        bytes;

    final supabase = Supabase.instance.client;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$vehicleId/$docType/${docType}_$timestamp.$extension';
    await supabase.storage
        .from('vehicle_sensitive_media')
        .uploadBinary(path, finalBytes);
    return supabase.storage.from('vehicle_sensitive_media').getPublicUrl(path);
  } catch (e) {
    debugPrint('❌ Vehicle sensitive doc upload failed: $e');
    return null;
  }
}

/// Upload operator photo to vehicle_sensitive_media bucket
/// Returns the public URL or null on failure
Future<String?> _uploadOperatorPhoto({
  required String vehicleId,
  required Uint8List bytes,
}) async {
  try {
    final userId = AuthRepository.instance.currentUser?.id;
    if (userId == null) return null;

    // Compress operator photo (512x512)
    final finalBytes =
        await ImageCompressionHelper.compressImageBytes(
          bytes,
          targetWidth: 512,
          targetHeight: 512,
        ) ??
        bytes;

    final supabase = Supabase.instance.client;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$vehicleId/operator_photo/photo_$timestamp.jpg';
    await supabase.storage
        .from('vehicle_sensitive_media')
        .uploadBinary(path, finalBytes);
    return supabase.storage.from('vehicle_sensitive_media').getPublicUrl(path);
  } catch (e) {
    debugPrint('❌ Operator photo upload failed: $e');
    return null;
  }
}

Color _bookingStatusColor(BookingStatus s) {
  switch (s) {
    case BookingStatus.pending:
      return Colors.orange;
    case BookingStatus.accepted:
    case BookingStatus.confirmed:
      return Colors.blue;
    case BookingStatus.inProgress:
      return Colors.teal;
    case BookingStatus.completed:
      return Colors.green;
    case BookingStatus.rejected:
    case BookingStatus.noShow:
      return Colors.red;
    case BookingStatus.disputed:
      return Colors.deepOrange;
    case BookingStatus.expired:
      return Colors.grey;
    case BookingStatus.refunded:
    case BookingStatus.cancelled:
    case BookingStatus.cancelledByCustomer:
    case BookingStatus.cancelledByProvider:
      return Colors.purple;
  }
}

class VehicleActionsScreen extends StatefulWidget {
  final String vehicleId;
  final bool isUserMode;
  final VehicleRepository? vehicleRepository;

  const VehicleActionsScreen({
    super.key,
    required this.vehicleId,
    this.isUserMode = false,
    this.vehicleRepository,
  });

  @override
  State<VehicleActionsScreen> createState() => _VehicleActionsScreenState();
}

class _VehicleActionsScreenState extends State<VehicleActionsScreen> {
  VehicleGpsMode _gpsMode = VehicleGpsMode.deviceLive;
  final _gpsLinkController = TextEditingController();
  final _manualLatController = TextEditingController();
  final _manualLngController = TextEditingController();
  String? _lastSyncedVehicleId; // Track which vehicle we last synced

  bool _isVehicleComplianceDoc(DocumentType documentType) {
    return documentType == DocumentType.rc ||
        documentType == DocumentType.insurance;
  }

  dynamic get _vehicleRepo => widget.isUserMode
      ? CustomerVehicleRepository.instance
      : widget.vehicleRepository!;

  @override
  void dispose() {
    _gpsLinkController.dispose();
    _manualLatController.dispose();
    _manualLngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.isUserMode
          ? CustomerVehicleRepository.instance.vehiclesListenable
          : widget.vehicleRepository!.vehiclesListenable,
      builder: (context, _, child) {
        final vehicle = _vehicleRepo.getById(widget.vehicleId);
        if (vehicle == null) {
          return const Scaffold(
            body: SafeArea(child: Center(child: Text('Vehicle not found'))),
          );
        }

        // Only sync GPS fields when vehicle changes, not on every build
        if (_lastSyncedVehicleId != vehicle.id) {
          _syncGpsFields(vehicle);
          _lastSyncedVehicleId = vehicle.id;
        }
        final yearText = vehicle.year != null ? ' ${vehicle.year}' : '';

        return Scaffold(
          appBar: AppBar(
            title: Text('${vehicle.name}$yearText'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit vehicle',
                onPressed: () => _openEditSheet(context, vehicle),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              _openAddSheet(context, vehicle);
            },
            child: const Icon(Icons.add),
          ),
          body: FutureBuilder<List<SlotEntry>>(
            future: widget.isUserMode
                ? CustomerSlotRepository.instance.getAllSlotsForVehicle(
                    vehicle.id,
                  )
                : SlotRepository.instance.getAllSlotsForVehicle(vehicle.id),
            builder: (context, snapshot) {
              // Show loading while fetching
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Get entries from snapshot, fallback to empty list
              final entries = snapshot.data ?? [];

              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  _buildVehicleStatsCard(vehicle, entries.length),
                  const SizedBox(height: 4),
                  _buildVehicleCountryRow(vehicle),
                  const SizedBox(height: 12),
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No services added yet',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...entries.map((e) => _buildSlotCard(context, e)),
                  const SizedBox(height: 12),
                  _buildGpsSettingsCard(vehicle),
                  const SizedBox(height: 12),
                  if (!widget.isUserMode) ...[
                    const SizedBox(height: 12),
                    _buildDocumentVerificationCard(vehicle),
                    const SizedBox(height: 12),
                    _buildOperatorSection(vehicle),
                  ],
                  const SizedBox(height: 12),
                  _buildHistorySection(entries),
                  const SizedBox(height: 12),
                  _buildVehicleBookingHistory(context, vehicle),
                  const SizedBox(height: 12),
                  _buildReviewsSection(context, vehicle),
                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _syncGpsFields(Vehicle vehicle) {
    if (_gpsMode != vehicle.gpsMode) {
      _gpsMode = vehicle.gpsMode;
    }
    final linkText = vehicle.gpsExternalLink ?? '';
    if (_gpsLinkController.text != linkText) {
      _gpsLinkController.text = linkText;
    }
    final latText = vehicle.manualLat?.toString() ?? '';
    if (_manualLatController.text != latText) {
      _manualLatController.text = latText;
    }
    final lngText = vehicle.manualLng?.toString() ?? '';
    if (_manualLngController.text != lngText) {
      _manualLngController.text = lngText;
    }
  }

  Widget _buildSlotCard(BuildContext context, SlotEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<ProfileInfo>(
          valueListenable: ProfileRepository.instance.profile,
          builder: (context, currentProfile, _) {
            final userAvatar = currentProfile.avatarUrl ?? '';

            return SlotCard(
              slot: entry.slot,
              vehicle: entry.vehicle,
              providerName: 'You',
              providerAvatar: userAvatar,
              providerRating: 5.0,
              isOffer: true,
              isUserPost: widget.isUserMode,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SlotDetailScreen(
                      slot: entry.slot,
                      vehicle: entry.vehicle,
                      providerName: 'You',
                      providerAvatar: userAvatar,
                      providerRating: 5.0,
                      isOffer: true,
                    ),
                  ),
                );
              },
              onAction: () {},
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete post?'),
                    content: const Text(
                      'This will permanently remove this post.\n\nNote: posts with active bookings cannot be deleted.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm != true || !context.mounted) return;
                try {
                  if (widget.isUserMode) {
                    await CustomerSlotRepository.instance.deleteSlot(
                      entry.slot.id,
                    );
                  } else {
                    await SlotRepository.instance.deleteSlot(entry.slot.id);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Post deleted'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } on ActiveBookingsException catch (e) {
                  if (!context.mounted) return;
                  _showActiveBookingsDialog(context, e.activeCount, entry);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to delete: ${e.toString().split('\n').first}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(
                Icons.delete_outline,
                size: 16,
                color: Colors.red,
              ),
              label: const Text(
                'Delete post',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showActiveBookingsDialog(
    BuildContext context,
    int activeCount,
    SlotEntry entry,
  ) {
    // Find the latest deadline_time across active bookings for this slot
    final activeBookings = BookingRepository.instance.bookings.value
        .where((b) => b.slotId == entry.slot.id && b.status.isActive)
        .toList();

    DateTime? latestDeadline;
    for (final b in activeBookings) {
      if (b.deadlineTime != null) {
        if (latestDeadline == null || b.deadlineTime!.isAfter(latestDeadline)) {
          latestDeadline = b.deadlineTime;
        }
      }
    }

    final String unlockHint;
    if (latestDeadline != null && latestDeadline.isAfter(DateTime.now())) {
      final h = latestDeadline.hour.toString().padLeft(2, '0');
      final m = latestDeadline.minute.toString().padLeft(2, '0');
      final d = '${latestDeadline.day}/${latestDeadline.month}';
      unlockHint =
          'Delete will be available after $d $h:$m (booking deadline).';
    } else if (latestDeadline != null) {
      unlockHint = 'Deadline has passed — try deleting again.';
    } else {
      unlockHint = 'Wait for all bookings to complete or cancel them.';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Cannot Delete Post'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$activeCount active booking${activeCount == 1 ? '' : 's'} still within deadline.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      unlockHint,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Or do this now:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Mark post inactive — stops new bookings',
                    style: TextStyle(fontSize: 13),
                  ),
                  Text(
                    '• Cancel/refund active bookings first',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final updated = entry.slot.copyWith(isAvailable: false);
              if (widget.isUserMode) {
                CustomerSlotRepository.instance.updateSlot(updated);
              } else {
                SlotRepository.instance.updateSlot(updated);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Post marked inactive — no new bookings allowed',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark Inactive Instead'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditSheet(BuildContext context, Vehicle vehicle) async {
    final nameCtrl = TextEditingController(text: vehicle.name);
    final typeCtrl = TextEditingController(text: vehicle.type);
    final yearCtrl = TextEditingController(
      text: vehicle.year?.toString() ?? '',
    );

    final vehicleTypes = [
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
    String? selectedType = vehicleTypes.contains(vehicle.type)
        ? vehicle.type
        : 'Other';
    if (selectedType == 'Other') typeCtrl.text = vehicle.type;

    // Media state
    String? profileImage = vehicle.profileImage;
    List<String> galleryImages = [...vehicle.galleryImages];
    String? videoUrl = vehicle.videoUrl;

    // Operator state
    final operatorNameCtrl = TextEditingController(
      text: vehicle.operatorName ?? '',
    );
    final operatorPhoneCtrl = TextEditingController(
      text: vehicle.operatorPhone ?? '',
    );
    final operatorLicenseCtrl = TextEditingController(
      text: vehicle.operatorLicense ?? '',
    );
    String? operatorPhoto = vehicle.operatorPhoto;
    String? operatorGender =
        vehicle.operatorGender; // 'male', 'female', or null
    DateTime? operatorDob = vehicle.operatorDob;
    String? operatorDocument =
        vehicle.operatorDocumentUrl; // Single document (image or PDF)

    final picker = ImagePicker();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> pickProfileImage() async {
              final file = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 1024,
                maxHeight: 1024,
                imageQuality: 85,
              );
              if (file == null) return;
              final bytes = await file.readAsBytes();
              if (ctx.mounted) {
                setModalState(() => profileImage = base64Encode(bytes));
              }
            }

            Future<void> pickGalleryImages() async {
              final files = await picker.pickMultiImage(
                maxWidth: 1024,
                maxHeight: 1024,
                imageQuality: 80,
              );
              if (files.isEmpty) return;
              final encoded = <String>[];
              for (final f in files) {
                encoded.add(base64Encode(await f.readAsBytes()));
              }
              if (ctx.mounted) {
                setModalState(() => galleryImages.addAll(encoded));
              }
            }

            Future<void> pickVideo() async {
              final file = await picker.pickVideo(
                source: ImageSource.gallery,
                maxDuration: const Duration(seconds: 60),
              );
              if (file == null) return;
              final bytes = await file.readAsBytes();
              if (ctx.mounted) {
                setModalState(() => videoUrl = base64Encode(bytes));
              }
            }

            Future<void> pickOperatorPhoto() async {
              final file = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 512,
                maxHeight: 512,
                imageQuality: 85,
              );
              if (file == null) return;
              final bytes = await file.readAsBytes();
              if (ctx.mounted) {
                setModalState(() => operatorPhoto = base64Encode(bytes));
              }
            }

            Future<void> pickOperatorDocument() async {
              // Allow picking any file (image or PDF)
              final file = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 2048,
                maxHeight: 2048,
                imageQuality: 90,
              );
              if (file == null) return;
              final bytes = await file.readAsBytes();
              if (ctx.mounted) {
                setModalState(() => operatorDocument = base64Encode(bytes));
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Edit Vehicle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Type',
                        border: OutlineInputBorder(),
                      ),
                      items: vehicleTypes
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) => setModalState(() => selectedType = v),
                    ),
                    if (selectedType == 'Other') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: typeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Custom type',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: yearCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Year (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // --- Media Section ---
                    const Text(
                      'Media',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    // Profile image
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: profileImage != null
                              ? (profileImage!.startsWith('http')
                                    ? Image.network(
                                        profileImage!,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          width: 72,
                                          height: 72,
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      )
                                    : Image.memory(
                                        base64Decode(
                                          profileImage!.contains(',')
                                              ? profileImage!.split(',').last
                                              : profileImage!,
                                        ),
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          width: 72,
                                          height: 72,
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ))
                              : Container(
                                  width: 72,
                                  height: 72,
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.directions_car,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Profile Image',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              OutlinedButton.icon(
                                onPressed: pickProfileImage,
                                icon: const Icon(Icons.photo_camera, size: 16),
                                label: Text(
                                  profileImage != null ? 'Change' : 'Add',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (profileImage != null)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () =>
                                setModalState(() => profileImage = null),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Gallery images
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Gallery (${galleryImages.length})',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        OutlinedButton.icon(
                          onPressed: pickGalleryImages,
                          icon: const Icon(Icons.add_photo_alternate, size: 16),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    if (galleryImages.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: galleryImages.length,
                          separatorBuilder: (_, i) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final img = galleryImages[i];
                            final isUrl = img.startsWith('http');
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: isUrl
                                      ? Image.network(
                                          img,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      : Image.memory(
                                          base64Decode(
                                            img.contains(',')
                                                ? img.split(',').last
                                                : img,
                                          ),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () => setModalState(
                                      () => galleryImages.removeAt(i),
                                    ),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Video
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Video',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              OutlinedButton.icon(
                                onPressed: pickVideo,
                                icon: const Icon(Icons.videocam, size: 16),
                                label: Text(
                                  videoUrl != null
                                      ? 'Change video'
                                      : 'Add video',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (videoUrl != null) ...[
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () =>
                                setModalState(() => videoUrl = null),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    // --- Operator Section ---
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 20,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Vehicle Operator',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Assign a person who operates/handles this vehicle.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    // Operator Photo
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (operatorPhoto != null) {
                              _showFullImageDialog(
                                context,
                                operatorPhoto!,
                                'Operator Photo',
                              );
                            }
                          },
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                child: operatorPhoto != null
                                    ? Image.memory(
                                        base64Decode(operatorPhoto!),
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Colors.grey,
                                        ),
                                      ),
                              ),
                              if (operatorPhoto != null)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.zoom_in,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Profile Photo',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              OutlinedButton.icon(
                                onPressed: pickOperatorPhoto,
                                icon: const Icon(Icons.photo_camera, size: 16),
                                label: Text(
                                  operatorPhoto != null
                                      ? 'Change'
                                      : 'Add Photo',
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (operatorPhoto != null)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () =>
                                setModalState(() => operatorPhoto = null),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: operatorNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Operator name',
                        hintText: 'e.g. John Driver',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: operatorPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Operator phone',
                        hintText: 'e.g. +1234567890',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: operatorGender,
                      decoration: const InputDecoration(
                        labelText: 'Operator gender',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('Not specified'),
                        ),
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'female',
                          child: Text('Female'),
                        ),
                      ],
                      onChanged: (v) => setModalState(() => operatorGender = v),
                    ),
                    const SizedBox(height: 12),

                    // Date of Birth Picker
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: operatorDob ?? DateTime(1990, 1, 1),
                          firstDate: DateTime(1940),
                          lastDate: DateTime.now(),
                          helpText: 'Select Date of Birth',
                        );
                        if (picked != null) {
                          setModalState(() => operatorDob = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of Birth',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        child: Text(
                          operatorDob != null
                              ? '${operatorDob!.day.toString().padLeft(2, '0')}/${operatorDob!.month.toString().padLeft(2, '0')}/${operatorDob!.year}'
                              : 'Not set',
                          style: TextStyle(
                            color: operatorDob != null
                                ? Colors.black87
                                : Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: operatorLicenseCtrl,
                      decoration: const InputDecoration(
                        labelText: 'License number (optional)',
                        hintText: 'For your records',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.credit_card_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Operator Document Upload
                    const Text(
                      'Operator Document (Optional)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Upload ID, driving license, or any verification document (Image or PDF)',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[50],
                      ),
                      child: Column(
                        children: [
                          if (operatorDocument != null)
                            GestureDetector(
                              onTap: () => _showFullImageDialog(
                                context,
                                operatorDocument!,
                                'Operator Document',
                              ),
                              child: Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(
                                        base64Decode(operatorDocument!),
                                        fit: BoxFit.cover,
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.zoom_in,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.upload_file,
                                    size: 40,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No document uploaded',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: pickOperatorDocument,
                                  icon: const Icon(Icons.upload_file, size: 18),
                                  label: Text(
                                    operatorDocument != null
                                        ? 'Change Document'
                                        : 'Upload Document',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              if (operatorDocument != null) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => setModalState(
                                    () => operatorDocument = null,
                                  ),
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Remove document',
                                ),
                              ],
                            ],
                          ),
                          if (operatorDocument != null)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Colors.green[700],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Document uploaded ✓',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          try {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Enter vehicle name'),
                                ),
                              );
                              return;
                            }
                            final type = selectedType == 'Other'
                                ? typeCtrl.text.trim()
                                : (selectedType ?? vehicle.type);
                            final year = int.tryParse(yearCtrl.text.trim());

                            // Handle operator photo upload if it's base64
                            String? finalOperatorPhoto = operatorPhoto;
                            if (operatorPhoto != null &&
                                operatorPhoto!.isNotEmpty &&
                                !operatorPhoto!.startsWith('http')) {
                              // It's base64, upload to storage
                              try {
                                final photoBytes = base64Decode(operatorPhoto!);
                                finalOperatorPhoto = await _uploadOperatorPhoto(
                                  vehicleId: vehicle.id,
                                  bytes: photoBytes,
                                );
                                if (finalOperatorPhoto == null) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Failed to upload operator photo',
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                  return;
                                }
                              } catch (e) {
                                debugPrint(
                                  '❌ Error uploading operator photo: $e',
                                );
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Photo upload error: ${e.toString()}',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                                return;
                              }
                            }

                            final updated = vehicle.copyWith(
                              name: name,
                              type: type,
                              year: year,
                              profileImage: profileImage,
                              galleryImages: galleryImages,
                              videoUrl: videoUrl,
                              operatorName: operatorNameCtrl.text.trim().isEmpty
                                  ? null
                                  : operatorNameCtrl.text.trim(),
                              operatorPhone:
                                  operatorPhoneCtrl.text.trim().isEmpty
                                  ? null
                                  : operatorPhoneCtrl.text.trim(),
                              operatorGender: operatorGender,
                              operatorDob: operatorDob,
                              operatorLicense:
                                  operatorLicenseCtrl.text.trim().isEmpty
                                  ? null
                                  : operatorLicenseCtrl.text.trim(),
                              operatorPhoto: finalOperatorPhoto,
                              operatorDocumentUrl: operatorDocument,
                            );
                            if (widget.isUserMode) {
                              await CustomerVehicleRepository.instance
                                  .updateVehicle(updated);
                            } else {
                              await widget.vehicleRepository!.updateVehicle(
                                updated,
                              );
                            }
                            if (!context.mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vehicle updated')),
                            );
                          } catch (e) {
                            debugPrint('❌ Error updating vehicle: $e');
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString()}'),
                                backgroundColor: Colors.red[700],
                              ),
                            );
                          }
                        },
                        child: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    typeCtrl.dispose();
    yearCtrl.dispose();
    operatorNameCtrl.dispose();
    operatorPhoneCtrl.dispose();
    operatorLicenseCtrl.dispose();
  }

  Future<void> _openAddSheet(BuildContext context, Vehicle vehicle) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.people),
                        title: const Text('Passenger'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreatePostScreen(
                                serviceType: ServiceType.passenger,
                                initialVehicle: vehicle,
                                isUserMode: widget.isUserMode,
                              ),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.local_shipping),
                        title: const Text('Parcel'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreatePostScreen(
                                serviceType: ServiceType.parcel,
                                initialVehicle: vehicle,
                                isUserMode: widget.isUserMode,
                              ),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.handshake),
                        title: const Text('Help Vehicle'),
                        subtitle: const Text('With or without operator'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreatePostScreen(
                                serviceType: ServiceType.lease,
                                initialVehicle: vehicle,
                                isUserMode: widget.isUserMode,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOperatorSection(Vehicle vehicle) {
    final hasOperator =
        vehicle.operatorName != null && vehicle.operatorName!.isNotEmpty;
    if (!hasOperator) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_outline, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Vehicle Operator',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Operator photo - tappable to view full size
                GestureDetector(
                  onTap: () {
                    if (vehicle.operatorPhoto != null &&
                        vehicle.operatorPhoto!.isNotEmpty) {
                      _showFullImageDialog(
                        context,
                        vehicle.operatorPhoto!,
                        'Operator Photo',
                      );
                    }
                  },
                  child: Stack(
                    children: [
                      if (vehicle.operatorPhoto != null &&
                          vehicle.operatorPhoto!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: vehicle.operatorPhoto!.startsWith('http')
                              ? Image.network(
                                  vehicle.operatorPhoto!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _operatorAvatar(vehicle.operatorName),
                                )
                              : Image.memory(
                                  base64Decode(vehicle.operatorPhoto!),
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                ),
                        )
                      else
                        _operatorAvatar(vehicle.operatorName),
                      if (vehicle.operatorPhoto != null &&
                          vehicle.operatorPhoto!.isNotEmpty)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              Icons.zoom_in,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            vehicle.operatorName ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (vehicle.operatorGender != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: vehicle.operatorGender == 'male'
                                    ? Colors.blue.shade50
                                    : Colors.pink.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: vehicle.operatorGender == 'male'
                                      ? Colors.blue.shade200
                                      : Colors.pink.shade200,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    vehicle.operatorGender == 'male'
                                        ? Icons.male
                                        : Icons.female,
                                    size: 14,
                                    color: vehicle.operatorGender == 'male'
                                        ? Colors.blue.shade700
                                        : Colors.pink.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    vehicle.operatorGender == 'male'
                                        ? 'Male'
                                        : 'Female',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: vehicle.operatorGender == 'male'
                                          ? Colors.blue.shade700
                                          : Colors.pink.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (vehicle.operatorPhone != null &&
                          vehicle.operatorPhone!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              vehicle.operatorPhone!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (vehicle.operatorDob != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.cake,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Builder(
                              builder: (context) {
                                final age = _calculateAge(vehicle.operatorDob!);
                                return Text(
                                  'Age: $age years (${vehicle.operatorDob!.day.toString().padLeft(2, '0')}/${vehicle.operatorDob!.month.toString().padLeft(2, '0')}/${vehicle.operatorDob!.year})',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                      if (vehicle.operatorLicense != null &&
                          vehicle.operatorLicense!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.badge,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'License: ${vehicle.operatorLicense}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _operatorAvatar(String? name) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.blue.shade100,
      child: Text(
        name != null && name.isNotEmpty ? name[0].toUpperCase() : 'O',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade700,
        ),
      ),
    );
  }

  /// Calculate age from date of birth
  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;

    // Check if birthday hasn't occurred yet this year
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }

    return age;
  }

  void _showFullImageDialog(
    BuildContext context,
    String imageData,
    String title,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: imageData.startsWith('http')
                    ? Image.network(
                        imageData,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.error, color: Colors.white),
                      )
                    : Image.memory(base64Decode(imageData)),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentVerificationCard(Vehicle vehicle) {
    // Get verification status from vehicle model
    final Map<String, bool> verificationStatus = {
      'RC Book': vehicle.rcVerified,
      'Insurance': vehicle.insuranceVerified,
      // Personal ID docs removed for legal safety
    };

    return ValueListenableBuilder<SubscriptionPlan>(
      valueListenable: AppPreferences.instance.subscriptionPlan,
      builder: (context, plan, _) {
        final canVerify =
            plan == SubscriptionPlan.premium || plan == SubscriptionPlan.expert;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Document Verification',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Verify your documents to increase trust and get more bookings',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // All Documents Section - Build Trust Voluntarily
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Build Trust Voluntarily',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'All documents are optional. Upload to increase bookings.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Documents List
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'OPTIONAL DOCUMENTS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDocumentItem(
                  'RC Book',
                  'Registration Certificate - Proves ownership',
                  verificationStatus['RC Book']!,
                  DocumentType.rc,
                  imageBase64: vehicle.rcFrontUrl,
                  isMandatory: false,
                  canVerify: canVerify,
                ),
                const Divider(height: 1),
                _buildDocumentItemWithExpiry(
                  'Insurance',
                  'Vehicle Insurance - Shows professionalism',
                  verificationStatus['Insurance']!,
                  DocumentType.insurance,
                  imageBase64: vehicle.insuranceDocumentUrl,
                  expiryDate: vehicle.insuranceExpiry,
                  isMandatory: false,
                  canVerify: canVerify,
                ),

                const SizedBox(height: 16),

                // Additional Documents
                Row(
                  children: [
                    const Icon(
                      Icons.star_outline,
                      size: 16,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ADDITIONAL (Increases Trust)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Personal ID documents removed for legal safety
                // (DL, Aadhaar, PAN no longer collected)
                if (!canVerify) ...[
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.lock_outline,
                      color: Colors.orange,
                    ),
                    title: const Text('Document upload locked'),
                    subtitle: const Text(
                      'Upgrade to Premium or Expert plan to add documents',
                    ),
                    trailing: TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/plans'),
                      child: const Text('Upgrade'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocumentItem(
    String title,
    String subtitle,
    bool isVerified,
    DocumentType documentType, {
    String? imageBase64,
    bool isMandatory = false,
    bool canVerify = true,
  }) {
    Uint8List? imageBytes;
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        imageBytes = base64Decode(imageBase64);
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: Icon(
            isVerified
                ? Icons.verified
                : (isMandatory ? Icons.error : Icons.pending_outlined),
            color: isVerified
                ? Colors.green
                : (isMandatory ? Colors.red : Colors.orange),
            size: 28,
          ),
          title: Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (isMandatory && !isVerified) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'REQUIRED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            isVerified ? 'Verified ✓' : subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isVerified ? Colors.green : Colors.grey,
            ),
          ),
          trailing: isVerified
              ? null
              : canVerify
              ? OutlinedButton(
                  onPressed: () => _startDocumentVerification(documentType),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    foregroundColor: isMandatory ? Colors.red : null,
                    side: isMandatory
                        ? const BorderSide(color: Colors.red, width: 2)
                        : null,
                  ),
                  child: Text(imageBytes != null ? 'Update' : 'Add'),
                )
              : const Icon(Icons.lock_outline, color: Colors.orange),
        ),
        if (imageBytes != null)
          _buildDocumentThumbnail(title, imageBytes, isVerified),
      ],
    );
  }

  Widget _buildDocumentItemWithExpiry(
    String title,
    String subtitle,
    bool isVerified,
    DocumentType documentType, {
    String? imageBase64,
    DateTime? expiryDate,
    bool isMandatory = false,
    bool canVerify = true,
  }) {
    Uint8List? imageBytes;
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        imageBytes = base64Decode(imageBase64);
      } catch (_) {}
    }
    final isExpired = expiryDate != null && expiryDate.isBefore(DateTime.now());
    final isBlockedForUserMode =
        widget.isUserMode && _isVehicleComplianceDoc(documentType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: Icon(
            isVerified && !isExpired
                ? Icons.verified
                : (isMandatory || isExpired
                      ? Icons.error
                      : Icons.pending_outlined),
            color: isVerified && !isExpired
                ? Colors.green
                : (isMandatory || isExpired ? Colors.red : Colors.orange),
            size: 28,
          ),
          title: Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (isMandatory && (!isVerified || isExpired)) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'REQUIRED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isVerified && !isExpired ? 'Verified ✓' : subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isVerified && !isExpired ? Colors.green : Colors.grey,
                ),
              ),
              if (expiryDate != null) ...[
                const SizedBox(height: 2),
                Text(
                  isExpired
                      ? 'Expired on ${_fmtDate(expiryDate)}'
                      : expiryDate.isBefore(
                          DateTime.now().add(const Duration(days: 30)),
                        )
                      ? 'Expires soon: ${_fmtDate(expiryDate)}'
                      : 'Valid until ${_fmtDate(expiryDate)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isExpired
                        ? Colors.red
                        : expiryDate.isBefore(
                            DateTime.now().add(const Duration(days: 30)),
                          )
                        ? Colors.orange
                        : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          trailing: isVerified && !isExpired
              ? null
              : !canVerify
              ? const Icon(Icons.lock_outline, color: Colors.orange)
              : OutlinedButton(
                  onPressed: isBlockedForUserMode
                      ? null
                      : () => _startDocumentVerification(documentType),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    foregroundColor: isMandatory || isExpired
                        ? Colors.red
                        : null,
                    side: isMandatory || isExpired
                        ? const BorderSide(color: Colors.red, width: 2)
                        : null,
                  ),
                  child: Text(
                    isBlockedForUserMode
                        ? 'Not allowed'
                        : (imageBytes != null && !isVerified
                              ? 'Verify'
                              : (isExpired ? 'Renew' : 'Upload')),
                  ),
                ),
        ),
        if (imageBytes != null)
          _buildDocumentThumbnail(title, imageBytes, isVerified && !isExpired),
      ],
    );
  }

  Widget _buildDocumentThumbnail(
    String title,
    Uint8List bytes,
    bool isVerified,
  ) {
    return GestureDetector(
      onTap: () => _previewDocumentImage(title, bytes),
      child: Container(
        margin: const EdgeInsets.only(left: 48, right: 16, bottom: 8),
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isVerified ? Colors.green : Colors.blue.shade200,
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Image.memory(bytes, fit: BoxFit.cover, height: 48),
              ),
              const SizedBox(width: 8),
              Icon(
                isVerified ? Icons.verified : Icons.zoom_in,
                size: 14,
                color: isVerified ? Colors.green : Colors.blue,
              ),
              const SizedBox(width: 4),
              Text(
                isVerified ? 'Verified — tap to preview' : 'Tap to preview',
                style: TextStyle(
                  fontSize: 11,
                  color: isVerified ? Colors.green : Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _previewDocumentImage(String title, Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Routes KYC payment to Razorpay (INR) or Stripe (other currencies).
  /// Returns true if payment succeeded, false otherwise.
  Future<bool> _processKycPayment() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('display_name') ?? 'User';
    final userEmail = prefs.getString('user_email') ?? '';
    final userPhone = prefs.getString('user_phone') ?? '';
    final currency = AppPreferences.instance.currencyCode.value;

    final payResult = await PaymentService.instance.processKycPayment(
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      currency: currency,
    );

    if (!mounted) return false;

    if (payResult.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ${payResult['error']}')),
      );
      return false;
    }
    return true;
  }

  Future<void> _startDocumentVerification(DocumentType documentType) async {
    if (widget.isUserMode && _isVehicleComplianceDoc(documentType)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'RC/Insurance verification is only available for the vehicle owner/provider.',
          ),
        ),
      );
      return;
    }

    final vehicle = _vehicleRepo.getById(widget.vehicleId);
    if (vehicle == null) return;

    // Step 1: Ask user to upload document photo first
    final uploadChoice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upload ${_getDocumentName(documentType)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.upload_file, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'First, upload a clear photo of your ${_getDocumentName(documentType)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Make sure all text is visible and readable',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'upload'),
            icon: const Icon(Icons.photo_library),
            label: const Text('Choose Photo'),
          ),
        ],
      ),
    );

    if (uploadChoice != 'upload' || !mounted) return;

    // Pick document image from gallery
    final picker = ImagePicker();
    final documentFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );

    if (documentFile == null || !mounted) return;

    final documentBytes = await documentFile.readAsBytes();

    if (!mounted) return;

    // Show preview of uploaded document
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_getDocumentName(documentType)} Preview'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                documentBytes,
                width: 300,
                height: 400,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Is the document clear and all text readable?',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Choose Another'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // If insurance, ask for expiry date
    DateTime? expiryDate;
    if (documentType == DocumentType.insurance) {
      expiryDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 365)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        helpText: 'Select insurance expiry date',
      );
      if (expiryDate == null || !mounted) return;
    }

    // Step 2: Ask whether to verify or just save
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('What would you like to do?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.save_alt, color: Colors.blue),
              title: const Text('Save only'),
              subtitle: const Text('Upload document to profile'),
              onTap: () => Navigator.pop(context, 'save'),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.face, color: Colors.green),
              title: const Text('Save & Face Match'),
              subtitle: const Text(
                'Upload with face matching (adds trust badge)',
              ),
              onTap: () => Navigator.pop(context, 'verify'),
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

    if (action == null || !mounted) return;

    if (action == 'save') {
      // Upload document to vehicle_sensitive_media bucket
      final ext = 'jpg';
      String? docUrl;
      switch (documentType) {
        case DocumentType.rc:
          docUrl = await _uploadVehicleSensitiveDoc(
            vehicleId: vehicle.id,
            docType: 'rc',
            bytes: documentBytes,
            extension: ext,
          );
          if (docUrl != null) {
            final updatedVehicle = vehicle.copyWith(rcFrontUrl: docUrl);
            widget.isUserMode
                ? CustomerVehicleRepository.instance.updateVehicle(
                    updatedVehicle,
                  )
                : await widget.vehicleRepository!.updateVehicle(updatedVehicle);
          }
          break;
        case DocumentType.insurance:
          docUrl = await _uploadVehicleSensitiveDoc(
            vehicleId: vehicle.id,
            docType: 'insurance',
            bytes: documentBytes,
            extension: ext,
          );
          if (docUrl != null) {
            final updatedVehicle = vehicle.copyWith(
              insuranceDocumentUrl: docUrl,
              insuranceExpiryDate: expiryDate,
            );
            widget.isUserMode
                ? CustomerVehicleRepository.instance.updateVehicle(
                    updatedVehicle,
                  )
                : await widget.vehicleRepository!.updateVehicle(updatedVehicle);
          }
          break;
        case DocumentType.dl:
          docUrl = await _uploadVehicleSensitiveDoc(
            vehicleId: vehicle.id,
            docType: 'dl',
            bytes: documentBytes,
            extension: ext,
          );
          break;
        case DocumentType.aadhaar:
          docUrl = await _uploadVehicleSensitiveDoc(
            vehicleId: vehicle.id,
            docType: 'aadhaar',
            bytes: documentBytes,
            extension: ext,
          );
          break;
        case DocumentType.pan:
          docUrl = await _uploadVehicleSensitiveDoc(
            vehicleId: vehicle.id,
            docType: 'pan',
            bytes: documentBytes,
            extension: ext,
          );
          break;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            docUrl != null
                ? '${_getDocumentName(documentType)} saved (unverified)'
                : '${_getDocumentName(documentType)} upload failed',
          ),
        ),
      );
      return;
    }

    // action == 'verify' — charge trust fee before opening camera
    if (!mounted) return;
    final payConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Face Matching Fee'),
        content: const Text(
          'A one-time fee of ₹49 enables face matching for your profile.\n\n'
          'This helps build trust in the community.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.payment),
            label: const Text('Pay ₹49 & Continue'),
          ),
        ],
      ),
    );

    if (payConfirmed != true || !mounted) return;

    // Route payment via Razorpay (INR) or Stripe (international)
    final paid = await _processKycPayment();
    if (!paid || !mounted) return;

    // Payment succeeded — open live camera
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentVerificationScreen(
          documentType: documentType,
          referenceDocumentBytes: documentBytes,
        ),
      ),
    );

    if (result == null || !mounted) return;

    final faceVerified = result['faceVerified'] as bool;
    final docType = result['documentType'] as String;

    if (faceVerified) {
      final faceMatched = result['faceMatched'] as bool? ?? false;
      final matchScore = result['matchScore'] as double? ?? 0.0;
      final base64Doc = base64Encode(documentBytes);
      final now = DateTime.now();
      Vehicle updatedVehicle;
      switch (documentType) {
        case DocumentType.rc:
          updatedVehicle = vehicle.copyWith(
            rcVerified: true,
            rcVerifiedAt: now,
            rcImageBase64: base64Doc,
          );
          break;
        case DocumentType.insurance:
          updatedVehicle = vehicle.copyWith(
            insuranceVerified: true,
            insuranceVerifiedAt: now,
            insuranceExpiryDate: expiryDate,
            insuranceImageBase64: base64Doc,
          );
          break;
        // Personal ID document cases removed for legal safety
        case DocumentType.dl:
        case DocumentType.aadhaar:
        case DocumentType.pan:
          throw UnsupportedError('Personal ID documents no longer supported');
      }
      // Auto-grant verified badge if all documents are now verified
      final withBadge = updatedVehicle.isFullyVerified
          ? updatedVehicle.copyWith(isVerifiedToggle: true)
          : updatedVehicle;
      if (widget.isUserMode) {
        CustomerVehicleRepository.instance.updateVehicle(withBadge);
      } else {
        await widget.vehicleRepository!.updateVehicle(withBadge);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedVehicle.isFullyVerified
                ? '$docType verified! All documents complete — Verified badge granted ✓'
                : faceMatched
                ? '$docType verified! ${matchScore.toStringAsFixed(1)}% match ✓'
                : '$docType verified with liveness ✓',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildHistorySection(List<SlotEntry> entries) {
    // Slot history removed - users only need booking history
    // Bookings are shown in the Requests page
    return const SizedBox.shrink();
  }

  Widget _buildVehicleBookingHistory(BuildContext context, Vehicle vehicle) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Booking History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Recent bookings for this vehicle',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<List<Booking>>(
              valueListenable: BookingRepository.instance.bookings,
              builder: (context, allBookings, _) {
                // Get all slots for this vehicle
                final vehicleSlotIds =
                    (widget.isUserMode
                            ? CustomerSlotRepository.instance.allSlots
                            : SlotRepository.instance.allSlots)
                        .where((e) => e.slot.vehicleId == vehicle.id)
                        .map((e) => e.slot.id)
                        .toSet();

                // Filter bookings for this vehicle's slots
                final vehicleBookings =
                    allBookings
                        .where((b) => vehicleSlotIds.contains(b.slotId))
                        .toList()
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                if (vehicleBookings.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No bookings yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Show statistics
                final completed = vehicleBookings
                    .where((b) => b.status == BookingStatus.completed)
                    .length;
                final totalEarnings = vehicleBookings
                    .where((b) => b.status == BookingStatus.completed)
                    .fold<double>(0, (sum, b) => sum + b.price);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistics row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatBox(
                            'Total',
                            vehicleBookings.length.toString(),
                            Icons.local_taxi,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatBox(
                            'Done',
                            completed.toString(),
                            Icons.check_circle,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatBox(
                            'Earned',
                            '₹${totalEarnings.toStringAsFixed(0)}',
                            Icons.currency_rupee,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Recent Bookings',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Show latest 3 bookings
                    ...vehicleBookings.take(3).map((booking) {
                      return _buildBookingTile(booking);
                    }),
                    if (vehicleBookings.length > 3) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/requests');
                          },
                          child: const Text('View All'),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBookingTile(Booking booking) {
    final statusColor = _bookingStatusColor(booking.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.person, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.userName ?? 'User',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _fmtDate(booking.createdAt),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            '₹${booking.price.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: statusColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsSettingsCard(Vehicle vehicle) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GPS Settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<VehicleGpsMode>(
              initialValue: _gpsMode,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: VehicleGpsMode.deviceLive,
                  child: Text('Device live'),
                ),
                DropdownMenuItem(
                  value: VehicleGpsMode.externalLink,
                  child: Text('External link'),
                ),
                DropdownMenuItem(
                  value: VehicleGpsMode.manual,
                  child: Text('Manual'),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _gpsMode = v);
              },
            ),
            const SizedBox(height: 12),
            if (_gpsMode == VehicleGpsMode.externalLink) ...[
              TextField(
                controller: _gpsLinkController,
                decoration: const InputDecoration(
                  labelText: 'Tracking link',
                  hintText: 'Paste tracker URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_gpsMode == VehicleGpsMode.manual) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualLatController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        hintText: 'e.g., 12.9716',
                        border: OutlineInputBorder(),
                        helperText: 'Range: -90 to 90',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _manualLngController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        hintText: 'e.g., 77.5946',
                        border: OutlineInputBorder(),
                        helperText: 'Range: -180 to 180',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Get Current Location'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '💡 Tip: Use "Get Current Location" for accurate GPS coordinates, or enter manually if you know the exact location.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _saveGpsSettings(vehicle),
                child: const Text('Save GPS Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 16),
              Text('Getting current location...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );

      // Request permission
      final permission = await Permission.location.request();
      if (permission != PermissionStatus.granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission denied'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (!mounted) return;

      // Update text fields
      setState(() {
        _manualLatController.text = position.latitude.toStringAsFixed(6);
        _manualLngController.text = position.longitude.toStringAsFixed(6);
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Location obtained!\nLat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _saveGpsSettings(Vehicle vehicle) {
    final gpsLink = _gpsMode == VehicleGpsMode.externalLink
        ? _gpsLinkController.text.trim()
        : null;

    if (_gpsMode == VehicleGpsMode.externalLink &&
        (gpsLink == null || gpsLink.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter tracking link')));
      return;
    }

    final double? manualLat = _gpsMode == VehicleGpsMode.manual
        ? double.tryParse(_manualLatController.text.trim())
        : null;
    final double? manualLng = _gpsMode == VehicleGpsMode.manual
        ? double.tryParse(_manualLngController.text.trim())
        : null;

    if (_gpsMode == VehicleGpsMode.manual &&
        (manualLat == null || manualLng == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid manual coordinates')),
      );
      return;
    }
    if (_gpsMode == VehicleGpsMode.manual &&
        (manualLat! < -90 || manualLat > 90)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid latitude')));
      return;
    }
    if (_gpsMode == VehicleGpsMode.manual &&
        (manualLng! < -180 || manualLng > 180)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid longitude')));
      return;
    }

    final updated = Vehicle(
      id: vehicle.id,
      userId: vehicle.userId,
      userName: vehicle.userName,
      name: vehicle.name,
      type: vehicle.type,
      year: vehicle.year,
      capabilities: vehicle.capabilities,
      profileImage: vehicle.profileImage,
      galleryImages: vehicle.galleryImages,
      videoUrl: vehicle.videoUrl,
      createdAt: vehicle.createdAt,
      gpsMode: _gpsMode,
      gpsExternalLink: gpsLink,
      manualLat: manualLat,
      manualLng: manualLng,
      lastKnownLat: _gpsMode == VehicleGpsMode.manual
          ? manualLat
          : vehicle.lastKnownLat,
      lastKnownLng: _gpsMode == VehicleGpsMode.manual
          ? manualLng
          : vehicle.lastKnownLng,
      averageRating: vehicle.averageRating,
      totalRatings: vehicle.totalRatings,
      totalBookings: vehicle.totalBookings,
      activePostsCount: vehicle.activePostsCount,
    );

    if (widget.isUserMode) {
      CustomerVehicleRepository.instance.updateVehicle(updated);
    } else {
      widget.vehicleRepository!.updateVehicle(updated);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('GPS settings saved')));
  }

  Widget _buildReviewsSection(BuildContext context, Vehicle vehicle) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Provider Reviews',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                TextButton.icon(
                  onPressed: () {
                    // Navigate to provider's reviews screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReviewsScreen(
                          userId: vehicle.userId,
                          userName: vehicle.userName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<List<Review>>(
              valueListenable: ReviewRepository.instance.reviews,
              builder: (context, reviews, _) {
                // Get reviews for this provider (vehicle owner)
                final providerReviews = reviews
                    .where((r) => r.revieweeId == vehicle.userId)
                    .toList();

                if (providerReviews.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No reviews yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Calculate average rating
                final avgRating =
                    providerReviews.fold<double>(
                      0,
                      (sum, r) => sum + r.rating,
                    ) /
                    providerReviews.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          avgRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${providerReviews.length} ${providerReviews.length == 1 ? 'review' : 'reviews'})',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Show latest 2 reviews
                    ...providerReviews.take(2).map((review) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ...List.generate(
                                    5,
                                    (index) => Icon(
                                      index < review.rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatReviewDate(review.createdAt),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              if (review.comment != null &&
                                  review.comment!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  review.comment!,
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                    if (providerReviews.length > 2)
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReviewsScreen(
                                  userId: vehicle.userId,
                                  userName: vehicle.userName,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            'View all ${providerReviews.length} reviews',
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            /* Vehicle reviews section - temporarily disabled
            ValueListenableBuilder<List<VehicleReview>>(
              valueListenable: ReviewRepository.instance.vehicleReviews,
              builder: (context, reviews, _) {
                final vehicleReviews = reviews
                    .where((r) => r.vehicleId == vehicle.id)
                    .toList(growable: false);

                if (vehicleReviews.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No reviews yet'),
                  );
                }

                final avg = vehicleReviews
                        .map((r) => r.rating)
                        .fold<double>(0, (a, b) => a + b) /
                    vehicleReviews.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Average rating: ${avg.toStringAsFixed(1)} (${vehicleReviews.length} reviews)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...vehicleReviews.map(
                      (r) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person),
                        title: Text(r.reviewerName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rating: ${r.rating.toStringAsFixed(1)}'),
                            if (r.comment != null) Text(r.comment!),
                            Text(
                              _fmtDate(r.createdAt),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            */
          ],
        ),
      ),
    );
  }

  /* Vehicle review sheet - temporarily disabled
  void _showAddReviewSheet(BuildContext context, Vehicle vehicle) {
    final nameController = TextEditingController(text: 'User');
    final commentController = TextEditingController();
    double rating = 4.0;

    showModalBottomSheet(
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
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Review',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Your name'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Rating'),
                      Expanded(
                        child: Slider(
                          value: rating,
                          min: 1,
                          max: 5,
                          divisions: 8,
                          label: rating.toStringAsFixed(1),
                          onChanged: (v) => setState(() => rating = v),
                        ),
                      ),
                      Text(rating.toStringAsFixed(1)),
                    ],
                  ),
                  TextField(
                    controller: commentController,
                    decoration:
                        const InputDecoration(labelText: 'Comment (optional)'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ReviewRepository.instance.addReview(
                          vehicleId: vehicle.id,
                          reviewerName: nameController.text.trim().isEmpty
                              ? 'User'
                              : nameController.text.trim(),
                          rating: double.parse(rating.toStringAsFixed(1)),
                          comment: commentController.text,
                        );
                        Navigator.pop(context);
                      },
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
  */

  String _fmtDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }

  String _getDocumentName(DocumentType documentType) {
    switch (documentType) {
      case DocumentType.rc:
        return 'RC Book';
      case DocumentType.insurance:
        return 'Insurance Certificate';
      case DocumentType.dl:
        return 'Driving License';
      case DocumentType.aadhaar:
        return 'National ID';
      case DocumentType.pan:
        return 'Tax ID';
    }
  }

  Widget _buildVehicleCountryRow(Vehicle vehicle) {
    // Resolve lat/lon to country via reverse geocode
    final double? lat;
    final double? lon;
    switch (vehicle.gpsMode) {
      case VehicleGpsMode.manual:
        lat = vehicle.manualLat;
        lon = vehicle.manualLng;
        break;
      case VehicleGpsMode.externalLink:
      case VehicleGpsMode.deviceLive:
        lat = vehicle.lastKnownLat;
        lon = vehicle.lastKnownLng;
        break;
    }

    if (lat == null || lon == null) return const SizedBox.shrink();

    return FutureBuilder<GeoLocation?>(
      future: LocationAutocompleteService.instance.reverseGeocode(lat, lon),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final geo = snapshot.data!;
        final district = geo.district ?? geo.stateDistrict;
        final postcode = geo.postcode;
        final country = geo.country;
        final countryCode = geo.countryCode?.toUpperCase();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          color: Colors.grey[50],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (district != null) _geoChip(Icons.map, district),
                      if (geo.state != null)
                        _geoChip(Icons.account_balance, geo.state!),
                      if (postcode != null)
                        _geoChip(Icons.markunread_mailbox, postcode),
                      if (country != null)
                        _geoChip(
                          Icons.public,
                          countryCode != null
                              ? '$country ($countryCode)'
                              : country,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _geoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey[600]),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildVehicleStatsCard(Vehicle vehicle, int activePostsCount) {
    // Get slot IDs that belong to this specific vehicle
    final vehicleSlotIds = {
      ...SlotRepository.instance
          .getSlotsByVehicleId(vehicle.id)
          .map((s) => s.id),
      ...CustomerSlotRepository.instance.allSlotsRaw
          .where((s) => s.vehicleId == vehicle.id)
          .map((s) => s.id),
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ValueListenableBuilder<List<Review>>(
              valueListenable: ReviewRepository.instance.reviews,
              builder: (context, allReviews, _) {
                final vehicleReviews = allReviews
                    .where((r) => r.revieweeId == vehicle.userId)
                    .toList();
                final avgRating = vehicleReviews.isEmpty
                    ? 0.0
                    : vehicleReviews.fold<double>(0, (s, r) => s + r.rating) /
                          vehicleReviews.length;
                return Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 20, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          avgRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${vehicleReviews.length} ratings',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                );
              },
            ),
            ValueListenableBuilder<List<Booking>>(
              valueListenable: BookingRepository.instance.bookings,
              builder: (context, allBookings, _) {
                // Only completed bookings for this vehicle's slots
                final totalTrips = allBookings
                    .where(
                      (b) =>
                          vehicleSlotIds.contains(b.slotId) &&
                          b.status == BookingStatus.completed,
                    )
                    .length;
                return Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history, size: 20, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          '$totalTrips',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'total trips',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                );
              },
            ),
            Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.post_add, size: 20, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      '$activePostsCount',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'active posts',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatReviewDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else {
      return '${(difference.inDays / 365).floor()}y ago';
    }
  }
}

/// Expandable tile showing a slot's summary and its booking history.
class _SlotHistoryTile extends StatefulWidget {
  final dynamic slot; // Slot
  final List<Booking> bookings;
  final String Function(DateTime) fmtDate;
  final String Function(Booking) statusLabel;

  const _SlotHistoryTile({
    required this.slot,
    required this.bookings,
    required this.fmtDate,
    required this.statusLabel,
  });

  @override
  State<_SlotHistoryTile> createState() => _SlotHistoryTileState();
}

class _SlotHistoryTileState extends State<_SlotHistoryTile> {
  bool _expanded = false;

  Color _colorFor(Booking b) => _bookingStatusColor(b.status);

  String _fmtTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${widget.fmtDate(d)} $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final bookings = widget.bookings;
    final completed = bookings
        .where((b) => b.status == BookingStatus.completed)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.event_note,
                    size: 18,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${slot.serviceType?.name ?? 'Slot'} · ${_fmtTime(slot.startTime)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${bookings.length} booking${bookings.length == 1 ? '' : 's'}'
                        '${bookings.isNotEmpty ? ' · $completed completed' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          if (bookings.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 46, bottom: 8),
              child: Text(
                'No bookings for this slot',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            )
          else
            ...bookings.map((b) {
              final color = _colorFor(b);
              return Padding(
                padding: const EdgeInsets.only(left: 46, bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.userName ?? 'Booking #${b.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _fmtTime(b.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          widget.statusLabel(b),
                          style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const Divider(height: 8),
        ],
      ],
    );
  }
}
