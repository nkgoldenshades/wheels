 
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';
import 'models/seat_layout.dart';
import 'models/service_type.dart';
import 'models/slot.dart';
import 'models/slot_entry.dart';
import 'models/slot_type.dart';
import 'models/vehicle.dart';
import 'models/pickup_mode.dart';
import 'models/post_mode.dart';
import 'models/booking.dart';
import 'models/review.dart';
import 'config/supabase_config.dart';
import 'screens/slot_detail_screen.dart';
import 'screens/vehicle/vehicle_list_screen.dart';
import 'services/booking_repository.dart';
import 'services/slot_repository.dart';
import 'services/vehicle_repository.dart';
import 'services/auth_repository.dart';
import 'services/seat_layout_repository.dart';
import 'services/customer_vehicle_repository.dart';
import 'services/customer_slot_repository.dart';
import 'services/user_post_repository.dart';
import 'services/user_post_acceptance_repository.dart';
import 'services/otp_service.dart';
import 'models/user_post_acceptance.dart';
import 'services/review_repository.dart';
import 'widgets/slot_card.dart';
import 'widgets/booking_confirm_sheet.dart';
import 'widgets/review_dialog.dart';
import 'services/profile_repository.dart';
import 'services/profile_name_registry.dart';
import 'services/app_preferences.dart';
import 'services/passenger_repository.dart';
import 'services/stripe_service.dart';
import 'screens/booking_map_screen.dart';
import 'services/location_autocomplete_service.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/reviews_screen.dart';
import 'screens/ai_chat_page.dart';
import 'widgets/voice_ai_overlay.dart';
import 'services/voice_ai_service.dart';
import 'app_tab_controller.dart';
import 'utils/test_backend_connection.dart';
import 'utils/timezone_utils.dart';

// Global Supabase client getter (lazy evaluation - only accessed when needed)
// Don't use 'final' here because it evaluates immediately before Supabase.initialize()
SupabaseClient get supabase => Supabase.instance.client;

/// Strip |lat,lon|keywords from stored location string — returns display name only
String _cleanLoc(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final t = raw.trim();
  return t.contains('|') ? t.split('|').first.trim() : t;
}

/// Extract lat,lng from location string format: "Address|lat,lng|keywords"
Map<String, double>? _extractLatLng(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split('|');
  if (parts.length < 2) return null;
  
  final coords = parts[1].split(',');
  if (coords.length != 2) return null;
  
  final lat = double.tryParse(coords[0].trim());
  final lng = double.tryParse(coords[1].trim());
  
  if (lat == null || lng == null) return null;
  return {'lat': lat, 'lng': lng};
}

void main() async {
  // Add global error handlers to prevent crashes
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      print('❌ Flutter Error: ${details.exception}');
      print('Stack: ${details.stack}');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      print('❌ Platform Error: $error');
      print('Stack: $stack');
    }
    return true; // Prevent crash
  };

  WidgetsFlutterBinding.ensureInitialized();

  // CRITICAL: Initialize Firebase FIRST before starting app
  // This prevents splash screen from accessing Firebase before it's ready
  if (kDebugMode) print('⏳ Initializing Firebase...');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) print('✅ Firebase initialized');
  } catch (e) {
    // Check if already initialized
    try {
      Firebase.app();
      if (kDebugMode) print('✅ Firebase already initialized');
    } catch (_) {
      if (kDebugMode) print('⚠️ Firebase unavailable: $e');
    }
  }
  
  // Initialize AuthRepository immediately (splash screen needs it)
  if (kDebugMode) print('⏳ Initializing AuthRepository...');
  try {
    await AuthRepository.instance.init();
    if (kDebugMode) print('✅ AuthRepository initialized');
  } catch (e) {
    if (kDebugMode) print('⚠️ AuthRepository init failed: $e');
  }
  
  // Now start app - Firebase and Auth are ready
  if (kDebugMode) print('🚀 Starting app...');
  runApp(const MyApp());
  
  // Initialize other services in background (non-blocking)
  _initializeServicesInBackground();
}

// Background initialization that doesn't block app startup
void _initializeServicesInBackground() async {
  try {
    if (kDebugMode) print('🔧 Starting background initialization...');
    
    // Helper function to wrap repository inits with timeout
    Future<void> initWithTimeout(Future<void> future, String name) async {
      try {
        if (kDebugMode) print('⏳ Starting $name...');
        await future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('$name initialization timed out', const Duration(seconds: 5));
          },
        );
        if (kDebugMode) print('✅ $name initialized');
      } catch (e) {
        if (kDebugMode) print('⚠️ $name init failed/timed out: $e');
        // Don't rethrow — let app continue
      }
    }
    
    // Firebase and AuthRepository are already initialized in main(), skip them here
    
    // Check if running on web and warn about CORS
    if (kIsWeb) {
      if (kDebugMode) {
        print('⚠️ ═══════════════════════════════════════════════════════');
        print('⚠️ WARNING: Running on WEB - CORS issues may occur!');
        print('⚠️ If you see "Failed to fetch" errors:');
        print('⚠️   1. Run on mobile/desktop instead: flutter run -d android');
        print('⚠️   2. Or configure CORS in Supabase Dashboard');
        print('⚠️   3. See FIX_SUPABASE_CORS_FOR_WEB.md for details');
        print('⚠️ ═══════════════════════════════════════════════════════');
      }
    }
    
    // Initialize Supabase with Firebase JWT
    if (kDebugMode) print('⏳ Starting Supabase...');
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
        accessToken: () async {
          final user = firebase_auth.FirebaseAuth.instance.currentUser;
          if (user == null) {
            if (kDebugMode) print('🔑 No Firebase user - guest mode (using anon key)');
            return null; // Supabase will use anon key automatically
          }
          try {
            final token = await user.getIdToken(true);
            if (token == null || token.isEmpty) {
              if (kDebugMode) print('⚠️ Firebase token is empty - falling back to anon');
              return null;
            }
            if (kDebugMode) {
              print('🔑 Firebase UID: ${user.uid}');
              print('🔑 Sending Firebase JWT to Supabase');
            }
            return token;
          } catch (e) {
            if (kDebugMode) print('⚠️ Failed to get Firebase token: $e');
            return null; // Fallback to anon key on error
          }
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Supabase initialization timed out', const Duration(seconds: 10));
        },
      );
      if (kDebugMode) print('✅ Supabase initialized');
    } catch (e) {
      if (kDebugMode) print('❌ Supabase initialization error: $e');
      // Continue anyway - app can work with limited functionality
    }

    // Initialize core services with timeout protection (AuthRepository already done)
    await initWithTimeout(AppPreferences.instance.init(), 'AppPreferences');
    
    // Initialize ProfileRepository with timeout protection (already had timeout)
    if (kDebugMode) print('⏳ Starting ProfileRepository...');
    try {
      await ProfileRepository.instance.init().timeout(
        const Duration(seconds: 10), // Reduced from 30 to 10 seconds
        onTimeout: () {
          if (kDebugMode) print('⏰ ProfileRepository init timed out');
          throw TimeoutException('ProfileRepository initialization timed out', const Duration(seconds: 10));
        },  
      );
      if (kDebugMode) print('✅ ProfileRepository initialized');
    } catch (e) {
      if (kDebugMode) print('❌ ProfileRepository init failed: $e');
      // Continue with app initialization even if profile fails
    }
    
    // Initialize all other repositories with timeout protection
    // CRITICAL: Load vehicles FIRST, then slots (slots need vehicles to build entries)
    await initWithTimeout(VehicleRepository.instance.init(), 'VehicleRepository');
    await initWithTimeout(CustomerVehicleRepository.instance.init(), 'CustomerVehicleRepository');
    
    // Now load slots (they can find vehicles now)
    await initWithTimeout(SlotRepository.instance.init(), 'SlotRepository');
    await initWithTimeout(CustomerSlotRepository.instance.init(), 'CustomerSlotRepository');
    
    // Load other repositories
    await initWithTimeout(UserPostRepository.instance.init(), 'UserPostRepository');
    await initWithTimeout(UserPostAcceptanceRepository.instance.init(), 'UserPostAcceptanceRepository');
    await initWithTimeout(SeatLayoutRepository.instance.init(), 'SeatLayoutRepository');
    await initWithTimeout(BookingRepository.instance.init(), 'BookingRepository');
    await initWithTimeout(PassengerRepository.instance.init(), 'PassengerRepository');
    await initWithTimeout(ReviewRepository.instance.init(), 'ReviewRepository');
    
    // Force refresh slot entries after all data is loaded
    // This ensures slots find their vehicles even if there was a timing issue
    if (kDebugMode) print('🔄 Refreshing slot entries after all data loaded...');
    try {
      await SlotRepository.instance.loadSlots();
      await CustomerSlotRepository.instance.init(); // Reload to rebuild entries
      if (kDebugMode) print('✅ Slot entries refreshed');
    } catch (e) {
      if (kDebugMode) print('⚠️ Failed to refresh slot entries: $e');
    }

    // Test Supabase connection (only in debug mode)
    if (kDebugMode) {
      debugPrint('🔗 Supabase connection configured');
      debugPrint('📍 URL: ${SupabaseConfig.url}');
      debugPrint('🔑 Auth: Firebase JWT → Supabase RLS');
      
      // Run backend connection tests
      await BackendConnectionTest.runAllTests();
    }

    // Initialize Stripe for payments with timeout
    await initWithTimeout(StripeService.instance.init(), 'StripeService');
    
    // Initialize Voice AI service with timeout (this was the last call - likely culprit!)
    await initWithTimeout(VoiceAIService().initialize(), 'VoiceAIService');
    
    if (kDebugMode) print('🎉 All services initialized successfully!');
    
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('❌ Background initialization error: $e');
      print('📍 Stack trace: $stackTrace');
      print('ℹ️ App will continue running with limited functionality');
    }
  }
}

class EditUserPostPage extends StatefulWidget {
  final UserPost post;
  const EditUserPostPage({super.key, required this.post});

  @override
  State<EditUserPostPage> createState() => _EditUserPostPageState();
}

class _EditUserPostPageState extends State<EditUserPostPage> {
  late ServiceType _serviceType;
  late SlotType _slotType;

  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  late final TextEditingController _baseController;
  late final TextEditingController _radiusController;
  late final TextEditingController _budgetController;
  late final TextEditingController _notesController;

  int _persons = 1;
  DateTime? _startTime;
  DateTime? _endTime;

