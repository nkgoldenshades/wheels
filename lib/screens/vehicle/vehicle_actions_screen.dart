import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/booking.dart';
import '../../models/review.dart';
import '../../models/service_type.dart';
import '../../models/slot_entry.dart';
import '../../models/vehicle.dart';
import '../../services/booking_repository.dart';
import '../../services/review_repository.dart';
import '../../services/slot_repository.dart';
import '../../services/vehicle_repository.dart';
import '../../services/user_vehicle_repository.dart';
import '../../services/user_slot_repository.dart';
import '../reviews_screen.dart';
import '../slot_detail_screen.dart';
import '../add_flow/create_post_screen.dart';
import '../verification/document_verification_screen.dart';
import '../../widgets/slot_card.dart';
import '../../services/location_autocomplete_service.dart';
import '../../services/app_preferences.dart';

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

  Widget _buildVehicleTagsCard(BuildContext context, Vehicle vehicle) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vehicle tags',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: vehicle.isVerifiedToggle,
              onChanged: (v) async {
                final updated = vehicle.copyWith(isVerifiedToggle: v);
                await _saveVehicle(context, updated);
              },
              title: const Text('Verified vehicle'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: vehicle.isExpertToggle,
              onChanged: (v) async {
                final updated = vehicle.copyWith(isExpertToggle: v);
                await _saveVehicle(context, updated);
              },
              title: const Text('Expert vehicle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveVehicle(BuildContext context, Vehicle updated) async {
    try {
      if (widget.isUserMode) {
        await UserVehicleRepository.instance.updateVehicle(updated);
      } else {
        await widget.vehicleRepository!.updateVehicle(updated);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle updated')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }

  dynamic get _vehicleRepo => widget.isUserMode 
      ? UserVehicleRepository.instance
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
          ? UserVehicleRepository.instance.vehiclesListenable
          : widget.vehicleRepository!.vehiclesListenable,
      builder: (context, _, child) {
        final vehicle = _vehicleRepo.getById(widget.vehicleId);
        if (vehicle == null) {
          return const Scaffold(
            body: SafeArea(
              child: Center(child: Text('Vehicle not found')),
            ),
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
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openAddSheet(context, vehicle),
            child: const Icon(Icons.add),
          ),
          body: ValueListenableBuilder(
            valueListenable: widget.isUserMode
                ? UserSlotRepository.instance.slotsListenable
                : SlotRepository.instance.slotsListenable,
            builder: (context, _, child) {
              final entries = widget.isUserMode
                  ? UserSlotRepository.instance.allSlots
                      .where((e) => e.slot.vehicleId == vehicle.id)
                      .toList()
                  : SlotRepository.instance.getSlotEntriesByVehicleId(vehicle.id);

              return ListView(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  _buildVehicleImagesSection(vehicle),
                  const SizedBox(height: 12),
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
                  else ...entries.map((e) => _buildSlotCard(context, e)),
                  const SizedBox(height: 12),
                  _buildGpsSettingsCard(vehicle),
                  const SizedBox(height: 12),
                  _buildVehicleTagsCard(context, vehicle),
                  if (!widget.isUserMode) ...[
                    const SizedBox(height: 12),
                    _buildDocumentVerificationCard(vehicle),
                  ],
                  const SizedBox(height: 12),
                  _buildHistorySection(entries),
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

  Widget _buildVehicleImagesSection(Vehicle vehicle) {
    final hasProfile = vehicle.profileImage != null;
    final galleryCount = vehicle.galleryImages.length;
    final totalCount = (hasProfile ? 1 : 0) + galleryCount;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Images ($totalCount)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (totalCount == 0)
              const Text('No images added yet')
            else
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: totalCount,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    // First item is profile image if it exists
                    final isProfile = hasProfile && index == 0;
                    final photo = isProfile 
                        ? vehicle.profileImage! 
                        : vehicle.galleryImages[hasProfile ? index - 1 : index];
                    
                    Uint8List? bytes;
                    try {
                      final normalized = photo.contains(',')
                          ? photo.split(',').last
                          : photo;
                      bytes = base64Decode(normalized);
                    } catch (_) {
                      bytes = null;
                    }
                    
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: bytes == null
                            ? Container(
                                color: Colors.black12,
                                child: const Center(
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              )
                            : Image.memory(
                                bytes,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.black12,
                                    child: const Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  );
                                },
                              ),
                          ),
                        ),
                        if (isProfile)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PROFILE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
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
        ),
      ),
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
    return SlotCard(
      slot: entry.slot,
      vehicle: entry.vehicle,
      providerName: 'You',
      providerAvatar: '',
      providerRating: 5.0,
      isOffer: true,
      isUserPost: widget.isUserMode, // User mode = looking for service, Provider mode = offering service
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.photo_library_outlined),
                        title: const Text('Vehicle images'),
                        subtitle: const Text('Add images to your vehicle'),
                        onTap: () async {
                          try{
                            final picker = ImagePicker();
                            final files = await picker.pickMultiImage(
                              maxWidth: 1024,
                              maxHeight: 1024,
                              imageQuality: 80,
                            );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            if (files.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No images selected')),
                              );
                              return;
                            }

                            debugPrint(
                              'VehicleImages: picked ${files.length} file(s) for vehicle ${vehicle.id}',
                            );

                            final encoded = <String>[];
                            for (final f in files) {
                              final bytes = await f.readAsBytes();
                      encoded.add(base64Encode(bytes));
                    }

                    // If no profile image exists and user picked images, ask if first should be profile
                    String? newProfileImage = vehicle.profileImage;
                    List<String> newGalleryImages = [...vehicle.galleryImages];
                    
                    if (vehicle.profileImage == null && encoded.isNotEmpty) {
                      if (!context.mounted) return;
                      final setAsProfile = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Set Profile Image'),
                          content: const Text(
                            'Would you like to set the first image as the vehicle profile image?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('No, add to gallery'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Yes, set as profile'),
                            ),
                          ],
                        ),
                      );
                      
                      if (setAsProfile == true) {
                        newProfileImage = encoded.first;
                        newGalleryImages.addAll(encoded.skip(1));
                      } else {
                        newGalleryImages.addAll(encoded);
                      }
                    } else {
                      newGalleryImages.addAll(encoded);
                    }

                    final updated = vehicle.copyWith(
                      profileImage: newProfileImage,
                      galleryImages: newGalleryImages,
                    );
                    debugPrint(
                      'VehicleImages: saving. profile=${newProfileImage != null} gallery=${newGalleryImages.length}',
                    );
                    try {
                      if (widget.isUserMode) {
                        UserVehicleRepository.instance.updateVehicle(updated);
                      } else {
                        await widget.vehicleRepository!.updateVehicle(updated);
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Could not save images: $e',
                          ),
                        ),
                      );
                      return;
                    }
                    VehicleRepository.instance.updateVehicle(updated);

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Added ${encoded.length} image(s) to vehicle',
                        ),
                      ),
                    );
                  } catch (e) {
                    debugPrint(
                      'VehicleImages: failed to pick/save images: $e',
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Image add failed: $e')),
                    );
                  }
                },
              ),
              if (vehicle.capabilities.contains(ServiceType.passenger))
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
              if (vehicle.capabilities.contains(ServiceType.parcel))
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
              if (vehicle.capabilities.contains(ServiceType.working)) ...[
                ListTile(
                  leading: const Icon(Icons.car_rental),
                  title: const Text('Lease'),
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

  Widget _buildDocumentVerificationCard(Vehicle vehicle) {
    // Get verification status from vehicle model
    final Map<String, bool> verificationStatus = {
      'RC Book': vehicle.rcVerified,
      'Insurance': vehicle.insuranceVerified,
      'Driving License': vehicle.dlVerified,
      'National ID': vehicle.aadhaarVerified,
      'Tax ID': vehicle.panVerified,
    };

    return ValueListenableBuilder<SubscriptionPlan>(
      valueListenable: AppPreferences.instance.subscriptionPlan,
      builder: (context, plan, _) {
        final canVerify = plan == SubscriptionPlan.premium || plan == SubscriptionPlan.expert;
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
            
            // Mandatory Documents Section
            Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: Colors.red),
                const SizedBox(width: 6),
                Text(
                  'MANDATORY (Required by Law)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
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
              isMandatory: true,
              canVerify: canVerify,
            ),
            const Divider(height: 1),
            _buildDocumentItemWithExpiry(
              'Insurance',
              'Vehicle Insurance - Mandatory by law',
              verificationStatus['Insurance']!,
              DocumentType.insurance,
              expiryDate: vehicle.insuranceExpiryDate,
              isMandatory: true,
              canVerify: canVerify,
            ),
            
            const SizedBox(height: 16),
            
            // Optional Documents Section
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 6),
                Text(
                  'OPTIONAL (Increases Trust)',
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
              'Driving License',
              'Valid driving license',
              verificationStatus['Driving License']!,
              DocumentType.dl,
              isMandatory: false,
              canVerify: canVerify,
            ),
            const Divider(height: 1),
            _buildDocumentItem(
              'National ID',
              'Identity verification',
              verificationStatus['National ID']!,
              DocumentType.aadhaar,
              isMandatory: false,
              canVerify: canVerify,
            ),
            const Divider(height: 1),
            _buildDocumentItem(
              'Tax ID',
              'Tax identification',
              verificationStatus['Tax ID']!,
              DocumentType.pan,
              isMandatory: false,
              canVerify: canVerify,
            ),
            if (!canVerify) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline, color: Colors.orange),
                title: const Text('Verification locked'),
                subtitle: const Text('Upgrade to Premium or Expert plan to verify documents'),
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
    bool isMandatory = false,
    bool canVerify = true,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Icon(
        isVerified ? Icons.verified : (isMandatory ? Icons.error : Icons.pending_outlined),
        color: isVerified ? Colors.green : (isMandatory ? Colors.red : Colors.orange),
        size: 28,
      ),
      title: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (isMandatory && !isVerified) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    foregroundColor: isMandatory ? Colors.red : null,
                    side: isMandatory ? const BorderSide(color: Colors.red, width: 2) : null,
                  ),
                  child: const Text('Verify'),
                )
              : const Icon(Icons.lock_outline, color: Colors.orange),
    );
  }

  Widget _buildDocumentItemWithExpiry(
    String title,
    String subtitle,
    bool isVerified,
    DocumentType documentType, {
    DateTime? expiryDate,
    bool isMandatory = false,
    bool canVerify = true,
  }) {
    final isExpired = expiryDate != null && expiryDate.isBefore(DateTime.now());
    final isExpiringSoon = expiryDate != null && 
        expiryDate.isAfter(DateTime.now()) && 
        expiryDate.isBefore(DateTime.now().add(const Duration(days: 30)));
    
    final isBlockedForUserMode = widget.isUserMode &&
        _isVehicleComplianceDoc(documentType);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Icon(
        isVerified && !isExpired 
            ? Icons.verified 
            : (isMandatory || isExpired ? Icons.error : Icons.pending_outlined),
        color: isVerified && !isExpired 
            ? Colors.green 
            : (isMandatory || isExpired ? Colors.red : Colors.orange),
        size: 28,
      ),
      title: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (isMandatory && (!isVerified || isExpired)) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  : isExpiringSoon
                      ? 'Expires soon: ${_fmtDate(expiryDate)}'
                      : 'Valid until ${_fmtDate(expiryDate)}',
              style: TextStyle(
                fontSize: 11,
                color: isExpired 
                    ? Colors.red 
                    : isExpiringSoon 
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    foregroundColor: isMandatory || isExpired ? Colors.red : null,
                    side: isMandatory || isExpired
                        ? const BorderSide(color: Colors.red, width: 2)
                        : null,
                  ),
                  child: Text(
                    isBlockedForUserMode
                        ? 'Not allowed'
                        : (isExpired ? 'Renew' : 'Verify'),
                  ),
                ),
    );
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

      if (expiryDate == null || !mounted) return; // User cancelled
    }

    // Step 2: Show instructions before opening camera
    final proceedToCamera = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Live Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Next, we\'ll verify you with the document',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📸 You\'ll need to:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('1. Show your face clearly'),
                  Text('2. Turn your head left'),
                  Text('3. Turn your head right'),
                  Text('4. Hold the physical document next to your face'),
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

    if (proceedToCamera != true || !mounted) return;

    // Step 3: Open camera with document reference
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

    // Handle verification result
    final faceVerified = result['faceVerified'] as bool;
    final docType = result['documentType'] as String;

    if (faceVerified) {
      final faceMatched = result['faceMatched'] as bool? ?? false;
      final matchScore = result['matchScore'] as double? ?? 0.0;

      // Update vehicle with verification status
      final now = DateTime.now();
      Vehicle updatedVehicle;

      switch (documentType) {
        case DocumentType.rc:
          updatedVehicle = vehicle.copyWith(
            rcVerified: true,
            rcVerifiedAt: now,
          );
          break;
        case DocumentType.insurance:
          updatedVehicle = vehicle.copyWith(
            insuranceVerified: true,
            insuranceVerifiedAt: now,
            insuranceExpiryDate: expiryDate,
          );
          break;
        case DocumentType.dl:
          updatedVehicle = vehicle.copyWith(
            dlVerified: true,
            dlVerifiedAt: now,
          );
          break;
        case DocumentType.aadhaar:
          updatedVehicle = vehicle.copyWith(
            aadhaarVerified: true,
            aadhaarVerifiedAt: now,
          );
          break;
        case DocumentType.pan:
          updatedVehicle = vehicle.copyWith(
            panVerified: true,
            panVerifiedAt: now,
          );
          break;
      }

      // Save to repository
      if (widget.isUserMode) {
        UserVehicleRepository.instance.updateVehicle(updatedVehicle);
      } else {
        await widget.vehicleRepository!.updateVehicle(updatedVehicle);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            faceMatched
                ? '$docType verified with face matching! ${matchScore.toStringAsFixed(1)}% match ✓'
                : '$docType verified with liveness detection! ✓',
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
    final slotIds = entries.map((e) => e.slot.id).toSet();
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
            const SizedBox(height: 8),
            ValueListenableBuilder<List<Booking>>(
              valueListenable: BookingRepository.instance.bookings,
              builder: (context, bookings, _) {
                final vehicleBookings = bookings
                    .where((b) => slotIds.contains(b.slotId))
                    .toList(growable: false);

                if (vehicleBookings.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No bookings yet'),
                  );
                }

                return Column(
                  children: vehicleBookings
                      .map(
                        (b) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history),
                          title: Text('Booking #${b.id}'),
                          subtitle: Text('Status: ${_statusLabel(b)}'),
                          trailing: Text(
                            _fmtDate(b.createdAt),
                            style:
                                const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
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
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
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
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter tracking link')),
      );
      return;
    }

    final double? manualLat = _gpsMode == VehicleGpsMode.manual
        ? double.tryParse(_manualLatController.text.trim())
        : null;
    final double? manualLng = _gpsMode == VehicleGpsMode.manual
        ? double.tryParse(_manualLngController.text.trim())
        : null;

    if (_gpsMode == VehicleGpsMode.manual && (manualLat == null || manualLng == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid manual coordinates')),
      );
      return;
    }
    if (_gpsMode == VehicleGpsMode.manual && (manualLat! < -90 || manualLat > 90)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid latitude')),
      );
      return;
    }
    if (_gpsMode == VehicleGpsMode.manual && (manualLng! < -180 || manualLng > 180)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid longitude')),
      );
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
      lastKnownLat: _gpsMode == VehicleGpsMode.manual ? manualLat : vehicle.lastKnownLat,
      lastKnownLng: _gpsMode == VehicleGpsMode.manual ? manualLng : vehicle.lastKnownLng,
      averageRating: vehicle.averageRating,
      totalRatings: vehicle.totalRatings,
      totalBookings: vehicle.totalBookings,
      activePostsCount: vehicle.activePostsCount,
    );

    if (widget.isUserMode) {
      UserVehicleRepository.instance.updateVehicle(updated);
    } else {
      widget.vehicleRepository!.updateVehicle(updated);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('GPS settings saved')),
    );
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
                final avgRating = providerReviews.fold<double>(
                  0,
                  (sum, r) => sum + r.rating,
                ) / providerReviews.length;

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

  String _statusLabel(Booking booking) {
    switch (booking.status) {
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
                      if (geo.state != null) _geoChip(Icons.account_balance, geo.state!),
                      if (postcode != null) _geoChip(Icons.markunread_mailbox, postcode),
                      if (country != null)
                        _geoChip(
                          Icons.public,
                          countryCode != null ? '$country ($countryCode)' : country,
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
                final userReviews = allReviews
                    .where((r) => r.revieweeId == vehicle.userId)
                    .toList();
                final avgRating = userReviews.isEmpty
                    ? 0.0
                    : userReviews.fold<double>(0, (s, r) => s + r.rating) /
                        userReviews.length;
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
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${userReviews.length} ratings',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                );
              },
            ),
            ValueListenableBuilder<List<Booking>>(
              valueListenable: BookingRepository.instance.bookings,
              builder: (context, allBookings, _) {
                final totalTrips = allBookings
                    .where((b) =>
                        b.providerId == vehicle.userId &&
                        b.status == BookingStatus.completed)
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
                              fontSize: 18, fontWeight: FontWeight.bold),
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
