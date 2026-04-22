/// Lifecycle status of a post (provider's service listing).
enum PostStatus {
  active,     // Accepting bookings, end_time in the future
  ended,      // end_time passed, trip completed normally — is_active = false
  paused,     // Provider manually paused — is_active = false, end_time still future
  full,       // All capacity booked — is_active = false automatically
  cancelled,  // Provider cancelled the post entirely
}

extension PostStatusX on PostStatus {
  String get label {
    switch (this) {
      case PostStatus.active:    return 'Active';
      case PostStatus.ended:     return 'Ended';
      case PostStatus.paused:    return 'Paused';
      case PostStatus.full:      return 'Full';
      case PostStatus.cancelled: return 'Cancelled';
    }
  }

  String get dbValue {
    switch (this) {
      case PostStatus.active:    return 'active';
      case PostStatus.ended:     return 'ended';
      case PostStatus.paused:    return 'paused';
      case PostStatus.full:      return 'full';
      case PostStatus.cancelled: return 'cancelled';
    }
  }

  bool get isActive => this == PostStatus.active;

  static PostStatus fromString(String? value) {
    switch (value) {
      case 'active':    return PostStatus.active;
      case 'ended':     return PostStatus.ended;
      case 'paused':    return PostStatus.paused;
      case 'full':      return PostStatus.full;
      case 'cancelled': return PostStatus.cancelled;
      default:          return PostStatus.active;
    }
  }

  /// Derive status from is_active + end_time (for backward compat with old rows)
  static PostStatus fromFields({
    required bool isAvailable,
    required DateTime endTime,
    String? explicitStatus,
  }) {
    if (explicitStatus != null && explicitStatus != 'active') {
      return fromString(explicitStatus);
    }
    if (!isAvailable && DateTime.now().isAfter(endTime)) return PostStatus.ended;
    if (!isAvailable) return PostStatus.paused;
    return PostStatus.active;
  }
}
