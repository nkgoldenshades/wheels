import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Timezone utility functions for displaying times with timezone hints
class TimezoneUtils {
  // Cache: coordinates string → timezone offset in hours
  static final Map<String, String> _tzCache = {};

  /// Get the current device timezone abbreviation (e.g., "IST", "EST", "GMT")
  static String getTimezoneAbbreviation() {
    return DateTime.now().timeZoneName;
  }

  /// Get timezone abbreviation from lat/lng using TimeZoneDB API
  /// Falls back to device timezone if lookup fails
  static Future<String> getTimezoneFromCoords(double lat, double lng) async {
    final key = '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';
    if (_tzCache.containsKey(key)) return _tzCache[key]!;

    try {
      // Use free timezone API (no key needed)
      final response = await http.get(
        Uri.parse('https://timeapi.io/api/timezone/coordinate?latitude=$lat&longitude=$lng'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tzName = data['timeZone'] as String? ?? '';
        // Convert IANA timezone to abbreviation
        final abbr = _ianaToAbbr(tzName);
        _tzCache[key] = abbr;
        return abbr;
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Timezone lookup failed: $e');
    }

    // Fallback to device timezone
    return getTimezoneAbbreviation();
  }

  /// Convert IANA timezone name to abbreviation
  static String _ianaToAbbr(String iana) {
    const map = {
      'Asia/Kolkata': 'IST',
      'Asia/Calcutta': 'IST',
      'America/New_York': 'EST',
      'America/Los_Angeles': 'PST',
      'America/Chicago': 'CST',
      'America/Denver': 'MST',
      'Europe/London': 'GMT',
      'Europe/Paris': 'CET',
      'Europe/Berlin': 'CET',
      'Asia/Dubai': 'GST',
      'Asia/Singapore': 'SGT',
      'Asia/Tokyo': 'JST',
      'Asia/Shanghai': 'CST',
      'Asia/Hong_Kong': 'HKT',
      'Australia/Sydney': 'AEST',
      'Pacific/Auckland': 'NZST',
      'America/Sao_Paulo': 'BRT',
      'Africa/Johannesburg': 'SAST',
      'Asia/Karachi': 'PKT',
      'Asia/Dhaka': 'BST',
      'Asia/Colombo': 'IST',
      'Asia/Kathmandu': 'NPT',
      'Asia/Yangon': 'MMT',
      'Asia/Bangkok': 'ICT',
      'Asia/Jakarta': 'WIB',
      'Asia/Manila': 'PHT',
      'Asia/Seoul': 'KST',
      'Asia/Riyadh': 'AST',
      'Africa/Cairo': 'EET',
      'Africa/Lagos': 'WAT',
      'America/Toronto': 'EST',
      'America/Vancouver': 'PST',
    };
    return map[iana] ?? iana.split('/').last.replaceAll('_', ' ');
  }

  /// Format time with timezone hint (device timezone)
  static String formatTimeWithTimezone(DateTime time, {bool show24Hour = false}) {
    final tz = getTimezoneAbbreviation();
    return _formatTime(time, tz, show24Hour: show24Hour);
  }

  /// Format time with a specific timezone label
  static String formatTimeWithTz(DateTime time, String tz, {bool show24Hour = true}) {
    return _formatTime(time, tz, show24Hour: show24Hour);
  }

  static String _formatTime(DateTime time, String tz, {bool show24Hour = false}) {
    if (show24Hour) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m $tz';
    } else {
      final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
      final minute = time.minute.toString().padLeft(2, '0');
      final period = time.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period $tz';
    }
  }

  /// Format time range with timezone hint
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
  static String formatDateTimeWithTimezone(DateTime dateTime, {bool show24Hour = false}) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    final timeStr = formatTimeWithTimezone(dateTime, show24Hour: show24Hour);
    return '$month $day, $year $timeStr';
  }

  /// Format date and time with a specific timezone label
  static String formatDateTimeWithTz(DateTime dateTime, String tz, {bool show24Hour = true}) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    final timeStr = formatTimeWithTz(dateTime, tz, show24Hour: show24Hour);
    return '$month $day, $year $timeStr';
  }

  /// Format short date with time and timezone
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

  /// Format a time range showing FROM timezone for start, TO timezone for end
  /// Used for international routes
  static Future<String> formatInternationalTimeRange({
    required DateTime startTime,
    required DateTime endTime,
    double? fromLat,
    double? fromLng,
    double? toLat,
    double? toLng,
    bool show24Hour = true,
  }) async {
    // Get from/to timezones
    String fromTz = getTimezoneAbbreviation();
    String toTz = getTimezoneAbbreviation();

    if (fromLat != null && fromLng != null) {
      fromTz = await getTimezoneFromCoords(fromLat, fromLng);
    }
    if (toLat != null && toLng != null) {
      toTz = await getTimezoneFromCoords(toLat, toLng);
    }

    final startStr = formatDateTimeWithTz(startTime, fromTz, show24Hour: show24Hour);
    final endStr = formatDateTimeWithTz(endTime, toTz, show24Hour: show24Hour);

    // If same timezone, show once
    if (fromTz == toTz) {
      return '$startStr – ${_formatTime(endTime, toTz, show24Hour: show24Hour)}';
    }

    return '$startStr → $endStr';
  }
}
