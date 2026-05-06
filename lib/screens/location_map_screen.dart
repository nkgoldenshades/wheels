import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Simple map screen to show a single location
class LocationMapScreen extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String locationName;

  const LocationMapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    final location = LatLng(latitude, longitude);

    return Scaffold(
      appBar: AppBar(
        title: Text(locationName),
        actions: [
          // Open in external map app
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in Maps',
            onPressed: () => _openInMaps(latitude, longitude),
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: location,
          initialZoom: 14.0,
          minZoom: 5.0,
          maxZoom: 18.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: location,
                width: 80,
                height: 80,
                child: Column(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openInMaps(latitude, longitude),
        icon: const Icon(Icons.directions),
        label: const Text('Get Directions'),
      ),
    );
  }

  Future<void> _openInMaps(double lat, double lon) async {
    // Try Google Maps first, fallback to generic geo: URL
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    final geoUrl = Uri.parse('geo:$lat,$lon');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(geoUrl)) {
        await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not open maps: $e');
    }
  }
}


