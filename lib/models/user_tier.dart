enum UserTier {
  basic,    // Free - everyone starts here
  verified, // Paid upgrade - more trust
  expert,   // Premium - highest trust
}

extension UserTierExtension on UserTier {
  String get displayName {
    switch (this) {
      case UserTier.basic:
        return 'Basic';
      case UserTier.verified:
        return 'Verified';
      case UserTier.expert:
        return 'Expert';
    }
  }

  String get icon {
    switch (this) {
      case UserTier.basic:
        return '👤';
      case UserTier.verified:
        return '✓';
      case UserTier.expert:
        return '⭐';
    }
  }

  String get description {
    switch (this) {
      case UserTier.basic:
        return 'Standard access';
      case UserTier.verified:
        return 'Verified identity & documents';
      case UserTier.expert:
        return 'Premium trusted member';
    }
  }

  bool canAcceptTier(UserTier customerTier) {
    switch (this) {
      case UserTier.basic:
        return customerTier == UserTier.basic;
      case UserTier.verified:
        return customerTier == UserTier.basic || customerTier == UserTier.verified;
      case UserTier.expert:
        return true; // Can accept all
    }
  }

  List<UserTier> allowedMinTiers() {
    switch (this) {
      case UserTier.basic:
        return [UserTier.basic];
      case UserTier.verified:
        return [UserTier.basic, UserTier.verified];
      case UserTier.expert:
        return [UserTier.basic, UserTier.verified, UserTier.expert];
    }
  }
}

