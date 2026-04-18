import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
// ✅ Add this import
import 'package:geolocator/geolocator.dart';
import 'package:geodesy/geodesy.dart';
import 'dart:async';
import '../services/location_autocomplete_service.dart';

/// Uber/Ola style map picker - drag map to select location
class MapLocationPicker extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialAddress;
  final double? radiusInKm; // ✅ Add radius parameter

  const MapLocationPicker({
    super.key,
    this.initialLocation,
    this.initialAddress,
    this.radiusInKm, // ✅ Optional radius in kilometers
  });

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  late final MapController _mapController;
  LatLng _centerPosition = const LatLng(13.0827, 80.2707); // Default: Chennai
  String _currentAddress = 'Loading address...';
  bool _isLoadingAddress = false;
  bool _isLoadingLocation = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    if (widget.initialLocation != null) {
      _centerPosition = widget.initialLocation!;
      _currentAddress = widget.initialAddress ?? 'Selected Location';
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _centerPosition = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
        _mapController.move(_centerPosition, 15.0);
        _updateAddress(_centerPosition);
      }
    } catch (e) {
      debugPrint('Failed to get current location: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _updateAddress(LatLng position) async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      final address = await LocationAutocompleteService.instance.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _currentAddress = address?.displayName ?? 'Unknown location';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to get address: $e');
      if (mounted) {
        setState(() {
          _currentAddress = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
          _isLoadingAddress = false;
        });
      }
    }
  }

  void _onMapMoveEnd() {
    final center = _mapController.camera.center;
    
    // Only update if moved significantly (>10 meters)
    final geodesy = Geodesy();
    final distance = geodesy.distanceBetweenTwoGeoPoints(
      LatLng(_centerPosition.latitude, _centerPosition.longitude),
      center,
    );
    
    if (distance < 10) return; // Ignore small movements
    
    setState(() {
      _centerPosition = center;
    });
    
    // Debounce address updates
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _updateAddress(center);
    });
  }

  void _confirmLocation() {
    Navigator.pop(context, {
      'lat': _centerPosition.latitude,
      'lon': _centerPosition.longitude,
      'address': _currentAddress,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centerPosition,
              initialZoom: 15.0,
              minZoom: 5.0,
              maxZoom: 18.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  _onMapMoveEnd();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vaultwheels.app',
                maxZoom: 19,
              ),
              // ✅ Add radius circle if radiusInKm is provided
              if (widget.radiusInKm != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _centerPosition,
                      radius: widget.radiusInKm! * 1000, // Convert km to meters
                      useRadiusInMeter: true,
                      color: Colors.blue.withOpacity(0.2),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
            ],
          ),

          // Center pin (fixed in center)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  size: 48,
                  color: Colors.red[600],
                  shadows: const [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black26,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                const SizedBox(height: 48), // Offset for pin point
              ],
            ),
          ),

          // Address card at top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.place,
                          size: 20,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Selected Location',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        if (_isLoadingAddress)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lat: ${_centerPosition.latitude.toStringAsFixed(6)}, Lng: ${_centerPosition.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // My Location button
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
              child: _isLoadingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.my_location,
                      color: Colors.blue[700],
                    ),
            ),
          ),

          // Confirm button at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: FilledButton(
              onPressed: _isLoadingAddress ? null : _confirmLocation,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green[600],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Confirm Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
