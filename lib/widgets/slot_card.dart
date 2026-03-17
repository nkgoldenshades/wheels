import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../models/slot.dart';
import '../models/vehicle.dart';
import '../models/service_type.dart';
import '../models/slot_type.dart';
import '../models/pickup_mode.dart';
import '../services/booking_repository.dart';
import '../services/app_preferences.dart';

class SlotCard extends StatelessWidget {
  final Slot slot;
  final Vehicle vehicle;
  final String providerName;
  final String providerAvatar;
  final double providerRating;
  final bool isOffer; // true = Offer (User books), false = Request (Provider accepts)
  final bool isUserPost; // true = user post (looking for service), false = provider post (offering service)
  final VoidCallback onTap;
  final VoidCallback onAction;

  const SlotCard({
    super.key,
    required this.slot,
    required this.vehicle,
    required this.providerName,
    required this.providerAvatar,
    required this.providerRating,
    required this.isOffer,
    required this.isUserPost,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final distanceKm = _distanceKm();
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TOP ROW - WHO + WHAT
              _buildTopRow(),
              const SizedBox(height: 12),
              
              // MIDDLE - LOCATION
              _buildLocationRow(),
              if (distanceKm != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.my_location, size: 14, color: Colors.grey[700]),
                    const SizedBox(width: 6),
                    Text(
                      'Vehicle ~${distanceKm.toStringAsFixed(1)} km away',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              
              // PICKUP MODE
              _buildPickupModeRow(),
              const SizedBox(height: 12),
              
              // TIME
              _buildTimeRow(),
              const SizedBox(height: 12),
              
              // PRICE + CAPACITY
              _buildPriceCapacityRow(),
              const SizedBox(height: 12),
              
              // OPTIONAL NOTES
              if (slot.notes != null && slot.notes!.isNotEmpty) ...[
                _buildNotesRow(),
                const SizedBox(height: 12),
              ],
              
              // BOTTOM - ACTION
              _buildActionRow(),
            ],
          ),
        ),
      ),
    );
  }

  Uint8List? _tryDecodePhoto(String? photo) {
    if (photo == null) return null;
    try {
      final normalized = photo.contains(',') ? photo.split(',').last : photo;
      if (normalized.trim().isEmpty) return null;
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  double? _distanceKm() {
    final vehiclePos = _vehicleResolvedLatLng();
    if (vehiclePos == null) return null;

    final targetText = slot.slotType == SlotType.fromTo
        ? (slot.fromLocation ?? '')
        : (slot.baseLocation ?? '');

    final target = _tryResolveLocation(targetText);
    if (target == null) return null;

    return _haversineKm(
      vehiclePos.$1,
      vehiclePos.$2,
      target.$1,
      target.$2,
    );
  }

  (double, double)? _vehicleResolvedLatLng() {
    switch (vehicle.gpsMode) {
      case VehicleGpsMode.manual:
        if (vehicle.manualLat == null || vehicle.manualLng == null) return null;
        return (vehicle.manualLat!, vehicle.manualLng!);
      case VehicleGpsMode.externalLink:
      case VehicleGpsMode.deviceLive:
        if (vehicle.lastKnownLat == null || vehicle.lastKnownLng == null) return null;
        return (vehicle.lastKnownLat!, vehicle.lastKnownLng!);
    }
  }

  (double, double)? _tryParseLatLng(String s) {
    final t = s.trim();
    final parts = t.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90) return null;
    if (lng < -180 || lng > 180) return null;
    return (lat, lng);
  }

  (double, double)? _tryResolveLocation(String s) {
    final parsed = _tryParseLatLng(s);
    if (parsed != null) return parsed;
    return _cityLatLng(s);
  }

  (double, double)? _cityLatLng(String s) {
    final key = s.trim().toLowerCase();
    switch (key) {
      case 'chennai':
        return (13.0827, 80.2707);
      case 'madurai':
        return (9.9252, 78.1198);
      case 'bangalore':
      case 'bengaluru':
        return (12.9716, 77.5946);
      case 'coimbatore':
        return (11.0168, 76.9558);
      case 'hyderabad':
        return (17.3850, 78.4867);
      case 'mumbai':
        return (19.0760, 72.8777);
      case 'delhi':
        return (28.6139, 77.2090);
      default:
        return null;
    }
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    double toRad(double deg) => deg * (math.pi / 180.0);

    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);

    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a.toDouble()), math.sqrt((1 - a).toDouble()));
    return r * c;
  }

  Widget _buildTopRow() {
    // Use profile image if available, otherwise first gallery image
    final imageToShow = vehicle.profileImage ?? 
        (vehicle.galleryImages.isNotEmpty ? vehicle.galleryImages.first : null);
    
    final Uint8List? bytes = imageToShow != null 
        ? _tryDecodePhoto(imageToShow)
        : null;

    return Row(
      children: [
        if (bytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.black12,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, size: 18),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        // Provider avatar
        CircleAvatar(
          radius: 20,
          backgroundImage: providerAvatar.isNotEmpty ? NetworkImage(providerAvatar) : null,
          child: providerAvatar.isEmpty ? const Icon(Icons.person) : null,
        ),
        const SizedBox(width: 12),
        
        // Provider name + rating
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                providerName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    providerRating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Service type badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getServiceTypeColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getServiceTypeIcon(),
                size: 16,
                color: _getServiceTypeColor(),
              ),
              const SizedBox(width: 4),
              Text(
                slot.serviceType.displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: _getServiceTypeColor(),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow() {
    return Row(
      children: [
        Icon(
          slot.slotType == SlotType.fromTo ? Icons.route : Icons.location_on,
          color: Colors.blue[700],
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            slot.slotType == SlotType.fromTo
                ? '${slot.fromLocation} → ${slot.toLocation}'
                : 'Based in ${slot.baseLocation} · ${slot.radius?.toInt()} km range',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPickupModeRow() {
    return Row(
      children: [
        Text(
          slot.pickupOption.icon,
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(width: 6),
        Text(
          slot.pickupOption.shortLabel,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRow() {
    return Row(
      children: [
        const Icon(Icons.access_time, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          '${_formatTime(slot.startTime)} – ${_formatTime(slot.endTime)}',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCapacityRow() {
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: BookingRepository.instance.remainingCapacityBySlotId,
      builder: (context, _, _) {
        final remaining =
            BookingRepository.instance.getRemainingCapacity(slot.id, slot.capacity);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: AppPreferences.instance.currencyCode,
              builder: (context, _, _) {
                return Text(
                  AppPreferences.instance.formatMoney(slot.price.toInt()),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                );
              },
            ),
            Row(
              children: [
                Icon(_getCapacityIcon(), size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _getCapacityText(remaining),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotesRow() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slot.notes!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onAction,
        style: ElevatedButton.styleFrom(
          backgroundColor: isOffer ? Colors.blue : Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          isOffer ? '👉 Book' : '👉 Accept',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Helper methods
  Color _getServiceTypeColor() {
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

  IconData _getServiceTypeIcon() {
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

  IconData _getCapacityIcon() {
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

  String _getCapacityText(int remaining) {
    switch (slot.serviceType) {
      case ServiceType.passenger:
        return 'Seats: $remaining';
      case ServiceType.parcel:
        return 'Parcels: $remaining';
      case ServiceType.working:
        return 'Jobs: $remaining';
      case ServiceType.lease:
        return 'Available: $remaining';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
