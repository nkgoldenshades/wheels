import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../models/slot.dart';
import '../models/vehicle.dart';
import '../models/service_type.dart';
import '../models/slot_type.dart';
import '../models/pickup_mode.dart';
import '../utils/timezone_utils.dart';
import '../models/post_mode.dart';
import '../services/booking_repository.dart';
import '../services/review_repository.dart';
import '../services/location_autocomplete_service.dart';

class SlotCard extends StatelessWidget {
  final Slot slot;
  final Vehicle vehicle;
  final String providerName;
  final String providerAvatar;
  final double providerRating;
  final bool
  isOffer; // true = Offer (User books), false = Request (Provider accepts)
  final bool
  isUserPost; // true = user post (looking for service), false = provider post (offering service)
  final VoidCallback onTap;
  final VoidCallback onAction;
  final VoidCallback? onRatingTap;

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
    this.onRatingTap,
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
              const SizedBox(height: 8),

              // GPS MODE INDICATOR
              _buildGpsModeRow(),
              const SizedBox(height: 12),

              // PRICE + CAPACITY
              _buildPriceCapacityRow(),
              const SizedBox(height: 12),

              // PARCEL DIMENSIONS (only for parcel slots with dimensions set)
              if (slot.serviceType == ServiceType.parcel &&
                  (slot.maxWeight != null ||
                      slot.maxLength != null ||
                      slot.maxWidth != null ||
                      slot.maxHeight != null)) ...[
                _buildParcelDimensionsRow(),
                const SizedBox(height: 12),
              ],

              // TERMS ICON (shown in action row, not here)

