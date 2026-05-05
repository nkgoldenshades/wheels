/// Timezone utility functions for displaying times with timezone hints
class TimezoneUtils {
  /// Get the current timezone abbreviation (e.g., "IST", "EST", "GMT")
  static String getTimezoneAbbreviation() {
    final now = DateTime.now();
    final timeZoneName = now.timeZoneName;
    
    // Return the timezone abbreviation
    // Examples: "IST", "EST", "PST", "GMT", etc.
    return timeZoneName;
  }

  /// Format time with timezone hint
  /// Example: "09:30 AM IST"
  static String formatTimeWithTimezone(DateTime time, {bool show24Hour = false}) {
    if (show24Hour) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m ${getTimezoneAbbreviation()}';
    } else {
      final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
      final minute = time.minute.toString().padLeft(2, '0');
      final period = time.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period ${getTimezoneAbbreviation()}';
    }
  }

  /// Format time range with timezone hint
  /// Example: "09:30 AM - 05:00 PM IST"
  static String formatTimeRangeWithTimezone(
    DateTime start,
    DateTime end, {
    bool show24Hour = false,
  }) {
    final tz = getTimezoneAbbreviation();
    
    if (show24Hour) {
      final startH = start.hour.toString().padLeft(2, '0');
      final startM = start.minute.toString().padLeft(2, '0');
      final endH = end.hour.toString().padLeft(2, '0');
      final endM = end.minute.toString().padLeft(2, '0');
      return '$startH:$startM - $endH:$endM $tz';
    } else {
      final startHour = start.hour % 12 == 0 ? 12 : start.hour % 12;
      final startMinute = start.minute.toString().padLeft(2, '0');
      final startPeriod = start.hour >= 12 ? 'PM' : 'AM';
      
      final endHour = end.hour % 12 == 0 ? 12 : end.hour % 12;
      final endMinute = end.minute.toString().padLeft(2, '0');
      final endPeriod = end.hour >= 12 ? 'PM' : 'AM';
      
      return '$startHour:$startMinute $startPeriod - $endHour:$endMinute $endPeriod $tz';
    }
  }

  /// Format date and time with timezone
  /// Example: "Jan 26, 2025 09:30 AM IST"
  static String formatDateTimeWithTimezone(DateTime dateTime, {bool show24Hour = false}) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    
    final timeStr = formatTimeWithTimezone(dateTime, show24Hour: show24Hour);
    
    return '$month $day, $year $timeStr';
  }

  /// Format short date with time and timezone
  /// Example: "26/1 09:30 IST"
  static String formatShortDateTimeWithTimezone(DateTime dateTime, {bool show24Hour = true}) {
    final tz = getTimezoneAbbreviation();
    
    if (show24Hour) {
      final h = dateTime.hour.toString().padLeft(2, '0');
      final m = dateTime.minute.toString().padLeft(2, '0');
      return '${dateTime.day}/${dateTime.month} $h:$m $tz';
    } else {
      final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '${dateTime.day}/${dateTime.month} $hour:$minute $period $tz';
    }
  }
}

