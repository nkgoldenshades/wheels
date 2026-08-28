import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/seat_layout.dart';
import '../models/simple_seat_layout.dart';
import '../models/booking.dart';
import '../models/slot.dart';
import '../models/slot_type.dart';
import '../models/post_mode.dart';
import '../models/vehicle.dart';
import '../models/service_type.dart';
import '../services/auth_repository.dart';
import '../services/booking_repository.dart';
import '../services/seat_layout_repository.dart';
import '../services/vehicle_repository.dart';
import '../services/customer_vehicle_repository.dart';
import '../services/slot_repository.dart' as slot_repo;
import '../services/customer_slot_repository.dart';
import '../models/slot_entry.dart';
import '../services/review_repository.dart';
import 'reviews_screen.dart';
import '../widgets/booking_confirm_sheet.dart';
import '../widgets/location_autocomplete_field.dart';
import '../services/location_autocomplete_service.dart';
import 'booking_map_screen.dart';
import 'location_map_screen.dart';
import '../utils/timezone_utils.dart';
import '../controllers/seat_layout_controller.dart';
import 'add_flow/seat_layout_builder_screen.dart';

class SlotDetailScreen extends StatelessWidget {
  final Slot slot;
  final Vehicle vehicle;
  final String providerName;
  final String providerAvatar;
  final double providerRating;
  final bool isOffer;

