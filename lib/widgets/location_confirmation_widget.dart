import 'package:flutter/material.dart';
import '../models/location_confirmation.dart';

/// Widget to display automatic GPS location confirmation status
/// Separate from manual trip media (photos/videos)
class LocationConfirmationWidget extends StatelessWidget {
  final LocationConfirmations confirmations;
  final bool isProvider;

  const LocationConfirmationWidget({
    super.key,
    required this.confirmations,
    required this.isProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Location Confirmations',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (confirmations.pickup.bothConfirmed && confirmations.dropoff.bothConfirmed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'All Verified',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Automatic GPS tracking',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        // Pickup Location
        _buildPhaseCard(
          label: 'Pickup Location',
          icon: Icons.play_circle_outline,
          color: Colors.green,
          phase: confirmations.pickup,
        ),

        const SizedBox(height: 12),

        // Dropoff Location
        _buildPhaseCard(
          label: 'Dropoff Location',
          icon: Icons.stop_circle_outlined,
          color: Colors.orange,
          phase: confirmations.dropoff,
        ),
      ],
    );
  }

  Widget _buildPhaseCard({
    required String label,
    required IconData icon,
    required Color color,
    required LocationConfirmationPhase phase,
  }) {
    final myParty = isProvider ? phase.provider : phase.customer;
    final otherParty = isProvider ? phase.customer : phase.provider;
    final otherLabel = isProvider ? 'Customer' : 'Provider';

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (phase.bothConfirmed)
                  const Row(
                    children: [
                      Icon(Icons.verified, size: 16, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'Both Verified',
                        style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Your confirmation
                _buildPartyStatus(
                  label: 'You',
                  party: myParty,
                  isYou: true,
                ),

                const Divider(height: 20),

                // Other party confirmation
                _buildPartyStatus(
                  label: otherLabel,
                  party: otherParty,
                  isYou: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyStatus({
    required String label,
    required LocationConfirmationParty party,
    required bool isYou,
  }) {
    if (!party.isConfirmed) {
      return Row(
        children: [
          Icon(
            Icons.schedule,
            size: 16,
            color: Colors.grey[400],
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Text(
            'Waiting for arrival...',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.check_circle,
              size: 16,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            Text(
              '$label: ',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const Text(
              'Location Confirmed',
              style: TextStyle(
                fontSize: 13,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (party.confirmedAt != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              'Confirmed at ${_formatTime(party.confirmedAt!)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ],
        if (party.gpsLat != null && party.gpsLng != null) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              'GPS: ${party.gpsLat!.toStringAsFixed(6)}, ${party.gpsLng!.toStringAsFixed(6)}',
              style: TextStyle(fontSize: 10, color: Colors.grey[500], fontFamily: 'monospace'),
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
