import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geodesy/geodesy.dart';
import '../models/booking.dart';
import '../models/slot.dart';
import '../models/vehicle.dart';
import '../services/slot_repository.dart';
import '../app_tab_controller.dart';

class BookingMapScreen extends StatefulWidget {
  final Booking? booking;
  final Slot? slot;
  final Vehicle? vehicle;
  final String? from;
  final String? to;
  final bool isProviderView; // true = provider view, false = user view
  final int? autoCloseSeconds;

  const BookingMapScreen({
    super.key,
    this.booking,
    this.slot,
    this.vehicle,
    this.from,
    this.to,
    this.isProviderView = false,
    this.autoCloseSeconds,
  });

  @override
  State<BookingMapScreen> createState() => _BookingMapScreenState();
}

class _BookingMapScreenState extends State<BookingMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  LatLng? _vehicleLocation;
  bool _loading = true;
  Timer? _vehicleUpdateTimer;
  Timer? _autoCloseTimer;
  double? _totalDistance; // in kilometers
  List<LatLng> _routePoints = [];
  Slot? _slot;

  @override
  void initState() {
    super.initState();
    _loadData();

    final secs = widget.autoCloseSeconds;
    if (secs != null && secs > 0) {
      _autoCloseTimer = Timer(Duration(seconds: secs), () {
        if (!mounted) return;
        mainTabIndex.value = 1;
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  String _displayLocationText(String raw) {
    final parts = raw.split('|');
    if (parts.length >= 2) {
      final label = parts.first.trim();
      if (label.isNotEmpty) return label;
    }
    return raw;
  }

  String _extractCoordinateText(String raw) {
    final parts = raw.split('|');
    if (parts.length >= 2) {
      final coords = parts.last.trim();
      if (coords.isNotEmpty) return coords;
    }
    return raw;
  }

  @override
  void dispose() {
    _vehicleUpdateTimer?.cancel();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Load slot
    final bookingSlotId = widget.booking?.slotId;
    final slotEntry = bookingSlotId == null
        ? null
        : SlotRepository.instance.allSlots
            .where((e) => e.slot.id == bookingSlotId)
            .firstOrNull;

    _slot = slotEntry?.slot;

    // Get user location with 5s timeout
    try {
      await _requestUserLocation().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Ignore timeout or permission errors
    }

    // Mock vehicle location
    final slot = widget.slot ?? _slot;
    if (slot != null) {
      final from = slot.fromLocation != null
          ? _resolveLocation(slot.fromLocation!)
          : null;
      final to = slot.toLocation != null
          ? _resolveLocation(slot.toLocation!)
          : null;
      _vehicleLocation = from ?? to;

      if (from != null && to != null) {
        _calculateDistance(from, to);
        _generateRoute(from, to);
      }

      _startVehicleUpdates(from, to);
    }

    if (!mounted) return;
    setState(() => _loading = false);

    // Fit camera after map is (presumably) ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitMarkers();
    });
  }

  void _fitMarkers() {
    final markers = <LatLng>[];
    final slot = widget.slot ?? _slot;

    if (slot?.fromLocation != null) {
      final p = _resolveLocation(slot!.fromLocation!);
      if (p != null) markers.add(p);
    }
    if (slot?.toLocation != null) {
      final p = _resolveLocation(slot!.toLocation!);
      if (p != null) markers.add(p);
    }
    if (_vehicleLocation != null) markers.add(_vehicleLocation!);
    if (_userLocation != null) markers.add(_userLocation!);

    if (markers.isEmpty) return;

    final lats = markers.map((p) => p.latitude).toList();
    final lngs = markers.map((p) => p.longitude).toList();

    final bounds = LatLngBounds(
      LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
      LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
    );

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  Widget _buildLegendItem(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title: $value',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  void _startVehicleUpdates(LatLng? from, LatLng? to) {
    if (from == null || to == null) return;

    _vehicleUpdateTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final current = _vehicleLocation ?? from;
      final newLat = current.latitude + (to.latitude - from.latitude) * 0.1;
      final newLng = current.longitude + (to.longitude - from.longitude) * 0.1;

      setState(() {
        _vehicleLocation = LatLng(newLat, newLng);
      });
    });
  }

  Future<void> _requestUserLocation() async {
    final status = await Permission.locationWhenInUse.request();
    if (status == PermissionStatus.granted) {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _userLocation = LatLng(position.latitude, position.longitude);
    }
  }

  void _calculateDistance(LatLng from, LatLng to) {
    final geodesy = Geodesy();
    final distance = geodesy.distanceBetweenTwoGeoPoints(
      LatLng(from.latitude, from.longitude),
      LatLng(to.latitude, to.longitude),
    );
    if (!mounted) return;
    setState(() {
      _totalDistance = distance / 1000;
    });
  }

  void _generateRoute(LatLng from, LatLng to) {
    final points = <LatLng>[];
    const steps = 20;
    for (int i = 0; i <= steps; i++) {
      final fraction = i / steps;
      final lat = from.latitude + (to.latitude - from.latitude) * fraction;
      final lng = from.longitude + (to.longitude - from.longitude) * fraction;
      points.add(LatLng(lat, lng));
    }
    if (!mounted) return;
    setState(() {
      _routePoints = points;
    });
  }

  LatLng? _resolveLocation(String text) {
    final coordinateText = _extractCoordinateText(text);
    final parts = coordinateText.split(',');
    if (parts.length == 2) {
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }
    final city = coordinateText.trim().toLowerCase();
    switch (city) {
      case 'chennai':
        return const LatLng(13.0827, 80.2707);
      case 'madurai':
        return const LatLng(9.9252, 78.1198);
      case 'bangalore':
      case 'bengaluru':
        return const LatLng(12.9716, 77.5946);
      case 'coimbatore':
        return const LatLng(11.0168, 76.9558);
      case 'hyderabad':
        return const LatLng(17.3850, 78.4867);
      case 'mumbai':
        return const LatLng(19.0760, 72.8777);
      case 'delhi':
        return const LatLng(28.6139, 77.2090);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final markers = <Marker>[];
    final slot = widget.slot ?? _slot;

    if (slot?.fromLocation != null) {
      final p = _resolveLocation(slot!.fromLocation!);
      if (p != null) {
        markers.add(
          Marker(
            point: p,
            width: 40,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white),
            ),
          ),
        );
      }
    }

    if (slot?.toLocation != null) {
      final p = _resolveLocation(slot!.toLocation!);
      if (p != null) {
        markers.add(
          Marker(
            point: p,
            width: 40,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.flag, color: Colors.white),
            ),
          ),
        );
      }
    }

    if (_vehicleLocation != null) {
      markers.add(
        Marker(
          point: _vehicleLocation!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.directions_car, color: Colors.white),
          ),
        ),
      );
    }

    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isProviderView ? 'Booking Details' : 'Trip Map'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialZoom: 12.0,
              minZoom: 2.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.app',
              ),
              if (_routePoints.isNotEmpty) ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.0,
                      color: Colors.blue.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ],
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Trip Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_totalDistance != null) ...[
                    Text(
                      'Total Distance: ${_totalDistance!.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildLegendItem(
                    Icons.location_on,
                    'From',
                    slot?.fromLocation == null
                        ? 'Not set'
                        : _displayLocationText(slot!.fromLocation!),
                  ),
                  _buildLegendItem(
                    Icons.location_on,
                    'To',
                    slot?.toLocation == null
                        ? 'Not set'
                        : _displayLocationText(slot!.toLocation!),
                  ),
                  if (widget.booking != null) ...[
                    _buildLegendItem(
                      Icons.person,
                      'Passenger',
                      widget.booking!.userName ?? 'N/A',
                    ),
                    _buildLegendItem(
                      Icons.info_outline,
                      'Details',
                      '${widget.booking!.userAge ?? '?'} yrs · ${widget.booking!.userGender?.name ?? 'Any'}',
                    ),
                    _buildLegendItem(
                      Icons.calendar_today,
                      'Date',
                      _formatDate(widget.booking!.createdAt),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
