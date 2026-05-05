import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/slot_entry.dart';
import '../services/slot_repository.dart';

/// Map screen showing all posts with radius circles
class PostsMapScreen extends StatefulWidget {
  const PostsMapScreen({super.key});

  @override
  State<PostsMapScreen> createState() => _PostsMapScreenState();
}

class _PostsMapScreenState extends State<PostsMapScreen> {
  final MapController _mapController = MapController();
  List<SlotEntry> _posts = [];
  SlotEntry? _selectedPost; // Track which post is selected

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  void _loadPosts() {
    setState(() {
      _posts = SlotRepository.instance.allSlots;
    });
  }

  LatLng? _extractLocation(String? locationString) {
    if (locationString == null) return null;
    
    // Format: "Address|lat,lng|keywords"
    final parts = locationString.split('|');
    if (parts.length < 2) return null;
    
    final coords = parts[1].split(',');
    if (coords.length != 2) return null;
    
    final lat = double.tryParse(coords[0].trim());
    final lng = double.tryParse(coords[1].trim());
    
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  List<Marker> _buildTextLabels() {
    final textMarkers = <Marker>[];
    
    for (final post in _posts) {
      // 1. Base location label - Orange
      final baseLocation = _extractLocation(post.slot.baseLocation);
      if (baseLocation != null) {
        textMarkers.add(
          Marker(
            point: LatLng(baseLocation.latitude - 0.0008, baseLocation.longitude), // Slightly below marker
            width: 80,
            height: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Text(
                'BASE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }

      // 2. From location label - Green
      final fromLocation = _extractLocation(post.slot.fromLocation);
      if (fromLocation != null) {
        textMarkers.add(
          Marker(
            point: LatLng(fromLocation.latitude - 0.0008, fromLocation.longitude),
            width: 80,
            height: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Text(
                'PICKUP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }

      // 3. To location label - Red
      final toLocation = _extractLocation(post.slot.toLocation);
      if (toLocation != null) {
        textMarkers.add(
          Marker(
            point: LatLng(toLocation.latitude - 0.0008, toLocation.longitude),
            width: 80,
            height: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Text(
                'DROP-OFF',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }

      // 4. Vehicle location label (only when selected) - Blue
      final isSelected = _selectedPost?.slot.id == post.slot.id;
      if (isSelected && post.vehicle.lastKnownLat != null && post.vehicle.lastKnownLng != null) {
        final vehicleLocation = LatLng(post.vehicle.lastKnownLat!, post.vehicle.lastKnownLng!);
        textMarkers.add(
          Marker(
            point: LatLng(vehicleLocation.latitude - 0.0008, vehicleLocation.longitude),
            width: 80,
            height: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Text(
                'VEHICLE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }
    }
    
    return textMarkers;
  }

  @override
  Widget build(BuildContext context) {
    // Extract all markers with locations
    final markers = <Marker>[];
    final circles = <CircleMarker>[];

    for (final post in _posts) {
      final isSelected = _selectedPost?.slot.id == post.slot.id;

      // 1. Base location (with radius circle when selected) - Orange
      final baseLocation = _extractLocation(post.slot.baseLocation);
      if (baseLocation != null) {
        // Add radius circle ONLY for selected post
        if (isSelected) {
          circles.add(
            CircleMarker(
              point: baseLocation,
              radius: (post.slot.radius ?? 5.0) * 1000, // Convert km to meters
              useRadiusInMeter: true,
              color: Colors.orange.withValues(alpha: 0.2),
              borderColor: Colors.orange,
              borderStrokeWidth: 2,
            ),
          );
        }

        // Add base marker
        markers.add(
          Marker(
            point: baseLocation,
            width: isSelected ? 50 : 40, // Larger when selected
            height: isSelected ? 50 : 40,
            child: GestureDetector(
              onTap: () => _onMarkerTap(post),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.white,
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: isSelected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.home, // Base/home icon
                  color: Colors.white,
                  size: isSelected ? 25 : 20,
                ),
              ),
            ),
          ),
        );
      }

      // 2. From location (pickup) - Green
      final fromLocation = _extractLocation(post.slot.fromLocation);
      if (fromLocation != null) {
        markers.add(
          Marker(
            point: fromLocation,
            width: isSelected ? 50 : 40,
            height: isSelected ? 50 : 40,
            child: GestureDetector(
              onTap: () => _onMarkerTap(post),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.white,
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: isSelected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.play_arrow, // Start/pickup icon
                  color: Colors.white,
                  size: isSelected ? 25 : 20,
                ),
              ),
            ),
          ),
        );
      }

      // 3. To location (drop-off) - Red
      final toLocation = _extractLocation(post.slot.toLocation);
      if (toLocation != null) {
        markers.add(
          Marker(
            point: toLocation,
            width: isSelected ? 50 : 40,
            height: isSelected ? 50 : 40,
            child: GestureDetector(
              onTap: () => _onMarkerTap(post),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.white,
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: isSelected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.flag, // Destination/flag icon
                  color: Colors.white,
                  size: isSelected ? 25 : 20,
                ),
              ),
            ),
          ),
        );
      }

      // 4. Current vehicle location (ONLY for selected post) - Blue car icon
      if (isSelected && post.vehicle.lastKnownLat != null && post.vehicle.lastKnownLng != null) {
        final vehicleLocation = LatLng(post.vehicle.lastKnownLat!, post.vehicle.lastKnownLng!);
        markers.add(
          Marker(
            point: vehicleLocation,
            width: 50,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_car, // Vehicle icon
                color: Colors.white,
                size: 25,
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPosts,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(13.0827, 80.2707), // Chennai
              initialZoom: 12.0,
              minZoom: 5.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vaultwheels.app',
                maxZoom: 19,
              ),
              // Draw circles first (behind markers)
              CircleLayer(circles: circles),
              // Draw markers on top
              MarkerLayer(markers: markers),
              // Add text labels for markers
              MarkerLayer(
                markers: _buildTextLabels(),
              ),
            ],
          ),
          // Legend/Key - Improved visibility
          Positioned(
            top: 16,
            right: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                        const SizedBox(width: 6),
                        Text(
                          'Map Legend',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    _buildLegendItem(
                      Icons.home,
                      Colors.orange,
                      'Orange Circle = Base',
                      'Service coverage area',
                    ),
                    const SizedBox(height: 10),
                    _buildLegendItem(
                      Icons.play_arrow,
                      Colors.green,
                      'Green Circle = Pickup',
                      'Where you get in',
                    ),
                    const SizedBox(height: 10),
                    _buildLegendItem(
                      Icons.flag,
                      Colors.red,
                      'Red Circle = Drop-off',
                      'Where you get out',
                    ),
                    const SizedBox(height: 10),
                    _buildLegendItem(
                      Icons.directions_car,
                      Colors.blue,
                      'Blue Circle = Vehicle',
                      'Current location (tap to see)',
                    ),
                    const Divider(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 6),
                          Text(
                            'Tap marker to see details',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[900],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Help button
          FloatingActionButton(
            heroTag: 'help',
            mini: true,
            backgroundColor: Colors.blue,
            onPressed: () => _showMapHelp(context),
            child: const Icon(Icons.help_outline, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'zoom_in',
            mini: true,
            onPressed: () {
              final zoom = _mapController.camera.zoom;
              _mapController.move(_mapController.camera.center, zoom + 1);
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'zoom_out',
            mini: true,
            onPressed: () {
              final zoom = _mapController.camera.zoom;
              _mapController.move(_mapController.camera.center, zoom - 1);
            },
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }

  void _onMarkerTap(SlotEntry post) {
    setState(() {
      // Toggle selection: if already selected, deselect; otherwise select
      _selectedPost = (_selectedPost?.slot.id == post.slot.id) ? null : post;
    });

    // Show post details in bottom sheet
    if (_selectedPost != null) {
      _showPostDetails(context, post);
    }
  }

  void _showMapHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.map, color: Colors.blue),
            SizedBox(width: 8),
            Text('How to Use This Map'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Marker Colors & Meanings:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _buildHelpItem(
                Icons.home,
                Colors.orange,
                'Orange (Home)',
                'Base location - where the service operates from. Shows coverage radius when selected.',
              ),
              const SizedBox(height: 10),
              _buildHelpItem(
                Icons.play_arrow,
                Colors.green,
                'Green (Play)',
                'Pickup point - where passengers will be picked up.',
              ),
              const SizedBox(height: 10),
              _buildHelpItem(
                Icons.flag,
                Colors.red,
                'Red (Flag)',
                'Drop-off point - final destination for passengers.',
              ),
              const SizedBox(height: 10),
              _buildHelpItem(
                Icons.directions_car,
                Colors.blue,
                'Blue (Car)',
                'Current vehicle location - only visible when you tap a marker.',
              ),
              const Divider(height: 24),
              const Text(
                'How to Interact:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text('• Tap any marker to see post details'),
              const Text('• Selected markers grow larger with blue border'),
              const Text('• Radius circle shows service coverage area'),
              const Text('• Tap again to deselect and hide details'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, Color color, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPostDetails(BuildContext context, SlotEntry post) {
    // Calculate duration
    final duration = post.slot.endTime.difference(post.slot.startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final durationText = hours > 0 
        ? '${hours}h ${minutes > 0 ? '${minutes}m' : ''}'.trim()
        : '${minutes}m';

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with provider name
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Text(
                    post.vehicle.userName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.vehicle.userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        post.vehicle.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Key details in cards
            Row(
              children: [
                Expanded(
                  child: _buildDetailCard(
                    icon: Icons.currency_rupee,
                    label: 'Price',
                    value: '₹${post.slot.price}',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailCard(
                    icon: Icons.access_time,
                    label: 'Duration',
                    value: durationText,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDetailCard(
                    icon: Icons.people,
                    label: 'Capacity',
                    value: '${post.slot.capacity} seats',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailCard(
                    icon: Icons.radio_button_checked,
                    label: 'Coverage',
                    value: '${post.slot.radius ?? 5} km',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Time details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.grey[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatTime(post.slot.startTime)} - ${_formatTime(post.slot.endTime)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Book button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to booking screen
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Book Now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  Widget _buildLegendItem(
    IconData icon,
    Color color,
    String label,
    String? subtitle,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Color indicator box
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.grey.shade400, width: 1),
          ),
        ),
        const SizedBox(width: 8),
        // Icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

