import 'package:flutter/material.dart';
import '../services/profile_repository.dart';

/// Shows a blue verified checkmark badge next to verified profiles
class VerifiedBadge extends StatelessWidget {
  final String userId;
  final double size;

  const VerifiedBadge({
    super.key,
    required this.userId,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProfileInfo>(
      valueListenable: ProfileRepository.instance.profile,
      builder: (context, profile, child) {
        // Check if this user is verified
        final isVerified = _isProfileVerified(userId);
        
        if (!isVerified) return const SizedBox.shrink();
        
        return Tooltip(
          message: 'Verified Profile',
          child: Icon(
            Icons.verified,
            size: size,
            color: Colors.blue,
          ),
        );
      },
    );
  }

  /// Check if profile has any document verified
  bool _isProfileVerified(String userId) {
    // For now, check current user's profile
    // In future, fetch from ProfileNameRegistry or cache
    final profile = ProfileRepository.instance.profile.value;
    
    if (profile.id != userId) {
      // Can't check other users without fetching their profile
      // Return false for now, or implement a cache/registry lookup
      return false;
    }
    
    // Profile is verified if any document is verified
    return profile.aadhaarVerified || 
           profile.panVerified || 
           profile.dlVerified;
  }
}

/// Extension to check if profile is verified
extension ProfileVerification on ProfileInfo {
  /// Returns true if profile has at least one document verified
  bool get isVerified {
    return aadhaarVerified || panVerified || dlVerified;
  }
  
  /// Returns verification level: 0 (none), 1 (partial), 2 (full)
  int get verificationLevel {
    int count = 0;
    if (aadhaarVerified) count++;
    if (panVerified) count++;
    if (dlVerified) count++;
    
    if (count == 0) return 0; // Not verified
    if (count < 3) return 1; // Partially verified
    return 2; // Fully verified (all 3 documents)
  }
  
  /// Returns a list of verified documents
  List<String> get verifiedDocuments {
    final docs = <String>[];
    if (aadhaarVerified) docs.add('Aadhaar');
    if (panVerified) docs.add('PAN');
    if (dlVerified) docs.add('Driving License');
    return docs;
  }
}
