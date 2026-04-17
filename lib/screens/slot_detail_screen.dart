import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/seat_layout.dart';
import '../models/booking.dart';
import '../models/slot.dart';
import '../models/slot_type.dart';
import '../models/post_mode.dart';
import '../models/vehicle.dart';
import '../models/service_type.dart';
import '../services/auth_repository.dart';
import '../services/booking_repository.dart';
import '../services/seat_layout_repository.dart';
import '../services/app_preferences.dart';
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

  Widget _buildContent(BuildContext context) {
    return ValueListenableBuilder<List<Vehicle>>(
      valueListenable: VehicleRepository.instance.vehiclesListenable,
      builder: (context, _, child) {
        // Resolve latest slot from repositories
        final resolvedSlot = slot_repo.SlotRepository.instance.allSlotsRaw
                .cast<Slot?>()
                .firstWhere((s) => s?.id == slot.id, orElse: () => null) ??
            CustomerSlotRepository.instance.allSlotsRaw
                .cast<Slot?>()
                .firstWhere((s) => s?.id == slot.id, orElse: () => null) ??
            slot;

        // Try to find vehicle in both repositories
        final resolvedVehicle = VehicleRepository.instance.getById(resolvedSlot.vehicleId) ??
            CustomerVehicleRepository.instance.getById(resolvedSlot.vehicleId) ??
            VehicleRepository.instance.getById(vehicle.id) ??
            CustomerVehicleRepository.instance.getById(vehicle.id) ??
            vehicle;

        debugPrint(
          'SlotDetailScreen: slot.vehicleId=${slot.vehicleId} passedVehicle.id=${vehicle.id} resolvedVehicle.id=${resolvedVehicle.id} images=${(resolvedVehicle.profileImage != null ? 1 : 0) + resolvedVehicle.galleryImages.length}',
        );

        final currentUser = AuthRepository.instance.currentUser;
        final isOwner = currentUser != null && currentUser.id == resolvedSlot.profileId; // Use post owner

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
                    final updated = await _showEditSlotSheet(context, resolvedSlot);
                    if (updated == null || !context.mounted) return;

                    final existsInProviderRepo = slot_repo.SlotRepository.instance.allSlotsRaw
                        .any((s) => s.id == updated.id);
                    final existsInUserRepo =
                        CustomerSlotRepository.instance.getById(updated.id) != null;

                    if (existsInProviderRepo) {
                      await slot_repo.SlotRepository.instance.updateSlot(updated);
                    } else if (existsInUserRepo) {
                      await CustomerSlotRepository.instance.updateSlot(updated);
                    } else {
                      await slot_repo.SlotRepository.instance.updateSlot(updated);
                    }

                    // Recalculate remaining capacity based on new capacity value
                    await BookingRepository.instance.recalculateCapacity(
                      updated.id,
                      updated.capacity,
                    );

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post updated')),
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
                          serviceTypeLabel: resolvedSlot.serviceType.displayName,
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
                          value: _formatDuration(resolvedSlot.startTime, resolvedSlot.endTime),
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.payments,
                          title: 'Price',
                          value: AppPreferences.instance.formatMoney(
                            resolvedSlot.price.toInt(),
                          ),
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
                              .instance.remainingCapacityBySlotId,
                          builder: (context, _, c) {
                            return _InfoRow(
                              icon: _capacityIcon(resolvedSlot),
                              title: 'Capacity remaining',
                              value: _capacityRemainingText(resolvedSlot),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        if (resolvedSlot.seatLayoutOwnerId != null) ...[
                          ValueListenableBuilder<Map<String, SeatLayout>>(
                            valueListenable:
                                SeatLayoutRepository.instance.layoutsByOwnerId,
                            builder: (context, layouts, _) {
                              final layout = layouts[resolvedSlot.seatLayoutOwnerId];
                              if (layout == null) {
                                return const SizedBox.shrink();
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Seat Layout',
                                    style: TextStyle(
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

  static Future<Slot?> _showEditSlotSheet(BuildContext context, Slot slot) async {
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
    final priceController = TextEditingController(text: slot.price.toStringAsFixed(0));
    final capacityController = TextEditingController(text: slot.capacity.toString());
    final notesController = TextEditingController(text: slot.notes ?? '');

    LocationSuggestion? fromSuggestion;
    LocationSuggestion? toSuggestion;
    LocationSuggestion? baseSuggestion;

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
      if (originalValue != null && typedText.trim() == displayOnly(originalValue)) {
        return originalValue;
      }
      return typedText.trim();
    }

    DateTime startTime = slot.startTime;
    DateTime endTime = slot.endTime;

    Future<void> pickTime({required bool isStart, required void Function(void Function()) setSheetState}) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStart ? startTime : endTime),
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
      if (picked == null) return;
      final base = isStart ? startTime : endTime;
      final newDt = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      );
      setSheetState(() {
        if (isStart) {
          startTime = newDt;
          if (endTime.isBefore(startTime)) {
            endTime = startTime.add(const Duration(hours: 2));
          }
        } else {
          endTime = newDt;
        }
      });
    }

    String fmt(DateTime dt) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

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
                  TextField(
                    controller: notesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Terms (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                                    content: Text('Please enter both from and to locations'),
                                  ),
                                );
                                return;
                              }
                            } else {
                              if (baseController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter base location')),
                                );
                                return;
                              }
                              final r = double.tryParse(radiusController.text.trim());
                              if (r != null && r < 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invalid radius')),
                                );
                                return;
                              }
                            }

                            final price = double.tryParse(priceController.text.trim());
                            if (price == null || price <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Invalid price')),
                              );
                              return;
                            }

                            final cap = int.tryParse(capacityController.text.trim());
                            if (cap == null || cap <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Invalid capacity')),
                              );
                              return;
                            }

                            final newRadius = slot.slotType == SlotType.fromRange
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
                              setFromLocationNull: slot.slotType != SlotType.fromTo,
                              toLocation: slot.slotType == SlotType.fromTo
                                  ? formatLocationValue(
                                      typedText: toController.text,
                                      suggestion: toSuggestion,
                                      originalValue: slot.toLocation,
                                    )
                                  : null,
                              setToLocationNull: slot.slotType != SlotType.fromTo,
                              baseLocation: slot.slotType == SlotType.fromRange
                                  ? formatLocationValue(
                                      typedText: baseController.text,
                                      suggestion: baseSuggestion,
                                      originalValue: slot.baseLocation,
                                    )
                                  : null,
                              setBaseLocationNull: slot.slotType != SlotType.fromRange,
                              radius: newRadius,
                              setRadiusNull: slot.slotType != SlotType.fromRange,
                              startTime: startTime,
                              endTime: endTime,
                              price: price,
                              capacity: cap,
                              notes: notesController.text.trim().isEmpty
                                  ? null
                                  : notesController.text.trim(),
                              setNotesNull: notesController.text.trim().isEmpty,
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
      case ServiceType.working:
        return Icons.build;
      case ServiceType.lease:
        return Icons.car_rental;
    }
  }

  static Color _serviceTypeColor(Slot slot) {
    switch (slot.serviceType) {
      case ServiceType.passenger:
        return Colors.blue;
      case ServiceType.parcel:
        return Colors.orange;
      case ServiceType.working:
        return Colors.purple;
      case ServiceType.lease:
        return Colors.green;
    }
  }

  static IconData _capacityIcon(Slot slot) {
    switch (slot.serviceType) {
      case ServiceType.passenger:
        return Icons.people;
      case ServiceType.parcel:
        return Icons.inventory_2;
      case ServiceType.working:
        return Icons.work;
      case ServiceType.lease:
        return Icons.event_available;
    }
  }

  static String _capacityRemainingText(Slot slot) {
    final remaining = BookingRepository.instance.getRemainingCapacity(
      slot.id,
      slot.capacity,
    );
    switch (slot.serviceType) {
      case ServiceType.passenger:
        return 'Passengers: $remaining';
      case ServiceType.parcel:
        return 'Parcels: $remaining';
      case ServiceType.working:
        return 'Jobs/units: $remaining';
      case ServiceType.lease:
        return 'Available: $remaining';
    }
  }

  static Future<void> _handleBookingAction(
    BuildContext context, {
    required Slot slot,
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

    // For "Accept" flow, create request directly without popup sheet.
    if (!isOffer) {
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
        userGender: null,
        userName: 'Guest',
        userAge: 18,
        userPhone: null,
        userEmail: null,
      );

      if (!context.mounted) return;

      if (booking == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No capacity remaining')),
        );
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
            vehicle: null,
            isProviderView: false,
            autoCloseSeconds: 3,
          ),
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
      final seatKey = confirmed.seatKeys.length > i ? confirmed.seatKeys[i] : null;
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
        userGender: confirmed.userGenders.length > i ? confirmed.userGenders[i] : null,
        userName: confirmed.userNames.length > i ? confirmed.userNames[i] : 'Guest',
        userAge: confirmed.userAges.length > i ? confirmed.userAges[i] : 18,
        userPhone: confirmed.userPhones.length > i ? confirmed.userPhones[i] : null,
        userEmail: confirmed.userEmails.length > i ? confirmed.userEmails[i] : null,
      );

      if (booking == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No capacity remaining')),
        );
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
          vehicle: null,
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
          Text(
            'No media added yet',
            style: TextStyle(color: Colors.grey[700]),
          )
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
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(Icons.image_not_supported),
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
          backgroundImage: providerAvatar.isNotEmpty
              ? NetworkImage(providerAvatar)
              : null,
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
                          : userReviews.fold<double>(0, (s, r) => s + r.rating) /
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
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              avg.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
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
                    child: Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
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
      return Text(label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
    }
    return FutureBuilder<GeoLocation?>(
      future: LocationAutocompleteService.instance
          .reverseGeocode(coords!.$1, coords!.$2),
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
                  if (district != null)
                    _GeoTag(Icons.map_outlined, district),
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
  static const double _cellSize = 36;

  const _SeatLayoutPreview({required this.layout});

  @override
  Widget build(BuildContext context) {
    return Center(
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

            if (type == CellType.empty || type == CellType.space) {
              return const SizedBox.shrink();
            }

            final seat = cell!;
            final isLocked = seat.isLocked;

            return Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isLocked ? Colors.grey[300] : Colors.grey[400],
                border: Border.all(
                  color: isLocked ? Colors.grey : Colors.blueGrey,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  seat.seatName ?? '',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(color: Colors.grey, label: 'Booked'),
        SizedBox(width: 20),
        _LegendItem(color: Colors.blueGrey, label: 'Available'),
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
            color: color.withValues(alpha: 0.5),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