  bool _requiresVerifiedVehicle = false;
  bool _requiresExpertVehicle = false;

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    _serviceType = p.serviceType;
    _slotType = p.slotType;
    _fromController = TextEditingController(text: p.fromLocation ?? '');
    _toController = TextEditingController(text: p.toLocation ?? '');
    _baseController = TextEditingController(text: p.baseLocation ?? '');
    _radiusController = TextEditingController(
      text: (p.radius ?? 10).toString(),
    );
    _budgetController = TextEditingController(text: p.budget.toString());
    _notesController = TextEditingController(text: p.notes ?? '');
    _persons = p.persons;
    _startTime = p.startTime;
    _endTime = p.endTime;
    _requiresVerifiedVehicle = p.requiresVerifiedVehicle;
    _requiresExpertVehicle = p.requiresExpertVehicle;
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _baseController.dispose();
    _radiusController.dispose();
    _budgetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = TimeOfDay.fromDateTime(isStart ? _startTime! : _endTime!);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final date = isStart ? _startTime! : _endTime!;
    final newDt = DateTime(
      date.year,
      date.month,
      date.day,
      picked.hour,
      picked.minute,
    );
    setState(() {
      if (isStart) {
        _startTime = newDt;
        if (_endTime != null && _endTime!.isBefore(_startTime!)) {
          _endTime = _startTime!.add(const Duration(hours: 2));
        }
      } else {
        _endTime = newDt;
      }
    });
  }

  Future<void> _save() async {
    if (_slotType == SlotType.fromTo) {

      if (_fromController.text.trim().isEmpty ||
          _toController.text.trim().isEmpty) {
        _showError('Please enter both from and to locations');
        return;
      }
    } else {
      if (_baseController.text.trim().isEmpty) {
        _showError('Please enter base location');
        return;
      }
    }

    final budget = double.tryParse(_budgetController.text.trim());
    if (budget == null || budget <= 0) {
      _showError('Please enter a valid budget');
      return;
    }

    final radius = _slotType == SlotType.fromRange
        ? double.tryParse(_radiusController.text)
        : null;

    final updated = widget.post.copyWith(
      serviceType: _serviceType,
      slotType: _slotType,
      fromLocation: _slotType == SlotType.fromTo
          ? _fromController.text.trim()
          : null,
      toLocation: _slotType == SlotType.fromTo
          ? _toController.text.trim()
          : null,
      baseLocation: _slotType == SlotType.fromRange
          ? _baseController.text.trim()
          : null,
      radius: radius,
      startTime: _startTime,
      endTime: _endTime,
      budget: budget,
      persons: _persons,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      requiresVerifiedVehicle: _requiresVerifiedVehicle,
      requiresExpertVehicle: _requiresExpertVehicle,
    );

    try {
      await UserPostRepository.instance.update(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post updated')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to update post: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<ServiceType>(
            initialValue: _serviceType,
            decoration: const InputDecoration(
              labelText: 'Service',
              border: OutlineInputBorder(),
            ),
            items: ServiceType.values
                .map(
                  (s) => DropdownMenuItem(value: s, child: Text(s.displayName)),
                )
                .toList(growable: false),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _serviceType = v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<SlotType>(
            initialValue: _slotType,
            decoration: const InputDecoration(
              labelText: 'Route type',
              border: OutlineInputBorder(),
            ),
            items: SlotType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.displayName)))
                .toList(growable: false),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _slotType = v);
            },
          ),
          const SizedBox(height: 12),
          if (_slotType == SlotType.fromTo) ...[
            TextField(
              controller: _fromController,
              decoration: const InputDecoration(
                labelText: 'From',
                hintText: 'e.g. Chennai Central',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _toController,
              decoration: const InputDecoration(
                labelText: 'To',
                hintText: 'e.g. Bangalore City Junction',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
          ] else ...[
            TextField(
              controller: _baseController,
              decoration: const InputDecoration(
                labelText: 'Base location',
                hintText: 'e.g. Mumbai CST',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.my_location),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _radiusController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Radius (km)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(isStart: true),
                  child: Text('Start: ${_fmtTime(_startTime!)}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(isStart: false),
                  child: Text('End: ${_fmtTime(_endTime!)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Budget ()',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Persons'),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _persons > 1
                    ? () => setState(() => _persons -= 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_persons'),
              IconButton(
                onPressed: () => setState(() => _persons += 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Needed vehicle tags',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _requiresVerifiedVehicle,
            onChanged: (v) => setState(() => _requiresVerifiedVehicle = v),
            title: const Text('Verified vehicle required'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _requiresExpertVehicle,
            onChanged: (v) => setState(() => _requiresExpertVehicle = v),
            title: const Text('Expert vehicle required'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Terms (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save Changes')),
        ],
      ),
    );
  }

  String _fmtTime(DateTime d) {
    return TimezoneUtils.formatTimeWithTimezone(d, show24Hour: true);
  }
}

ImageProvider? _profileAvatarProvider(ProfileInfo info) {
  final avatar = info.avatarUrl;
  if (avatar == null || avatar.trim().isEmpty) return null;

  final a = avatar.trim();
  if (a.startsWith('http://') || a.startsWith('https://')) {
    return NetworkImage(a);
  }

  try {
    return MemoryImage(base64Decode(a));
  } catch (_) {
    return null;
  }
}

Future<void> _pickAndSaveAvatar(BuildContext context) async {
  // Step 1: Ask user if they want verified or normal upload
  final uploadType = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Upload Profile Photo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Choose how you want to upload your profile photo:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 20),

          // Option 1: Verified Upload
          InkWell(
            onTap: () => Navigator.pop(context, 'verified'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: Colors.green.withValues(alpha: 0.1),
              ),
              child: const Column(
                children: [
                  Icon(Icons.verified_user, color: Colors.green, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'Verified Upload',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Upload + Live verification\n(Recommended for trust)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Option 2: Normal Upload
          InkWell(
            onTap: () => Navigator.pop(context, 'normal'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.photo_library, color: Colors.grey, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'Normal Upload',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Quick upload from gallery\n(No verification)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );

  if (uploadType == null || !context.mounted) return;

  // Step 2: Pick image from gallery
  // Note: ImagePicker not available on Windows - using placeholder
  if (!context.mounted) return;
  
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Image picker not available on this platform. Use web version for full functionality.'),
      backgroundColor: Colors.orange,
    ),
  );
}

Widget _buildDocumentUploadCard(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
  required String documentType,
  String? frontBase64,
  String? backBase64,
}) {
  Uint8List? tryDecode(String? s) {
    if (s == null) return null;
    try {
      final normalized = s.contains(',') ? s.split(',').last : s;
      if (normalized.trim().isEmpty) return null;
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  Future<void> openPreview(Uint8List bytes, String sideLabel) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$title ($sideLabel)',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final frontBytes = tryDecode(frontBase64);
  final backBytes = tryDecode(backBase64);

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _uploadDocument(context, documentType, 'front'),
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Upload Front'),
                ),
              ),
              if (documentType == 'aadhaar' || documentType == 'dl') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _uploadDocument(context, documentType, 'back'),
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Upload Back'),
                  ),
                ),
              ],
            ],
          ),
          if (frontBytes != null || backBytes != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (frontBytes != null) ...[
                  Expanded(
                    child: InkWell(
                      onTap: () => openPreview(frontBytes, 'front'),
                      borderRadius: BorderRadius.circular(10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AspectRatio(
                          aspectRatio: 3 / 2,
                          child: Image.memory(frontBytes, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const Expanded(child: SizedBox()),
                ],
                if (documentType == 'aadhaar' || documentType == 'dl') ...[
                  const SizedBox(width: 8),
                  if (backBytes != null) ...[
                    Expanded(
                      child: InkWell(
                        onTap: () => openPreview(backBytes, 'back'),
                        borderRadius: BorderRadius.circular(10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: AspectRatio(
                            aspectRatio: 3 / 2,
                            child: Image.memory(backBytes, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const Expanded(child: SizedBox()),
                  ],
                ],
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

Future<void> _uploadDocument(
  BuildContext context,
  String documentType,
  String side,
) async {
  // Document upload functionality not available on Windows
  // Use web version for full document upload functionality
  if (!context.mounted) return;
  
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Document upload not available on this platform. Use web version for full functionality.'),
      backgroundColor: Colors.orange,
      duration: Duration(seconds: 3),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VaultWheels',
      debugShowCheckedModeBanner: false, // Remove debug banner
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const Splashscreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/main': (context) => const MainScreen(),
        '/plans': (context) => const PlansScreen(),
        '/expert-support': (context) => const ExpertSupportScreen(),
        '/payment-success': (context) => const PaymentSuccessScreen(),
        '/payment-cancel': (context) => const PaymentCancelScreen(),
      },
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  final String message;

  const StartupErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final display = kReleaseMode
        ? 'Something went wrong while starting the app.'
        : message;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.red),
              const SizedBox(height: 12),
              const Text(
                'Startup error',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(display, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plans'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ValueListenableBuilder<SubscriptionPlan>(
            valueListenable: AppPreferences.instance.subscriptionPlan,
            builder: (context, plan, _) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Current plan: ${plan.name.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _PlanCard(
            title: 'Basic',
            priceLabel: 'BASIC',
            bullets: const [
              'Add images to vehicle',
              'Post requests & book trips',
              'Standard support',
            ],
            isRecommended: false,
            onSelect: () {
              AppPreferences.instance.setSubscriptionPlan(
                SubscriptionPlan.basic,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Basic plan selected')),
              );
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 12),
          _PlanCard(
            title: 'Premium',
            priceLabel: 'PREMIUM',
            bullets: const [
              'Everything in Basic',
              'Verify PAN / Aadhaar',
              'Verify RC / Driving License',
            ],
            isRecommended: true,
            onSelect: () {
              AppPreferences.instance.setSubscriptionPlan(
                SubscriptionPlan.premium,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Premium plan selected')),
              );
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 12),
          _PlanCard(
            title: 'Expert',
            priceLabel: 'EXPERT',
            bullets: const [
              'Everything in Premium',
              'Expert connection',
              'Priority customer support',
            ],
            isRecommended: false,
            isComingSoon: true, // Set to coming soon
            onSelect: null, // No action for coming soon
          ),
        ],
      ),
    );
  }
}

class ExpertSupportScreen extends StatelessWidget {
  const ExpertSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expert Support'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Expert support will be available here.'),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String priceLabel;
  final List<String> bullets;
  final bool isRecommended;
  final VoidCallback? onSelect; // Made nullable for coming soon
  final bool isComingSoon; // Added coming soon flag

  const _PlanCard({
    required this.title,
    required this.priceLabel,
    required this.bullets,
    required this.isRecommended,
    this.onSelect, // Made optional
    this.isComingSoon = false, // Default to false
  });

  @override
  Widget build(BuildContext context) {
    final color = isComingSoon 
        ? Colors.orange 
        : (isRecommended ? Colors.blue : Colors.grey);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    priceLabel,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (isRecommended) ...[
              const SizedBox(height: 8),
              Text(
                'Recommended',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue[700],
                ),
              ),
            ],
            if (isComingSoon) ...[
              const SizedBox(height: 8),
              Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange[700],
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: color),
                    const SizedBox(width: 10),
                    Expanded(child: Text(b)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isComingSoon ? null : onSelect,
                style: isComingSoon 
                    ? FilledButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.grey[600],
                      )
                    : null,
                child: Text(isComingSoon ? 'Coming Soon' : 'Choose'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openExternalMapForSlot(BuildContext context, Slot slot) async {
  String? origin;
  String? destination;

  if (slot.fromLocation != null && slot.fromLocation!.trim().isNotEmpty) {
    origin = slot.fromLocation!.trim();
  } else if (slot.baseLocation != null &&
      slot.baseLocation!.trim().isNotEmpty) {
    origin = slot.baseLocation!.trim();
  }

  if (slot.toLocation != null && slot.toLocation!.trim().isNotEmpty) {
    destination = slot.toLocation!.trim();
  }

  if (origin == null && destination == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Location not available')));
    return;
  }

  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'origin': ?origin,
    'destination': ?destination,
    'api': '1',
    'travelmode': 'driving',
  });

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open maps')));
  }
}

// Open Google Maps with lat/lng coordinates
Future<void> _openGoogleMapsLatLng(
  BuildContext context,
  double lat,
  double lng,
) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
  );

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open maps')));
  }
}

class CreateUserPostPage extends StatefulWidget {
  const CreateUserPostPage({super.key});

  @override
  State<CreateUserPostPage> createState() => _CreateUserPostPageState();
}

class _CreateUserPostPageState extends State<CreateUserPostPage> {
  ServiceType _serviceType = ServiceType.passenger;
  SlotType _slotType = SlotType.fromTo;

  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _baseController = TextEditingController();
  final _radiusController = TextEditingController(text: '10');
  final _budgetController = TextEditingController();
  int _persons = 1;
  final _notesController = TextEditingController();

  // Parcel dimension controllers
  final _parcelWeightController = TextEditingController();
  final _parcelLengthController = TextEditingController();
  final _parcelWidthController = TextEditingController();
  final _parcelHeightController = TextEditingController();

  bool _requiresVerifiedVehicle = false;
  bool _requiresExpertVehicle = false;

  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startTime = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    _endTime = DateTime(now.year, now.month, now.day, now.hour + 3, 0);
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _baseController.dispose();
    _radiusController.dispose();
    _budgetController.dispose();
    _notesController.dispose();
    _parcelWeightController.dispose();
    _parcelLengthController.dispose();
    _parcelWidthController.dispose();
    _parcelHeightController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = TimeOfDay.fromDateTime(isStart ? _startTime! : _endTime!);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final date = isStart ? _startTime! : _endTime!;
    final newDt = DateTime(
      date.year,
      date.month,
      date.day,
      picked.hour,
      picked.minute,
    );
    setState(() {
      if (isStart) {
        _startTime = newDt;
        if (_endTime != null && _endTime!.isBefore(_startTime!)) {
          _endTime = _startTime!.add(const Duration(hours: 2));
        }
      } else {
        _endTime = newDt;
      }
    });
  }

  Future<void> _create() async {
    if (_slotType == SlotType.fromTo) {
      if (_fromController.text.trim().isEmpty ||
          _toController.text.trim().isEmpty) {
        _showError('Please enter both from and to locations');
        return;
      }
    } else {
      if (_baseController.text.trim().isEmpty) {
        _showError('Please enter base location');
        return;
      }
    }
    final budget = double.tryParse(_budgetController.text.trim());
    if (budget == null || budget <= 0) {
      _showError('Please enter a valid budget');
      return;
    }

    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) {
      _showError('User not authenticated');
      return;
    }

    final post = UserPost(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      userId: currentUser.id,
      serviceType: _serviceType,
      slotType: _slotType,
      fromLocation: _slotType == SlotType.fromTo
          ? _fromController.text.trim()
          : null,
      toLocation: _slotType == SlotType.fromTo
          ? _toController.text.trim()
          : null,
      baseLocation: _slotType == SlotType.fromRange
          ? _baseController.text.trim()
          : null,
      radius: _slotType == SlotType.fromRange
          ? double.tryParse(_radiusController.text)
          : null,
      startTime: _startTime!,
      endTime: _endTime!,
      budget: budget,
      persons: _persons,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      requiresVerifiedVehicle: _requiresVerifiedVehicle,
      requiresExpertVehicle: _requiresExpertVehicle,
      createdAt: DateTime.now(),
      status: UserPostStatus.active,
      isOnline: true,
      parcelWeight: _serviceType == ServiceType.parcel
          ? double.tryParse(_parcelWeightController.text.trim())
          : null,
      parcelLength: _serviceType == ServiceType.parcel
          ? double.tryParse(_parcelLengthController.text.trim())
          : null,
      parcelWidth: _serviceType == ServiceType.parcel
          ? double.tryParse(_parcelWidthController.text.trim())
          : null,
      parcelHeight: _serviceType == ServiceType.parcel
          ? double.tryParse(_parcelHeightController.text.trim())
          : null,
    );

    try {
      await UserPostRepository.instance.add(post);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Posted ')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to post: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<ServiceType>(
            initialValue: _serviceType,
            decoration: const InputDecoration(
              labelText: 'Service',
              border: OutlineInputBorder(),
            ),
            items: ServiceType.values
                .map(
                  (s) => DropdownMenuItem(value: s, child: Text(s.displayName)),
                )
                .toList(growable: false),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _serviceType = v);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<SlotType>(
            initialValue: _slotType,
            decoration: const InputDecoration(
              labelText: 'Route type',
              border: OutlineInputBorder(),
            ),
            items: SlotType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.displayName)))
                .toList(growable: false),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _slotType = v);
            },
          ),
          const SizedBox(height: 12),
          if (_slotType == SlotType.fromTo) ...[
            TextField(
              controller: _fromController,
              decoration: const InputDecoration(
                labelText: 'From',
                hintText: 'e.g. Chennai Central',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _toController,
              decoration: const InputDecoration(
                labelText: 'To',
                hintText: 'e.g. Bangalore City Junction',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
          ] else ...[
            TextField(
              controller: _baseController,
              decoration: const InputDecoration(
                labelText: 'Base location',
                hintText: 'e.g. Mumbai CST',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.my_location),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _radiusController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Radius (km)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(isStart: true),
                  child: Text('Start: ${_fmtTime(_startTime!)}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(isStart: false),
                  child: Text('End: ${_fmtTime(_endTime!)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Budget ()',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Persons'),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _persons > 1
                    ? () => setState(() => _persons -= 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_persons'),
              IconButton(
                onPressed: () => setState(() => _persons += 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Terms (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          // Parcel dimensions — only shown for parcel service type
          if (_serviceType == ServiceType.parcel) ...[
            const SizedBox(height: 16),
            const Text(
              'Parcel Dimensions',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _parcelWeightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _parcelLengthController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Length (cm)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _parcelWidthController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Width (cm)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _parcelHeightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Height (cm)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Needed vehicle tags',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _requiresVerifiedVehicle,
            onChanged: (v) => setState(() => _requiresVerifiedVehicle = v),
            title: const Text('Verified vehicle required'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _requiresExpertVehicle,
            onChanged: (v) => setState(() => _requiresExpertVehicle = v),
            title: const Text('Expert vehicle required'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _create, child: const Text('Post')),
        ],
      ),
    );
  }

  String _fmtTime(DateTime d) {
    return TimezoneUtils.formatTimeWithTimezone(d, show24Hour: true);
  }
}

class UserMyPostsPage extends StatelessWidget {
  const UserMyPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<UserPost>>(
        valueListenable: UserPostRepository.instance.posts,
        builder: (context, allPosts, _) {
          final userPosts = UserPostRepository.instance.userPosts;
          final active = userPosts
              .where((p) => p.status == UserPostStatus.active)
              .toList(growable: false);
          if (active.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('You have not posted anything yet'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: active.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final p = active[index];
              return Card(
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    child: const Icon(Icons.post_add, color: Colors.blue),
                  ),
                  title: Text(
                    _userPostTitle(p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userPostTime(p)),
                      const SizedBox(height: 4),
                      Text('Budget: ()'),
                      if (p.requiresVerifiedVehicle || p.requiresExpertVehicle) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (p.requiresVerifiedVehicle)
                              const Chip(
                                label: Text('Verified only'),
                                visualDensity: VisualDensity.compact,
                              ),
                            if (p.requiresExpertVehicle)
                              const Chip(
                                label: Text('Expert only'),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                      if (p.notes?.isNotEmpty == true)
                        Text(
                          p.notes!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: p.isOnline ? 'Online' : 'Offline',
                        child: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: p.isOnline,
                            onChanged: (v) async {
                              try {
                                await UserPostRepository.instance.update(
                                  p.copyWith(isOnline: v),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      v
                                          ? 'Post is now online'
                                          : 'Post is now offline',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to update: $e',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Actions',
                        onSelected: (value) {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditUserPostPage(post: p),
                              ),
                            );
                            return;
                          }

                          if (value == 'delete') {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Post'),
                                content: const Text(
                                  'Are you sure you want to delete this post?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      UserPostRepository.instance.archive(p.id);
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Post deleted'),
                                        ),
                                      );
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }

                          if (value == 'history') {
                            UserPostRepository.instance.archive(p.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Moved to history')),
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                          PopupMenuItem(
                            value: 'history',
                            child: Text('Move to history'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      // FloatingActionButton removed: Posts should be created inside a vehicle detail screen only
    );
  }

  String _userPostTitle(UserPost p) {
    if (p.fromLocation != null && p.toLocation != null) {
      return '${_cleanLoc(p.fromLocation)} → ${_cleanLoc(p.toLocation)}';
    }
    if (p.baseLocation != null) return _cleanLoc(p.baseLocation);
    return 'Post';
  }

  String _userPostTime(UserPost p) {
    String fmt(DateTime d) {
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    return '${p.startTime.day}/${p.startTime.month} ${fmt(p.startTime)}';
  }
}

class UserPostHistoryPage extends StatelessWidget {
  const UserPostHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<UserPost>>(
        valueListenable: UserPostRepository.instance.posts,
        builder: (context, posts, _) {
          final history = posts
              .where((p) => p.status == UserPostStatus.archived)
              .toList(growable: false);
          if (history.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('No history yet'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final p = history[index];
              return Card(
                elevation: 1,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.withValues(alpha: 0.15),
                    child: const Icon(Icons.history, color: Colors.black54),
                  ),
                  title: Text(
                    _userPostTitle(p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('Budget: ()'),
                  trailing: IconButton(
                    tooltip: 'Restore',
                    onPressed: () {
                      UserPostRepository.instance.restore(p.id);
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Restored')));
                    },
                    icon: const Icon(Icons.restore),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _userPostTitle(UserPost p) {
    if (p.fromLocation != null && p.toLocation != null) {
      return '${_cleanLoc(p.fromLocation)} → ${_cleanLoc(p.toLocation)}';
    }
    if (p.baseLocation != null) return _cleanLoc(p.baseLocation);
    return 'Post';
  }
}

class MyPostsPage extends StatelessWidget {
  const MyPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<SlotEntry>>(
        valueListenable: SlotRepository.instance.slotsListenable,
        builder: (context, slots, _) {
          if (slots.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('You have not posted any rides yet'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: slots.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = slots[index];
              final slot = entry.slot;
              final title = _slotTitle(slot);
              final time = _fmtRange(slot.startTime, slot.endTime);
              return Card(
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    child: const Icon(Icons.local_offer, color: Colors.blue),
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(time),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            slot.pickupOption.icon,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            slot.pickupOption.shortLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      // Show lat/lng if available
                      Builder(
                        builder: (context) {
                          final location = slot.baseLocation ?? slot.fromLocation;
                          final coords = _extractLatLng(location);
                          if (coords != null) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Lat: ${coords['lat']!.toStringAsFixed(6)}, Lng: ${coords['lng']!.toStringAsFixed(6)}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      if (slot.notes?.isNotEmpty == true)
                        Text(
                          slot.notes!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('()'),
                      const SizedBox(height: 4),
                      Chip(
                        label: Text(_serviceLabel(slot.serviceType)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _slotTitle(Slot slot) {
    if (slot.fromLocation != null && slot.toLocation != null) {
      return '${_cleanLoc(slot.fromLocation)} → ${_cleanLoc(slot.toLocation)}';
    }
    if (slot.baseLocation != null) return _cleanLoc(slot.baseLocation);
    return 'Posted ride';
  }

  String _fmtRange(DateTime start, DateTime end) {
    // Format: 26/1 09:30 IST
    return TimezoneUtils.formatShortDateTimeWithTimezone(start, show24Hour: true);
  }

  String _serviceLabel(ServiceType type) {
    switch (type) {
      case ServiceType.passenger:
        return 'Passenger';
      case ServiceType.parcel:
        return 'Parcel';
      case ServiceType.working:
        return 'Working';
      case ServiceType.lease:
        return 'Lease';
    }
  }
}

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<Booking>>(
        valueListenable: BookingRepository.instance.bookings,
        builder: (context, allBookings, _) {
          final currentUser = AuthRepository.instance.currentUser;
          if (currentUser == null) {
            return const Center(child: Text('Please login to view earnings'));
          }

          // Get bookings where current user is the provider
          final providerBookings = allBookings
              .where(
                (b) =>
                    b.providerId == currentUser.id &&
                    b.status == BookingStatus.completed,
              )
              .toList();

          // Calculate total earnings
          final totalEarnings = providerBookings.fold<double>(
            0,
            (sum, booking) => sum + booking.price,
          );

          // Get slots to determine service types
          final slotRepo = SlotRepository.instance;
          final allSlots = slotRepo.allSlotsRaw;

          // Group by service type
          double passengerEarnings = 0;
          double parcelEarnings = 0;
          double leaseEarnings = 0;

          for (var booking in providerBookings) {
            try {
              final slot = allSlots.firstWhere((s) => s.id == booking.slotId);
              if (slot.serviceType == ServiceType.passenger) {
                passengerEarnings += booking.price;
              } else if (slot.serviceType == ServiceType.parcel) {
                parcelEarnings += booking.price;
              } else if (slot.serviceType == ServiceType.lease ||
                  slot.serviceType == ServiceType.working) {
                leaseEarnings += booking.price;
              }
            } catch (e) {
              // Slot not found, skip
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Total Earnings Card
              Card(
                elevation: 4,
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        'Total Earnings',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${totalEarnings.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${providerBookings.length} completed trips',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Earnings by Service Type
              const Text(
                'Earnings by Service',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              _buildServiceEarningCard(
                'Passenger',
                passengerEarnings,
                Icons.people,
                Colors.blue,
              ),
              const SizedBox(height: 8),

              _buildServiceEarningCard(
                'Parcel',
                parcelEarnings,
                Icons.local_shipping,
                Colors.orange,
              ),
              const SizedBox(height: 8),

              _buildServiceEarningCard(
                'Lease/Working',
                leaseEarnings,
                Icons.car_rental,
                Colors.purple,
              ),

              const SizedBox(height: 24),

              // Recent Transactions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to full transaction history
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (providerBookings.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No completed bookings yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                )
              else
                ...providerBookings.take(10).map((booking) {
                  final allSlots = SlotRepository.instance.allSlotsRaw;
                  Slot? slot;
                  try {
                    slot = allSlots.firstWhere((s) => s.id == booking.slotId);
                  } catch (e) {
                    // Slot not found
                  }
                  return _buildTransactionCard(booking, slot);
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildServiceEarningCard(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Booking booking, Slot? slot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot != null ? '${slot.serviceType.displayName} Service' : 'Service',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${booking.createdAt.day}/${booking.createdAt.month}/${booking.createdAt.year}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${booking.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            if (slot != null) ...[
              const SizedBox(height: 12),
              _BookingTimingSection(
                booking: booking,
                slot: slot,
                isRiderView: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ProfileSection({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileRepository.instance.profile;
    final nameController = TextEditingController(
      text: profile.value.profileName,
    );
    final phoneController = TextEditingController(
      text: profile.value.phone ?? '',
    );
    final aadhaarController = TextEditingController(
      text: profile.value.aadhaar ?? '',
    );
    final panController = TextEditingController(text: profile.value.pan ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<ProfileInfo>(
        valueListenable: profile,
        builder: (context, info, _) {
          return ValueListenableBuilder<SubscriptionPlan>(
            valueListenable: AppPreferences.instance.subscriptionPlan,
            builder: (context, plan, _) {
              final canVerifyDocs =
                  plan == SubscriptionPlan.premium ||
                  plan == SubscriptionPlan.expert;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _profileAvatarProvider(info),
                          child: info.avatarUrl == null
                              ? const Icon(
                                  Icons.person,
                                  size: 44,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: FloatingActionButton.small(
                            heroTag: 'edit-dp',
                            onPressed: () => _pickAndSaveAvatar(context),
                            child: const Icon(Icons.edit),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Profile sections with navigation
                  _ProfileSection(
                    title: 'My Posts',
                    icon: Icons.article,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PostsPage()),
                      );
                    },
                  ),
                  _ProfileSection(
                    title: 'My Vehicles',
                    icon: Icons.directions_car,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VehicleListScreen(),
                        ),
                      );
                    },
                  ),
                  _ProfileSection(
                    title: 'Booking History',
                    icon: Icons.history,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RequestsPage()),
                      );
                    },
                  ),
                  _ProfileSection(
                    title: 'My Reviews',
                    icon: Icons.star,
                    onTap: () {
                      final currentUser = AuthRepository.instance.currentUser;
                      if (currentUser == null) return;
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReviewsScreen(
                            userId: currentUser.id,
                            userName: info.profileName,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _ProfileSection(
                    title: 'Plans',
                    icon: Icons.workspace_premium,
                    onTap: () {
                      Navigator.pushNamed(context, '/plans');
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Account Settings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  StatefulBuilder(
                    builder: (context, setState) {
                      String? nameError;
                      
                      return TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          border: const OutlineInputBorder(),
                          errorText: nameError,
                          suffixIcon: nameController.text.trim().isEmpty
                              ? null
                              : FutureBuilder<bool>(
                                  future: () async {
                                    final currentUser = AuthRepository.instance.currentUser;
                                    if (currentUser == null) return true;
                                    
                                    await ProfileNameRegistry.instance.init();
                                    return ProfileNameRegistry.instance.isNameAvailable(
                                      nameController.text.trim(),
                                      currentUserId: currentUser.id,
                                    );
                                  }(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const Padding(
                                        padding: EdgeInsets.all(12.0),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      );
                                    }
                                    
                                    final isAvailable = snapshot.data!;
                                    return Icon(
                                      isAvailable ? Icons.check_circle : Icons.error,
                                      color: isAvailable ? Colors.green : Colors.red,
                                    );
                                  },
                                ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            if (value.trim().isEmpty) {
                              nameError = 'Name cannot be empty';
                            } else {
                              nameError = null;
                            }
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: info.businessType,
                    decoration: const InputDecoration(
                      labelText: 'Branding type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'solo', child: Text('Solo')),
                      DropdownMenuItem(
                        value: 'private',
                        child: Text('Private'),
                      ),
                      DropdownMenuItem(value: 'llc', child: Text('LLC')),
                    ],
                    onChanged: (value) async {
                      await ProfileRepository.instance.update(
                        businessType: value,
                        setBusinessTypeNull: value == null,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (canVerifyDocs) ...[
                    TextField(
                      controller: aadhaarController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Aadhaar number (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDocumentUploadCard(
                      context,
                      title: 'National ID',
                      subtitle: 'Upload front and back',
                      icon: Icons.credit_card,
                      documentType: 'aadhaar',
                      frontBase64: info.aadhaarFrontImage,
                      backBase64: info.aadhaarBackImage,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: panController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'PAN number (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDocumentUploadCard(
                      context,
                      title: 'Tax ID',
                      subtitle: 'Upload tax identification',
                      icon: Icons.badge,
                      documentType: 'pan',
                      frontBase64: info.panFrontImage,
                    ),
                    const SizedBox(height: 12),
                    _buildDocumentUploadCard(
                      context,
                      title: 'Driving License',
                      subtitle: 'Upload front and back',
                      icon: Icons.drive_eta,
                      documentType: 'dl',
                      frontBase64: info.dlFrontImage,
                      backBase64: info.dlBackImage,
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Document verification'),
                      subtitle: const Text(
                        'Upgrade to Premium to add Tax ID/National ID/Vehicle Docs',
                      ),
                      trailing: TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/plans'),
                        child: const Text('Upgrade'),
                      ),
                    ),
                  ],
                  ValueListenableBuilder<String>(
                    valueListenable: AppPreferences.instance.currencyCode,
                    builder: (context, selectedCode, _) {
                      return DropdownButtonFormField<String>(
                        initialValue: selectedCode,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'INR',
                            child: Text('INR (₹)'),
                          ),
                          DropdownMenuItem(
                            value: 'USD',
                            child: Text('USD (\$)'),
                          ),
                          DropdownMenuItem(
                            value: 'EUR',
                            child: Text('EUR (€)'),
                          ),
                          DropdownMenuItem(
                            value: 'GBP',
                            child: Text('GBP (£)'),
                          ),
                        ],
                        onChanged: (code) {
                          if (code == null) return;
                          AppPreferences.instance.setCurrencyCode(code);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<String>(
                    valueListenable: AppPreferences.instance.preferredCountry,
                    builder: (context, selectedCountry, _) {
                      return DropdownButtonFormField<String>(
                        initialValue: selectedCountry,
                        decoration: const InputDecoration(
                          labelText: 'Preferred country',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'India',
                            child: Text('India'),
                          ),
                          DropdownMenuItem(
                            value: 'United States',
                            child: Text('United States'),
                          ),
                          DropdownMenuItem(
                            value: 'United Kingdom',
                            child: Text('United Kingdom'),
                          ),
                          DropdownMenuItem(
                            value: 'Germany',
                            child: Text('Germany'),
                          ),
                          DropdownMenuItem(
                            value: 'France',
                            child: Text('France'),
                          ),
                        ],
                        onChanged: (country) {
                          if (country == null) return;
                          AppPreferences.instance.setPreferredCountry(country);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Bank Details Section (for providers to receive payments)
                  Text(
                    'Bank Details (For Receiving Payments)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your bank details to receive earnings from completed trips',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Account Holder Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Account Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Bank Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'IFSC Code / SWIFT Code',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.code),
                      hintText: 'e.g., SBIN0001234',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Account Type',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'savings',
                        child: Text('Savings'),
                      ),
                      DropdownMenuItem(
                        value: 'current',
                        child: Text('Current'),
                      ),
                    ],
                    onChanged: (value) {},
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your bank details are encrypted and secure. They will only be used to transfer your earnings.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await ProfileRepository.instance.update(
                            profileName: nameController.text.trim().isEmpty
                                ? info.profileName
                                : nameController.text.trim(),
                            phone: phoneController.text.trim().isEmpty
                                ? null
                                : phoneController.text.trim(),
                            aadhaar: aadhaarController.text.trim().isEmpty
                                ? null
                                : aadhaarController.text.trim(),
                            pan: panController.text.trim().isEmpty
                                ? null
                                : panController.text.trim(),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceAll('Exception: ', '')),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(child: Text('Wallet coming soon')),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const PostsPage(),
    const RequestsPage(),
    AIChatPage(), // AI Chat screen (not const because it has state)
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = mainTabIndex.value;
    mainTabIndex.addListener(_onTabIndexChanged);
  }

  @override
  void dispose() {
    mainTabIndex.removeListener(_onTabIndexChanged);
    super.dispose();
  }

  void _onTabIndexChanged() {
    if (!mounted) return;
    if (_currentIndex == mainTabIndex.value) return;
    setState(() {
      _currentIndex = mainTabIndex.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return VoiceAIOverlay(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('VaultWheels'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            // Guest-first: Show Login/SignUp button if not logged in
            ValueListenableBuilder(
              valueListenable: AuthRepository.instance.currentUserListenable,
              builder: (context, user, _) {
                if (user == null) {
                  // Not logged in - show Login button
                  return TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    child: const Text(
                      'Login',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  );
                } else {
                  // Logged in - show profile icon (already in bottom nav, so just show indicator)
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Logged in',
                              style: TextStyle(color: Colors.green, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        body: _pages[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            mainTabIndex.value = index;
          },
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.article), label: 'Posts'),
            BottomNavigationBarItem(
              icon: Icon(Icons.request_page),
              label: 'Requests',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy), // AI chat icon
              label: 'AI Chat',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

class SlotFeedItem {
  final Slot slot;
  final Vehicle vehicle;
  final String providerName;
  final String providerAvatar;
  final double providerRating;
  final bool isOffer;
  final bool
  isUserPost; // true = user post (looking for service), false = provider post (offering service)

  SlotFeedItem({
    required this.slot,
    required this.vehicle,
    required this.providerName,
    required this.providerAvatar,
    required this.providerRating,
    required this.isOffer,
    required this.isUserPost,
  });
}

class PostsPage extends StatefulWidget {
  const PostsPage({super.key});

  @override
  State<PostsPage> createState() => _PostsPageState();
}

enum SortOption {
  priceHighToLow,
  priceLowToHigh,
  ratingHighToLow,
  bookingsHighToLow,
  newest,
  oldest,
}

extension SortOptionExtension on SortOption {
  String get displayName {
    switch (this) {
      case SortOption.priceHighToLow:
        return 'Price: High to Low';
      case SortOption.priceLowToHigh:
        return 'Price: Low to High';
      case SortOption.ratingHighToLow:
        return 'Rating: High to Low';
      case SortOption.bookingsHighToLow:
        return 'Most Booked';
      case SortOption.newest:
        return 'Newest First';
      case SortOption.oldest:
        return 'Oldest First';
    }
  }
}

class _PostsPageState extends State<PostsPage> {
  ServiceType?
  _selectedServiceType; // null = show all, otherwise filter by service type

  // Route filter
  SlotType?
  _selectedSlotType; // null = both, otherwise filter by slot type

  // Pickup mode filter
  PickupMode?
  _selectedPickupMode; // null = both, otherwise filter by pickup mode

  // Booking mode filter (Post Mode)
  PostMode? _selectedPostMode; // null = all, otherwise filter by post mode
  
  // Wait for full deadline filter (only when Wait for Full is selected)
  int? _waitForFullDeadlineHours; // Filter by deadline hours

  // Sort option
  SortOption _sortOption = SortOption.newest;

  // Location filters (based on route type)
  String? _filterFromLocation;
  String? _filterToLocation;
  String? _filterBaseLocation;

  // Operator filter (only for Lease)
  bool?
  _withOperator; // null = both, true = with operator, false = without operator

  // Security deposit filter (only for Lease)
  double? _minSecurityDeposit;
  double? _maxSecurityDeposit;

  // Parcel dimension filters (only for Parcel)
  double? _minParcelWeight;
  double? _maxParcelWeight;
  double? _minParcelLength;
  double? _maxParcelLength;
  double? _minParcelWidth;
  double? _maxParcelWidth;
  double? _minParcelHeight;
  double? _maxParcelHeight;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _fromSearchController = TextEditingController();
  final TextEditingController _toSearchController = TextEditingController();
  final TextEditingController _baseSearchController = TextEditingController();
  bool _nearestEnabled = false;
  bool _showUserPosts = false; // Toggle between provider and user posts

  double? _minPrice;
  double? _maxPrice;
  DateTime? _fromDateTime;
  DateTime? _toDateTime;
  double? _maxDistanceKm;

  // Resolved coordinates for base location radius search
  (double, double)? _filterBaseLatLon;

  final VehicleRepository _vehicleRepository = VehicleRepository.instance;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fromSearchController.dispose();
    _toSearchController.dispose();
    _baseSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        SlotRepository.instance.slotsListenable,
        CustomerSlotRepository.instance.slotsListenable,
        _vehicleRepository.onlineStatusListenable,
        CustomerVehicleRepository.instance.onlineStatusListenable,
      ]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Posts'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              // Refresh button to reload posts from Supabase
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Posts',
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Refreshing posts...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  
                  // Reload all data from Supabase
                  await Future.wait([
                    VehicleRepository.instance.loadAllVehicles(),
                    CustomerVehicleRepository.instance.init(),
                    SlotRepository.instance.loadAllSlots(),
                    CustomerSlotRepository.instance.init(),
                  ]);
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Posts refreshed!'),
                        duration: Duration(seconds: 1),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              // Sort button
              IconButton(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort',
                onPressed: () => _showSortBottomSheet(context),
              ),
              // Debug button to show repository status
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  final providerSlots = SlotRepository.instance.allSlots.length;
                  final userSlots = CustomerSlotRepository.instance.allSlots.length;
                  final providerVehicles =
                      VehicleRepository.instance.allVehicles.length;
                  final userVehicles =
                      CustomerVehicleRepository.instance.allVehicles.length;

                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Repository Status'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Provider Vehicles: $providerVehicles'),
                          Text('Provider Posts: $providerSlots'),
                          const SizedBox(height: 8),
                          Text('Customer Vehicles: $userVehicles'),
                          Text('Customer Posts: $userSlots'),
                          const SizedBox(height: 8),
                          Text('Total Posts: ${providerSlots + userSlots}'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _selectedSlotType == SlotType.fromTo
                          ? Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _fromSearchController,
                                    decoration: InputDecoration(
                                      hintText: 'From',
                                      prefixIcon: const Icon(Icons.my_location),
                                      suffixIcon: _fromSearchController.text.isEmpty
                                          ? null
                                          : IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  _fromSearchController.clear();
                                                  _filterFromLocation = null;
                                                });
                                              },
                                              icon: const Icon(Icons.clear),
                                            ),
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (v) {
                                      setState(() {
                                        final t = v.trim();
                                        _filterFromLocation = t.isEmpty ? null : t;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _toSearchController,
                                    decoration: InputDecoration(
                                      hintText: 'To',
                                      prefixIcon: const Icon(Icons.place),
                                      suffixIcon: _toSearchController.text.isEmpty
                                          ? null
                                          : IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  _toSearchController.clear();
                                                  _filterToLocation = null;
                                                });
                                              },
                                              icon: const Icon(Icons.clear),
                                            ),
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (v) {
                                      setState(() {
                                        final t = v.trim();
                                        _filterToLocation = t.isEmpty ? null : t;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            )
                          : _selectedSlotType == SlotType.fromRange
                              ? TextField(
                                  controller: _baseSearchController,
                                  decoration: InputDecoration(
                                    hintText: 'Base location',
                                    prefixIcon: const Icon(Icons.location_on),
                                    suffixIcon: _baseSearchController.text.isEmpty
                                        ? null
                                        : IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _baseSearchController.clear();
                                                _filterBaseLocation = null;
                                              });
                                            },
                                            icon: const Icon(Icons.clear),
                                          ),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (v) {
                                    final t = v.trim();
                                    setState(() {
                                      _filterBaseLocation = t.isEmpty ? null : t;
                                      _filterBaseLatLon = null; // reset until resolved
                                    });
                                    if (t.length >= 3) {
                                      LocationAutocompleteService.instance
                                          .searchLocations(t)
                                          .then((results) {
                                        if (results.isNotEmpty && mounted) {
                                          setState(() {
                                            _filterBaseLatLon = (
                                              results.first.lat,
                                              results.first.lon,
                                            );
                                          });
                                        }
                                      });
                                    }
                                  },
                                )
                              : TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: _showUserPosts
                                        ? 'Search customer requests'
                                        : 'Search by location',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: _searchController.text.isEmpty
                                        ? null
                                        : IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _searchController.clear();
                                              });
                                            },
                                            icon: const Icon(Icons.clear),
                                          ),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _openFiltersSheet(context),
                      icon: const Icon(Icons.tune),
                      label: const Text('Filters'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Toggle between Provider and User posts
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showUserPosts = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_showUserPosts
                                  ? Colors.blue
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Provider Posts',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !_showUserPosts
                                    ? Colors.white
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showUserPosts = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _showUserPosts
                                  ? Colors.blue
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Customer Posts',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _showUserPosts
                                    ? Colors.white
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Service type filter chips (Passenger, Parcel, Lease) - Show on both tabs
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ...ServiceType.values
                        .where(
                          (service) => service != ServiceType.working,
                        ) // Exclude Working
                        .map(
                          (service) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(_serviceLabel(service)),
                              selected: _selectedServiceType == service,
                              onSelected: (_) {
                                setState(() {
                                  // Toggle: click to select, click again to unselect
                                  _selectedServiceType =
                                      _selectedServiceType == service
                                      ? null
                                      : service;
                                  _withOperator = null; // Reset operator filter
                                  _minSecurityDeposit = null;
                                  _maxSecurityDeposit = null;
                                });
                              },
                            ),
                          ),
                        ),
                    // Operator filter chips (show ONLY when Lease is selected)
                    if (_selectedServiceType == ServiceType.lease) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('With Operator'),
                          selected: _withOperator == true,
                          onSelected: (_) {
                            setState(() {
                              _withOperator = _withOperator == true
                                  ? null
                                  : true;
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('Without Operator'),
                          selected: _withOperator == false,
                          onSelected: (_) {
                            setState(() {
                              _withOperator = _withOperator == false
                                  ? null
                                  : false;
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _showUserPosts
                    ? _buildUserPostsList()
                    : _buildProviderPostsList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSortBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort By',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...SortOption.values.map((option) => ListTile(
              leading: Icon(
                _sortOption == option ? Icons.check_circle : Icons.circle_outlined,
                color: _sortOption == option ? Colors.blue : Colors.grey,
              ),
              title: Text(option.displayName),
              selected: _sortOption == option,
              onTap: () {
                setState(() => _sortOption = option);
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderPostsList() {
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: BookingRepository.instance.remainingCapacityBySlotId,
      builder: (context, capacityMap, child) {
        final allSlotItems = _filteredSlotItems();
        debugPrint('=== POSTS DEBUG ===');
        debugPrint(
          'Provider slots: ${SlotRepository.instance.allSlots.length}',
        );
        debugPrint(
          'User slots: ${CustomerSlotRepository.instance.allSlots.length}',
        );
        debugPrint('Total slot items: ${allSlotItems.length}');

        // Debug each slot's capacity
        for (final item in allSlotItems) {
          final remaining = BookingRepository.instance.getRemainingCapacity(
            item.slot.id,
            item.slot.capacity,
          );
          debugPrint(
            'Slot ${item.slot.id}: capacity=${item.slot.capacity}, remaining=$remaining',
          );
        }

        final filteredSlots = allSlotItems
            .where(
              (item) =>
                  BookingRepository.instance.getRemainingCapacity(
                    item.slot.id,
                    item.slot.capacity,
                  ) >
                  0,
            )
            .toList(growable: false);

        debugPrint('Filtered slots with capacity > 0: ${filteredSlots.length}');
        debugPrint('==================');

        if (filteredSlots.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                _selectedServiceType == null
                    ? 'No services available'
                    : 'No ${_serviceLabel(_selectedServiceType!)} services available',
              ),
            ),
          );
        }

        return ListView(
          children: [
            ...filteredSlots.map(
              (item) => SlotCard(
                slot: item.slot,
                vehicle: item.vehicle,
                providerName: item.providerName,
                providerAvatar: item.providerAvatar,
                providerRating: item.providerRating,
                isOffer: item.isOffer,
                isUserPost: item.isUserPost,
                onRatingTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReviewsScreen(
                        userId: item.vehicle.userId,
                        userName: item.providerName,
                      ),
                    ),
                  );
                },
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SlotDetailScreen(
                        slot: item.slot,
                        vehicle: item.vehicle,
                        providerName: item.providerName,
                        providerAvatar: item.providerAvatar,
                        providerRating: item.providerRating,
                        isOffer: item.isOffer,
                      ),
                    ),
                  );
                },
                onAction: () {
                  final currentUser = AuthRepository.instance.currentUser;
                  if (currentUser == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please login to book')),
                    );
                    return;
                  }

                  // Prevent self-booking: User cannot book their own post
                  if (currentUser.id == item.slot.profileId) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You cannot book your own service'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  _handleBookingAction(
                    slot: item.slot,
                    providerId: item.slot.profileId, // Use post owner
                    userId: currentUser.id,
                    isOffer: item.isOffer,
                    providerName: item.providerName,
                    providerAvatar: item.providerAvatar,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildUserPostsList() {
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: BookingRepository.instance.remainingCapacityBySlotId,
      builder: (context, capacityMap, child) {
        final allSlotItems = _filteredSlotItems();

        debugPrint('=== USER POSTS DEBUG ===');
        debugPrint(
          'User slots (looking for services): ${CustomerSlotRepository.instance.allSlots.length}',
        );
        debugPrint('Filtered user slot items: ${allSlotItems.length}');
        debugPrint('========================');

        // Filter by capacity
        final filteredSlots = allSlotItems
            .where(
              (item) =>
                  BookingRepository.instance.getRemainingCapacity(
                    item.slot.id,
                    item.slot.capacity,
                  ) >
                  0,
            )
            .toList(growable: false);

        if (filteredSlots.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                _selectedServiceType == null
                    ? 'No user posts available'
                    : 'No ${_serviceLabel(_selectedServiceType!)} requests available',
              ),
            ),
          );
        }

        return ListView(
          children: [
            ...filteredSlots.map(
              (item) => SlotCard(
                slot: item.slot,
                vehicle: item.vehicle,
                providerName: 'Looking for service',
                providerAvatar: '',
                providerRating: 0.0,
                isOffer: false, // User is looking, not offering
                isUserPost: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SlotDetailScreen(
                        slot: item.slot,
                        vehicle: item.vehicle,
                        providerName: 'User Request',
                        providerAvatar: '',
                        providerRating: 0.0,
                        isOffer: false,
                      ),
                    ),
                  );
                },
                onAction: () async {
                  final currentUser = AuthRepository.instance.currentUser;
                  if (currentUser == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please login to respond')),
                    );
                    return;
                  }

                  // Prevent accepting your own request
                  if (currentUser.id == item.slot.profileId) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You cannot accept your own request'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  final profile = ProfileRepository.instance.profile.value;

                  final booking = await BookingRepository.instance.createBooking(
                    slotId: item.slot.id,
                    providerId: currentUser.id,
                    providerName: profile.profileName,
                    providerPhone: profile.phone,
                    userId: item.slot.profileId, // Use post owner
                    defaultCapacity: item.slot.capacity,
                    price: item.slot.price,
                    userName: ProfileNameRegistry.instance.getNameForUser(item.slot.profileId) ?? 'User',
                  );

                  if (!context.mounted) return;

                  if (booking == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to accept request')),
                    );
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Request accepted!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  mainTabIndex.value = 1;
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  String _serviceLabel(ServiceType type) {
    switch (type) {
      case ServiceType.passenger:
        return 'Passenger';
      case ServiceType.parcel:
        return 'Parcel';
      case ServiceType.working:
        return 'Working';
      case ServiceType.lease:
        return 'Lease';
    }
  }


  List<SlotFeedItem> _filteredSlotItems() {
    final currentUser = AuthRepository.instance.currentUser;

    debugPrint('=== FILTERING DEBUG ===');
    debugPrint('Current user ID: ${currentUser?.id ?? "GUEST"}');
    debugPrint('Show user posts: $_showUserPosts');

    // Get posts based on active tab
    final List<SlotFeedItem> repoItems;

    if (_showUserPosts) {
      // User Posts tab - show ALL customer requests (common feed)
      final allUserSlots = CustomerSlotRepository.instance.allSlots;
      debugPrint('Total user slots: ${allUserSlots.length}');
      
      final now = DateTime.now();
      
      repoItems = allUserSlots
          .where(
            // Filter out expired posts (end time has passed)
            (e) => e.slot.endTime.isAfter(now),
          )
          // REMOVED: User-specific filter - show ALL posts for common feed
          // .where(
          //   (e) => isGuest || e.slot.profileId != currentUser.id,
          // )
          .map(
            (e) => SlotFeedItem(
              slot: e.slot,
              vehicle: e.vehicle,
              providerName: e.vehicle.userName, // ✅ Show real name to everyone
              providerAvatar: '',
              providerRating: 5.0,
              isOffer: false,
              isUserPost: true,
            ),
          )
          .toList();
      debugPrint('📊 User posts after expiry filter: ${repoItems.length}');
    } else {
      // Provider Posts tab - show ALL provider offers (common feed)
      final allProviderSlots = SlotRepository.instance.allSlots;
      debugPrint('Total provider slots: ${allProviderSlots.length}');
      
      final now = DateTime.now();
      
      repoItems = allProviderSlots
          .where(
            // Filter out expired posts (end time has passed)
            (e) => e.slot.endTime.isAfter(now),
          )
          // REMOVED: Vehicle online status filter - show ALL posts for common feed
          // .where(
          //   (e) => isGuest || _vehicleRepository.isOnline(e.vehicle.id),
          // )
          .map((e) {
            // Show provider name to everyone
            final providerName = e.vehicle.userName;

            return SlotFeedItem(
              slot: e.slot,
              vehicle: e.vehicle,
              providerName: providerName,
              providerAvatar: '',
              providerRating: 5.0,
              isOffer: true,
              isUserPost: false,
            );
          })
          .toList();
      debugPrint('📊 Provider posts after expiry filter: ${repoItems.length}');
    }

    final query = _searchController.text.trim().toLowerCase();
    final searched = (_selectedSlotType == null && query.isNotEmpty)
        ? repoItems
              .where((e) {
                final from = (e.slot.fromLocation ?? '').toLowerCase();
                final to = (e.slot.toLocation ?? '').toLowerCase();
                final base = (e.slot.baseLocation ?? '').toLowerCase();
                return from.contains(query) ||
                    to.contains(query) ||
                    base.contains(query);
              })
              .toList(growable: false)
        : repoItems;
    debugPrint('📊 After search filter: ${searched.length}');

    final dateTimeFiltered = searched
        .where((e) {
          if (_fromDateTime == null && _toDateTime == null) return true;
          final st = e.slot.startTime;
          if (_fromDateTime != null && st.isBefore(_fromDateTime!)) {
            return false;
          }
          if (_toDateTime != null && st.isAfter(_toDateTime!)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    debugPrint('📊 After date/time filter: ${dateTimeFiltered.length}');

    // Apply price filter
    final priceFiltered = dateTimeFiltered
        .where((e) {
          final p = e.slot.price;
          if (_minPrice != null && p < _minPrice!) return false;
          if (_maxPrice != null && p > _maxPrice!) return false;
          return true;
        })
        .toList(growable: false);
    debugPrint(
      '📊 After price filter (${_minPrice ?? "any"}-${_maxPrice ?? "any"}): ${priceFiltered.length}',
    );

    // Apply service type filter
    final serviceFiltered = _selectedServiceType == null
        ? priceFiltered
        : priceFiltered
              .where((e) => e.slot.serviceType == _selectedServiceType)
              .toList();

    // Apply operator filter
    final operatorFiltered = _withOperator == null
        ? serviceFiltered
        : serviceFiltered
              .where((e) => e.slot.withOperator == _withOperator)
              .toList();

    // Apply security deposit filter (Lease only)
    final depositFiltered = (_minSecurityDeposit == null &&
            _maxSecurityDeposit == null)
        ? operatorFiltered
        : operatorFiltered
            .where((e) {
              if (e.slot.serviceType != ServiceType.lease) return true;
              final d = e.slot.securityDeposit;
              if (d == null) return false;
              if (_minSecurityDeposit != null && d < _minSecurityDeposit!) {
                return false;
              }
              if (_maxSecurityDeposit != null && d > _maxSecurityDeposit!) {
                return false;
              }
              return true;
            })
            .toList(growable: false);

    // Apply parcel dimension filter
    final hasParcelFilter = _minParcelWeight != null || _maxParcelWeight != null ||
        _minParcelLength != null || _maxParcelLength != null ||
        _minParcelWidth  != null || _maxParcelWidth  != null ||
        _minParcelHeight != null || _maxParcelHeight != null;
    final parcelFiltered = !hasParcelFilter
        ? depositFiltered
        : depositFiltered.where((e) {
            if (e.slot.serviceType != ServiceType.parcel) return true;
            bool check(double? val, double? min, double? max) {
              if (val == null) return min == null && max == null;
              if (min != null && val < min) return false;
              if (max != null && val > max) return false;
              return true;
            }
            return check(e.slot.maxWeight, _minParcelWeight, _maxParcelWeight) &&
                check(e.slot.maxLength, _minParcelLength, _maxParcelLength) &&
                check(e.slot.maxWidth,  _minParcelWidth,  _maxParcelWidth)  &&
                check(e.slot.maxHeight, _minParcelHeight, _maxParcelHeight);
          }).toList(growable: false);

    // Apply route type filter
    final routeFiltered = _selectedSlotType == null
        ? parcelFiltered
        : parcelFiltered
            .where((e) => e.slot.slotType == _selectedSlotType)
            .toList(growable: false);
    // Apply pickup mode filter
    final pickupFiltered = _selectedPickupMode == null
        ? routeFiltered
        : routeFiltered
            .where((e) => e.slot.pickupOption == _selectedPickupMode)
            .toList(growable: false);
    
    // Apply booking mode (post mode) filter
    final postModeFiltered = _selectedPostMode == null
        ? pickupFiltered
        : pickupFiltered
            .where((e) {
              if (e.slot.postMode != _selectedPostMode) return false;
              
              // If Wait for Full is selected and deadline filter is set
              if (_selectedPostMode == PostMode.waitForFull && 
                  _waitForFullDeadlineHours != null) {
                final slotDeadline = e.slot.waitForFullDeadlineHours;
                if (slotDeadline == null) return false;
                return slotDeadline == _waitForFullDeadlineHours;
              }
              
              return true;
            })
            .toList(growable: false);

    // Apply location filters
    final locationFiltered = (_filterFromLocation == null ||
                _filterFromLocation!.trim().isEmpty) &&
            (_filterToLocation == null || _filterToLocation!.trim().isEmpty) &&
            (_filterBaseLocation == null ||
                _filterBaseLocation!.trim().isEmpty)
        ? postModeFiltered
        : postModeFiltered
            .where((e) {
              final slot = e.slot;
              final fromNeedle = (_filterFromLocation ?? '').trim().toLowerCase();
              final toNeedle = (_filterToLocation ?? '').trim().toLowerCase();
              final baseNeedle = (_filterBaseLocation ?? '').trim().toLowerCase();

              final fromHay = (slot.fromLocation ?? '').toLowerCase();
              final toHay = (slot.toLocation ?? '').toLowerCase();

              if (fromNeedle.isNotEmpty && !fromHay.contains(fromNeedle)) {
                return false;
              }
              if (toNeedle.isNotEmpty && !toHay.contains(toNeedle)) {
                return false;
              }

              // Base location: use radius-based filtering for fromRange slots
              if (baseNeedle.isNotEmpty) {
                final rawBase = slot.baseLocation ?? '';
                // baseLocation format: "Name|lat,lon"
                final parts = rawBase.split('|');
                final coordStr = parts.length == 2 ? parts[1] : null;
                final coords = coordStr?.split(',');
                final baseLat = coords != null && coords.length == 2
                    ? double.tryParse(coords[0])
                    : null;
                final baseLon = coords != null && coords.length == 2
                    ? double.tryParse(coords[1])
                    : null;

                final searchLatLon = _filterBaseLatLon;
                final slotRadius = slot.radius;

                if (baseLat != null &&
                    baseLon != null &&
                    searchLatLon != null &&
                    slotRadius != null &&
                    slotRadius > 0) {
                  // Radius-based: show slot if searched location is within slot's radius
                  final dist = _haversineKm(
                    searchLatLon.$1,
                    searchLatLon.$2,
                    baseLat,
                    baseLon,
                  );
                  if (dist > slotRadius) return false;
                } else {
                  // Fallback: text contains match
                  final baseHay = rawBase.toLowerCase();
                  if (!baseHay.contains(baseNeedle)) return false;
                }
              }

              return true;
            })
            .toList(growable: false);

    final distanceFiltered = _maxDistanceKm == null
        ? locationFiltered
        : locationFiltered
            .where((e) {
              final userPos = _currentUserPosition;
              if (userPos == null) return true;
              final vehiclePos = _vehicleResolvedLatLng(e.vehicle);
              if (vehiclePos == null) return false;
              final distance = _haversineKm(
                userPos.$1,
                userPos.$2,
                vehiclePos.$1,
                vehiclePos.$2,
              );
              return distance <= (_maxDistanceKm ?? double.infinity);
            })
            .toList(growable: false);

    if (!_nearestEnabled) {
      final result = _applySorting(distanceFiltered);
      debugPrint('📊 FINAL RESULT: ${result.length} posts after all filters');
      return result;
    }

    final result = _sortByDistance(distanceFiltered);
    debugPrint('📊 FINAL RESULT: ${result.length} posts after all filters (sorted by distance)');
    return result;
  }

  List<SlotFeedItem> _applySorting(List<SlotFeedItem> items) {
    final sorted = List<SlotFeedItem>.from(items);
    
    switch (_sortOption) {
      case SortOption.priceHighToLow:
        sorted.sort((a, b) => b.slot.price.compareTo(a.slot.price));
        break;
      case SortOption.priceLowToHigh:
        sorted.sort((a, b) => a.slot.price.compareTo(b.slot.price));
        break;
      case SortOption.ratingHighToLow:
        sorted.sort((a, b) => b.vehicle.averageRating.compareTo(a.vehicle.averageRating));
        break;
      case SortOption.bookingsHighToLow:
        sorted.sort((a, b) => b.vehicle.totalBookings.compareTo(a.vehicle.totalBookings));
        break;
      case SortOption.newest:
        sorted.sort((a, b) => b.slot.createdAt.compareTo(a.slot.createdAt));
        break;
      case SortOption.oldest:
        sorted.sort((a, b) => a.slot.createdAt.compareTo(b.slot.createdAt));
        break;
    }
    
    return sorted;
  }

  List<SlotFeedItem> _sortByDistance(List<SlotFeedItem> items) {
    final userPos = _currentUserPosition;
    if (userPos == null) return items;

    final withDist = items.map((e) {
      final vehiclePos = _vehicleResolvedLatLng(e.vehicle);
      final distance = vehiclePos != null
          ? _haversineKm(userPos.$1, userPos.$2, vehiclePos.$1, vehiclePos.$2)
          : double.infinity;
      return (item: e, distance: distance);
    }).toList();

    withDist.sort((a, b) => a.distance.compareTo(b.distance));
    return withDist.map((e) => e.item).toList();
  }

  (double, double)? _currentUserPosition;

  (double, double)? _vehicleResolvedLatLng(Vehicle vehicle) {
    switch (vehicle.gpsMode) {
      case VehicleGpsMode.manual:
        if (vehicle.manualLat == null || vehicle.manualLng == null) return null;
        return (vehicle.manualLat!, vehicle.manualLng!);
      case VehicleGpsMode.externalLink:
      case VehicleGpsMode.deviceLive:
        if (vehicle.lastKnownLat == null || vehicle.lastKnownLng == null) {
          return null;
        }
        return (vehicle.lastKnownLat!, vehicle.lastKnownLng!);
    }
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            (math.sin(dLon / 2) * math.sin(dLon / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * (3.14159265359 / 180.0);

  Future<bool> _requestUserLocation() async {
    final status = await Permission.locationWhenInUse.request();
    if (status != PermissionStatus.granted) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
      return false;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return false;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 12));
      if (mounted) {
        setState(() {
          _currentUserPosition = (pos.latitude, pos.longitude);
        });
      }
      return true;
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location request timed out')),
        );
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not get location')));
      }
      return false;
    }
  }

  Future<void> _openFiltersSheet(BuildContext context) async {
    final minPriceController = TextEditingController(
      text: _minPrice?.toInt().toString() ?? '',
    );
    final maxPriceController = TextEditingController(
      text: _maxPrice?.toInt().toString() ?? '',
    );
    final maxDistanceController = TextEditingController(
      text: _maxDistanceKm?.toStringAsFixed(
            _maxDistanceKm != null && _maxDistanceKm! % 1 == 0 ? 0 : 1,
          ) ??
          '',
    );
    final minSecurityDepositController = TextEditingController(
      text: _minSecurityDeposit?.toInt().toString() ?? '',
    );
    final maxSecurityDepositController = TextEditingController(
      text: _maxSecurityDeposit?.toInt().toString() ?? '',
    );
    final minWeightController = TextEditingController(
      text: _minParcelWeight?.toString() ?? '',
    );
    final maxWeightController = TextEditingController(
      text: _maxParcelWeight?.toString() ?? '',
    );
    final minLengthController = TextEditingController(
      text: _minParcelLength?.toString() ?? '',
    );
    final maxLengthController = TextEditingController(
      text: _maxParcelLength?.toString() ?? '',
    );
    final minWidthController = TextEditingController(
      text: _minParcelWidth?.toString() ?? '',
    );
    final maxWidthController = TextEditingController(
      text: _maxParcelWidth?.toString() ?? '',
    );
    final minHeightController = TextEditingController(
      text: _minParcelHeight?.toString() ?? '',
    );
    final maxHeightController = TextEditingController(
      text: _maxParcelHeight?.toString() ?? '',
    );
    final fromLocationController = TextEditingController(
      text: _filterFromLocation ?? '',
    );
    final toLocationController = TextEditingController(
      text: _filterToLocation ?? '',
    );
    final baseLocationController = TextEditingController(
      text: _filterBaseLocation ?? '',
    );

    DateTime? from = _fromDateTime;
    DateTime? to = _toDateTime;
    bool nearest = _nearestEnabled;
    bool requestingLocation = false;
    String? businessType =
        ProfileRepository.instance.profile.value.businessType;
    SlotType? slotType = _selectedSlotType;
    PickupMode? pickupMode = _selectedPickupMode;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final sheetMaxHeight = MediaQuery.of(context).size.height * 0.85;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: sheetMaxHeight),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: nearest,
                        onChanged: (v) async {
                          if (requestingLocation) return;
                          if (!v) {
                            setSheetState(() => nearest = false);
                            return;
                          }
                          if (_currentUserPosition != null) {
                            setSheetState(() => nearest = true);
                            return;
                          }
                          setSheetState(() => requestingLocation = true);
                          final ok = await _requestUserLocation();
                          if (!mounted) return;
                          setSheetState(() {
                            requestingLocation = false;
                            nearest = ok && _currentUserPosition != null;
                          });
                        },
                        title: const Text('Nearest first'),
                        subtitle: Text(
                          _currentUserPosition == null
                              ? 'Requires location permission'
                              : 'Sort by distance from your location',
                        ),
                        secondary: requestingLocation
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: maxDistanceController,
                        decoration: const InputDecoration(
                          labelText: 'Max distance (km)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.social_distance),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Branding type',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<ProfileInfo>(
                        valueListenable: ProfileRepository.instance.profile,
                        builder: (context, info, _) {
                          final current = businessType ?? info.businessType;
                          return Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Solo'),
                                selected: current == 'solo',
                                onSelected: (_) async {
                                  setSheetState(() => businessType = 'solo');
                                  await ProfileRepository.instance.update(
                                    businessType: 'solo',
                                    setBusinessTypeNull: false,
                                  );
                                },
                              ),
                              ChoiceChip(
                                label: const Text('Pvt'),
                                selected: current == 'private',
                                onSelected: (_) async {
                                  setSheetState(
                                      () => businessType = 'private');
                                  await ProfileRepository.instance.update(
                                    businessType: 'private',
                                    setBusinessTypeNull: false,
                                  );
                                },
                              ),
                              ChoiceChip(
                                label: const Text('LLM'),
                                selected: current == 'llc',
                                onSelected: (_) async {
                                  setSheetState(() => businessType = 'llc');
                                  await ProfileRepository.instance.update(
                                    businessType: 'llc',
                                    setBusinessTypeNull: false,
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Route type',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: SlotType.values
                            .map(
                              (t) => ChoiceChip(
                                label: Text(t.displayName),
                                selected: slotType == t,
                                onSelected: (_) => setSheetState(() {
                                  slotType = slotType == t ? null : t;
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      if (slotType == SlotType.fromTo) ...[
                        _locationAutocompleteField(
                          controller: fromLocationController,
                          label: 'From location',
                          icon: Icons.my_location,
                          suggestions: _allLocationNames(field: 'from'),
                          onChanged: () => setSheetState(() {}),
                        ),
                        const SizedBox(height: 12),
                        _locationAutocompleteField(
                          controller: toLocationController,
                          label: 'To location',
                          icon: Icons.place,
                          suggestions: _allLocationNames(field: 'to'),
                          onChanged: () => setSheetState(() {}),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (slotType == SlotType.fromRange) ...[
                        _locationAutocompleteField(
                          controller: baseLocationController,
                          label: 'Base location',
                          icon: Icons.location_on,
                          suggestions: _allLocationNames(field: 'base'),
                          onChanged: () => setSheetState(() {}),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Text(
                        'Pickup mode',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: PickupMode.values
                            .map(
                              (m) => ChoiceChip(
                                label: Text(m.shortLabel),
                                selected: pickupMode == m,
                                onSelected: (_) => setSheetState(() {
                                  pickupMode = pickupMode == m ? null : m;
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Booking Mode',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: PostMode.values
                            .map(
                              (m) => ChoiceChip(
                                label: Text(m.displayName),
                                selected: _selectedPostMode == m,
                                onSelected: (_) => setSheetState(() {
                                  _selectedPostMode = _selectedPostMode == m ? null : m;
                                  // Reset deadline filter when changing mode
                                  if (_selectedPostMode != PostMode.waitForFull) {
                                    _waitForFullDeadlineHours = null;
                                  }
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      if (_selectedPostMode == PostMode.waitForFull) ...[
                        const SizedBox(height: 12),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Deadline (hours before start)',
                            helperText: 'Filter by confirmation deadline',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.schedule),
                          ),
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: _waitForFullDeadlineHours?.toString() ?? '',
                          ),
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            setSheetState(() {
                              _waitForFullDeadlineHours = parsed;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: minPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Min Price',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.currency_rupee),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: maxPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Max Price',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.currency_rupee),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_month),
                        title: const Text('From date/time'),
                        subtitle:
                            Text(from == null ? 'Any' : _fmtDateTime(from!)),
                        trailing: TextButton(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              initialDate: from ?? DateTime.now(),
                            );
                            if (!context.mounted) return;
                            if (pickedDate == null) return;
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(
                                from ?? DateTime.now(),
                              ),
                              builder: (ctx, child) => MediaQuery(
                                data: MediaQuery.of(ctx).copyWith(
                                    alwaysUse24HourFormat: true),
                                child: child!,
                              ),
                            );
                            if (!context.mounted) return;
                            if (pickedTime == null) return;
                            setSheetState(() {
                              from = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          },
                          child: const Text('Pick'),
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_month),
                        title: const Text('To date/time'),
                        subtitle: Text(to == null ? 'Any' : _fmtDateTime(to!)),
                        trailing: TextButton(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              initialDate: to ?? (from ?? DateTime.now()),
                            );
                            if (!context.mounted) return;
                            if (pickedDate == null) return;
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime:
                                  TimeOfDay.fromDateTime(to ?? DateTime.now()),
                              builder: (ctx, child) => MediaQuery(
                                data: MediaQuery.of(ctx).copyWith(
                                    alwaysUse24HourFormat: true),
                                child: child!,
                              ),
                            );
                            if (!context.mounted) return;
                            if (pickedTime == null) return;
                            setSheetState(() {
                              to = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          },
                          child: const Text('Pick'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedServiceType == ServiceType.lease) ...[
                        const Text(
                          'Security Deposit',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minSecurityDepositController,
                                decoration: const InputDecoration(
                                  labelText: 'Min Deposit',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.currency_rupee),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: maxSecurityDepositController,
                                decoration: const InputDecoration(
                                  labelText: 'Max Deposit',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.currency_rupee),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_selectedServiceType == ServiceType.parcel) ...[
                        const Text(
                          'Parcel Dimensions',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minWeightController,
                                decoration: const InputDecoration(
                                  labelText: 'Min Weight (kg)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.scale),
                                ),
                                keyboardType:
                                    TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: maxWeightController,
                                decoration: const InputDecoration(
                                  labelText: 'Max Weight (kg)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.scale),
                                ),
                                keyboardType:
                                    TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minLengthController,
                                decoration: const InputDecoration(
                                  labelText: 'Min Length (cm)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.straighten),
                                ),
                                keyboardType:
                                    TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: maxLengthController,
                                decoration: const InputDecoration(
                                  labelText: 'Max Length (cm)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.straighten),
                                ),
                                keyboardType:
                                    TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minWidthController,
                                decoration: const InputDecoration(
                                  labelText: 'Min Width (cm)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.width_normal),
                                ),
                                keyboardType:
                                    TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: maxWidthController,
                                decoration: const InputDecoration(
                                  labelText: 'Max Width (cm)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.width_normal),
                                ),
                                keyboardType:
                                    TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minHeightController,
                                decoration: const InputDecoration(
                                  labelText: 'Min Height (cm)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.height),
                                ),
                                keyboardType:
                                    TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: maxHeightController,
                                decoration: const InputDecoration(
                                  labelText: 'Max Height (cm)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.height),
                                ),
                                keyboardType:
                                    TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _minPrice = null;
                                  _maxPrice = null;
                                  _fromDateTime = null;
                                  _toDateTime = null;
                                  _nearestEnabled = false;
                                  _maxDistanceKm = null;
                                  _minSecurityDeposit = null;
                                  _maxSecurityDeposit = null;
                                  _selectedSlotType = null;
                                  _selectedPickupMode = null;
                                  _selectedPostMode = null;
                                  _waitForFullDeadlineHours = null;
                                  _filterFromLocation = null;
                                  _filterToLocation = null;
                                  _filterBaseLocation = null;
                                  _filterBaseLatLon = null;
                                  _minParcelWeight = null;
                                  _maxParcelWeight = null;
                                  _minParcelLength = null;
                                  _maxParcelLength = null;
                                  _minParcelWidth = null;
                                  _maxParcelWidth = null;
                                  _minParcelHeight = null;
                                  _maxParcelHeight = null;
                                  _selectedServiceType = null;
                                  _searchController.clear();
                                  _fromSearchController.clear();
                                  _toSearchController.clear();
                                  _baseSearchController.clear();
                                });
                                Navigator.pop(context);
                              },
                              child: const Text('Reset'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                final parsedMaxDistance = double.tryParse(
                                    maxDistanceController.text.trim());
                                final wantsDistance = parsedMaxDistance !=
                                        null &&
                                    parsedMaxDistance.isFinite &&
                                    parsedMaxDistance > 0;
                                if (wantsDistance && _currentUserPosition == null) {
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                  await _requestUserLocation();
                                  if (!mounted) return;
                                  if (_currentUserPosition == null) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Location permission required for distance filter',
                                          ),
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                }
                                setState(() {
                                  _minPrice =
                                      double.tryParse(minPriceController.text);
                                  _maxPrice =
                                      double.tryParse(maxPriceController.text);
                                  _fromDateTime = from;
                                  _toDateTime = to;
                                  _nearestEnabled = nearest;
                                  _maxDistanceKm =
                                      wantsDistance ? parsedMaxDistance : null;
                                  _minSecurityDeposit = _selectedServiceType ==
                                          ServiceType.lease
                                      ? double.tryParse(
                                          minSecurityDepositController.text,
                                        )
                                      : null;
                                  _maxSecurityDeposit = _selectedServiceType ==
                                          ServiceType.lease
                                      ? double.tryParse(
                                          maxSecurityDepositController.text,
                                        )
                                      : null;
                                  _selectedSlotType = slotType;
                                  _selectedPickupMode = pickupMode;
                                  _filterFromLocation =
                                      fromLocationController.text.trim().isEmpty
                                          ? null
                                          : fromLocationController.text.trim();
                                  _filterToLocation =
                                      toLocationController.text.trim().isEmpty
                                          ? null
                                          : toLocationController.text.trim();
                                  _filterBaseLocation =
                                      baseLocationController.text.trim().isEmpty
                                          ? null
                                          : baseLocationController.text.trim();
                                  _fromSearchController.text =
                                      _filterFromLocation ?? '';
                                  _toSearchController.text = _filterToLocation ?? '';
                                  _baseSearchController.text =
                                      _filterBaseLocation ?? '';
                                  _filterBaseLatLon = null;
                                  _minParcelWeight =
                                      _selectedServiceType == ServiceType.parcel
                                          ? double.tryParse(minWeightController.text)
                                          : null;
                                  _maxParcelWeight =
                                      _selectedServiceType == ServiceType.parcel
                                          ? double.tryParse(maxWeightController.text)
                                          : null;
                                  _minParcelLength =
                                      _selectedServiceType == ServiceType.parcel
                                          ? double.tryParse(minLengthController.text)
                                          : null;
                                  _maxParcelLength =
                                      _selectedServiceType == ServiceType.parcel
                                          ? double.tryParse(maxLengthController.text)
                                          : null;
                                  _minParcelWidth =
                                      _selectedServiceType == ServiceType.parcel
                                          ? double.tryParse(minWidthController.text)
                                          : null;
                                  _maxParcelWidth =
                                      _selectedServiceType == ServiceType.parcel
                                          ? double.tryParse(maxWidthController.text)
                                          : null;
                                  _minParcelHeight =
                                      _selectedServiceType == ServiceType.parcel
                                          ? double.tryParse(minHeightController.text)
                                          : null;
                                  _maxParcelHeight =
                                      _selectedServiceType == ServiceType.parcel
                                          ? double.tryParse(maxHeightController.text)
                                          : null;
                                });

                                final baseText = _filterBaseLocation;
                                if (baseText != null && baseText.length >= 3) {
                                  final results =
                                      await LocationAutocompleteService.instance
                                          .searchLocations(baseText);
                                  if (results.isNotEmpty && mounted) {
                                    setState(() {
                                      _filterBaseLatLon =
                                          (results.first.lat, results.first.lon);
                                    });
                                  }
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Autocomplete text field backed by in-app slot location names
  Widget _locationAutocompleteField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Set<String> suggestions,
    required VoidCallback onChanged,
  }) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textEditingValue) {
        final q = textEditingValue.text.trim().toLowerCase();
        if (q.isEmpty) return suggestions;
        return suggestions.where((s) => s.toLowerCase().contains(q));
      },
      onSelected: (value) {
        controller.text = value;
        onChanged();
      },
      fieldViewBuilder: (context, fieldController, focusNode, onSubmitted) {
        // Keep our controller in sync
        fieldController.text = controller.text;
        fieldController.addListener(() => controller.text = fieldController.text);
        return TextField(
          controller: fieldController,
          focusNode: focusNode,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            prefixIcon: Icon(icon),
            suffixIcon: fieldController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      fieldController.clear();
                      controller.clear();
                      onChanged();
                    },
                  )
                : null,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on, size: 16),
                    title: Text(option, style: const TextStyle(fontSize: 13)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Extracts unique human-readable location names from all slots in the app.
  /// Locations are stored as "Name|lat,lon" — we return just the Name part.
  Set<String> _allLocationNames({required String field}) {
    final allSlots = [
      ...SlotRepository.instance.allSlots.map((e) => e.slot),
      ...CustomerSlotRepository.instance.allSlots.map((e) => e.slot),
    ];
    final names = <String>{};
    for (final slot in allSlots) {
      String? raw;
      if (field == 'from') raw = slot.fromLocation;
      if (field == 'to') raw = slot.toLocation;
      if (field == 'base') raw = slot.baseLocation;
      if (raw == null || raw.isEmpty) continue;
      final name = raw.contains('|') ? raw.split('|').first.trim() : raw.trim();
      if (name.isNotEmpty) names.add(name);
    }
    return names;
  }

  String _fmtDateTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $h:$m';
  }

  Future<void> _handleBookingAction({
    required Slot slot,
    required String providerId,
    required String userId,
    required bool isOffer,
    String? providerName,
    String? providerPhone,
    String? providerEmail,
    String? providerAvatar,
  }) async {
    // Guest-first: Check if user is logged in before booking
    if (AuthRepository.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please login to book'),
          action: SnackBarAction(
            label: 'Login',
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
          ),
        ),
      );
      return;
    }

    debugPrint('🎫 Booking action started for slot: ${slot.id}');

    final canBook = BookingRepository.instance.canBook(slot.id, slot.capacity);
    if (!canBook) {
      debugPrint('❌ Cannot book: No capacity remaining');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No capacity remaining')));
      return;
    }

    debugPrint(
      '✅ Capacity check passed, looking for vehicle: ${slot.vehicleId}',
    );

    final vehicle = VehicleRepository.instance.getById(slot.vehicleId);
    if (vehicle == null) {
      debugPrint('❌ Vehicle not found in VehicleRepository: ${slot.vehicleId}');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vehicle not found')));
      return;
    }

    debugPrint('✅ Vehicle found, showing booking sheet');

    final result = await showModalBottomSheet<BookingConfirmResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => BookingConfirmSheet(
        slot: slot,
        isOffer: isOffer,
        providerId: slot.profileId, // Use post owner
      ),
    );

    if (result == null) {
      debugPrint('❌ Booking cancelled by user or already created');
      return;
    }

    if (!mounted) return;

    // Use fallback provider info if not provided
    // Priority: 1. Operator contact (if assigned), 2. Provided contact, 3. Owner contact
    final finalProviderName = providerName ?? vehicle.userName;
    final finalProviderPhone = providerPhone ?? 
        (vehicle.operatorPhone ?? _providerPhone(vehicle.userId));

    debugPrint('=== BOOKING DEBUG ===');
    debugPrint('Post profileId: ${slot.profileId}');
    debugPrint('Vehicle userId: ${vehicle.userId}');
    debugPrint('Current user ID: ${AuthRepository.instance.currentUser?.id}');
    debugPrint('Provider ID for booking: ${slot.profileId}');
    debugPrint('====================');

    final confirmedCount = result.seatKeys.length;
    if (confirmedCount == 0) {
      debugPrint('⚠️ No seats selected, booking already created in sheet');
      return;
    }

    final SeatLayout? layout = slot.seatLayoutOwnerId == null
        ? null
        : SeatLayoutRepository.instance.getLayout(slot.seatLayoutOwnerId!);

    final createdBookings = <Booking>[];
    for (var i = 0; i < confirmedCount; i++) {
      final seatKey = result.seatKeys[i];
      final seatPrice = (layout != null && seatKey != null)
          ? layout.cells[seatKey]?.price
          : null;
      final double bookingPrice = (seatPrice ?? slot.price.toInt()).toDouble();

      final booking = await BookingRepository.instance.createBooking(
        slotId: slot.id,
        providerId: slot.profileId, // Use post owner
        providerName: finalProviderName,
        providerPhone: finalProviderPhone,
        providerEmail: providerEmail,
        providerAvatar: providerAvatar,
        userId: AuthRepository.instance.currentUser?.id ?? 'guest',
        defaultCapacity: slot.capacity,
        price: bookingPrice,
        seatKey: seatKey,
        userName: result.userNames[i],
        userAge: result.userAges[i],
        userGender: result.userGenders[i],
        userPhone: result.userPhones[i],
        userEmail: result.userEmails[i],
        securityDeposit: slot.serviceType.name == 'lease' ? slot.securityDeposit : null,
      );

      if (booking == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to book. Seat may be taken.')),
        );
        return;
      }

      createdBookings.add(booking);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Booking request sent!')));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingMapScreen(
          booking: createdBookings.first,
          slot: slot,
          vehicle: vehicle,
          isProviderView: false,
          autoCloseSeconds: 3,
        ),
      ),
    );
  }

  String _providerPhone(String providerId) {
    // Use current profile phone if it's the current user or 'user1', otherwise use default
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser != null &&
        (providerId == currentUser.id || providerId == 'user1')) {
      return ProfileRepository.instance.profile.value.phone ??
          '+91 90000 00000';
    }
    return '+91 98765 43210';
  }
}

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  DateTimeRange? _dateRange;

  void _showDateRangeFilter() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _dateRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requests'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear date filter',
              onPressed: _clearDateFilter,
            ),
          IconButton(
            icon: Icon(
              _dateRange != null ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _dateRange != null ? Colors.blue : null,
            ),
            tooltip: 'Filter by date range',
            onPressed: _showDateRangeFilter,
          ),
        ],
      ),
      body: _RequestsBody(dateRange: _dateRange),
    );
  }
}

class _RequestsBody extends StatefulWidget {
  final DateTimeRange? dateRange;
  
  const _RequestsBody({this.dateRange});

  @override
  State<_RequestsBody> createState() => _RequestsBodyState();
}

class _RequestsBodyState extends State<_RequestsBody> {
  bool _isRiderView = true;
  final Map<String, TextEditingController> _otpControllers = {};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Set<BookingStatus> _statusFilters = {}; // Empty = show all
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Wait a bit for repositories to initialize
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    for (final c in _otpControllers.values) {
      c.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  TextEditingController _otpControllerFor(String bookingId) {
    return _otpControllers.putIfAbsent(
      bookingId,
      () => TextEditingController(),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isRiderView = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isRiderView ? Colors.blue : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Customer',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isRiderView ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isRiderView = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isRiderView ? Colors.blue : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Provider',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !_isRiderView ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, status, time...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        const SizedBox(height: 8),
        // Status filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Active', style: TextStyle(fontSize: 12)),
                  selected: _statusFilters.contains(BookingStatus.accepted),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _statusFilters.add(BookingStatus.accepted);
                      } else {
                        _statusFilters.remove(BookingStatus.accepted);
                      }
                    });
                  },
                  selectedColor: Colors.green.withValues(alpha: 0.3),
                  checkmarkColor: Colors.green,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Completed', style: TextStyle(fontSize: 12)),
                  selected: _statusFilters.contains(BookingStatus.completed),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _statusFilters.add(BookingStatus.completed);
                      } else {
                        _statusFilters.remove(BookingStatus.completed);
                      }
                    });
                  },
                  selectedColor: Colors.blue.withValues(alpha: 0.3),
                  checkmarkColor: Colors.blue,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Refunded', style: TextStyle(fontSize: 12)),
                  selected: _statusFilters.contains(BookingStatus.refunded),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _statusFilters.add(BookingStatus.refunded);
                      } else {
                        _statusFilters.remove(BookingStatus.refunded);
                      }
                    });
                  },
                  selectedColor: Colors.orange.withValues(alpha: 0.3),
                  checkmarkColor: Colors.orange,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Pending', style: TextStyle(fontSize: 12)),
                  selected: _statusFilters.contains(BookingStatus.pending),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _statusFilters.add(BookingStatus.pending);
                      } else {
                        _statusFilters.remove(BookingStatus.pending);
                      }
                    });
                  },
                  selectedColor: Colors.amber.withValues(alpha: 0.3),
                  checkmarkColor: Colors.amber,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (widget.dateRange != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filtered: ${_formatDate(widget.dateRange!.start)} - ${_formatDate(widget.dateRange!.end)}',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (widget.dateRange != null) const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ValueListenableBuilder<List<Booking>>(
            valueListenable: BookingRepository.instance.bookings,
            builder: (context, bookings, _) {
              return ValueListenableBuilder<List<UserPostAcceptance>>(
                valueListenable: UserPostAcceptanceRepository.instance.acceptances,
                builder: (context, acceptances, _) {
                  final currentUser = AuthRepository.instance.currentUser;
                  if (currentUser == null) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text('Please login to view requests'),
                      ),
                    );
                  }

                  final filteredBookings = bookings
                      .where((b) {
                        if (_isRiderView) {
                          if (b.userId != currentUser.id) return false;
                        } else {
                          if (b.providerId != currentUser.id && b.providerId != 'user1') return false;
                        }
                        
                        // Status filter
                        if (_statusFilters.isNotEmpty && !_statusFilters.contains(b.status)) {
                          return false;
                        }
                        
                        // Date range filter
                        if (widget.dateRange != null) {
                          final bookingDate = b.createdAt;
                          final startDate = widget.dateRange!.start;
                          final endDate = widget.dateRange!.end.add(const Duration(days: 1)); // Include end date
                          if (bookingDate.isBefore(startDate) || bookingDate.isAfter(endDate)) {
                            return false;
                          }
                        }
                        
                        if (_query.isEmpty) return true;
                        return (b.providerName ?? '').toLowerCase().contains(_query) ||
                            (b.userName ?? '').toLowerCase().contains(_query) ||
                            b.status.name.toLowerCase().contains(_query) ||
                            b.id.toLowerCase().contains(_query) ||
                            b.slotId.toLowerCase().contains(_query);
                      })
                      .toList(growable: false);

                  final filteredAcceptances = acceptances
                      .where((a) {
                        if (_isRiderView) {
                          if (a.userId != currentUser.id) return false;
                        } else {
                          if (a.providerId != currentUser.id) return false;
                        }
                        
                        // Date range filter
                        if (widget.dateRange != null) {
                          final acceptanceDate = a.createdAt;
                          final startDate = widget.dateRange!.start;
                          final endDate = widget.dateRange!.end.add(const Duration(days: 1)); // Include end date
                          if (acceptanceDate.isBefore(startDate) || acceptanceDate.isAfter(endDate)) {
                            return false;
                          }
                        }
                        
                        if (_query.isEmpty) return true;
                        return a.status.name.toLowerCase().contains(_query);
                      })
                      .toList(growable: false);

                  if (filteredBookings.isEmpty && filteredAcceptances.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isRiderView
                                  ? 'No bookings yet'
                                  : 'No provider bookings yet',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16),
                            ),
                            if (bookings.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Clear All Bookings?'),
                                      content: const Text(
                                        'This will delete all bookings. This action cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Clear All'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    BookingRepository.instance.bookings.value = [];
                                    BookingRepository
                                            .instance
                                            .remainingCapacityBySlotId
                                            .value = {};
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.remove('bookings_data');
                                    await prefs.remove('remaining_capacity');
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('All bookings cleared'),
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.delete_sweep),
                                label: const Text('Clear All Bookings'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  // Combine both lists: slot bookings first, then post acceptances
                  final totalCount = filteredBookings.length + filteredAcceptances.length;

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: totalCount,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index < filteredBookings.length) {
                        return _buildBookingCard(
                          context,
                          filteredBookings[index],
                          isRiderView: _isRiderView,
                        );
                      } else {
                        final acceptance = filteredAcceptances[index - filteredBookings.length];
                        return _buildAcceptanceCard(context, acceptance);
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAcceptanceCard(BuildContext context, UserPostAcceptance acceptance) {
    final currentUser = AuthRepository.instance.currentUser;
    final isUserView = currentUser?.id == acceptance.userId;

    // Look up the related post for details
    UserPost? post;
    try {
      post = UserPostRepository.instance.posts.value
          .firstWhere((p) => p.id == acceptance.postId);
    } catch (_) {}

    Color statusColor;
    String statusLabel;
    switch (acceptance.status) {
      case AcceptanceStatus.pending:
        statusColor = Colors.orange;
        statusLabel = 'Pending OTP';
        break;
      case AcceptanceStatus.otpVerified:
        statusColor = Colors.blue;
        statusLabel = 'OTP Verified';
        break;
      case AcceptanceStatus.paid:
        statusColor = Colors.green;
        statusLabel = 'Completed';
        break;
      case AcceptanceStatus.cancelled:
        statusColor = Colors.red;
        statusLabel = 'Cancelled';
        break;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_turned_in_outlined, size: 16, color: Colors.purple),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Post Request #${acceptance.postId.length > 8 ? acceptance.postId.substring(0, 8) : acceptance.postId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (post != null) ...[
              const SizedBox(height: 8),
              Text(
                '${_getServiceTypeName(post.serviceType)} · ${_fmtDateTime(post.startTime)}',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              if (post.fromLocation != null && post.toLocation != null)
                Text(
                  '${post.fromLocation} → ${post.toLocation}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
            const Divider(height: 20),
            Row(
              children: [
                Icon(Icons.currency_rupee, size: 14, color: Colors.grey[600]),
                Text(
                  acceptance.amount.toStringAsFixed(0),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const Spacer(),
                Text(
                  _fmtDateTime(acceptance.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            // OTP section: user sees OTP to share, provider enters OTP
            if (acceptance.status == AcceptanceStatus.pending) ...[
              const SizedBox(height: 12),
              if (isUserView) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 18, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Share this OTP with the provider',
                                style: TextStyle(fontSize: 12, color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text(
                              acceptance.otp ?? '------',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (acceptance.otp != null)
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          tooltip: 'Copy OTP',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: acceptance.otp!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('OTP copied')),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ] else ...[
                // Provider enters OTP
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _otpControllerFor(acceptance.id),
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'Enter OTP from user',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final otpText = _otpControllerFor(acceptance.id).text;
                        if (otpText.length != 6) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Please enter 6-digit OTP')),
                          );
                          return;
                        }
                        final ok = await UserPostAcceptanceRepository.instance
                            .verifyOTP(acceptanceId: acceptance.id, enteredOTP: otpText);
                        if (!context.mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(ok ? '✅ OTP verified' : 'Invalid OTP'),
                            backgroundColor: ok ? Colors.green : Colors.red,
                          ),
                        );
                      },
                      child: const Text('Verify'),
                    ),
                  ],
                ),
              ],
            ],
            if (acceptance.status == AcceptanceStatus.otpVerified) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('OTP verified — awaiting payment', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
            if (acceptance.status == AcceptanceStatus.paid) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Payment completed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getServiceTypeName(dynamic serviceType) {
    return serviceType?.toString().split('.').last ?? 'Service';
  }

  Widget _buildBookingCard(
    BuildContext context,
    Booking b, {
    required bool isRiderView,
  }) {
    final status = _statusLabel(b.status);
    final color = _statusColor(b.status);
    Slot? bookingSlot;
    // Try to find slot in both provider and user repositories
    for (final e in SlotRepository.instance.allSlots) {
      if (e.slot.id == b.slotId) {
        bookingSlot = e.slot;
        break;
      }
    }
    // If not found in provider slots, check user slots
    if (bookingSlot == null) {
      for (final e in CustomerSlotRepository.instance.allSlots) {
        if (e.slot.id == b.slotId) {
          bookingSlot = e.slot;
          break;
        }
      }
    }
    final Slot? slotForMap = b.status == BookingStatus.accepted
        ? bookingSlot
        : null;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Booking #${b.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  child: const Icon(Icons.person, size: 16, color: Colors.blue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.userName ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${b.userAge ?? '?'} yrs · ${b.userGender?.name ?? 'Any'}${b.seatKey != null ? ' · Seat: ${b.seatKey}' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Slot: ${b.slotId}',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            const SizedBox(height: 4),
            if (bookingSlot != null) ...[
              // GPS Type and Location
              Builder(
                builder: (context) {
                  // Find vehicle for this booking
                  Vehicle? vehicle;
                  for (final e in VehicleRepository.instance.allVehicles) {
                    if (e.id == bookingSlot!.vehicleId) {
                      vehicle = e;
                      break;
                    }
                  }
                  if (vehicle == null) {
                    for (final e in CustomerVehicleRepository.instance.allVehicles) {
                      if (e.id == bookingSlot!.vehicleId) {
                        vehicle = e;
                        break;
                      }
                    }
                  }
                  
                  if (vehicle == null) return const SizedBox.shrink();
                  
                  final IconData gpsIcon;
                  final String gpsLabel;
                  final Color gpsColor;
                  
                  switch (vehicle.gpsMode) {
                    case VehicleGpsMode.deviceLive:
                      gpsIcon = Icons.gps_fixed;
                      gpsLabel = 'Live GPS';
                      gpsColor = Colors.green;
                      break;
                    case VehicleGpsMode.externalLink:
                      gpsIcon = Icons.link;
                      gpsLabel = 'External GPS';
                      gpsColor = Colors.blue;
                      break;
                    case VehicleGpsMode.manual:
                      gpsIcon = Icons.edit_location_alt;
                      gpsLabel = 'Manual Location';
                      gpsColor = Colors.orange;
                      break;
                  }
                  
                  double? lat;
                  double? lng;
                  
                  if (vehicle.gpsMode == VehicleGpsMode.manual) {
                    lat = vehicle.manualLat;
                    lng = vehicle.manualLng;
                  } else {
                    lat = vehicle.lastKnownLat;
                    lng = vehicle.lastKnownLng;
                  }
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(gpsIcon, size: 14, color: gpsColor),
                          const SizedBox(width: 6),
                          Text(
                            gpsLabel,
                            style: TextStyle(
                              fontSize: 13,
                              color: gpsColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (lat != null && lng != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.map, size: 18, color: Colors.blue),
                              tooltip: 'Open in Google Maps',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _openGoogleMapsLatLng(context, lat!, lng!),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
            ] else
              Text(
                'Booked: ${_fmtDateTime(b.createdAt)}',
                style: TextStyle(color: Colors.grey[700]),
              ),
            if (slotForMap != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (slotForMap.fromLocation != null &&
                              slotForMap.toLocation != null)
                          ? '${_cleanLoc(slotForMap.fromLocation!)} → ${_cleanLoc(slotForMap.toLocation!)}'
                          : _cleanLoc(slotForMap.baseLocation),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open map',
                    onPressed: () =>
                        _openExternalMapForSlot(context, slotForMap),
                    icon: const Icon(Icons.map_outlined),
                  ),
                ],
              ),
            ],
            if (b.status == BookingStatus.accepted ||
                b.status == BookingStatus.completed ||
                b.status == BookingStatus.pending) ...[
              const SizedBox(height: 12),
              if (isRiderView) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_pin,
                        size: 20,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Provider: ${b.providerName ?? _providerName(b.providerId)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Contact: ${b.providerPhone ?? _providerPhone(b.providerId)}',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  tooltip: 'Copy contact',
                                  onPressed: () {
                                    final phone =
                                        b.providerPhone ??
                                        _providerPhone(b.providerId);
                                    Clipboard.setData(
                                      ClipboardData(text: phone),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Provider contact copied',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            if ((b.providerEmail ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Email: ${b.providerEmail}',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 18),
                                    tooltip: 'Copy email',
                                    onPressed: () {
                                      final email = b.providerEmail ?? '';
                                      Clipboard.setData(
                                        ClipboardData(text: email),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Provider email copied',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        b.paymentHeldInEscrow ? Icons.lock : Icons.lock_open,
                        size: 18,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.status == BookingStatus.completed
                                  ? 'Trip completed'
                                  : (b.paymentHeldInEscrow
                                      ? 'Payment Held in Escrow'
                                      : 'Booking Confirmed'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (b.otp != null && b.status != BookingStatus.completed) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'OTP: ',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  Text(
                                    b.otp!,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (b.otp != null && b.status != BookingStatus.completed)
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20, color: Colors.blue),
                          tooltip: 'Copy OTP',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: b.otp!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('OTP copied to clipboard')),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                // After end time: user can extend or request refund
                if (bookingSlot != null) ...[
                  const SizedBox(height: 10),
                  // Start and End times at the bottom
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Start: ${_fmtDateTime(bookingSlot.startTime)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.event_available, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'End:   ${_fmtDateTime(bookingSlot.endTime)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  _AutoRefundSection(
                    booking: b,
                    slot: bookingSlot,
                    isRiderView: isRiderView,
                  ),
                  const SizedBox(height: 6),
                  // Timing section with countdown as small hint at the very bottom
                  _BookingTimingSection(
                    booking: b,
                    slot: bookingSlot,
                    isRiderView: isRiderView,
                  ),
                ],
                // Add review button for completed trips (user view)
                if (b.status == BookingStatus.completed) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      final currentUser = AuthRepository.instance.currentUser;
                      if (currentUser == null) return;

                      final hasReviewed = ReviewRepository.instance.hasReviewed(
                        bookingId: b.id,
                        reviewerId: currentUser.id,
                      );

                      if (hasReviewed) {
                        // Show reviews
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReviewsScreen(
                              userId: b.providerId,
                              userName: b.providerName ?? _providerName(b.providerId),
                            ),
                          ),
                        );
                      } else {
                        // Leave review
                        showDialog(
                          context: context,
                          builder: (context) => ReviewDialog(
                            bookingId: b.id,
                            reviewerId: currentUser.id,
                            revieweeId: b.providerId,
                            revieweeName: b.providerName ?? _providerName(b.providerId),
                            type: ReviewType.userToProvider,
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      ReviewRepository.instance.hasReviewed(
                        bookingId: b.id,
                        reviewerId: AuthRepository.instance.currentUser?.id ?? '',
                      ) ? Icons.star : Icons.star_border,
                      size: 18,
                    ),
                    label: Text(
                      ReviewRepository.instance.hasReviewed(
                        bookingId: b.id,
                        reviewerId: AuthRepository.instance.currentUser?.id ?? '',
                      ) ? 'View Reviews' : 'Leave Review',
                    ),
                  ),
                ],
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_pin_circle,
                        size: 20,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User: ${b.userName ?? _userName(b.userId)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Contact: ${b.userPhone ?? _userPhone(b.userId)}',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  tooltip: 'Copy contact',
                                  onPressed: () {
                                    final phone =
                                        b.userPhone ?? _userPhone(b.userId);
                                    Clipboard.setData(
                                      ClipboardData(text: phone),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('User contact copied'),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            if ((b.userEmail ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Email: ${b.userEmail}',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 18),
                                    tooltip: 'Copy email',
                                    onPressed: () {
                                      final email = b.userEmail ?? '';
                                      Clipboard.setData(
                                        ClipboardData(text: email),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('User email copied'),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (b.status == BookingStatus.completed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified, size: 18, color: Colors.green),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'OTP verified',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (bookingSlot != null && DateTime.now().isAfter(bookingSlot.endTime))
                  // After end time: OTP entry for provider
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.timer_off_outlined, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Trip time over - Ask extension from user',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _otpControllerFor(b.id),
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: const InputDecoration(
                                labelText: 'Enter OTP to complete',
                                border: OutlineInputBorder(),
                                counterText: '',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final otpText = _otpControllerFor(b.id).text;
                              if (otpText.length != 6) {
                                messenger.showSnackBar(const SnackBar(content: Text('Please enter 6-digit OTP')));
                                return;
                              }
                              showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                              try {
                                if (b.paymentHeldInEscrow && b.stripePaymentIntentId != null) {
                                  final success = await StripeService.instance.verifyOtpAndRelease(bookingId: b.id, otp: otpText);
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  if (success) {
                                    await BookingRepository.instance.updateBookingAfterPayment(bookingId: b.id, status: BookingStatus.completed, otpVerified: true);
                                    if (context.mounted) {
                                      messenger.showSnackBar(const SnackBar(content: Text('✅ Payment released!'), backgroundColor: Colors.green));
                                      _promptForReview(context, b, isProvider: true);
                                    }
                                  } else {
                                    messenger.showSnackBar(const SnackBar(content: Text('Invalid OTP'), backgroundColor: Colors.red));
                                  }
                                } else {
                                  // Use OtpService for better error messages
                                  final result = await OtpService().verifyOtp(
                                    bookingId: int.parse(b.id),
                                    userId: b.userId,
                                    enteredOtp: otpText,
                                  );
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  
                                  if (result.isSuccess) {
                                    // Update local state
                                    await BookingRepository.instance.updateBookingAfterPayment(
                                      bookingId: b.id,
                                      status: BookingStatus.completed,
                                      otpVerified: true,
                                    );
                                    messenger.showSnackBar(SnackBar(
                                      content: Text(result.message),
                                      backgroundColor: Colors.green,
                                    ));
                                    if (context.mounted) _promptForReview(context, b, isProvider: true);
                                  } else {
                                    // Show specific error message
                                    messenger.showSnackBar(SnackBar(
                                      content: Text(result.message),
                                      backgroundColor: Colors.red,
                                    ));
                                  }
                                }
                              } catch (e) {
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                              }
                            },
                            child: const Text('Verify'),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _otpControllerFor(b.id),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'Enter OTP from user',
                            border: OutlineInputBorder(),
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final otpText = _otpControllerFor(b.id).text;

                          if (otpText.length != 6) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Please enter 6-digit OTP')),
                            );
                            return;
                          }

                          // Show loading
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );

                          try {
                            // If payment is held in escrow, verify with Stripe backend
                            if (b.paymentHeldInEscrow && b.stripePaymentIntentId != null) {
                              final success = await StripeService.instance.verifyOtpAndRelease(
                                bookingId: b.id,
                                otp: otpText,
                              );

                              if (!context.mounted) return;
                              Navigator.pop(context); // Close loading

                              if (success) {
                                // Update local booking status
                                await BookingRepository.instance.updateBookingAfterPayment(
                                  bookingId: b.id,
                                  status: BookingStatus.completed,
                                  otpVerified: true,
                                );

                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Payment released! Funds transferred to your account.'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 4),
                                  ),
                                );

                                // Prompt for review
                                if (context.mounted) {
                                  _promptForReview(context, b, isProvider: true);
                                }
                              } else {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Invalid OTP. Please try again.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } else {
                              // Use OtpService for better error messages
                              final result = await OtpService().verifyOtp(
                                bookingId: int.parse(b.id),
                                userId: b.userId,
                                enteredOtp: otpText,
                              );

                              if (!context.mounted) return;
                              Navigator.pop(context); // Close loading

                              if (result.isSuccess) {
                                // Update local booking status
                                await BookingRepository.instance.updateBookingAfterPayment(
                                  bookingId: b.id,
                                  status: BookingStatus.completed,
                                  otpVerified: true,
                                );

                                if (b.securityDeposit != null && b.securityDeposit! > 0) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '✅ OTP verified! Security deposit of ${AppPreferences.instance.formatMoney(b.securityDeposit!.toInt())} refunded to user.',
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                } else {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(result.message),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }

                                // Prompt for review if successful
                                if (context.mounted) {
                                  _promptForReview(context, b, isProvider: true);
                                }
                              } else {
                                // Show specific error message
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(result.message),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            Navigator.pop(context); // Close loading
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text('Verify'),
                      ),
                    ],
                  ),
                // Add review button for completed trips (provider view)
                if (!isRiderView && b.status == BookingStatus.completed) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      final currentUser = AuthRepository.instance.currentUser;
                      if (currentUser == null) return;

                      final hasReviewed = ReviewRepository.instance.hasReviewed(
                        bookingId: b.id,
                        reviewerId: currentUser.id,
                      );

                      if (hasReviewed) {
                        // Show reviews
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReviewsScreen(
                              userId: b.userId,
                              userName: b.userName ?? _userName(b.userId),
                            ),
                          ),
                        );
                      } else {
                        // Leave review
                        showDialog(
                          context: context,
                          builder: (context) => ReviewDialog(
                            bookingId: b.id,
                            reviewerId: currentUser.id,
                            revieweeId: b.userId,
                            revieweeName: b.userName ?? _userName(b.userId),
                            type: ReviewType.providerToUser,
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      ReviewRepository.instance.hasReviewed(
                        bookingId: b.id,
                        reviewerId: AuthRepository.instance.currentUser?.id ?? '',
                      ) ? Icons.star : Icons.star_border,
                      size: 18,
                    ),
                    label: Text(
                      ReviewRepository.instance.hasReviewed(
                        bookingId: b.id,
                        reviewerId: AuthRepository.instance.currentUser?.id ?? '',
                      ) ? 'View Reviews' : 'Leave Review',
                    ),
                  ),
                ],
              ],
              if (isRiderView) ...[const SizedBox(height: 12)],
            ],
          ],
        ),
      ),
    );
  }

  static String _statusLabel(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.accepted:
        return 'Accepted';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.rejected:
        return 'Rejected';
      case BookingStatus.refunded:
        return 'Refunded';
    }
  }

  static Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.accepted:
        return Colors.green;
      case BookingStatus.completed:
        return Colors.blue;
      case BookingStatus.rejected:
        return Colors.red;
      case BookingStatus.refunded:
        return Colors.purple;
    }
  }

  static String _fmtDateTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $h:$m';
  }

  String _providerName(String providerId) {
    // Try ProfileNameRegistry first
    final registryName = ProfileNameRegistry.instance.getNameForUser(providerId);
    if (registryName != null && registryName.isNotEmpty) return registryName;
    // Try vehicle repos
    try {
      final vehicle = VehicleRepository.instance.allVehicles.firstWhere(
        (v) => v.userId == providerId,
      );
      return vehicle.userName;
    } catch (_) {
      try {
        final vehicle = CustomerVehicleRepository.instance.allVehicles.firstWhere(
          (v) => v.userId == providerId,
        );
        return vehicle.userName;
      } catch (_) {
        return 'Provider';
      }
    }
  }

  String _providerPhone(String providerId) {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser != null && (providerId == currentUser.id || providerId == 'user1')) {
      return ProfileRepository.instance.profile.value.phone ?? '+91 90000 00000';
    }
    return '+91 90000 00000';
  }

  void _promptForReview(BuildContext context, Booking booking, {required bool isProvider}) {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return;

    // Check if already reviewed
    final hasReviewed = ReviewRepository.instance.hasReviewed(
      bookingId: booking.id,
      reviewerId: currentUser.id,
    );

    if (hasReviewed) return;

    // Determine who is being reviewed
    final revieweeId = isProvider ? booking.userId : booking.providerId;
    final revieweeName = isProvider
        ? (booking.userName ?? _userName(booking.userId))
        : (booking.providerName ?? _providerName(booking.providerId));

    final reviewType = isProvider
        ? ReviewType.providerToUser
        : ReviewType.userToProvider;

    // Show review dialog after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => ReviewDialog(
          bookingId: booking.id,
          reviewerId: currentUser.id,
          revieweeId: revieweeId,
          revieweeName: revieweeName,
          type: reviewType,
        ),
      );
    });
  }

  String _userName(String userId) {
    final registryName = ProfileNameRegistry.instance.getNameForUser(userId);
    if (registryName != null && registryName.isNotEmpty) return registryName;
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser != null && userId == currentUser.id) {
      return ProfileRepository.instance.profile.value.profileName;
    }
    return 'User';
  }

  String _userPhone(String userId) {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser != null && userId == currentUser.id) {
      return ProfileRepository.instance.profile.value.phone ?? '+91 90000 00000';
    }
    return '+91 90000 00000';
  }
}

/// Dialog for user to request a time extension on a booking.
class _ExtendTimeDialog extends StatefulWidget {
  final Booking booking;
  final Slot slot;
  const _ExtendTimeDialog({required this.booking, required this.slot});

  @override
  State<_ExtendTimeDialog> createState() => _ExtendTimeDialogState();
}

class _ExtendTimeDialogState extends State<_ExtendTimeDialog> {
  int _extraHours = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Extend Time'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How many extra hours do you need?'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _extraHours > 1 ? () => setState(() => _extraHours--) : null,
              ),
              Text('$_extraHours hr${_extraHours > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _extraHours < 12 ? () => setState(() => _extraHours++) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'New end time: ${_fmtDT(widget.slot.endTime.add(Duration(hours: _extraHours)))}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Extension request sent to provider (+$_extraHours hr${_extraHours > 1 ? 's' : ''})'),
                backgroundColor: Colors.blue,
              ),
            );
          },
          child: const Text('Request Extension'),
        ),
      ],
    );
  }

  static String _fmtDT(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $h:$m';
  }
}

/// Auto-refund section that shows refund button after trip end time
class _AutoRefundSection extends StatefulWidget {
  final Booking booking;
  final Slot slot;
  final bool isRiderView;

  const _AutoRefundSection({
    required this.booking,
    required this.slot,
    required this.isRiderView,
  });

  @override
  State<_AutoRefundSection> createState() => _AutoRefundSectionState();
}

class _AutoRefundSectionState extends State<_AutoRefundSection> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hasEnded = now.isAfter(widget.slot.endTime);
    final booking = widget.booking;

    // Don't show if already completed, refunded, or rejected
    if (booking.status == BookingStatus.completed ||
        booking.status == BookingStatus.refunded ||
        booking.status == BookingStatus.rejected) {
      return const SizedBox.shrink();
    }

    // Only show after end time
    if (!hasEnded) {
      return const SizedBox.shrink();
    }

    // Provider view: Show message to ask user for extension
    if (!widget.isRiderView) {
      return Row(
        children: [
          Icon(Icons.timer_off_outlined, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Trip time over - Ask extension from user',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ],
      );
    }

    // User view: Show refund option
    return Row(
      children: [
        Icon(Icons.timer_off_outlined, size: 12, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          'Service time ended',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        const Spacer(),
        InkWell(
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Request Refund'),
                content: const Text(
                  'The service time has ended. Do you want to request a refund?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Refund'),
                  ),
                ],
              ),
            );
            if (confirm != true || !context.mounted) return;
            await BookingRepository.instance.markRefunded(booking.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refund requested'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.undo, size: 12, color: Colors.red[700]),
              const SizedBox(width: 4),
              Text(
                'Refund',
                style: TextStyle(fontSize: 11, color: Colors.red[700], fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows a time-phase banner on a booking card:
/// • Before start time  → "Starts in HH:MM:SS"
/// • Between start & end → "In Progress · ends in HH:MM:SS"
/// • After end time      → "Service ended"
class _BookingTimingSection extends StatefulWidget {
  final Booking booking;
  final Slot slot;
  final bool isRiderView;

  const _BookingTimingSection({
    required this.booking,
    required this.slot,
    required this.isRiderView,
  });

  @override
  State<_BookingTimingSection> createState() => _BookingTimingSectionState();
}

class _BookingTimingSectionState extends State<_BookingTimingSection> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = widget.slot.startTime;
    final end = widget.slot.endTime;

    IconData icon;
    String label;

    if (now.isBefore(start)) {
      final diff = start.difference(now);
      icon = Icons.schedule;
      label = 'Starts in ${_fmt(diff)}';
    } else if (now.isBefore(end)) {
      final diff = end.difference(now);
      icon = Icons.play_circle_outline;
      label = 'Trip time · ends in ${_fmt(diff)}';
    } else {
      icon = Icons.timer_off_outlined;
      label = 'Service time ended';
    }

    // Display as small hint text
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class CountdownText extends StatefulWidget {
  final DateTime endTime;
  final DateTime? startTime;   // slot start time — shows "Trip starts in" phase
  final String? bookingId;     // if set, auto-refund fires when endTime passes
  const CountdownText({
    super.key,
    required this.endTime,
    this.startTime,
    this.bookingId,
  });

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  late Timer _timer;
  Duration _remaining = Duration.zero;
  bool _autoRefundFired = false;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    final now = DateTime.now();
    final start = widget.startTime;

    // Phase 1: before start time
    if (start != null && now.isBefore(start)) {
      final r = start.difference(now);
      setState(() => _remaining = r);
      return;
    }

    // Phase 2: between start and end
    final r = widget.endTime.difference(now);
    if (r.isNegative) {
      setState(() => _remaining = Duration.zero);
      // Auto-refund: fire once when end time passes
      if (!_autoRefundFired && widget.bookingId != null) {
        _autoRefundFired = true;
        _triggerAutoRefund();
      }
    } else {
      setState(() => _remaining = r);
    }
  }

  Future<void> _triggerAutoRefund() async {
    final id = widget.bookingId!;
    final booking = BookingRepository.instance.getBookingById(id);
    if (booking == null) return;
    if (booking.status == BookingStatus.completed ||
        booking.status == BookingStatus.refunded) {
      return;
    }
    await BookingRepository.instance.markRefunded(id);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = widget.startTime;

    // Expired
    if (_remaining == Duration.zero && now.isAfter(widget.endTime)) {
      return Text('Auto-refunded', style: TextStyle(fontSize: 11, color: Colors.red[400]));
    }

    // Before start
    if (start != null && now.isBefore(start)) {
      return Row(
        children: [
          Icon(Icons.schedule, size: 12, color: Colors.blue[700]),
          const SizedBox(width: 4),
          Text(
            'Trip starts in ${_fmt(_remaining)}',
            style: TextStyle(fontSize: 11, color: Colors.blue[700]),
          ),
        ],
      );
    }

    // In progress — counting to end time (no text, just return empty)
    return const SizedBox.shrink();
  }
}

class SpendingPage extends StatefulWidget {
  const SpendingPage({super.key});

  @override
  State<SpendingPage> createState() => _SpendingPageState();
}

class _SpendingPageState extends State<SpendingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<Booking>>(
        valueListenable: BookingRepository.instance.bookings,
        builder: (context, allBookings, _) {
          final currentUser = AuthRepository.instance.currentUser;
          if (currentUser == null) {
            return const Center(child: Text('Please login to view spending'));
          }

          // Get bookings where current user is the customer
          final userBookings = allBookings
              .where(
                (b) =>
                    b.userId == currentUser.id &&
                    b.status == BookingStatus.completed,
              )
              .toList();

          // Calculate total spending
          final totalSpending = userBookings.fold<double>(
            0,
            (sum, booking) => sum + booking.price,
          );

          // Get slots to determine service types
          final slotRepo = SlotRepository.instance;
          final allSlots = slotRepo.allSlotsRaw;

          // Group by service type
          double passengerSpending = 0;
          double parcelSpending = 0;
          double leaseSpending = 0;

          for (var booking in userBookings) {
            try {
              final slot = allSlots.firstWhere((s) => s.id == booking.slotId);
              if (slot.serviceType == ServiceType.passenger) {
                passengerSpending += booking.price;
              } else if (slot.serviceType == ServiceType.parcel) {
                parcelSpending += booking.price;
              } else if (slot.serviceType == ServiceType.lease ||
                  slot.serviceType == ServiceType.working) {
                leaseSpending += booking.price;
              }
            } catch (e) {
              // Slot not found, skip
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Total Spending Card
              Card(
                elevation: 4,
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        'Total Spending',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<String>(
                        valueListenable: AppPreferences.instance.currencyCode,
                        builder: (context, currencyCode, child) {
                          return Text(
                            AppPreferences.instance.formatMoney(
                              totalSpending.toInt(),
                            ),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${userBookings.length} completed trips',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Spending by Service Type
              const Text(
                'Spending by Service',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              _buildServiceSpendingCard(
                'Passenger',
                passengerSpending,
                Icons.people,
                Colors.blue,
              ),
              const SizedBox(height: 8),

              _buildServiceSpendingCard(
                'Parcel',
                parcelSpending,
                Icons.local_shipping,
                Colors.orange,
              ),
              const SizedBox(height: 8),

              _buildServiceSpendingCard(
                'Lease',

                leaseSpending,
                Icons.car_rental,
                Colors.purple,
              ),

              const SizedBox(height: 24),

              // Recent Transactions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to full transaction history
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (userBookings.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No spending yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                )
              else
                ...userBookings.take(10).map((booking) {
                  final allSlots = SlotRepository.instance.allSlotsRaw;
                  Slot? slot;
                  try {
                    slot = allSlots.firstWhere((s) => s.id == booking.slotId);
                  } catch (e) {
                    // Slot not found
                  }
                  return _buildTransactionCard(booking, slot);
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildServiceSpendingCard(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: ValueListenableBuilder<String>(
          valueListenable: AppPreferences.instance.currencyCode,
          builder: (context, _, _) {
            return Text(
              AppPreferences.instance.formatMoney(amount.toInt()),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Booking booking, Slot? slot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  child: const Icon(Icons.payment, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot != null ? '${slot.serviceType.displayName} Service' : 'Service',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${booking.createdAt.day}/${booking.createdAt.month}/${booking.createdAt.year}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                ValueListenableBuilder<String>(
                  valueListenable: AppPreferences.instance.currencyCode,
                  builder: (context, _, _) {
                    return Text(
                      AppPreferences.instance.formatMoney(booking.price.toInt()),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    );
                  },
                ),
              ],
            ),
            if (slot != null) ...[
              const SizedBox(height: 12),
              _BookingTimingSection(
                booking: booking,
                slot: slot,
                isRiderView: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isCustomerMode = true;

  @override
  Widget build(BuildContext context) {
    // Guest-first: Check if user is logged in using ValueListenableBuilder for reactivity
    return ValueListenableBuilder<AppAuthUser?>(
      valueListenable: AuthRepository.instance.currentUserListenable,
      builder: (context, currentUser, _) {
        if (currentUser == null) {
          // Show login prompt for guests
          return Scaffold(
            appBar: AppBar(
              title: const Text('Profile'),
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_outline, size: 100, color: Colors.grey[400]),
                    const SizedBox(height: 24),
                    const Text(
                      'Login to access your profile',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Create posts, manage bookings, and more',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Login'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: const Text('Don\'t have an account? Sign Up'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // User is logged in - show normal profile
        return _buildLoggedInProfile(context);
      },
    );
  }

  Widget _buildLoggedInProfile(BuildContext context) {
    final profileListenable = ProfileRepository.instance.profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<ProfileInfo>(
        valueListenable: profileListenable,
        builder: (context, info, _) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Profile Header
              Row(
                children: [
                  // Profile Picture
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _profileAvatarProvider(info),
                    child: info.avatarUrl == null
                        ? const Icon(Icons.person, size: 40, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.profileName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (info.businessType != null &&
                            info.businessType!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            info.businessType!.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'online',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Passionate about transportation and helping others move efficiently.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Customer/Provider Toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isCustomerMode = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isCustomerMode
                                ? Colors.blue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Customer',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isCustomerMode ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isCustomerMode = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isCustomerMode
                                ? Colors.blue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Provider',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: !_isCustomerMode ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Mode-specific content
              if (_isCustomerMode) ...[
                ListTile(
                  leading: const Icon(Icons.directions_car_filled),
                  title: const Text('Needed Vehicles'),
                  subtitle: const Text('Vehicles you need'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            VehicleListScreen(isUserMode: true),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet),
                  title: const Text('Spending'),
                  subtitle: const Text('View your trip spending'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SpendingPage()),
                    );
                  },
                ),
                ValueListenableBuilder<SubscriptionPlan>(
                  valueListenable: AppPreferences.instance.subscriptionPlan,
                  builder: (context, plan, _) {
                    if (plan != SubscriptionPlan.expert) {
                      return const SizedBox();
                    }
                    return ListTile(
                      leading: const Icon(Icons.support_agent),
                      title: const Text('Expert Support'),
                      subtitle: const Text('Priority customer support'),
                      onTap: () {
                        Navigator.pushNamed(context, '/expert-support');
                      },
                    );
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: const Text('Providing Vehicles'),
                  subtitle: const Text('Manage your vehicles and services'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            VehicleListScreen(isUserMode: false),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Earnings'),
                  subtitle: const Text('View your riding earnings'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EarningsPage()),
                    );
                  },
                ),
              ],
              const Divider(),
              // Menu Items
              ListTile(
                leading: const Icon(Icons.workspace_premium),
                title: const Text('Plans'),
                onTap: () {
                  Navigator.pushNamed(context, '/plans');
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              ),
              const ListTile(
                leading: Icon(Icons.help_outline),
                title: Text('Help & Support'),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  await AuthRepository.instance.logout();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: _isCustomerMode
          ? FloatingActionButton.extended(
              onPressed: () {
                _showAddPostBottomSheet(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Post'),
            )
          : FloatingActionButton.extended(
              onPressed: () {
                _showAddPostBottomSheet(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Post'),
            ),
    );
  }

  void _showAddPostBottomSheet(BuildContext context) {
    // Guest-first: Check if user is logged in before creating post
    if (AuthRepository.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to create posts'),
          duration: Duration(seconds: 2),
        ),
      );
      // Navigate to login
      Navigator.pushNamed(context, '/login');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        // Use LayoutBuilder to adapt to screen size, and SingleChildScrollView for small screens
        return LayoutBuilder(
          builder: (context, constraints) {
            final double sheetHeight = constraints.maxHeight < 420 ? constraints.maxHeight * 0.95 : 400;
            return SizedBox(
              height: sheetHeight,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Center(
                        child: Text('Create Post', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _isCustomerMode 
                            ? 'Select a vehicle you need, then create posts'
                            : 'Select your vehicle, then create posts',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context, 
                              MaterialPageRoute(
                                builder: (_) => VehicleListScreen(isUserMode: _isCustomerMode)
                              )
                            );
                          },
                          icon: Icon(_isCustomerMode ? Icons.search : Icons.directions_car),
                          label: Text(
                            _isCustomerMode ? 'Choose Needed Vehicle' : 'Choose Your Vehicle',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isCustomerMode ? Colors.orange : Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isCustomerMode 
                          ? '1. Select a vehicle type you need\n2. Open the vehicle\n3. Create posts for that vehicle'
                          : '1. Select one of your vehicles\n2. Open the vehicle details\n3. Create posts for that vehicle',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// User Posts List Page - Shows all posts from CustomerSlotRepository
class UserPostsListPage extends StatelessWidget {
  const UserPostsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts (Looking)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<SlotEntry>>(
        valueListenable: CustomerSlotRepository.instance.slotsListenable,
        builder: (context, slots, _) {
          if (slots.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.post_add, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'No posts yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Go to your vehicles and create posts from there',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              VehicleListScreen(isUserMode: true),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Post'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: slots.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = slots[index];
              return SlotCard(
                slot: entry.slot,
                vehicle: entry.vehicle,
                providerName: 'You',
                providerAvatar: '',
                providerRating: 5.0,
                isOffer: true,
                isUserPost: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SlotDetailScreen(
                        slot: entry.slot,
                        vehicle: entry.vehicle,
                        providerName: 'You',
                        providerAvatar: '',
                        providerRating: 5.0,
                        isOffer: true,
                      ),
                    ),
                  );
                },
                onAction: () {},
              );
            },
          );
        },
      ),
    );
  }
}

// Provider Posts List Page - Shows all posts from SlotRepository
class ProviderPostsListPage extends StatelessWidget {
  const ProviderPostsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts (Offering)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<SlotEntry>>(
        valueListenable: SlotRepository.instance.slotsListenable,
        builder: (context, slots, _) {
          if (slots.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.post_add, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'No posts yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Go to your vehicles and create posts from there',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              VehicleListScreen(isUserMode: false),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Post'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: slots.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = slots[index];
              return SlotCard(
                slot: entry.slot,
                vehicle: entry.vehicle,
                providerName: 'You',
                providerAvatar: '',
                providerRating: 5.0,
                isOffer: true,
                isUserPost: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SlotDetailScreen(
                        slot: entry.slot,
                        vehicle: entry.vehicle,
                        providerName: 'You',
                        providerAvatar: '',
                        providerRating: 5.0,
                        isOffer: true,
                      ),
                    ),
                  );
                },
                onAction: () {},
              );
            },
          );
        },
      ),
    );
  }
}

// Payment Success Screen - Shown after successful Stripe Checkout
class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({super.key});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  String? _bookingId;
  bool _loading = true;
  Booking? _booking;
  SlotEntry? _slotEntry;

  @override
  void initState() {
    super.initState();
    _extractBookingIdAndLoadDetails();
  }

  Future<void> _extractBookingIdAndLoadDetails() async {
    // Extract booking_id from URL query parameters
    final uri = Uri.base;
    _bookingId = uri.queryParameters['booking_id'];
    
    if (_bookingId != null) {
      // Try to find the booking in local storage
      _booking = BookingRepository.instance.getBookingById(_bookingId!);

      // Try to find the slot details
      if (_booking != null) {
        final allSlots = SlotRepository.instance.allSlots;
        try {
          _slotEntry = allSlots.firstWhere(
            (s) => s.slot.id == _booking!.slotId,
          );
        } catch (_) {
          // Slot not found in provider slots, try user slots
          final allUserSlots = CustomerSlotRepository.instance.allSlots;
          try {
            _slotEntry = allUserSlots.firstWhere(
              (s) => s.slot.id == _booking!.slotId,
            );
          } catch (_) {
            // Slot not found
          }
        }
      }
    }
    
    setState(() {
      _loading = false;
    });
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.inDays == 0) {
      return 'Today at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Successful'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Payment Successful!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your booking has been confirmed.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              if (_bookingId != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.confirmation_number, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          const Text(
                            'Booking ID',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _bookingId!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_slotEntry != null) ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text(
                              'Trip Start Time',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(_slotEntry!.slot.startTime),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.event_available, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text(
                              'Trip End Time',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(_slotEntry!.slot.endTime),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.directions_car, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text(
                              'Vehicle',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _slotEntry!.vehicle.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'The provider will receive an OTP to confirm the service start.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/main',
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Go to Home'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/main',
                    (route) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('View My Bookings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Payment Cancel Screen - Shown when user cancels Stripe Checkout
class PaymentCancelScreen extends StatefulWidget {
  const PaymentCancelScreen({super.key});

  @override
  State<PaymentCancelScreen> createState() => _PaymentCancelScreenState();
}

class _PaymentCancelScreenState extends State<PaymentCancelScreen> {
  String? _bookingId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _extractBookingId();
  }

  void _extractBookingId() {
    final uri = Uri.base;
    _bookingId = uri.queryParameters['booking_id'];
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Cancelled'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Payment Cancelled',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your payment was not completed.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              if (_bookingId != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'The booking has been cancelled and no charges were made.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/main',
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                ),
                child: const Text('Go to Home'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
