import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geodesy/geodesy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

    // Get vehicle location from actual GPS data
    final slot = widget.slot ?? _slot;
    final vehicle = widget.vehicle ?? slotEntry?.vehicle;
    
    if (slot != null) {
      final from = slot.fromLocation != null
          ? _resolveLocation(slot.fromLocation!)
          : null;
      final to = slot.toLocation != null
          ? _resolveLocation(slot.toLocation!)
          : null;

      // Use vehicle's actual GPS location if available
      if (vehicle != null) {
        if (vehicle.lastKnownLat != null && vehicle.lastKnownLng != null) {
          _vehicleLocation = LatLng(vehicle.lastKnownLat!, vehicle.lastKnownLng!);
        } else if (vehicle.manualLat != null && vehicle.manualLng != null) {
          _vehicleLocation = LatLng(vehicle.manualLat!, vehicle.manualLng!);
        } else {
          // Fallback to route start if no GPS data
          _vehicleLocation = from ?? to;
        }
      } else {
        // No vehicle data, use route start
        _vehicleLocation = from ?? to;
      }

      if (from != null && to != null) {
        _calculateDistance(from, to);
        _generateRoute(from, to);
      }

      // Start live updates if vehicle has GPS tracking
      if (vehicle?.gpsMode == VehicleGpsMode.deviceLive) {
        _startVehicleUpdates(from, to);
      }
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

  Widget _buildMapLegendItem(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  void _startVehicleUpdates(LatLng? from, LatLng? to) {
    if (from == null || to == null) return;

    _vehicleUpdateTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Get vehicle ID from booking
      final bookingSlotId = widget.booking?.slotId;
      final slotEntry = SlotRepository.instance.allSlots
          .where((e) => e.slot.id == bookingSlotId)
          .firstOrNull;
      final vehicle = widget.vehicle ?? slotEntry?.vehicle;
      
      if (vehicle != null && vehicle.gpsMode == VehicleGpsMode.deviceLive) {
        // Fetch latest GPS coordinates from database
        try {
          final response = await Supabase.instance.client
              .from('vehicles')
              .select('last_known_lat, last_known_lng')
              .eq('id', vehicle.id)
              .single();
          
          final lat = response['last_known_lat'] as double?;
          final lng = response['last_known_lng'] as double?;
          
          if (lat != null && lng != null && mounted) {
            setState(() {
              _vehicleLocation = LatLng(lat, lng);
            });
            return;
          }
        } catch (e) {
          debugPrint('⚠️ Failed to fetch vehicle GPS: $e');
          // Fall through to simulated movement
        }
      }

      // Fallback: Simulated movement for demo/testing
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
            width: 80,
            height: 70,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Start', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.trip_origin, color: Colors.white, size: 20),
                ),
              ],
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
            width: 80,
            height: 70,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('End', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: const Icon(Icons.flag, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (_vehicleLocation != null) {
      final slot = widget.slot ?? _slot;
      final slotEntry = SlotRepository.instance.allSlots
          .where((e) => e.slot.id == (widget.booking?.slotId ?? slot?.id))
          .firstOrNull;
      final vehicle = widget.vehicle ?? slotEntry?.vehicle;
      
      // Determine vehicle marker color based on GPS mode
      Color vehicleColor = Colors.blue;
      IconData vehicleIcon = Icons.directions_car;
      
      if (vehicle != null) {
        switch (vehicle.gpsMode) {
          case VehicleGpsMode.deviceLive:
            vehicleColor = Colors.green;
            vehicleIcon = Icons.gps_fixed;
            break;
          case VehicleGpsMode.externalLink:
            vehicleColor = Colors.orange;
            vehicleIcon = Icons.link;
            break;
          case VehicleGpsMode.manual:
            vehicleColor = Colors.grey;
            vehicleIcon = Icons.location_on;
            break;
        }
      }
      
      markers.add(
        Marker(
          point: _vehicleLocation!,
          width: 120,
          height: 70,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Coordinate label above marker
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)],
                ),
                child: Text(
                  '${_vehicleLocation!.latitude.toStringAsFixed(4)},\n${_vehicleLocation!.longitude.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 9, color: vehicleColor, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 2),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: vehicleColor.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: vehicleColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(vehicleIcon, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 80,
          height: 70,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('You', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 2),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 20),
              ),
            ],
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
          
          // Trip Details Card (Top)
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
                  
                  // Vehicle GPS Status
                  if (_vehicleLocation != null) ...[
                    Builder(
                      builder: (context) {
                        final slotEntry = SlotRepository.instance.allSlots
                            .where((e) => e.slot.id == (widget.booking?.slotId ?? _slot?.id))
                            .firstOrNull;
                        final vehicle = widget.vehicle ?? slotEntry?.vehicle;
                        
                        if (vehicle != null) {
                          String gpsStatus;
                          Color gpsColor;
                          IconData gpsIcon;
                          
                          switch (vehicle.gpsMode) {
                            case VehicleGpsMode.deviceLive:
                              gpsStatus = 'Live GPS Tracking';
                              gpsColor = Colors.green;
                              gpsIcon = Icons.gps_fixed;
                              break;
                            case VehicleGpsMode.externalLink:
                              gpsStatus = 'External GPS Link';
                              gpsColor = Colors.orange;
                              gpsIcon = Icons.link;
                              break;
                            case VehicleGpsMode.manual:
                              gpsStatus = 'Manual Location';
                              gpsColor = Colors.grey;
                              gpsIcon = Icons.location_on;
                              break;
                          }
                          
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: gpsColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: gpsColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(gpsIcon, size: 16, color: gpsColor),
                                const SizedBox(width: 6),
                                Text(
                                  gpsStatus,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: gpsColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  if (_totalDistance != null) ...[
                    Text(
                      'Total Distance: ${_totalDistance!.toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                  ],
                  // Vehicle coordinates
                  if (_vehicleLocation != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.directions_car, size: 14, color: Colors.blue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Vehicle: ${_vehicleLocation!.latitude.toStringAsFixed(6)}, ${_vehicleLocation!.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 12, color: Colors.blue),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
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
                      '${widget.booking!.userAge != null ? '${widget.booking!.userAge} yrs' : ''}${widget.booking!.userAge != null && widget.booking!.userGender != null ? ' · ' : ''}${widget.booking!.userGender?.name ?? ''}',
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
          
          // Map Legend (Bottom)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Map Legend',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _buildMapLegendItem(Icons.play_arrow, 'Start', Colors.green),
                      _buildMapLegendItem(Icons.flag, 'End', Colors.red),
                      _buildMapLegendItem(Icons.directions_car, 'Vehicle', Colors.blue),
                      if (_userLocation != null)
                        _buildMapLegendItem(Icons.my_location, 'You', Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}



