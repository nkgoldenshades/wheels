# 🌍 Timezone Setting Implementation Guide

## Current Behavior (Automatic)

The app currently uses **device timezone automatically**:
- Indian user → sees IST
- US user → sees EST
- UK user → sees GMT

This is the **standard approach** and works well for most apps.

---

## When to Add Timezone Setting

Add a timezone setting if you need:

1. ✅ **Business operates in specific timezone** (e.g., "All times in IST")
2. ✅ **Users travel frequently** (e.g., "I'm in US but want to see India times")
3. ✅ **Show both timezones** (e.g., "9:30 AM IST (11:00 PM EST)")

---

## Implementation Steps

### Step 1: Add Timezone to User Profile

```dart
// lib/models/user_profile.dart
class UserProfile {
  final String id;
  final String name;
  // ... other fields
  
  // NEW: Timezone preference
  final String timezone; // 'auto', 'Asia/Kolkata', 'America/New_York', etc.
  
  UserProfile({
    required this.id,
    required this.name,
    this.timezone = 'auto', // Default: use device timezone
  });
}
```

### Step 2: Create Timezone Service

```dart
// lib/services/timezone_service.dart
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class TimezoneService {
  static final TimezoneService instance = TimezoneService._();
  TimezoneService._();

  // Initialize timezone database
  Future<void> init() async {
    tz.initializeTimeZones();
  }

  // Get user's preferred timezone
  String getUserTimezone(String? preference) {
    if (preference == null || preference == 'auto') {
      // Use device timezone
      return DateTime.now().timeZoneName;
    }
    return preference;
  }

  // Convert UTC to user's timezone
  DateTime toUserTimezone(DateTime utcTime, String? preference) {
    if (preference == null || preference == 'auto') {
      // Use device timezone (automatic)
      return utcTime.toLocal();
    }
    
    // Use specific timezone
    final location = tz.getLocation(preference);
    return tz.TZDateTime.from(utcTime, location);
  }

  // Format time with timezone
  String formatWithTimezone(DateTime time, String? preference) {
    final userTime = toUserTimezone(time, preference);
    final tzAbbr = _getTimezoneAbbreviation(preference);
    return '${_formatTime(userTime)} $tzAbbr';
  }

  String _getTimezoneAbbreviation(String? preference) {
    if (preference == null || preference == 'auto') {
      return DateTime.now().timeZoneName; // IST, EST, etc.
    }
    
    // Map timezone to abbreviation
    final tzMap = {
      'Asia/Kolkata': 'IST',
      'America/New_York': 'EST',
      'Europe/London': 'GMT',
      // Add more as needed
    };
    return tzMap[preference] ?? preference;
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
```

### Step 3: Add Timezone Picker in Settings

```dart
// lib/screens/settings/timezone_setting_screen.dart
import 'package:flutter/material.dart';

class TimezoneSettingScreen extends StatelessWidget {
  final String currentTimezone;
  final Function(String) onTimezoneChanged;

  const TimezoneSettingScreen({
    required this.currentTimezone,
    required this.onTimezoneChanged,
  });

  @override
  Widget build(BuildContext context) {
    final timezones = [
      {'value': 'auto', 'label': 'Automatic (Device Timezone)'},
      {'value': 'Asia/Kolkata', 'label': 'India (IST)'},
      {'value': 'America/New_York', 'label': 'US East (EST)'},
      {'value': 'America/Los_Angeles', 'label': 'US West (PST)'},
      {'value': 'Europe/London', 'label': 'UK (GMT)'},
      {'value': 'Asia/Dubai', 'label': 'UAE (GST)'},
      // Add more as needed
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Timezone Setting')),
      body: ListView.builder(
        itemCount: timezones.length,
        itemBuilder: (context, index) {
          final tz = timezones[index];
          final isSelected = currentTimezone == tz['value'];
          
          return ListTile(
            title: Text(tz['label']!),
            trailing: isSelected ? Icon(Icons.check, color: Colors.green) : null,
            onTap: () {
              onTimezoneChanged(tz['value']!);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}
```

### Step 4: Update Time Display

```dart
// lib/widgets/time_display.dart
import 'package:flutter/material.dart';
import '../services/timezone_service.dart';
import '../services/auth_repository.dart';

class TimeDisplay extends StatelessWidget {
  final DateTime utcTime;
  final bool showTimezone;

  const TimeDisplay({
    required this.utcTime,
    this.showTimezone = true,
  });

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    final timezone = user?.timezone ?? 'auto';
    
    final displayTime = TimezoneService.instance.toUserTimezone(
      utcTime,
      timezone,
    );
    
    final timeStr = TimezoneService.instance.formatWithTimezone(
      utcTime,
      timezone,
    );

    return Text(
      showTimezone ? timeStr : _formatTimeOnly(displayTime),
      style: TextStyle(fontSize: 16),
    );
  }

  String _formatTimeOnly(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
```

### Step 5: Add to pubspec.yaml

```yaml
dependencies:
  timezone: ^0.9.0  # Add this
```

### Step 6: Initialize in main.dart

```dart
// lib/main.dart
import 'services/timezone_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize timezone database
  await TimezoneService.instance.init();
  
  // ... rest of initialization
  
  runApp(MyApp());
}
```

---

## Usage Examples

### Display time with timezone:
```dart
TimeDisplay(
  utcTime: slot.startTime,
  showTimezone: true,  // Shows "9:30 AM IST"
)
```

### Display time without timezone:
```dart
TimeDisplay(
  utcTime: slot.startTime,
  showTimezone: false,  // Shows "9:30 AM"
)
```

### Show both timezones:
```dart
Column(
  children: [
    Text('Your time: ${formatInTimezone(time, userTimezone)}'),
    Text('Service time: ${formatInTimezone(time, 'Asia/Kolkata')}'),
  ],
)
```

---

## Simpler Alternative: Just Show Timezone Hint

If you don't want full timezone setting, just add a hint:

```dart
// Simple approach - just show timezone abbreviation
Text('9:30 AM ${DateTime.now().timeZoneName}')  // "9:30 AM IST"

// Or add a tooltip
Tooltip(
  message: 'Times shown in your local timezone',
  child: Row(
    children: [
      Text('9:30 AM'),
      Icon(Icons.info_outline, size: 16),
    ],
  ),
)
```

---

## Recommendation

### For Your App (Ride-sharing/Booking):

**✅ Keep automatic timezone detection** (current behavior)

**✅ Add timezone hint** (simple):
```dart
Text('9:30 AM IST')  // Just show abbreviation
```

**❌ Don't add timezone setting** unless:
- You operate across multiple timezones
- Users frequently travel
- You get user complaints about timezone confusion

---

## Summary

| Approach | Complexity | Best For |
|----------|-----------|----------|
| **Automatic (current)** | ⭐ Simple | Most apps, local services |
| **Show timezone hint** | ⭐⭐ Easy | Clarify without complexity |
| **Full timezone setting** | ⭐⭐⭐⭐ Complex | Multi-timezone businesses |

**My recommendation:** Keep automatic + add timezone hint (e.g., "9:30 AM IST")

This gives clarity without adding complexity! 🎯
