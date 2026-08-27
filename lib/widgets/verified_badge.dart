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

    // Profile has documents if any document is uploaded
    return profile.aadhaarVerified || profile.panVerified || profile.dlVerified;
  }
}

/// Extension to check if profile has documents
extension ProfileDocuments on ProfileInfo {
  /// Returns true if profile has at least one document uploaded
  bool get hasDocuments {
    return aadhaarVerified || panVerified || dlVerified;
  }

  /// Returns document level: 0 (none), 1 (partial), 2 (full)
  int get documentLevel {
    int count = 0;
    if (aadhaarVerified) count++;
    if (panVerified) count++;
    if (dlVerified) count++;

    if (count == 0) return 0; // No documents
    if (count < 3) return 1; // Partially uploaded
    return 2; // Fully uploaded (all 3 documents)
  }

  /// Returns a list of uploaded documents
  List<String> get uploadedDocuments {
    final docs = <String>[];
    if (aadhaarVerified) docs.add('Aadhaar');
    if (panVerified) docs.add('PAN');
    if (dlVerified) docs.add('Driving License');
    return docs;
  }
}