  const SlotDetailScreen({
    super.key,
    required this.slot,
    required this.vehicle,
    required this.providerName,
    required this.providerAvatar,
    required this.providerRating,
    required this.isOffer,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SlotEntry>>(
      valueListenable: slot_repo.SlotRepository.instance.slotsListenable,
      builder: (context, s1, c1) {
        return ValueListenableBuilder<List<SlotEntry>>(
          valueListenable: CustomerSlotRepository.instance.slotsListenable,
          builder: (context, s2, c2) {
            return _buildContent(context);
          },
        );
      },
    );
  }

  // Helper removed - no longer needed without image tracking

  Widget _buildContent(BuildContext context) {
    return ValueListenableBuilder<List<Vehicle>>(
      valueListenable: VehicleRepository.instance.vehiclesListenable,
      builder: (context, _, child) {
        // Resolve latest slot from repositories
        final resolvedSlot =
            slot_repo.SlotRepository.instance.allSlotsRaw
                .cast<Slot?>()
                .firstWhere((s) => s?.id == slot.id, orElse: () => null) ??
            CustomerSlotRepository.instance.allSlotsRaw
                .cast<Slot?>()
                .firstWhere((s) => s?.id == slot.id, orElse: () => null) ??
            slot;

        // Try to find vehicle in both repositories
        final resolvedVehicle =
            VehicleRepository.instance.getById(resolvedSlot.vehicleId) ??
            CustomerVehicleRepository.instance.getById(
              resolvedSlot.vehicleId,
            ) ??
            VehicleRepository.instance.getById(vehicle.id) ??
            CustomerVehicleRepository.instance.getById(vehicle.id) ??
            vehicle;

        debugPrint(
          'SlotDetailScreen: slot.vehicleId=${slot.vehicleId} passedVehicle.id=${vehicle.id} resolvedVehicle.id=${resolvedVehicle.id} images=${(resolvedVehicle.profileImage != null ? 1 : 0) + resolvedVehicle.galleryImages.length}',
        );

        final currentUser = AuthRepository.instance.currentUser;
        final isOwner =
            currentUser != null &&
            currentUser.id == resolvedSlot.profileId; // Use post owner

        return Scaffold(
          appBar: AppBar(
            title: const Text('Details'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              if (isOwner)
                IconButton(
                  tooltip: 'Edit post',
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final updated = await _showEditSlotSheet(
                      context,
                      resolvedSlot,
                    );
                    if (updated == null || !context.mounted) return;

                    // Detect changes and create edit history entry
                    final changes = <String, dynamic>{};

                    // Track price change
                    if (resolvedSlot.price != updated.price) {
                      changes['price'] = {
                        'old': resolvedSlot.price.toInt(),
                        'new': updated.price.toInt(),
                      };
                    }

                    // Track capacity change
                    if (resolvedSlot.capacity != updated.capacity) {
                      changes['capacity'] = {
                        'old': resolvedSlot.capacity,
                        'new': updated.capacity,
                      };
                    }

                    // Track time changes
                    if (resolvedSlot.startTime != updated.startTime) {
                      changes['startTime'] = {
                        'old': resolvedSlot.startTime.toIso8601String(),
                        'new': updated.startTime.toIso8601String(),
                      };
                    }

                    if (resolvedSlot.endTime != updated.endTime) {
                      changes['endTime'] = {
                        'old': resolvedSlot.endTime.toIso8601String(),
                        'new': updated.endTime.toIso8601String(),
                      };
                    }

                    // Track location changes
                    if (resolvedSlot.fromLocation != updated.fromLocation) {
                      changes['fromLocation'] = {
                        'old': resolvedSlot.fromLocation ?? '',
                        'new': updated.fromLocation ?? '',
                      };
                    }

                    if (resolvedSlot.toLocation != updated.toLocation) {
                      changes['toLocation'] = {
                        'old': resolvedSlot.toLocation ?? '',
                        'new': updated.toLocation ?? '',
                      };
                    }

                    if (resolvedSlot.baseLocation != updated.baseLocation) {
                      changes['baseLocation'] = {
                        'old': resolvedSlot.baseLocation ?? '',
                        'new': updated.baseLocation ?? '',
                      };
                    }

                    if (resolvedSlot.radius != updated.radius) {
                      changes['radius'] = {
                        'old': resolvedSlot.radius ?? 0,
                        'new': updated.radius ?? 0,
                      };
                    }

                    // Track notes/terms change
                    if (resolvedSlot.notes != updated.notes) {
                      changes['notes'] = {
                        'old': resolvedSlot.notes ?? '',
                        'new': updated.notes ?? '',
                      };
                    }

                    // Images tracking removed - posts use vehicle images

                    // Add edit history if there are changes
                    final updatedWithHistory = changes.isEmpty
                        ? updated
                        : updated.copyWith(
                            editHistory: resolvedSlot.editHistory.addEdit(
                              changes,
                            ),
                          );

                    final existsInProviderRepo = slot_repo
                        .SlotRepository
                        .instance
                        .allSlotsRaw
                        .any((s) => s.id == updatedWithHistory.id);
                    final existsInUserRepo =
                        CustomerSlotRepository.instance.getById(
                          updatedWithHistory.id,
                        ) !=
                        null;

                    if (existsInProviderRepo) {
                      await slot_repo.SlotRepository.instance.updateSlot(
                        updatedWithHistory,
                      );
                    } else if (existsInUserRepo) {
                      await CustomerSlotRepository.instance.updateSlot(
                        updatedWithHistory,
                      );
                    } else {
                      await slot_repo.SlotRepository.instance.updateSlot(
                        updatedWithHistory,
                      );
                    }

                    // Recalculate remaining capacity based on new capacity value
                    await BookingRepository.instance.recalculateCapacity(
                      updatedWithHistory.id,
                      updatedWithHistory.capacity,
                    );

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          changes.isEmpty
                              ? 'Post updated'
                              : 'Post updated (Edit #${updatedWithHistory.editHistory.totalEdits})',
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(
                          providerName: providerName,
                          providerAvatar: providerAvatar,
                          providerRating: providerRating,
                          vehicle: resolvedVehicle,
                          serviceTypeLabel:
                              resolvedSlot.serviceType.displayName,
                          serviceTypeIcon: _serviceTypeIcon(resolvedSlot),
                          serviceTypeColor: _serviceTypeColor(resolvedSlot),
                        ),
                        const SizedBox(height: 16),
                        _VehicleMediaSection(vehicle: resolvedVehicle),
                        const SizedBox(height: 16),
                        _LocationBlock(slot: resolvedSlot),
                        const SizedBox(height: 16),
                        _InfoRow(
                          icon: Icons.access_time,
                          title: 'Time window',
                          value:
                              '${_formatTime(resolvedSlot.startTime)} – ${_formatTime(resolvedSlot.endTime)}',
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.timelapse,
                          title: 'Duration',
                          value: _formatDuration(
                            resolvedSlot.startTime,
                            resolvedSlot.endTime,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.payments,
                          title: 'Price',
                          value:
                              '${resolvedSlot.currencySymbol}${resolvedSlot.price.toStringAsFixed(0)}',
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.mode,
                          title: 'Booking Mode',
                          value: resolvedSlot.postMode.displayName,
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<Map<String, int>>(
                          valueListenable: BookingRepository
                              .instance
                              .remainingCapacityBySlotId,
                          builder: (context, _, c) {
                            return _InfoRow(
                              icon: _capacityIcon(resolvedSlot),
                              title: 'Capacity remaining',
                              value: _capacityRemainingText(resolvedSlot),
                            );
                          },
                        ),
                        // Operating section — show operator info if available
                        if (resolvedSlot.operatorName != null &&
                            resolvedSlot.operatorName!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Operating',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.purple.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _InfoRow(
                                  icon: Icons.person,
                                  title: 'Operator Name',
                                  value: resolvedSlot.operatorName ?? '-',
                                ),
                                if (resolvedSlot.operatorGender != null) ...[
                                  const SizedBox(height: 8),
                                  _InfoRow(
                                    icon: resolvedSlot.operatorGender == 'male'
                                        ? Icons.male
                                        : Icons.female,
                                    title: 'Gender',
                                    value: resolvedSlot.operatorGender!
                                        .toUpperCase(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        // Parcel dimensions — only shown for parcel service type
                        if (resolvedSlot.serviceType == ServiceType.parcel &&
                            (resolvedSlot.maxWeight != null ||
                                resolvedSlot.maxLength != null ||
                                resolvedSlot.maxWidth != null ||
                                resolvedSlot.maxHeight != null)) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Parcel Dimensions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                if (resolvedSlot.maxWeight != null)
                                  _DimensionChip(
                                    icon: Icons.scale,
                                    label: 'Weight',
                                    value: '${resolvedSlot.maxWeight} kg',
                                  ),
                                if (resolvedSlot.maxLength != null)
                                  _DimensionChip(
                                    icon: Icons.straighten,
                                    label: 'Length',
                                    value: '${resolvedSlot.maxLength} cm',
                                  ),
                                if (resolvedSlot.maxWidth != null)
                                  _DimensionChip(
                                    icon: Icons.straighten,
                                    label: 'Width',
                                    value: '${resolvedSlot.maxWidth} cm',
                                  ),
                                if (resolvedSlot.maxHeight != null)
                                  _DimensionChip(
                                    icon: Icons.height,
                                    label: 'Height',
                                    value: '${resolvedSlot.maxHeight} cm',
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        // Parcel Type and HS Code — shown for parcel service type
                        if (resolvedSlot.serviceType == ServiceType.parcel &&
                            (resolvedSlot.parcelType != null ||
                                resolvedSlot.hsCode != null)) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Parcel Type & Customs',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (resolvedSlot.parcelType != null) ...[
                            _InfoRow(
                              icon: Icons.inventory_2,
                              title: 'Parcel Type',
                              value: resolvedSlot.parcelType ?? '-',
                            ),
                          ],
                          if (resolvedSlot.hsCode != null) ...[
                            const SizedBox(height: 8),
                            _InfoRow(
                              icon: Icons.local_shipping,
                              title: 'HS Code',
                              value: resolvedSlot.hsCode ?? '-',
                            ),
                          ],
                        ],
                        // Lease details — only shown for lease service type
                        if (resolvedSlot.serviceType == ServiceType.lease) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Lease Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (resolvedSlot.securityDeposit != null &&
                                    resolvedSlot.securityDeposit! > 0)
                                  _InfoRow(
                                    icon: Icons.security,
                                    title: 'Security Deposit',
                                    value:
                                        '₹${resolvedSlot.securityDeposit!.toStringAsFixed(0)}',
                                  ),
                                if (resolvedSlot.fuelPolicy != null) ...[
                                  const SizedBox(height: 4),
                                  _InfoRow(
                                    icon: Icons.local_gas_station,
                                    title: 'Fuel Policy',
                                    value: resolvedSlot.fuelPolicy!,
                                  ),
                                ],
                                if (resolvedSlot.leaseTerms != null &&
                                    resolvedSlot.leaseTerms!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Terms: ${resolvedSlot.leaseTerms}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (resolvedSlot.seatLayoutOwnerId != null ||
                            resolvedSlot.seatLayoutStructure != null) ...[
                          Builder(
                            builder: (context) {
                              // Try local repository first
                              SeatLayout? layout =
                                  resolvedSlot.seatLayoutOwnerId != null
                                  ? SeatLayoutRepository.instance.getLayout(
                                      resolvedSlot.seatLayoutOwnerId!,
                                    )
                                  : null;

                              // Fallback: convert from Supabase structure
                              if (layout == null &&
                                  resolvedSlot.seatLayoutStructure != null) {
                                layout = _simpleSeatLayoutToSeatLayout(
                                  resolvedSlot.seatLayoutStructure!,
                                  resolvedSlot.id,
                                );
                              }

                              if (layout == null) {
                                return const SizedBox.shrink();
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    resolvedSlot.serviceType.name == 'parcel'
                                        ? 'Parcel Layout'
                                        : 'Passenger Layout',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _SeatLayoutPreview(layout: layout),
                                  const SizedBox(height: 16),
                                  const _Legend(),
                                  const SizedBox(height: 16),
                                ],
                              );
                            },
                          ),
                        ],
                        if (resolvedSlot.notes != null &&
                            resolvedSlot.notes!.trim().isNotEmpty) ...[
                          const Text(
                            'Terms',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              resolvedSlot.notes!.trim(),
                              style: TextStyle(color: Colors.grey[800]),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (resolvedSlot.images.isNotEmpty) ...[
                          const Text(
                            'Images',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 92,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: resolvedSlot.images.length,
                              separatorBuilder: (_, c) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final url = resolvedSlot.images[index];
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[200],
                                              child: const Center(
                                                child: Icon(
                                                  Icons.image_not_supported,
                                                ),
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
                _StickyActionBar(
                  isOffer: isOffer,
                  onPressed: () {
                    _handleBookingAction(
                      context,
                      slot: resolvedSlot,
                      vehicle: vehicle,
                      providerId: resolvedSlot.profileId, // Use post owner
                      providerName: providerName,
                      providerAvatar: providerAvatar,
                      userId:
                          AuthRepository.instance.currentUser?.id ?? 'guest',
                      isOffer: isOffer,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<Slot?> _showEditSlotSheet(
    BuildContext context,
    Slot slot,
  ) async {
    String displayOnly(String raw) {
      final trimmed = raw.trim();
      if (!trimmed.contains('|')) return trimmed;
      return trimmed.split('|').first.trim();
    }

    final fromController = TextEditingController(
      text: slot.fromLocation == null ? '' : displayOnly(slot.fromLocation!),
    );
    final toController = TextEditingController(
      text: slot.toLocation == null ? '' : displayOnly(slot.toLocation!),
    );
    final baseController = TextEditingController(
      text: slot.baseLocation == null ? '' : displayOnly(slot.baseLocation!),
    );
    final radiusController = TextEditingController(
      text: slot.radius == null ? '' : slot.radius!.toStringAsFixed(0),
    );
    final priceController = TextEditingController(
      text: slot.price.toStringAsFixed(0),
    );
    final capacityController = TextEditingController(
      text: slot.capacity.toString(),
    );
    final notesController = TextEditingController(text: slot.notes ?? '');

    // Operator information controllers
    final operatorNameController = TextEditingController(
      text: slot.operatorName ?? '',
    );
    String? selectedOperatorGender = slot.operatorGender;

    // Parcel dimension controllers
    final weightController = TextEditingController(
      text: slot.maxWeight?.toString() ?? '',
    );
    final lengthController = TextEditingController(
      text: slot.maxLength?.toString() ?? '',
    );
    final widthController = TextEditingController(
      text: slot.maxWidth?.toString() ?? '',
    );
    final heightController = TextEditingController(
      text: slot.maxHeight?.toString() ?? '',
    );

    // Parcel type and HS code controllers
    String parcelTypeValue = slot.parcelType ?? 'Normal';
    final hsCodeController = TextEditingController(text: slot.hsCode ?? '');

    LocationSuggestion? fromSuggestion;
    LocationSuggestion? toSuggestion;
    LocationSuggestion? baseSuggestion;

    // Image management state - REMOVED (posts use vehicle images)
    // List<String> updatedImages = List<String>.from(slot.images);
    // bool isUploadingImage = false;

    String formatLocationValue({
      required String typedText,
      required LocationSuggestion? suggestion,
      required String? originalValue,
    }) {
      if (suggestion != null) {
        final label = displayOnly(suggestion.displayName);
        final coords = '${suggestion.lat},${suggestion.lon}';
        final geo = suggestion.geo;
        if (geo != null) {
          final keywords = [
            geo.district ?? geo.stateDistrict,
            geo.state,
            geo.postcode,
            geo.country,
            geo.countryCode?.toUpperCase(),
          ].whereType<String>().where((s) => s.isNotEmpty).join(',');
          return '$label|$coords|$keywords';
        }
        return '$label|$coords';
      }
      if (originalValue != null &&
          typedText.trim() == displayOnly(originalValue)) {
        return originalValue;
      }
      return typedText.trim();
    }

    DateTime startTime = slot.startTime;
    DateTime endTime = slot.endTime;

    Future<void> pickTime({
      required bool isStart,
      required void Function(void Function()) setSheetState,
    }) async {
      final current = isStart ? startTime : endTime;
      final now = DateTime.now();

      // Step 1: Pick date - prevent past dates
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: current.isBefore(now) ? now : current,
        firstDate: now, // Changed: Cannot select past dates
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (pickedDate == null || !context.mounted) return;

      // Step 2: Pick time
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
      if (picked == null) return;

      final newDt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        picked.hour,
        picked.minute,
      );

      // Prevent selecting past times
      if (newDt.isBefore(now)) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot select a time in the past'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setSheetState(() {
        if (isStart) {
          startTime = newDt;
          // Auto-adjust end time if it's before the new start time
          if (endTime.isBefore(startTime)) {
            endTime = startTime.add(const Duration(hours: 2));
          }
        } else {
          // Validate: end time must be after start time
          if (newDt.isBefore(startTime) || newDt.isAtSameMomentAs(startTime)) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('End time must be after start time'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          endTime = newDt;
        }
      });
    }

    String fmt(DateTime dt) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dtDate = DateTime(dt.year, dt.month, dt.day);

      final time =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

      // Show relative date if today/tomorrow, otherwise show full date
      if (dtDate == today) {
        return 'Today $time';
      } else if (dtDate == today.add(const Duration(days: 1))) {
        return 'Tomorrow $time';
      } else {
        return '${dt.day}/${dt.month}/${dt.year} $time';
      }
    }

    // Image upload/management removed - posts use vehicle images
    // To change images, edit the vehicle instead

    final result = await showModalBottomSheet<Slot>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Text(
                    'Edit Post',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (slot.slotType == SlotType.fromTo) ...[
                    LocationAutocompleteField(
                      controller: fromController,
                      label: 'From',
                      hint: 'Starting location',
                      onLocationSelected: (suggestion) {
                        fromSuggestion = suggestion;
                      },
                    ),
                    const SizedBox(height: 12),
                    LocationAutocompleteField(
                      controller: toController,
                      label: 'To',
                      hint: 'Destination',
                      onLocationSelected: (suggestion) {
                        toSuggestion = suggestion;
                      },
                    ),
                  ] else ...[
                    LocationAutocompleteField(
                      controller: baseController,
                      label: 'Base location',
                      hint: 'Service area center',
                      onLocationSelected: (suggestion) {
                        baseSuggestion = suggestion;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: radiusController,
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
                          onPressed: () => pickTime(
                            isStart: true,
                            setSheetState: setSheetState,
                          ),
                          child: Text('Start: ${fmt(startTime)}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => pickTime(
                            isStart: false,
                            setSheetState: setSheetState,
                          ),
                          child: Text('End: ${fmt(endTime)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Price and Capacity - only for simple mode
                  if (slot.seatLayoutStructure == null ||
                      slot.seatLayoutStructure!.layout.isEmpty) ...[
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: capacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Capacity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Operating Section - Only for simple mode (no layout)
                  if (slot.seatLayoutOwnerId == null &&
                      slot.seatLayoutStructure == null) ...[
                    const Text(
                      'Operating',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: operatorNameController,
                      decoration: const InputDecoration(
                        labelText: 'Operator Name (optional)',
                        hintText: 'Driver/Operator name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedOperatorGender,
                      decoration: const InputDecoration(
                        labelText: 'Operator Gender',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.wc),
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
                      onChanged: (value) {
                        setSheetState(() => selectedOperatorGender = value);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Terms (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  // Parcel dimensions (only for parcel service type in simple mode)
                  if (slot.serviceType == ServiceType.parcel &&
                      (slot.seatLayoutStructure == null ||
                          slot.seatLayoutStructure!.layout.isEmpty)) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Parcel Dimensions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Weight row
                    TextField(
                      controller: weightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Dimensions row: Length x Width
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: lengthController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'L (cm)',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: widthController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'W (cm)',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: heightController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'H (cm)',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Parcel Type + HS Code on same row
                    Row(
                      children: [
                        Expanded(
                          child: StatefulBuilder(
                            builder: (context, setEditState) {
                              return DropdownButtonFormField<String>(
                                initialValue: parcelTypeValue,
                                decoration: const InputDecoration(
                                  labelText: 'Type',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Normal',
                                    child: Text('Normal'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Fragile',
                                    child: Text('Fragile'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Perishable',
                                    child: Text('Perishable'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Medical',
                                    child: Text('Medical'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Hazardous',
                                    child: Text('Hazardous'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Live Animals',
                                    child: Text('Live Animals'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setEditState(
                                    () => parcelTypeValue = value ?? 'Normal',
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: hsCodeController,
                            decoration: const InputDecoration(
                              labelText: 'HS Code',
                              hintText: 'e.g., 392310',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Edit Layout Button - if layout already exists (for both layout-based sections)
                  if (slot.seatLayoutOwnerId != null ||
                      slot.seatLayoutStructure != null) ...[
                    FilledButton.icon(
                      onPressed: () async {
                        // Build existing layout
                        SeatLayout? existingLayout =
                            slot.seatLayoutOwnerId != null
                            ? SeatLayoutRepository.instance.getLayout(
                                slot.seatLayoutOwnerId!,
                              )
                            : null;

                        if (existingLayout == null &&
                            slot.seatLayoutStructure != null) {
                          existingLayout = _simpleSeatLayoutToSeatLayout(
                            slot.seatLayoutStructure!,
                            slot.id,
                          );
                        }

                        if (existingLayout == null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Unable to load layout'),
                              ),
                            );
                          }
                          return;
                        }

                        // Open layout builder with existing layout
                        if (!context.mounted) return;
                        final updatedLayout = await Navigator.push<SeatLayout?>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SeatLayoutBuilderScreen(
                              controller: SeatLayoutController(
                                initialLayout: existingLayout!,
                              ),
                              ownerId: slot.seatLayoutOwnerId,
                              serviceType: ServiceType.parcel,
                            ),
                          ),
                        );

                        if (updatedLayout != null) {
                          if (context.mounted) {
                            setSheetState(() {
                              // Store the updated layout for saving later
                              slot = slot.copyWith(
                                seatLayoutStructure:
                                    _seatLayoutToSimpleSeatLayout(
                                      updatedLayout,
                                    ),
                              );
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Layout updated')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.grid_3x3),
                      label: const Text('Edit Layout Grid'),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Images removed - posts use vehicle images
                  // To change images, edit the vehicle instead
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            if (slot.slotType == SlotType.fromTo) {
                              if (fromController.text.trim().isEmpty ||
                                  toController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter both from and to locations',
                                    ),
                                  ),
                                );
                                return;
                              }
                            } else {
                              if (baseController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter base location'),
                                  ),
                                );
                                return;
                              }
                              final r = double.tryParse(
                                radiusController.text.trim(),
                              );
                              if (r != null && r < 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invalid radius'),
                                  ),
                                );
                                return;
                              }
                            }

                            final price = double.tryParse(
                              priceController.text.trim(),
                            );
                            if (price == null || price <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Invalid price')),
                              );
                              return;
                            }

                            final cap = int.tryParse(
                              capacityController.text.trim(),
                            );
                            if (cap == null || cap <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Invalid capacity'),
                                ),
                              );
                              return;
                            }

                            // Validate parcel dimensions for parcel service type
                            double? maxWeight, maxLength, maxWidth, maxHeight;
                            if (slot.serviceType == ServiceType.parcel) {
                              maxWeight = double.tryParse(
                                weightController.text.trim(),
                              );
                              maxLength = double.tryParse(
                                lengthController.text.trim(),
                              );
                              maxWidth = double.tryParse(
                                widthController.text.trim(),
                              );
                              maxHeight = double.tryParse(
                                heightController.text.trim(),
                              );

                              if (maxWeight == null || maxWeight <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invalid weight'),
                                  ),
                                );
                                return;
                              }
                              if (maxLength == null || maxLength <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invalid length'),
                                  ),
                                );
                                return;
                              }
                              if (maxWidth == null || maxWidth <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invalid width'),
                                  ),
                                );
                                return;
                              }
                              if (maxHeight == null || maxHeight <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invalid height'),
                                  ),
                                );
                                return;
                              }
                            }

                            final newRadius =
                                slot.slotType == SlotType.fromRange
                                ? double.tryParse(radiusController.text.trim())
                                : null;

                            final updated = slot.copyWith(
                              fromLocation: slot.slotType == SlotType.fromTo
                                  ? formatLocationValue(
                                      typedText: fromController.text,
                                      suggestion: fromSuggestion,
                                      originalValue: slot.fromLocation,
                                    )
                                  : null,
                              setFromLocationNull:
                                  slot.slotType != SlotType.fromTo,
                              toLocation: slot.slotType == SlotType.fromTo
                                  ? formatLocationValue(
                                      typedText: toController.text,
                                      suggestion: toSuggestion,
                                      originalValue: slot.toLocation,
                                    )
                                  : null,
                              setToLocationNull:
                                  slot.slotType != SlotType.fromTo,
                              baseLocation: slot.slotType == SlotType.fromRange
                                  ? formatLocationValue(
                                      typedText: baseController.text,
                                      suggestion: baseSuggestion,
                                      originalValue: slot.baseLocation,
                                    )
                                  : null,
                              setBaseLocationNull:
                                  slot.slotType != SlotType.fromRange,
                              radius: newRadius,
                              setRadiusNull:
                                  slot.slotType != SlotType.fromRange,
                              startTime: startTime,
                              endTime: endTime,
                              price: price,
                              capacity: cap,
                              notes: notesController.text.trim().isEmpty
                                  ? null
                                  : notesController.text.trim(),
                              setNotesNull: notesController.text.trim().isEmpty,
                              // Parcel dimensions (only for parcel service type)
                              maxWeight: slot.serviceType == ServiceType.parcel
                                  ? maxWeight
                                  : null,
                              maxLength: slot.serviceType == ServiceType.parcel
                                  ? maxLength
                                  : null,
                              maxWidth: slot.serviceType == ServiceType.parcel
                                  ? maxWidth
                                  : null,
                              maxHeight: slot.serviceType == ServiceType.parcel
                                  ? maxHeight
                                  : null,
                              // Parcel type and HS code (only for parcel service type)
                              parcelType: slot.serviceType == ServiceType.parcel
                                  ? parcelTypeValue
                                  : null,
                              hsCode:
                                  slot.serviceType == ServiceType.parcel &&
                                      hsCodeController.text.trim().isNotEmpty
                                  ? hsCodeController.text.trim()
                                  : null,
                              // Layout structure (may be updated from layout editor)
                              seatLayoutStructure: slot.seatLayoutStructure,
                              // Operator information
                              operatorName:
                                  operatorNameController.text.trim().isEmpty
                                  ? null
                                  : operatorNameController.text.trim(),
                              operatorGender: selectedOperatorGender,
                              // images removed - posts use vehicle images
                            );

                            Navigator.pop(context, updated);
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    fromController.dispose();
    toController.dispose();
    baseController.dispose();
    radiusController.dispose();
    priceController.dispose();
    capacityController.dispose();
    notesController.dispose();
    operatorNameController.dispose();
    weightController.dispose();
    lengthController.dispose();
    widthController.dispose();
    heightController.dispose();
    return result;
  }

  static String _formatTime(DateTime time) {
    // Format: Jan 26, 2025 10:00 IST
    return TimezoneUtils.formatDateTimeWithTimezone(time, show24Hour: true);
  }

  static String _formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);

    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    final parts = <String>[];

    if (days > 0) {
      parts.add('$days ${days == 1 ? 'day' : 'days'}');
    }
    if (hours > 0) {
      parts.add('$hours ${hours == 1 ? 'hour' : 'hours'}');
    }
    if (minutes > 0 || parts.isEmpty) {
      parts.add('$minutes ${minutes == 1 ? 'minute' : 'minutes'}');
    }

    return parts.join(', ');
  }

  static IconData _serviceTypeIcon(Slot slot) {
    switch (slot.serviceType) {
      case ServiceType.passenger:
        return Icons.people;
      case ServiceType.parcel:
        return Icons.local_shipping;
      
      case ServiceType.lease:
        return Icons.handshake;
    }
  }

  static Color _serviceTypeColor(Slot slot) {
    switch (slot.serviceType) {
      case ServiceType.passenger:
        return Colors.blue;
      case ServiceType.parcel:
        return Colors.orange;
      
      case ServiceType.lease:
        return Colors.green;
    }
  }

  static SeatLayout _simpleSeatLayoutToSeatLayout(
    SimpleSeatLayout simple,
    String slotId,
  ) {
    final cells = <String, LayoutCell>{};
    int maxRow = 0;
    int maxCol = 0;

    for (final item in simple.layout) {
      final row = item.row;
      final col = item.col;
      if (row > maxRow) maxRow = row;
      if (col > maxCol) maxCol = col;

      final key = '$row:$col';
      SeatGender gender = SeatGender.any;
      if (item is PassengerSeat) {
        final g = item.allowedGender.toLowerCase();
        if (g == 'male') {
          gender = SeatGender.male;
        } else if (g == 'female') {
          gender = SeatGender.female;
        }
      }

      cells[key] = LayoutCell(
        row: row,
        col: col,
        type: item.isGap ? CellType.space : CellType.seat,
        seatName: item.key,
        price: item.price,
        gender: gender,
        isLocked: item.isLocked || item.isBooked,
      );
    }

    return SeatLayout(
      id: slotId,
      name: 'Seat Layout',
      rows: maxRow + 1,
      cols: maxCol + 1,
      cells: cells,
    );
  }

  /// Convert SeatLayout back to SimpleSeatLayout for storage
  static SimpleSeatLayout _seatLayoutToSimpleSeatLayout(SeatLayout layout) {
    final items = <LayoutItem>[];

    for (final entry in layout.cells.entries) {
      final cell = entry.value;

      if (cell.type == CellType.space) {
        // Gap item
        items.add(
          ParcelSlot(
            key: cell.key,
            matrix: '${cell.row}x${cell.col}',
            status: SlotStatus.gap,
            price: 0,
          ),
        );
      } else if (cell.type == CellType.seat) {
        // Seat item - could be passenger or parcel
        items.add(
          ParcelSlot(
            key: cell.seatName ?? cell.key,
            matrix: '${cell.row}x${cell.col}',
            status: cell.isLocked ? SlotStatus.locked : SlotStatus.available,
            price: cell.price ?? 0,
            bookingId: null,
          ),
        );
      }
    }

    return SimpleSeatLayout(type: 'parcel', layout: items);
  }

  static IconData _capacityIcon(Slot slot) {
    switch (slot.serviceType) {
      case ServiceType.passenger:
        return Icons.people;
      case ServiceType.parcel:
        return Icons.inventory_2;
      
      case ServiceType.lease:
        return Icons.event_available;
    }
  }

  static String _capacityRemainingText(Slot slot) {
    final remaining = BookingRepository.instance.getRemainingCapacity(
      slot.id,
      slot.capacity,
    );
    final total = slot.capacity;

    switch (slot.serviceType) {
      case ServiceType.passenger:
        return 'Passengers: $remaining/$total';
      case ServiceType.parcel:
        // Get available parcel numbers from layout
        final availableParcels = _getAvailableParcelNumbers(slot);
        if (availableParcels.isNotEmpty) {
          return 'Parcels: ${availableParcels.first} ($remaining/$total)';
        }
        return 'Parcels: $remaining/$total';
      
      case ServiceType.lease:
        return 'Available: $remaining/$total';
    }
  }

  static List<int> _getAvailableParcelNumbers(Slot slot) {
    // Get booked seat keys
    final bookedSeatKeys = <String>{};
    final slotIds = {slot.id};

    bookedSeatKeys.addAll(
      BookingRepository.instance.bookings.value
          .where(
            (b) =>
                slotIds.contains(b.slotId) &&
                b.seatKey != null &&
                b.status.isActive,
          )
          .map((b) => b.seatKey!),
    );

    // If there's no layout structure, return empty
    if (slot.seatLayoutStructure == null) return [];

    final availableNumbers = <int>[];
    for (final item in slot.seatLayoutStructure!.layout) {
      // Only count available items that are not booked
      if (item.isAvailable && !bookedSeatKeys.contains(item.key)) {
        // Try to extract number from seat key like "1", "A1", "Parcel 1", etc.
        final number = _extractNumberFromSeatName(item.key);
        if (number != null) {
          availableNumbers.add(number);
        }
      }
    }

    availableNumbers.sort();
    return availableNumbers;
  }

  static int? _extractNumberFromSeatName(String name) {
    // Try to extract the numeric part from names like "1", "A1", "Parcel 1", etc.
    final match = RegExp(r'(\d+)').firstMatch(name);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Show dialog to collect customer details before booking
  static Future<Map<String, dynamic>?> _showCustomerDetailsDialog(
    BuildContext context,
  ) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final ageController = TextEditingController();
    String? selectedGender;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Enter Your Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please provide your information for this booking:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                    helperText: 'Required',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    border: OutlineInputBorder(),
                    helperText: 'Required',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ageController,
                  decoration: const InputDecoration(
                    labelText: 'Age (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedGender = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Validate required fields
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Name is required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (phoneController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Phone number is required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Convert gender string to SeatGender enum if provided
                SeatGender? gender;
                if (selectedGender != null) {
                  switch (selectedGender) {
                    case 'male':
                      gender = SeatGender.male;
                      break;
                    case 'female':
                      gender = SeatGender.female;
                      break;
                    case 'other':
                      gender = SeatGender.any;
                      break;
                  }
                }

                Navigator.pop(context, {
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'age': ageController.text.isEmpty
                      ? null
                      : int.tryParse(ageController.text),
                  'gender': gender,
                });
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _handleBookingAction(
    BuildContext context, {
    required Slot slot,
    Vehicle? vehicle,
    required String providerId,
    String? providerName,
    String? providerPhone,
    String? providerEmail,
    String? providerAvatar,
    required String userId,
    required bool isOffer,
  }) async {
    final canBook = BookingRepository.instance.canBook(slot.id, slot.capacity);
    if (!canBook) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No capacity remaining')));
      return;
    }

    // For "Accept" flow, create request directly but first collect customer details
    if (!isOffer) {
      // Show dialog to collect customer details
      final customerDetails = await _showCustomerDetailsDialog(context);
      if (customerDetails == null) {
        // User cancelled
        return;
      }

      final booking = await BookingRepository.instance.createBooking(
        slotId: slot.id,
        providerId: providerId,
        providerName: providerName,
        providerPhone: providerPhone,
        providerEmail: providerEmail,
        providerAvatar: providerAvatar,
        userId: userId,
        defaultCapacity: slot.capacity,
        price: slot.price,
        seatKey: null,
        userGender: customerDetails['gender'],
        userName: customerDetails['name'],
        userAge: customerDetails['age'],
        userPhone: customerDetails['phone'],
        userEmail: null,
      );

      if (!context.mounted) return;

      if (booking == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No capacity remaining')));
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent successfully')),
      );

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
      return;
    }

    // Prevent self-booking: Check BEFORE showing payment sheet
    if (userId == providerId) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot book your own service'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showModalBottomSheet<BookingConfirmResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => BookingConfirmSheet(
        slot: slot,
        isOffer: isOffer,
        providerId: providerId,
      ),
    );

    if (!context.mounted) return;

    if (confirmed == null) return;

    final confirmedCount = confirmed.seatKeys.length;
    if (confirmedCount == 0) return;

    final SeatLayout? layout = slot.seatLayoutOwnerId == null
        ? null
        : SeatLayoutRepository.instance.getLayout(slot.seatLayoutOwnerId!);

    final createdBookings = <Booking>[];
    for (var i = 0; i < confirmedCount; i++) {
      final seatKey = confirmed.seatKeys.length > i
          ? confirmed.seatKeys[i]
          : null;
      final seatPrice = (layout != null && seatKey != null)
          ? layout.cells[seatKey]?.price
          : null;
      final double bookingPrice = (seatPrice ?? slot.price.toInt()).toDouble();

      final booking = await BookingRepository.instance.createBooking(
        slotId: slot.id,
        providerId: providerId,
        providerName: providerName,
        providerPhone: providerPhone,
        providerEmail: providerEmail,
        providerAvatar: providerAvatar,
        userId: userId,
        defaultCapacity: slot.capacity,
        price: bookingPrice,
        seatKey: seatKey,
        userGender: confirmed.userGenders.length > i
            ? confirmed.userGenders[i]
            : null,
        userName: confirmed.userNames.length > i
            ? confirmed.userNames[i]
            : 'Guest',
        userAge: confirmed.userAges.length > i ? confirmed.userAges[i] : 18,
        userPhone: confirmed.userPhones.length > i
            ? confirmed.userPhones[i]
            : null,
        userEmail: confirmed.userEmails.length > i
            ? confirmed.userEmails[i]
            : null,
      );

      if (booking == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No capacity remaining')));
        return;
      }

      createdBookings.add(booking);
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingMapScreen(
          booking: createdBookings.first,
          slot: slot,
          vehicle: vehicle,
          isProviderView: false,
          autoCloseSeconds: 3,
        ),
      ),
    );
  }
}

class _VehicleMediaSection extends StatelessWidget {
  final Vehicle vehicle;

  const _VehicleMediaSection({required this.vehicle});

  Uint8List? _tryDecode(String photo) {
    try {
      final normalized = photo.contains(',') ? photo.split(',').last : photo;
      if (normalized.trim().isEmpty) return null;
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  bool _isLikelyUrl(String s) {
    final t = s.trim().toLowerCase();
    return t.startsWith('http://') || t.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    // Combine profile image and gallery images
    final allImages = <String>[
      if (vehicle.profileImage != null) vehicle.profileImage!,
      ...vehicle.galleryImages,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Media',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (allImages.isEmpty)
          Text('No media added yet', style: TextStyle(color: Colors.grey[700]))
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: allImages.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final photo = allImages[index];
                final isProfile = vehicle.profileImage != null && index == 0;
                final bytes = _isLikelyUrl(photo) ? null : _tryDecode(photo);
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _isLikelyUrl(photo)
                            ? Image.network(
                                photo,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Icon(Icons.image_not_supported),
                                    ),
                                  );
                                },
                              )
                            : (bytes == null
                                  ? Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: Icon(Icons.image_not_supported),
                                      ),
                                    )
                                  : Image.memory(
                                      bytes,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[200],
                                              child: const Center(
                                                child: Icon(
                                                  Icons.image_not_supported,
                                                ),
                                              ),
                                            );
                                          },
                                    )),
                      ),
                    ),
                    if (isProfile)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PROFILE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
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
    );
  }
}

class _Header extends StatelessWidget {
  final String providerName;
  final String providerAvatar;
  final double providerRating;
  final Vehicle vehicle;
  final String serviceTypeLabel;
  final IconData serviceTypeIcon;
  final Color serviceTypeColor;

  const _Header({
    required this.providerName,
    required this.providerAvatar,
    required this.providerRating,
    required this.vehicle,
    required this.serviceTypeLabel,
    required this.serviceTypeIcon,
    required this.serviceTypeColor,
  });

  @override
  Widget build(BuildContext context) {
    final yearText = vehicle.year != null ? ' ${vehicle.year}' : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundImage: _getAvatarImageProvider(providerAvatar),
          child: providerAvatar.isEmpty ? const Icon(Icons.person) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      providerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder(
                    valueListenable: ReviewRepository.instance.reviews,
                    builder: (context, reviews, _) {
                      final userReviews = reviews
                          .where((r) => r.revieweeId == vehicle.userId)
                          .toList();
                      final avg = userReviews.isEmpty
                          ? 0.0
                          : userReviews.fold<double>(
                                  0,
                                  (s, r) => s + r.rating,
                                ) /
                                userReviews.length;
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReviewsScreen(
                              userId: vehicle.userId,
                              userName: providerName,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              avg.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            if (userReviews.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${userReviews.length} ${userReviews.length == 1 ? 'rating' : 'ratings'})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '🚗 ${vehicle.name}$yearText',
                style: TextStyle(color: Colors.grey[800]),
              ),
              // Operator info if available
              if (vehicle.operatorName != null &&
                  vehicle.operatorName!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Operator: ${vehicle.operatorName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (vehicle.operatorGender != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: vehicle.operatorGender == 'male'
                                ? Colors.blue.shade100
                                : Colors.pink.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                vehicle.operatorGender == 'male'
                                    ? Icons.male
                                    : Icons.female,
                                size: 12,
                                color: vehicle.operatorGender == 'male'
                                    ? Colors.blue.shade700
                                    : Colors.pink.shade700,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                vehicle.operatorGender == 'male'
                                    ? 'Male'
                                    : 'Female',
                                style: TextStyle(
                                  fontSize: 10,
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
                ),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: serviceTypeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(serviceTypeIcon, size: 16, color: serviceTypeColor),
                    const SizedBox(width: 6),
                    Text(
                      serviceTypeLabel,
                      style: TextStyle(
                        color: serviceTypeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Helper to get image provider from URL or base64
  ImageProvider? _getAvatarImageProvider(String? avatar) {
    if (avatar == null || avatar.trim().isEmpty) return null;

    final a = avatar.trim();

    // Handle URLs
    if (a.startsWith('http://') || a.startsWith('https://')) {
      return NetworkImage(a);
    }

    // Handle base64 images
    try {
      String base64String = a;
      if (a.contains(',')) {
        base64String = a.split(',').last;
      }
      if (base64String.isEmpty) return null;
      final bytes = base64Decode(base64String);
      if (bytes.isEmpty) return null;
      return MemoryImage(bytes);
    } catch (e) {
      return null;
    }
  }
}

class _LocationBlock extends StatelessWidget {
  final Slot slot;

  const _LocationBlock({required this.slot});

  /// Strip the |lat,lon suffix from stored location strings
  static String _clean(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final trimmed = raw.trim();
    return trimmed.contains('|') ? trimmed.split('|').first.trim() : trimmed;
  }

  /// Convert ISO country_code to flag emoji (e.g. "in" → "🇮🇳")
  static String _flag(String? code) {
    if (code == null || code.length != 2) return '';
    final base = 0x1F1E6 - 0x41; // regional indicator A offset
    final chars = code.toUpperCase().codeUnits;
    return String.fromCharCode(base + chars[0]) +
        String.fromCharCode(base + chars[1]);
  }

  /// Parse lat/lon from "Name|lat,lon|keywords" format
  static (double, double)? _coords(String? raw) {
    if (raw == null || !raw.contains('|')) return null;
    final parts = raw.split('|');
    if (parts.length < 2) return null;
    final coords = parts[1].split(',');
    if (coords.length < 2) return null;
    final lat = double.tryParse(coords[0]);
    final lon = double.tryParse(coords[1]);
    if (lat == null || lon == null) return null;
    return (lat, lon);
  }

  @override
  Widget build(BuildContext context) {
    final isFromTo = slot.slotType == SlotType.fromTo;

    if (isFromTo) {
      final from = _clean(slot.fromLocation);
      final to = _clean(slot.toLocation);
      final fromCoords = _coords(slot.fromLocation);
      final toCoords = _coords(slot.toLocation);

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Make route icon clickable to open map with both locations
            InkWell(
              onTap: (fromCoords != null || toCoords != null)
                  ? () {
                      // Use the first available coordinate, or from if both exist
                      final coords = fromCoords ?? toCoords!;
                      final name = fromCoords != null ? from : to;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LocationMapScreen(
                            latitude: coords.$1,
                            longitude: coords.$2,
                            locationName: name,
                          ),
                        ),
                      );
                    }
                  : null,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.route,
                  color: (fromCoords != null || toCoords != null)
                      ? Colors.blue[700]
                      : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LocationFlagRow(label: from, coords: fromCoords),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Icon(
                      Icons.arrow_downward,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                  _LocationFlagRow(label: to, coords: toCoords),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // fromRange
    final base = _clean(slot.baseLocation);
    final baseCoords = _coords(slot.baseLocation);
    final radius = slot.radius?.toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Make location icon clickable to open map
          InkWell(
            onTap: baseCoords != null
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationMapScreen(
                          latitude: baseCoords.$1,
                          longitude: baseCoords.$2,
                          locationName: base,
                        ),
                      ),
                    );
                  }
                : null,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.location_on,
                color: baseCoords != null ? Colors.blue[700] : Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LocationFlagRow(label: 'Based in $base', coords: baseCoords),
                if (radius != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$radius km range',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a location label + resolves flag and geo details from coordinates
class _LocationFlagRow extends StatelessWidget {
  final String label;
  final (double, double)? coords;

  const _LocationFlagRow({required this.label, required this.coords});

  @override
  Widget build(BuildContext context) {
    if (coords == null) {
      return Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      );
    }
    return FutureBuilder<GeoLocation?>(
      future: LocationAutocompleteService.instance.reverseGeocode(
        coords!.$1,
        coords!.$2,
      ),
      builder: (context, snapshot) {
        final geo = snapshot.data;
        final flag = _LocationBlock._flag(geo?.countryCode);
        final district = geo?.district ?? geo?.stateDistrict;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main label with flag
            Text(
              flag.isNotEmpty ? '$flag  $label' : label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (geo != null) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 10,
                runSpacing: 2,
                children: [
                  if (district != null) _GeoTag(Icons.map_outlined, district),
                  if (geo.state != null)
                    _GeoTag(Icons.account_balance_outlined, geo.state!),
                  if (geo.postcode != null)
                    _GeoTag(Icons.markunread_mailbox_outlined, geo.postcode!),
                  if (geo.country != null)
                    _GeoTag(
                      Icons.public,
                      geo.countryCode != null
                          ? '${geo.country!} (${geo.countryCode!.toUpperCase()})'
                          : geo.country!,
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _GeoTag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _GeoTag(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.grey[500]),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StickyActionBar extends StatelessWidget {
  final bool isOffer;
  final VoidCallback onPressed;

  const _StickyActionBar({required this.isOffer, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final label = isOffer ? 'BOOK' : 'ACCEPT';
    final color = isOffer ? Colors.blue : Colors.green;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatLayoutPreview extends StatelessWidget {
  final SeatLayout layout;
  static const double _cellSize = 40;

  const _SeatLayoutPreview({required this.layout});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SizedBox(
            width: layout.cols * _cellSize,
            height: layout.rows * _cellSize,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: layout.cols,
                childAspectRatio: 1,
              ),
              itemCount: layout.rows * layout.cols,
              itemBuilder: (context, index) {
                final row = index ~/ layout.cols;
                final col = index % layout.cols;
                final key = '$row:$col';
                final cell = layout.cells[key];
                final type = cell?.type ?? CellType.empty;

                if (type == CellType.empty) {
                  return const SizedBox.shrink();
                }

                if (type == CellType.space) {
                  return Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.block,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                }

                final seat = cell!;

                // Parse parcel dimensions if they exist
                String? length, breadth, height, weight;
                String displayName = seat.seatName ?? 'Seat';

                if (seat.seatName != null && seat.seatName!.contains('|')) {
                  final parts = seat.seatName!.split('|');
                  displayName = parts[0];
                  for (final part in parts.skip(1)) {
                    if (part.startsWith('L:')) {
                      length = part.substring(2);
                    } else if (part.startsWith('B:')) {
                      breadth = part.substring(2);
                    } else if (part.startsWith('H:')) {
                      height = part.substring(2);
                    } else if (part.startsWith('W:')) {
                      weight = part.substring(2);
                    }
                  }
                }

                final hasCompleteParcelDimensions =
                    length != null &&
                    length.isNotEmpty &&
                    breadth != null &&
                    breadth.isNotEmpty &&
                    height != null &&
                    height.isNotEmpty &&
                    weight != null &&
                    weight.isNotEmpty;

                // Determine border color based on gender
                Color borderColor = Colors.grey.shade400;
                if (seat.gender == SeatGender.male) {
                  borderColor = Colors.blue;
                } else if (seat.gender == SeatGender.female) {
                  borderColor = Colors.pink;
                }

                return Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: borderColor, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Stack(
                    children: [
                      // Compartment name (top-left)
                      Positioned(
                        top: 2,
                        left: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName.length > 6
                                  ? displayName.substring(0, 6)
                                  : displayName,
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Gender label
                            if (seat.gender == SeatGender.male)
                              const Text(
                                'M',
                                style: TextStyle(
                                  fontSize: 6,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            else if (seat.gender == SeatGender.female)
                              const Text(
                                'F',
                                style: TextStyle(
                                  fontSize: 6,
                                  color: Colors.pink,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Parcel dimensions (bottom-left)
                      if (hasCompleteParcelDimensions)
                        Positioned(
                          bottom: 2,
                          left: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'L:$length',
                                style: const TextStyle(
                                  fontSize: 5,
                                  color: Colors.blue,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'B:$breadth',
                                style: const TextStyle(
                                  fontSize: 5,
                                  color: Colors.blue,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Gender Indicators:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendItem(color: Colors.blue, label: 'Male'),
            const SizedBox(width: 24),
            _LegendItem(color: Colors.pink, label: 'Female'),
            const SizedBox(width: 24),
            _LegendItem(color: Colors.grey, label: 'Any'),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _DimensionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DimensionChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.orange.shade700),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.orange.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
