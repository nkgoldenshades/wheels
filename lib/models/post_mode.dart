enum PostMode {
  instant,
  waitForFull,
  fullPost,
}

extension PostModeExtension on PostMode {
  String get displayName {
    switch (this) {
      case PostMode.instant:
        return 'Instant Booking';
      case PostMode.waitForFull:
        return 'Wait for Full';
      case PostMode.fullPost:
        return 'Full Post Mode';
    }
  }
  
  String get description {
    switch (this) {
      case PostMode.instant:
        return 'Customers can book individual seats immediately';
      case PostMode.waitForFull:
        return 'Wait until all seats are filled before confirming';
      case PostMode.fullPost:
        return 'Customer must book all remaining slots in this post';
    }
  }
  
  String get dbValue {
    switch (this) {
      case PostMode.instant:
        return 'instant';
      case PostMode.waitForFull:
        return 'wait_for_full';
      case PostMode.fullPost:
        return 'full_post';
    }
  }
  
  static PostMode fromDbValue(String value) {
    switch (value) {
      case 'instant':
        return PostMode.instant;
      case 'wait_for_full':
        return PostMode.waitForFull;
      case 'full_post':
      case 'full_vehicle': // Backward compatibility
        return PostMode.fullPost;
      default:
        return PostMode.instant;
    }
  }
}



