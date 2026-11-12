enum UserTier {
  basic, // Free users - anyone can book
  verified, // Premium subscribers - financially committed users
  expert, // Elite subscribers - heavy investment & work dedication
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
        return 'Free users - anyone can book';
      case UserTier.verified:
        return 'Premium subscribers - financially committed users';
      case UserTier.expert:
        return 'Elite subscribers - heavy investment & work dedication';
    }
  }

  bool canAcceptTier(UserTier customerTier) {
    switch (this) {
      case UserTier.basic:
        return customerTier == UserTier.basic;
      case UserTier.verified:
        return customerTier == UserTier.basic ||
            customerTier == UserTier.verified;
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
