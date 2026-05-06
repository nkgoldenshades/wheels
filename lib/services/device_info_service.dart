import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Collected snapshot of the current device + network session.
class DeviceSession {
  final String? ipAddress;
  final String? country;
  final String? city;
  final String? isp;
  final String platform;       // 'android' | 'ios' | 'web' | 'windows' | 'macos' | 'linux'
  final String? deviceModel;
  final String? osVersion;
  final String? deviceId;      // Android ID / iOS identifierForVendor / web fingerprint
  final String? browser;       // web only
  final String? appVersion;
  final DateTime collectedAt;

  const DeviceSession({
    this.ipAddress,
    this.country,
    this.city,
    this.isp,
    required this.platform,
    this.deviceModel,
    this.osVersion,
    this.deviceId,
    this.browser,
    this.appVersion,
    required this.collectedAt,
  });

  Map<String, dynamic> toJson() => {
        'ip_address': ipAddress,
        'country': country,
        'city': city,
        'isp': isp,
        'platform': platform,
        'device_model': deviceModel,
        'os_version': osVersion,
        'device_id': deviceId,
        'browser': browser,
        'app_version': appVersion,
        'collected_at': collectedAt.toIso8601String(),
      };

  @override
  String toString() => toJson().toString();
}

/// Collects device info + public IP and persists a login session row
/// in the `device_sessions` Supabase table.
class DeviceInfoService {
  DeviceInfoService._();
  static final DeviceInfoService instance = DeviceInfoService._();

  final DeviceInfoPlugin _plugin = DeviceInfoPlugin();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Collect device + IP details. Never throws — returns partial data on error.
  Future<DeviceSession> collect() async {
    final deviceFuture = _collectDeviceInfo();
    final ipFuture = _fetchIpInfo();

    final device = await deviceFuture;
    final ip = await ipFuture;

    return DeviceSession(
      ipAddress: ip['ip'],
      country: ip['country'],
      city: ip['city'],
      isp: ip['isp'],
      platform: device['platform'] ?? _platformName(),
      deviceModel: device['model'],
      osVersion: device['osVersion'],
      deviceId: device['deviceId'],
      browser: device['browser'],
      appVersion: '1.0.0',
      collectedAt: DateTime.now().toUtc(),
    );
  }

  /// Collect device info and save a login session row for [userId].
  /// Fire-and-forget — call without awaiting from login flow.
  Future<void> recordLoginSession(String userId) async {
    try {
      final session = await collect();
      await _saveToSupabase(userId, session);
      debugPrint('📱 Device session recorded for $userId: ${session.ipAddress} / ${session.platform}');
    } catch (e) {
      debugPrint('⚠️ DeviceInfoService.recordLoginSession failed (non-fatal): $e');
    }
  }

  // ── Device Info ────────────────────────────────────────────────────────────

  Future<Map<String, String?>> _collectDeviceInfo() async {
    try {
      if (kIsWeb) return await _webInfo();
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return await _androidInfo();
        case TargetPlatform.iOS:
          return await _iosInfo();
        case TargetPlatform.windows:
          return await _windowsInfo();
        case TargetPlatform.macOS:
          return await _macosInfo();
        case TargetPlatform.linux:
          return await _linuxInfo();
        default:
          return {'platform': _platformName()};
      }
    } catch (e) {
      debugPrint('⚠️ _collectDeviceInfo error: $e');
      return {'platform': _platformName()};
    }
  }

  Future<Map<String, String?>> _androidInfo() async {
    final info = await _plugin.androidInfo;
    return {
      'platform': 'android',
      'model': '${info.manufacturer} ${info.model}',
      'osVersion': 'Android ${info.version.release} (SDK ${info.version.sdkInt})',
      'deviceId': info.id, // Android hardware serial / build ID
    };
  }

  Future<Map<String, String?>> _iosInfo() async {
    final info = await _plugin.iosInfo;
    return {
      'platform': 'ios',
      'model': info.utsname.machine,
      'osVersion': '${info.systemName} ${info.systemVersion}',
      'deviceId': info.identifierForVendor,
    };
  }

  Future<Map<String, String?>> _webInfo() async {
    final info = await _plugin.webBrowserInfo;
    return {
      'platform': 'web',
      'model': info.platform,
      'osVersion': info.appVersion,
      'deviceId': null, // No stable device ID on web
      'browser': '${info.browserName.name} ${info.appVersion ?? ""}',
    };
  }

  Future<Map<String, String?>> _windowsInfo() async {
    final info = await _plugin.windowsInfo;
    return {
      'platform': 'windows',
      'model': info.computerName,
      'osVersion': 'Windows ${info.majorVersion}.${info.minorVersion}',
      'deviceId': info.deviceId,
    };
  }

  Future<Map<String, String?>> _macosInfo() async {
    final info = await _plugin.macOsInfo;
    return {
      'platform': 'macos',
      'model': info.model,
      'osVersion': 'macOS ${info.osRelease}',
      'deviceId': info.systemGUID,
    };
  }

  Future<Map<String, String?>> _linuxInfo() async {
    final info = await _plugin.linuxInfo;
    return {
      'platform': 'linux',
      'model': info.prettyName,
      'osVersion': info.version,
      'deviceId': info.machineId,
    };
  }

  // ── IP Info ────────────────────────────────────────────────────────────────

  /// Tries multiple free IP-info APIs in order, returns first success.
  Future<Map<String, String?>> _fetchIpInfo() async {
    // List of fallback endpoints — all free, no key required
    final endpoints = [
      _tryIpApi,       // ip-api.com  (most detailed, 45 req/min free)
      _tryIpify,       // ipify.org   (IP only, very reliable)
      _tryIpInfo,      // ipinfo.io   (50k req/month free)
    ];

    for (final fn in endpoints) {
      try {
        final result = await fn().timeout(const Duration(seconds: 4));
        if (result['ip'] != null) return result;
      } catch (_) {
        // try next
      }
    }

    debugPrint('⚠️ All IP APIs failed — storing without IP');
    return {};
  }

  Future<Map<String, String?>> _tryIpApi() async {
    final res = await http.get(
      Uri.parse('http://ip-api.com/json/?fields=status,query,country,city,isp'),
      headers: {'Accept': 'application/json'},
    );
    if (res.statusCode != 200) return {};
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'success') return {};
    return {
      'ip': data['query'] as String?,
      'country': data['country'] as String?,
      'city': data['city'] as String?,
      'isp': data['isp'] as String?,
    };
  }

  Future<Map<String, String?>> _tryIpify() async {
    final res = await http.get(
      Uri.parse('https://api.ipify.org?format=json'),
      headers: {'Accept': 'application/json'},
    );
    if (res.statusCode != 200) return {};
    final data = json.decode(res.body) as Map<String, dynamic>;
    return {'ip': data['ip'] as String?};
  }

  Future<Map<String, String?>> _tryIpInfo() async {
    final res = await http.get(
      Uri.parse('https://ipinfo.io/json'),
      headers: {'Accept': 'application/json'},
    );
    if (res.statusCode != 200) return {};
    final data = json.decode(res.body) as Map<String, dynamic>;
    return {
      'ip': data['ip'] as String?,
      'country': data['country'] as String?,
      'city': data['city'] as String?,
      'isp': data['org'] as String?,
    };
  }

  // ── Supabase Persistence ───────────────────────────────────────────────────

  Future<void> _saveToSupabase(String userId, DeviceSession session) async {
    final supabase = Supabase.instance.client;
    await supabase.from('device_sessions').insert({
      'user_id': userId,
      ...session.toJson(),
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }
}


