import 'package:flutter/material.dart';
import '../services/profile_repository.dart';

/// Shows a blue verified checkmark badge next to profiles with documents
class VerifiedBadge extends StatelessWidget {
  final String userId;
  final double size;

  const VerifiedBadge({super.key, required this.userId, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProfileInfo>(
      valueListenable: ProfileRepository.instance.profile,
      builder: (context, profile, child) {
        // Check if this user has documents uploaded
        final hasDocuments = _hasProfileDocuments(userId);

        if (!hasDocuments) return const SizedBox.shrink();

        return Tooltip(
          message: 'Profile with Documents',
          child: Icon(Icons.verified, size: size, color: Colors.blue),
        );
      },
    );
  }

  /// Check if profile has any documents uploaded
  bool _hasProfileDocuments(String userId) {
    // For now, check current user's profile
    // In future, fetch from ProfileNameRegistry or cache
    final profile = ProfileRepository.instance.profile.value;

    if (profile.id != userId) {
      // Can't check other users without fetching their profile
      // Return false for now, or implement a cache/registry lookup
      return false;
    }

    // Personal ID documents removed for legal safety
    // Trust now based on ratings and trip history, not documents
    return false; // Always false since we don't store personal ID docs anymore
  }
}

/// Extension to check if profile has documents
/// NOTE: Personal ID verification removed for legal safety
extension ProfileDocuments on ProfileInfo {
  /// Returns true if profile is trusted (based on behavior, not documents)
  bool get hasDocuments {
    // Changed: No longer checking aadhaar/pan/dl
    // Trust is now based on ratings and trip history
    return false; // Deprecated - use rating/trip-based trust instead
  }

  /// Returns trust level: 0 (new), 1 (regular), 2 (trusted)
  /// Based on ratings and trips, NOT documents
  int get documentLevel {
    // Changed: Now based on behavior, not documents
    return 0; // Deprecated - use rating-based trust levels instead
  }

  /// Returns empty list (documents no longer stored)
  List<String> get uploadedDocuments {
    // Personal ID documents removed for legal safety
    return [];
  }
}
