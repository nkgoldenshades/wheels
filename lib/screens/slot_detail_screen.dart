import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/seat_layout.dart';
import '../models/slot.dart';
import '../models/slot_type.dart';
import '../models/vehicle.dart';
import '../models/service_type.dart';
import '../services/auth_repository.dart';
import '../services/booking_repository.dart';
import '../services/seat_layout_repository.dart';
import '../services/app_preferences.dart';
import '../services/vehicle_repository.dart';
import '../services/user_vehicle_repository.dart';
import '../widgets/booking_confirm_sheet.dart';
import 'booking_map_screen.dart';

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
    return ValueListenableBuilder<List<Vehicle>>(
      valueListenable: VehicleRepository.instance.vehiclesListenable,
      builder: (context, _, child) {
        // Try to find vehicle in both repositories
        final resolvedVehicle = VehicleRepository.instance.getById(slot.vehicleId) ??
            UserVehicleRepository.instance.getById(slot.vehicleId) ??
            VehicleRepository.instance.getById(vehicle.id) ??
            UserVehicleRepository.instance.getById(vehicle.id) ??
            vehicle;

        debugPrint(
          'SlotDetailScreen: slot.vehicleId=${slot.vehicleId} passedVehicle.id=${vehicle.id} resolvedVehicle.id=${resolvedVehicle.id} images=${(resolvedVehicle.profileImage != null ? 1 : 0) + resolvedVehicle.galleryImages.length}',
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Details'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                          serviceTypeLabel: slot.serviceType.displayName,
                          serviceTypeIcon: _serviceTypeIcon(slot),
                          serviceTypeColor: _serviceTypeColor(slot),
                        ),
                        const SizedBox(height: 16),
                        _VehicleMediaSection(vehicle: resolvedVehicle),
                        const SizedBox(height: 16),
                        _LocationBlock(slot: slot),
                        const SizedBox(height: 16),
                        _InfoRow(
                          icon: Icons.access_time,
                          title: 'Time window',
                          value:
                              '${_formatTime(slot.startTime)} – ${_formatTime(slot.endTime)}',
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.payments,
                          title: 'Price',
                          value: AppPreferences.instance.formatMoney(
                            slot.price.toInt(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<Map<String, int>>(
                          valueListenable: BookingRepository
                              .instance.remainingCapacityBySlotId,
                          builder: (context, _, _) {
                            return _InfoRow(
                              icon: _capacityIcon(slot),
                              title: 'Capacity remaining',
                              value: _capacityRemainingText(slot),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        if (slot.seatLayoutOwnerId != null) ...[
                          ValueListenableBuilder<Map<String, SeatLayout>>(
                            valueListenable:
                                SeatLayoutRepository.instance.layoutsByOwnerId,
                            builder: (context, layouts, _) {
                              final layout = layouts[slot.seatLayoutOwnerId];
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
                        if (slot.notes != null &&
                            slot.notes!.trim().isNotEmpty) ...[
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
                              slot.notes!.trim(),
                              style: TextStyle(color: Colors.grey[800]),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (slot.images.isNotEmpty) ...[
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
                              itemCount: slot.images.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final url = slot.images[index];
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
                      slot: slot,
                      providerId: resolvedVehicle.userId,
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

  static String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
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

    final confirmed = await showModalBottomSheet<BookingConfirmResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => BookingConfirmSheet(slot: slot, isOffer: isOffer),
    );

    if (!context.mounted) return;

    if (confirmed == null) return;

    final int? seatPrice =
        (slot.seatLayoutOwnerId != null && confirmed.seatKey != null)
        ? SeatLayoutRepository.instance
              .getLayout(slot.seatLayoutOwnerId!)
              ?.cells[confirmed.seatKey!]
              ?.price
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
      seatKey: confirmed.seatKey,
      userGender: confirmed.userGender,
      userName: confirmed.userName,
      userAge: confirmed.userAge,
      userPhone: confirmed.userPhone,
      userEmail: confirmed.userEmail,
    );

    if (booking == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No capacity remaining')));
      return;
    }

    if (!context.mounted) return;
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
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(providerRating.toStringAsFixed(1)),
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

  @override
  Widget build(BuildContext context) {
    final isFromTo = slot.slotType == SlotType.fromTo;

    final text = isFromTo
        ? '${slot.fromLocation} → ${slot.toLocation}'
        : 'Based in ${slot.baseLocation} · ${slot.radius?.toInt()} km range';

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
          Icon(
            isFromTo ? Icons.route : Icons.location_on,
            color: Colors.blue[700],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
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
