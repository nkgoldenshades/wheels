import 'package:flutter/material.dart';
import '../models/location_confirmation.dart';

/// Simple badge showing location confirmation status for Customer (C) and Provider (P)
class LocationStatusBadge extends StatelessWidget {
  final LocationConfirmations confirmations;

  const LocationStatusBadge({
    super.key,
    required this.confirmations,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pickup status
        _buildLocationRow(
          label: 'Pickup',
          icon: Icons.play_circle_outline,
          color: Colors.green,
          phase: confirmations.pickup,
        ),
        const SizedBox(height: 6),
        // Dropoff status
        _buildLocationRow(
          label: 'Dropoff',
          icon: Icons.stop_circle_outlined,
          color: Colors.orange,
          phase: confirmations.dropoff,
        ),
      ],
    );
  }

  Widget _buildLocationRow({
    required String label,
    required IconData icon,
    required Color color,
    required LocationConfirmationPhase phase,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$label:',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        // Provider badge
        _buildPartyBadge('P', phase.provider.isConfirmed),
        const SizedBox(width: 4),
        // Customer badge
        _buildPartyBadge('C', phase.customer.isConfirmed),
      ],
    );
  }

  Widget _buildPartyBadge(String letter, bool isConfirmed) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isConfirmed ? Colors.green : Colors.grey[300],
        shape: BoxShape.circle,
        border: Border.all(
          color: isConfirmed ? Colors.green.shade700 : Colors.grey.shade400,
          width: 1.5,
        ),
      ),
      child: Center(
        child: isConfirmed
            ? const Icon(Icons.check, size: 12, color: Colors.white)
            : Text(
                letter,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
      ),
    );
  }
}
