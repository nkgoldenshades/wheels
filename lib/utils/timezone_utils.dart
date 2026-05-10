import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Timezone utility functions for displaying times with timezone hints
class TimezoneUtils {
  // Cache: coordinates string → timezone offset in hours
  static final Map<String, String> _tzCache = {};

  /// Get the current device timezone abbreviation (e.g., "IST (India)")
  static String getTimezoneAbbreviation() {
    final name = DateTime.now().timeZoneName;
    // Convert full names like "India Standard Time" to short form
    final shortMap = {
      'India Standard Time': 'IST (India)',
      'Eastern Standard Time': 'EST (USA)',
      'Pacific Standard Time': 'PST (USA)',
      'Central Standard Time': 'CST (USA)',
      'Mountain Standard Time': 'MST (USA)',
      'GMT Standard Time': 'GMT (UK)',
      'UTC': 'UTC',
      'Arabian Standard Time': 'GST (Dubai)',
      'Singapore Standard Time': 'SGT (Singapore)',
      'Tokyo Standard Time': 'JST (Japan)',
      'China Standard Time': 'CST (China)',
      'AUS Eastern Standard Time': 'AEST (Australia)',
      'New Zealand Standard Time': 'NZST (New Zealand)',
      'E. South America Standard Time': 'BRT (Brazil)',
      'South Africa Standard Time': 'SAST (South Africa)',
      'Pakistan Standard Time': 'PKT (Pakistan)',
      'Bangladesh Standard Time': 'BST (Bangladesh)',
      'Nepal Standard Time': 'NPT (Nepal)',
      'SE Asia Standard Time': 'ICT (Thailand)',
      'Korea Standard Time': 'KST (South Korea)',
      'Arab Standard Time': 'AST (Saudi Arabia)',
      'Egypt Standard Time': 'EET (Egypt)',
      'W. Central Africa Standard Time': 'WAT (Nigeria)',
      'Turkey Standard Time': 'TRT (Turkey)',
      'Russia Time Zone 2': 'MSK (Russia)',
    };
    return shortMap[name] ?? name;
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

  /// Convert IANA timezone name to abbreviation with country/city name
  static String _ianaToAbbr(String iana) {
    const map = {
      'Asia/Kolkata':           'IST (India)',
      'Asia/Calcutta':          'IST (India)',
      'America/New_York':       'EST (New York)',
      'America/Los_Angeles':    'PST (Los Angeles)',
      'America/Chicago':        'CST (Chicago)',
      'America/Denver':         'MST (Denver)',
      'Europe/London':          'GMT (United Kingdom)',
      'Europe/Paris':           'CET (France)',
      'Europe/Berlin':          'CET (Germany)',
      'Asia/Dubai':             'GST (Dubai)',
      'Asia/Singapore':         'SGT (Singapore)',
      'Asia/Tokyo':             'JST (Japan)',
      'Asia/Shanghai':          'CST (China)',
      'Asia/Hong_Kong':         'HKT (Hong Kong)',
      'Australia/Sydney':       'AEST (Australia)',
      'Pacific/Auckland':       'NZST (New Zealand)',
      'America/Sao_Paulo':      'BRT (Brazil)',
      'Africa/Johannesburg':    'SAST (South Africa)',
      'Asia/Karachi':           'PKT (Pakistan)',
      'Asia/Dhaka':             'BST (Bangladesh)',
      'Asia/Colombo':           'IST (Sri Lanka)',
      'Asia/Kathmandu':         'NPT (Nepal)',
      'Asia/Yangon':            'MMT (Myanmar)',
      'Asia/Bangkok':           'ICT (Thailand)',
      'Asia/Jakarta':           'WIB (Indonesia)',
      'Asia/Manila':            'PHT (Philippines)',
      'Asia/Seoul':             'KST (South Korea)',
      'Asia/Riyadh':            'AST (Saudi Arabia)',
      'Africa/Cairo':           'EET (Egypt)',
      'Africa/Lagos':           'WAT (Nigeria)',
      'America/Toronto':        'EST (Canada)',
      'America/Vancouver':      'PST (Canada)',
      'Europe/Moscow':          'MSK (Russia)',
      'Asia/Kabul':             'AFT (Afghanistan)',
      'Asia/Tehran':            'IRST (Iran)',
      'Asia/Baghdad':           'AST (Iraq)',
      'Asia/Kuwait':            'AST (Kuwait)',
      'Asia/Qatar':             'AST (Qatar)',
      'Asia/Bahrain':           'AST (Bahrain)',
      'Asia/Muscat':            'GST (Oman)',
      'Africa/Nairobi':         'EAT (Kenya)',
      'Africa/Addis_Ababa':     'EAT (Ethiopia)',
      'America/Mexico_City':    'CST (Mexico)',
      'America/Argentina/Buenos_Aires': 'ART (Argentina)',
      'America/Lima':           'PET (Peru)',
      'America/Bogota':         'COT (Colombia)',
      'Europe/Amsterdam':       'CET (Netherlands)',
      'Europe/Rome':            'CET (Italy)',
      'Europe/Madrid':          'CET (Spain)',
      'Europe/Stockholm':       'CET (Sweden)',
      'Europe/Zurich':          'CET (Switzerland)',
      'Europe/Warsaw':          'CET (Poland)',
      'Europe/Istanbul':        'TRT (Turkey)',
      'Asia/Tashkent':          'UZT (Uzbekistan)',
      'Asia/Almaty':            'ALMT (Kazakhstan)',
    };
    if (map.containsKey(iana)) return map[iana]!;
    // Fallback: use city name from IANA
    final city = iana.split('/').last.replaceAll('_', ' ');
    return city;
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