              // BOTTOM - ACTION
              _buildActionRow(),
            ],
          ),
        ),
      ),
    );
  }

  bool _isInsuranceValidNow() {
    if (!vehicle.insuranceVerified) return false;
    final exp = vehicle.insuranceExpiry;
    if (exp == null) return true;
    return exp.isAfter(DateTime.now());
  }

  bool _isVerifiedOptionAProviderVehicle() {
    return vehicle.rcVerified && _isInsuranceValidNow() && vehicle.dlVerified;
  }

  bool _isVerifiedOptionBUser() {
    return vehicle.aadhaarVerified && vehicle.panVerified && vehicle.dlVerified;
  }

  bool _shouldShowGoldenTick() {
    return isUserPost
        ? _isVerifiedOptionBUser()
        : _isVerifiedOptionAProviderVehicle();
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

    return _haversineKm(vehiclePos.$1, vehiclePos.$2, target.$1, target.$2);
  }

  (double, double)? _vehicleResolvedLatLng() {
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
    final fromRaw = _coordsFromRaw(s);
    if (fromRaw != null) return fromRaw;
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

    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(toRad(lat1)) *
            math.cos(toRad(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    final c =
        2 * math.atan2(math.sqrt(a.toDouble()), math.sqrt((1 - a).toDouble()));
    return r * c;
  }

  Widget _buildTopRow() {
    // Use profile image if available, otherwise first gallery image
    final imageToShow =
        vehicle.profileImage ??
        (vehicle.galleryImages.isNotEmpty ? vehicle.galleryImages.first : null);

    final Uint8List? bytes = imageToShow != null
        ? _tryDecodePhoto(imageToShow)
        : null;

    return Row(
      children: [
        // Vehicle image (first)
        if (bytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.black12,
                    child: const Center(
                      child: Icon(
                        Icons.directions_car,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],

        // Provider avatar (second)
        CircleAvatar(
          radius: 20,
          backgroundImage: providerAvatar.isNotEmpty
              ? NetworkImage(providerAvatar)
              : null,
          child: providerAvatar.isEmpty ? const Icon(Icons.person) : null,
        ),
        const SizedBox(width: 12),

        // Provider name + rating
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
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_shouldShowGoldenTick()) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified,
                      size: 18,
                      color: Color(0xFFFFC107),
                    ),
                  ],
                ],
              ),
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
                    onTap: onRatingTap,
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          avg.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 14,
                            color: onRatingTap != null
                                ? Colors.blue
                                : Colors.black87,
                            decoration: onRatingTap != null
                                ? TextDecoration.underline
                                : null,
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
              const SizedBox(height: 2),
              Text(
                [
                  vehicle.name,
                  vehicle.type,
                  if (vehicle.year != null) '${vehicle.year}',
                ].join(' · '),
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              // Operator info
              if (vehicle.operatorName != null &&
                  vehicle.operatorName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 12,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      vehicle.operatorName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (vehicle.operatorGender != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        vehicle.operatorGender == 'male'
                            ? Icons.male
                            : Icons.female,
                        size: 12,
                        color: vehicle.operatorGender == 'male'
                            ? Colors.blue[700]
                            : Colors.pink[700],
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Post mode badges (stacked vertically)
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Edit history badge - shown if post has been edited
            if (slot.editHistory.hasEdits) ...[
              Builder(
                builder: (ctx) => GestureDetector(
                  onTap: () => _showEditHistoryDialog(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 12,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Edited ${slot.editHistory.totalEdits}x',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
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
            const SizedBox(height: 4),
            // Post mode badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getPostModeColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getPostModeIcon(),
                    size: 14,
                    color: _getPostModeColor(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getPostModeText(),
                    style: TextStyle(
                      fontSize: 11,
                      color: _getPostModeColor(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Extract coords from "Name|lat,lon|keywords" or "Name|lat,lon"
  (double, double)? _coordsFromRaw(String? raw) {
    if (raw == null || !raw.contains('|')) return null;
    final parts = raw.split('|');
    if (parts.length < 2) return null;
    return _tryParseLatLng(parts[1]);
  }

  /// Strip |lat,lon|keywords — return just the display name
  String _cleanLocation(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final trimmed = raw.trim();
    return trimmed.contains('|') ? trimmed.split('|').first.trim() : trimmed;
  }

  /// Extract geo keyword part (3rd segment after second |)
  String _geoKeywords(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parts = raw.split('|');
    if (parts.length < 3) return '';
    return parts[2].trim(); // "district,state,postcode,country,IN"
  }

  /// Convert ISO country_code to flag emoji
  String _flagFromKeywords(String keywords) {
    // last part is country code e.g. "IN"
    final parts = keywords.split(',');
    final code = parts.last.trim();
    if (code.length != 2) return '';
    final base = 0x1F1E6 - 0x41;
    final chars = code.toUpperCase().codeUnits;
    return String.fromCharCode(base + chars[0]) +
        String.fromCharCode(base + chars[1]);
  }

  Widget _buildLocationRow() {
    if (slot.slotType == SlotType.fromTo) {
      final from = _cleanLocation(slot.fromLocation);
      final to = _cleanLocation(slot.toLocation);
      final fromGeo = _geoKeywords(slot.fromLocation);
      final toGeo = _geoKeywords(slot.toLocation);
      final fromCoords = _coordsFromRaw(slot.fromLocation);
      final toCoords = _coordsFromRaw(slot.toLocation);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // POST TYPE BADGE - From → To
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade300, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.route, size: 12, color: Colors.blue.shade700),
                const SizedBox(width: 4),
                Text(
                  'Fixed Route',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.route, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _locationLine(from, fromGeo, coords: fromCoords),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Icon(
                        Icons.arrow_downward,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ),
                    _locationLine(to, toGeo, coords: toCoords),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    final base = _cleanLocation(slot.baseLocation);
    final baseGeo = _geoKeywords(slot.baseLocation);
    final baseCoords = _coordsFromRaw(slot.baseLocation);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // POST TYPE BADGE - Base Location + Range
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.green.shade300, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, size: 12, color: Colors.green.shade700),
              const SizedBox(width: 4),
              Text(
                'Base Location',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (slot.radius != null) ...[
                const SizedBox(width: 4),
                Text(
                  '• ${slot.radius!.toInt()} km',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on, color: Colors.blue[700], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _locationLine('Based in $base', baseGeo, coords: baseCoords),
                  if (slot.radius != null)
                    Text(
                      '${slot.radius!.toInt()} km service radius',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _locationLine(
    String label,
    String geoKeywords, {
    (double, double)? coords,
  }) {
    final flag = geoKeywords.isNotEmpty ? _flagFromKeywords(geoKeywords) : '';
    final parts = geoKeywords.isNotEmpty ? geoKeywords.split(',') : <String>[];
    String geoLine = '';
    if (parts.length >= 2) {
      final code = parts.last;
      final rest = parts.sublist(0, parts.length - 1).join(' · ');
      geoLine = code.length == 2 ? '$rest ($code)' : geoKeywords;
    } else if (parts.length == 1) {
      geoLine = parts.first;
    }

    // If we have geo keywords already, render immediately
    if (geoLine.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            flag.isNotEmpty ? '$flag  $label' : label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            geoLine,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (coords != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 11, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Lat: ${coords.$1.toStringAsFixed(6)}, Lng: ${coords.$2.toStringAsFixed(6)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    // Fallback: resolve from coords via reverse geocode (old slots without keywords)
    if (coords != null) {
      return FutureBuilder<GeoLocation?>(
        future: LocationAutocompleteService.instance.reverseGeocode(
          coords.$1,
          coords.$2,
        ),
        builder: (context, snap) {
          final geo = snap.data;
          final resolvedFlag = _flagFromCode(geo?.countryCode);
          final district = geo?.district ?? geo?.stateDistrict;
          final fallbackParts = <String>[
            ?district,
            if (geo?.state != null) geo!.state!,
            if (geo?.postcode != null) geo!.postcode!,
            if (geo?.country != null)
              geo!.countryCode != null
                  ? '${geo.country!} (${geo.countryCode!.toUpperCase()})'
                  : geo.country!,
          ];
          final fallbackLine = fallbackParts.join(' · ');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                resolvedFlag.isNotEmpty ? '$resolvedFlag  $label' : label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (fallbackLine.isNotEmpty)
                Text(
                  fallbackLine,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 11, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Lat: ${coords.$1.toStringAsFixed(6)}, Lng: ${coords.$2.toStringAsFixed(6)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    }

    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _flagFromCode(String? code) {
    if (code == null || code.length != 2) return '';
    final base = 0x1F1E6 - 0x41;
    final chars = code.toUpperCase().codeUnits;
    return String.fromCharCode(base + chars[0]) +
        String.fromCharCode(base + chars[1]);
  }

  Widget _buildPickupModeRow() {
    return Row(
      children: [
        Text(slot.pickupOption.icon, style: const TextStyle(fontSize: 14)),
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

  Widget _buildGpsModeRow() {
    final IconData icon;
    final String label;
    final Color color;

    switch (vehicle.gpsMode) {
      case VehicleGpsMode.deviceLive:
        icon = Icons.gps_fixed;
        label = 'Live GPS (device)';
        color = Colors.green;
        break;
      case VehicleGpsMode.externalLink:
        icon = Icons.link;
        label = 'GPS via external link';
        color = Colors.blue;
        break;
      case VehicleGpsMode.manual:
        icon = Icons.edit_location_alt;
        label = 'Manual location';
        color = Colors.orange;
        break;
    }

    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRow() {
    final duration = slot.endTime.difference(slot.startTime);
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    String durationText;
    if (days > 0 && hours > 0) {
      durationText = '${days}d ${hours}h';
    } else if (days > 0) {
      durationText = '${days}d';
    } else if (hours > 0) {
      durationText = '${hours}h';
    } else {
      durationText = '${minutes}m';
    }

    final isValid = slot.endTime.isAfter(slot.startTime);

    // Extract coordinates from location strings for timezone lookup
    double? fromLat, fromLng, toLat, toLng;
    if (slot.fromLocation != null) {
      final coords = _extractCoords(slot.fromLocation!);
      fromLat = coords?.$1;
      fromLng = coords?.$2;
    }
    if (slot.toLocation != null) {
      final coords = _extractCoords(slot.toLocation!);
      toLat = coords?.$1;
      toLng = coords?.$2;
    }
    if (fromLat == null && slot.baseLocation != null) {
      final coords = _extractCoords(slot.baseLocation!);
      fromLat = coords?.$1;
      fromLng = coords?.$2;
    }

    // Use FutureBuilder to show location-based timezone
    return FutureBuilder<String>(
      future: TimezoneUtils.formatInternationalTimeRange(
        startTime: slot.startTime,
        endTime: slot.endTime,
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
      ),
      builder: (context, snapshot) {
        final timeText =
            snapshot.data ??
            '${_formatTime(slot.startTime)} – ${_formatTime(slot.endTime)}';
        return Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                timeText,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isValid ? '($durationText)' : '(invalid)',
              style: TextStyle(
                fontSize: 12,
                color: isValid ? Colors.grey[500] : Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPriceCapacityRow() {
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: BookingRepository.instance.remainingCapacityBySlotId,
      builder: (context, _, _) {
        final remaining = BookingRepository.instance.getRemainingCapacity(
          slot.id,
          slot.capacity,
        );

        // Check if slot has a layout (with variable prices per seat/compartment)
        final hasLayout =
            slot.seatLayoutOwnerId != null || slot.seatLayoutStructure != null;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Only show price if NO layout (prices are fixed for entire post)
            // Hide price if layout exists (prices vary per seat/compartment)
            if (!hasLayout)
              Text(
                '${slot.currencySymbol}${slot.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              )
            else
              // Show placeholder text when layout exists
              Text(
                'View details',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            Row(
              children: [
                Icon(_getCapacityIcon(), size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _getCapacityText(remaining),
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildParcelDimensionsRow() {
    final parts = <String>[];
    if (slot.maxWeight != null) parts.add('${slot.maxWeight}kg');
    if (slot.maxLength != null) parts.add('${slot.maxLength}L');
    if (slot.maxWidth != null) parts.add('${slot.maxWidth}W');
    if (slot.maxHeight != null) parts.add('${slot.maxHeight}H cm');
    return Row(
      children: [
        Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          parts.join(' · '),
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildActionRow() {
    final hasTerms = slot.notes != null && slot.notes!.isNotEmpty;
    return Row(
      children: [
        if (hasTerms) ...[
          Tooltip(
            message: 'Has terms/notes — view in details',
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade400, width: 1),
              ),
              child: Icon(Icons.gavel, size: 18, color: Colors.amber.shade700),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
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

  Color _getPostModeColor() {
    switch (slot.postMode) {
      case PostMode.instant:
        return Colors.blue;
      case PostMode.waitForFull:
        return Colors.orange;
      case PostMode.fullPost:
        return Colors.green;
    }
  }

  IconData _getPostModeIcon() {
    switch (slot.postMode) {
      case PostMode.instant:
        return Icons.flash_on;
      case PostMode.waitForFull:
        return Icons.groups;
      case PostMode.fullPost:
        return Icons.directions_car;
    }
  }

  String _getPostModeText() {
    switch (slot.postMode) {
      case PostMode.instant:
        return 'Instant';
      case PostMode.waitForFull:
        return 'Wait Full';
      case PostMode.fullPost:
        return 'Full Post';
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
    // Format: Jan 26, 2025 10:00 IST
    return TimezoneUtils.formatDateTimeWithTimezone(time, show24Hour: true);
  }

  /// Extract lat/lng from location string format: "Label|lat,lng|..."
  (double, double)? _extractCoords(String location) {
    try {
      final parts = location.split('|');
      if (parts.length >= 2) {
        final coords = parts[1].split(',');
        if (coords.length == 2) {
          final lat = double.tryParse(coords[0].trim());
          final lng = double.tryParse(coords[1].trim());
          if (lat != null && lng != null) return (lat, lng);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Show edit history dialog
  void _showEditHistoryDialog(BuildContext context) {
    // Sort entries by timestamp - most recent first
    final sortedEntries = [...slot.editHistory.entries]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.history, size: 20),
            const SizedBox(width: 8),
            Text('Edit History (${slot.editHistory.totalEdits})'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: sortedEntries.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  child: Text(
                    '${entry.editNumber}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  entry.getDescription(),
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  entry.getFormattedDateTime(),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
