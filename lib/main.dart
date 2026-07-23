import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:image_picker/image_picker.dart';
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
import 'models/vehicle.dart' show Vehicle, VehicleGpsMode;
import 'models/pickup_mode.dart';
import 'models/post_mode.dart';
import 'models/booking.dart' show Booking, BookingStatus, BookingStatusX;
import 'models/booking.dart' as booking_types show BookingMode;
import 'models/exceptions.dart';
import 'models/review.dart';
import 'config/supabase_config.dart';
import 'widgets/payment_method_info.dart';
import 'screens/slot_detail_screen.dart';
import 'screens/vehicle/vehicle_list_screen.dart';
import 'services/booking_repository.dart';
import 'services/slot_repository.dart';
import 'services/vehicle_repository.dart';
import 'services/auth_repository.dart';
import 'services/seat_layout_repository.dart';
import 'services/customer_vehicle_repository.dart';
import 'services/customer_slot_repository.dart';
import 'services/user_post_repository.dart'
    show UserPost, UserPostStatus, UserPostRepository;
import 'services/user_post_acceptance_repository.dart'
    show UserPostAcceptanceRepository;
import 'models/user_post_acceptance.dart'
    show UserPostAcceptance, AcceptanceStatus;
import 'models/review.dart' show ReviewType;
import 'services/review_repository.dart' show ReviewRepository;
import 'widgets/slot_card.dart';
import 'widgets/booking_confirm_sheet.dart'
    show BookingConfirmSheet, BookingConfirmResult;
import 'widgets/trip_media_widget.dart';
import 'widgets/review_dialog.dart';
import 'services/profile_repository.dart' show ProfileRepository, ProfileInfo;
import 'services/profile_name_registry.dart' show ProfileNameRegistry;
import 'services/app_preferences.dart' show AppPreferences, SubscriptionPlan;

import 'services/passenger_repository.dart' show PassengerRepository;
import 'services/payment_service.dart' show PaymentService;
import 'screens/booking_map_screen.dart' show BookingMapScreen;
import 'services/location_autocomplete_service.dart'
    show LocationAutocompleteService;
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/reviews_screen.dart';
import 'screens/ai_chat_page.dart'; // ← Keep original
import 'widgets/voice_ai_overlay.dart';
import 'services/voice_ai_service.dart';
import 'services/pricing_service.dart';
import 'app_tab_controller.dart';
import 'utils/test_backend_connection.dart' show BackendConnectionTest;
import 'utils/timezone_utils.dart' show TimezoneUtils;

// Global Supabase client getter (lazy evaluation - only accessed when needed)
// Don't use 'final' here because it evaluates immediately before Supabase.initialize()
SupabaseClient get supabase => Supabase.instance.client;

/// Strip |lat,lon|keywords from stored location string ? returns display name only
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
  // Remove # from URLs (use path-based routing instead of hash-based)
  usePathUrlStrategy();

  // Add global error handlers to prevent crashes
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      print('? Flutter Error: ${details.exception}');
      print('Stack: ${details.stack}');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      print('? Platform Error: $error');
      print('Stack: $stack');
    }
    return true; // Prevent crash
  };

  WidgetsFlutterBinding.ensureInitialized();

  // CRITICAL: Initialize Firebase FIRST before starting app
  // This prevents splash screen from accessing Firebase before it's ready
  if (kDebugMode) print('🔥 Initializing Firebase...');
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
  if (kDebugMode) print('🔐 Initializing AuthRepository...');
  try {
    await AuthRepository.instance.init();
    if (kDebugMode) print('✅ AuthRepository initialized');
  } catch (e) {
    if (kDebugMode) print('⚠️ AuthRepository init failed: $e');
  }

  // Now start app - Firebase and Auth are ready
  if (kDebugMode) print('?? Starting app...');
  runApp(const MyApp());

  // Initialize other services in background (non-blocking)
  _initializeServicesInBackground();
}

// Background initialization that doesn't block app startup
Future<void> _initializeServicesInBackground() async {
  try {
    if (kDebugMode) print('?? Starting background initialization...');

    // Helper function to wrap repository inits with timeout
    Future<void> initWithTimeout(Future<void> future, String name) async {
      try {
        if (kDebugMode) print('⏳ Starting $name...');
        await future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException(
              '$name initialization timed out',
              const Duration(seconds: 30),
            );
          },
        );
        if (kDebugMode) print('? $name initialized');
      } catch (e) {
        if (kDebugMode) print('?? $name init failed/timed out: $e');
        // Don't rethrow ? let app continue
      }
    }

    // Firebase and AuthRepository are already initialized in main(), skip them here

    // Check if running on web and warn about CORS
    if (kIsWeb) {
      if (kDebugMode) {
        print('?? -------------------------------------------------------');
        print('?? WARNING: Running on WEB - CORS issues may occur!');
        print('?? If you see "Failed to fetch" errors:');
        print('??   1. Run on mobile/desktop instead: flutter run -d android');
        print('??   2. Or configure CORS in Supabase Dashboard');
        print('??   3. See FIX_SUPABASE_CORS_FOR_WEB.md for details');
        print('?? -------------------------------------------------------');
      }
    }

    // Initialize Supabase with Firebase JWT
    if (kDebugMode) print('? Starting Supabase...');
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
        accessToken: () async {
          final user = firebase_auth.FirebaseAuth.instance.currentUser;
          if (user == null) {
            if (kDebugMode) {
              print('?? No Firebase user - guest mode (using anon key)');
            }
            return null; // Supabase will use anon key automatically
          }
          try {
            final token = await user.getIdToken(true);
            if (token == null || token.isEmpty) {
              if (kDebugMode) {
                print('?? Firebase token is empty - falling back to anon');
              }
              return null;
            }
            if (kDebugMode) {
              print('?? Firebase UID: ${user.uid}');
              print('?? Sending Firebase JWT to Supabase');
            }
            return token;
          } catch (e) {
            if (kDebugMode) print('?? Failed to get Firebase token: $e');
            return null; // Fallback to anon key on error
          }
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
            'Supabase initialization timed out',
            const Duration(seconds: 10),
          );
        },
      );
      if (kDebugMode) print('? Supabase initialized');
    } catch (e) {
      if (kDebugMode) print('? Supabase initialization error: $e');
      // Continue anyway - app can work with limited functionality
    }

    // Initialize core services with timeout protection (AuthRepository already done)
    await initWithTimeout(AppPreferences.instance.init(), 'AppPreferences');

    // Initialize ProfileRepository with timeout protection (already had timeout)
    if (kDebugMode) print('? Starting ProfileRepository...');
    try {
      await ProfileRepository.instance.init().timeout(
        const Duration(seconds: 10), // Reduced from 30 to 10 seconds
        onTimeout: () {
          if (kDebugMode) print('? ProfileRepository init timed out');
          throw TimeoutException(
            'ProfileRepository initialization timed out',
            const Duration(seconds: 10),
          );
        },
      );
      if (kDebugMode) print('? ProfileRepository initialized');
    } catch (e) {
      if (kDebugMode) print('? ProfileRepository init failed: $e');
      // Continue with app initialization even if profile fails
    }

    // Initialize all other repositories with timeout protection
    // CRITICAL: Load vehicles FIRST, then slots (slots need vehicles to build entries)
    await initWithTimeout(
      VehicleRepository.instance.init(),
      'VehicleRepository',
    );
    await initWithTimeout(
      CustomerVehicleRepository.instance.init(),
      'CustomerVehicleRepository',
    );

    // Now load slots (they can find vehicles now)
    await initWithTimeout(SlotRepository.instance.init(), 'SlotRepository');
    await initWithTimeout(
      CustomerSlotRepository.instance.init(),
      'CustomerSlotRepository',
    );

    // Load other repositories
    await initWithTimeout(
      UserPostRepository.instance.init(),
      'UserPostRepository',
    );
    await initWithTimeout(
      UserPostAcceptanceRepository.instance.init(),
      'UserPostAcceptanceRepository',
    );
    await initWithTimeout(
      SeatLayoutRepository.instance.init(),
      'SeatLayoutRepository',
    );
    await initWithTimeout(
      BookingRepository.instance.init(),
      'BookingRepository',
    );
    await initWithTimeout(
      PassengerRepository.instance.init(),
      'PassengerRepository',
    );
    await initWithTimeout(ReviewRepository.instance.init(), 'ReviewRepository');

    // Force refresh slot entries after all data is loaded
    // This ensures slots find their vehicles even if there was a timing issue
    if (kDebugMode) {
      print('?? Refreshing slot entries after all data loaded...');
    }
    try {
      await SlotRepository.instance.loadSlots();
      await CustomerSlotRepository.instance.init(); // Reload to rebuild entries
      if (kDebugMode) print('? Slot entries refreshed');
    } catch (e) {
      if (kDebugMode) print('?? Failed to refresh slot entries: $e');
    }

    // Test Supabase connection (only in debug mode)
    if (kDebugMode) {
      debugPrint('?? Supabase connection configured');
      debugPrint('?? URL: ${SupabaseConfig.url}');
      debugPrint('?? Auth: Firebase JWT ? Supabase RLS');

      // Run backend connection tests
      await BackendConnectionTest.runAllTests();
    }

    // Initialize Stripe for payments with timeout
    // TODO: Stripe initialization hidden - will be restored later
    // await initWithTimeout(StripeService.instance.init(), 'StripeService');

    // Initialize Voice AI service with timeout (this was the last call - likely culprit!)
    await initWithTimeout(VoiceAIService().initialize(), 'VoiceAIService');

    if (kDebugMode) print('?? All services initialized successfully!');
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('? Background initialization error: $e');
      print('?? Stack trace: $stackTrace');
      print('?? App will continue running with limited functionality');
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
    final current = isStart ? _startTime! : _endTime!;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;

    final newDt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post updated')));
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
                .map(
                  (t) => DropdownMenuItem(value: t, child: Text(t.displayName)),
                )
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
          ValueListenableBuilder<String>(
            valueListenable: AppPreferences.instance.currencyCode,
            builder: (context, currency, _) {
              final symbol = AppPreferences.instance.currencySymbol;
              return TextField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Budget ($symbol)',
                  border: const OutlineInputBorder(),
                ),
              );
            },
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

  // Step 2: Pick image from gallery using ImagePicker (works on web too)
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null || !context.mounted) return;

    final bytes = await picked.readAsBytes();
    final base64Image = base64Encode(bytes);

    // Save to profile
    try {
      await ProfileRepository.instance.setLocalAvatarBase64(base64Image);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile photo updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
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
  if (!context.mounted) return;

  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final userId = AuthRepository.instance.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final supabase = Supabase.instance.client;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = picked.name.split('.').last;
    final fileName = '${documentType}_${side}_$timestamp.$ext';
    // Path: {userId}/{documentType}/{filename}
    final storagePath = '$userId/$documentType/$fileName';

    // Upload to profile_private_media bucket
    await supabase.storage
        .from('profile_private_media')
        .uploadBinary(storagePath, bytes);

    // Get URL
    final url = supabase.storage
        .from('profile_private_media')
        .getPublicUrl(storagePath);

    // Save URL to profile
    await ProfileRepository.instance.saveDocument(documentType, side, url);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${documentType.toUpperCase()} $side uploaded'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    debugPrint('❌ Document upload failed: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Helper function to get currency display based on connected payment provider
String _getCurrencySymbol(String currency) {
  final currencySymbols = {
    'INR': '₹',
    'USD': '\$',
    'GBP': '£',
    'EUR': '€',
    'AED': 'د.إ',
    'SGD': 'S\$',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'JPY': '¥',
    'CNY': '¥',
    'HKD': 'HK\$',
    'BRL': 'R\$',
    'MXN': 'MX\$',
  };
  return currencySymbols[currency.toUpperCase()] ?? currency;
}

String _getCurrencyDisplay(ProfileInfo profile) {
  // INR only for now (Razorpay support)
  return '🇮🇳 INR - Indian Rupee';

  // TODO: Multi-currency support ready for Rapyd/Stripe integration
  // final provider = profile.paymentProvider;
  // if (provider == 'razorpay') {
  //   return '🇮🇳 INR - Indian Rupee';
  // } else if (provider == 'stripe') {
  //   // Stripe multi-currency logic here
  // }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set custom error widget builder to show errors instead of white screen
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        child: Container(
          color: Colors.red[50],
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  details.exception.toString(),
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Try to restart the app
                    runApp(const MyApp());
                  },
                  child: const Text('Restart App'),
                ),
              ],
            ),
          ),
        ),
      );
    };

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

  // Get pricing from database with fallback to hardcoded values
  // This allows dynamic pricing updates without app redeployment
  Future<Map<String, dynamic>> _getPricingFromDatabase(String currency) async {
    try {
      // Try to fetch from database first
      return await PricingService.instance.getPricing(currency);
    } catch (e) {
      debugPrint(
        '[PlansScreen] Database fetch failed, using hardcoded fallback: $e',
      );
      // Fallback to hardcoded pricing if database fails
      return _getHardcodedPricing(currency);
    }
  }

  // Hardcoded pricing as fallback when database is unavailable
  // This ensures the app works even if Supabase is down
  //
  // IMPORTANT: Continents are for CODE ORGANIZATION only!
  // Actual pricing is determined by COUNTRY TIER (1, 2, or 3) based on:
  // - GDP per capita (purchasing power)
  // - Average income levels
  // - Digital service affordability
  //
  // TIER SYSTEM:
  // Tier 1 (High-income): Premium $12.99/month, Expert $59.99/month + $599 deposit
  //   - GDP per capita: $40,000+ USD
  //   - Examples: USA, UK, Japan, UAE, Australia (23 countries)
  //   - Affordability: 0.2%-0.5% of monthly income
  //
  // Tier 2 (Middle-income): Premium ₹999/month, Expert ₹4,999/month + ₹50,000 deposit
  //   - GDP per capita: $5,000-$20,000 USD
  //   - Reference: India pricing (₹999 = ~$12 equivalent purchasing power)
  //   - Examples: India, Brazil, Mexico, Poland, Thailand (29 countries)
  //   - Affordability: 2%-5% of monthly income
  //
  // Tier 3 (Lower-income): Premium ₹499/month, Expert ₹2,499/month + ₹25,000 deposit
  //   - GDP per capita: $1,000-$5,000 USD
  //   - 50% discount from Tier 2 for affordability
  //   - Examples: Pakistan, Bangladesh, Nigeria, Vietnam (50+ countries)
  //   - Affordability: 3%-8% of monthly income
  //
  // NOTE: Same continent can have different tiers!
  // Example: Europe has Tier 1 (Switzerland) and Tier 2 (Poland)
  // Example: Asia has Tier 1 (Japan), Tier 2 (India), Tier 3 (Pakistan)
  Map<String, dynamic> _getHardcodedPricing(String currency) {
    final curr = currency.toUpperCase();

    // NORTH AMERICA
    final northAmerica = {
      'USD': ['\$', 12.99, 59.99, 599, 1], // United States - Tier 1
      'CAD': ['C\$', 17.99, 83.99, 839, 1], // Canada - Tier 1
      'MXN': ['MX\$', 219, 1069, 10690, 2], // Mexico - Tier 2
    };

    // SOUTH AMERICA
    final southAmerica = {
      'BRL': ['R\$', 65, 319, 3190, 2], // Brazil - Tier 2
      'ARS': ['AR\$', 12000, 58800, 588000, 2], // Argentina - Tier 2
      'CLP': ['CLP\$', 11690, 57290, 572900, 2], // Chile - Tier 2
      'COP': ['COL\$', 50400, 246900, 2469000, 2], // Colombia - Tier 2
      'PEN': ['S/', 45, 220, 2200, 2], // Peru - Tier 2
      'UYU': ['UY\$', 504, 2469, 24690, 2], // Uruguay - Tier 2
      'BOB': ['Bs', 41, 205, 2050, 3], // Bolivia - Tier 3
      'PYG': ['₲', 44000, 220000, 2200000, 3], // Paraguay - Tier 3
    };

    // EUROPE
    final europe = {
      'EUR': ['€', 11.99, 54.99, 549, 1], // Eurozone (27 countries) - Tier 1
      'GBP': ['£', 10.99, 49.99, 499, 1], // United Kingdom - Tier 1
      'CHF': ['CHF ', 11.49, 52.99, 529, 1], // Switzerland - Tier 1
      'SEK': ['kr', 139, 644, 6440, 1], // Sweden - Tier 1
      'NOK': ['kr', 139, 644, 6440, 1], // Norway - Tier 1
      'DKK': ['kr', 89, 412, 4120, 1], // Denmark - Tier 1
      'ISK': ['kr', 1799, 8329, 83290, 1], // Iceland - Tier 1
      'PLN': ['zł', 49, 239, 2390, 2], // Poland - Tier 2
      'CZK': ['Kč', 279, 1369, 13690, 2], // Czech Republic - Tier 2
      'HUF': ['Ft', 4390, 21490, 214900, 2], // Hungary - Tier 2
      'RON': ['lei', 55, 269, 2690, 2], // Romania - Tier 2
      'BGN': ['лв', 21.99, 107.69, 1076, 2], // Bulgaria - Tier 2
      'HRK': ['kn', 82, 402, 4020, 2], // Croatia - Tier 2
      'RSD': ['дин', 1290, 6318, 63180, 2], // Serbia - Tier 2
      'UAH': ['₴', 494, 2419, 24190, 2], // Ukraine - Tier 2
      'RUB': ['₽', 1109, 5429, 54290, 2], // Russia - Tier 2
    };

    // ASIA
    final asia = {
      // East Asia - Tier 1
      'JPY': ['¥', 1899, 8799, 87990, 1], // Japan
      'KRW': ['₩', 17299, 80199, 801990, 1], // South Korea
      'TWD': ['NT\$', 412, 1908, 19080, 1], // Taiwan
      'HKD': ['HK\$', 101, 468, 4680, 1], // Hong Kong
      'SGD': ['S\$', 17.49, 80.99, 809, 1], // Singapore
      // South & Southeast Asia - Tier 2
      'INR': ['₹', 999, 4999, 50000, 2], // India
      'CNY': ['¥', 87, 426, 4260, 2], // China
      'THB': ['฿', 429, 2099, 20990, 2], // Thailand
      'MYR': ['RM', 56, 274, 2740, 2], // Malaysia
      'IDR': ['Rp', 189000, 926000, 9260000, 2], // Indonesia
      'TRY': ['₺', 409, 2004, 20040, 2], // Turkey
      // South & Southeast Asia - Tier 3
      'PKR': ['Rs', 1665, 8325, 83250, 3], // Pakistan
      'BDT': ['৳', 660, 3300, 33000, 3], // Bangladesh
      'VND': ['₫', 149000, 745000, 7450000, 3], // Vietnam
      'PHP': ['₱', 335, 1675, 16750, 3], // Philippines
      'LKR': ['Rs', 1950, 9750, 97500, 3], // Sri Lanka
      'NPR': ['Rs', 795, 3975, 39750, 3], // Nepal
      'MMK': ['K', 12575, 62875, 628750, 3], // Myanmar
      'KHR': ['៛', 24500, 122500, 1225000, 3], // Cambodia
      'LAK': ['₭', 131000, 655000, 6550000, 3], // Laos
      // Central Asia - Tier 2 & 3
      'KZT': ['₸', 5490, 26890, 268900, 2], // Kazakhstan - Tier 2
      'GEL': ['₾', 33, 161, 1610, 2], // Georgia - Tier 2
      'AMD': ['֏', 4640, 22740, 227400, 2], // Armenia - Tier 2
      'AZN': ['₼', 20.39, 99.89, 998, 2], // Azerbaijan - Tier 2
      'UZS': ['soʻm', 76000, 380000, 3800000, 3], // Uzbekistan - Tier 3
      'TJS': ['ЅМ', 65, 325, 3250, 3], // Tajikistan - Tier 3
      'KGS': ['с', 520, 2600, 26000, 3], // Kyrgyzstan - Tier 3
      'AFN': ['؋', 425, 2125, 21250, 3], // Afghanistan - Tier 3
    };

    // MIDDLE EAST
    final middleEast = {
      // Gulf States - Tier 1
      'AED': ['AED ', 47.69, 220.49, 2204, 1], // UAE
      'SAR': ['SAR ', 48.69, 224.99, 2249, 1], // Saudi Arabia
      'QAR': ['QAR ', 47.29, 218.49, 2184, 1], // Qatar
      'KWD': ['KWD ', 3.99, 18.49, 184, 1], // Kuwait
      'BHD': ['BHD ', 4.89, 22.59, 225, 1], // Bahrain
      'OMR': ['OMR ', 4.99, 23.09, 230, 1], // Oman
      'ILS': ['₪', 47.99, 221.99, 2219, 1], // Israel
      // Other Middle East - Tier 2 & 3
      'EGP': ['E£', 370, 1814, 18140, 2], // Egypt - Tier 2
      'LBP': ['ل.ل', 535000, 2675000, 26750000, 3], // Lebanon - Tier 3
      'IQD': ['ع.د', 7840, 39200, 392000, 3], // Iraq - Tier 3
      'JOD': ['د.ا', 4.25, 21.25, 212, 3], // Jordan - Tier 3
      'SYP': ['£S', 75500, 377500, 3775000, 3], // Syria - Tier 3
      'YER': ['﷼', 1500, 7500, 75000, 3], // Yemen - Tier 3
      'IRR': ['﷼', 252000, 1260000, 12600000, 3], // Iran - Tier 3
    };

    // AFRICA
    final africa = {
      // North Africa
      'ZAR': ['R', 219, 1074, 10740, 2], // South Africa - Tier 2
      'MAD': ['د.م.', 59, 295, 2950, 3], // Morocco - Tier 3
      'TND': ['د.ت', 18.50, 92.50, 925, 3], // Tunisia - Tier 3
      'DZD': ['د.ج', 805, 4025, 40250, 3], // Algeria - Tier 3
      'EGP': ['E£', 370, 1814, 18140, 2], // Egypt - Tier 2
      // Sub-Saharan Africa
      'NGN': ['₦', 9500, 47500, 475000, 3], // Nigeria
      'KES': ['KSh', 775, 3875, 38750, 3], // Kenya
      'GHS': ['GH₵', 95, 475, 4750, 3], // Ghana
      'TZS': ['TSh', 15000, 75000, 750000, 3], // Tanzania
      'UGX': ['USh', 22000, 110000, 1100000, 3], // Uganda
      'ETB': ['Br', 330, 1650, 16500, 3], // Ethiopia
      'RWF': ['FRw', 8200, 41000, 410000, 3], // Rwanda
      'MWK': ['MK', 10400, 52000, 520000, 3], // Malawi
      'ZMW': ['ZK', 165, 825, 8250, 3], // Zambia
      'AOA': ['Kz', 4950, 24750, 247500, 3], // Angola
      'MZN': ['MT', 382, 1910, 19100, 3], // Mozambique
      'SDG': ['ج.س.', 3600, 18000, 180000, 3], // Sudan
      'SSP': ['£', 7800, 39000, 390000, 3], // South Sudan
      'SOS': ['Sh', 3415, 17075, 170750, 3], // Somalia
      'DJF': ['Fdj', 1065, 5325, 53250, 3], // Djibouti
      'SLL': ['Le', 125000, 625000, 6250000, 3], // Sierra Leone
      'LRD': ['L\$', 1150, 5750, 57500, 3], // Liberia
      'GNF': ['FG', 51500, 257500, 2575000, 3], // Guinea
      'BIF': ['FBu', 17000, 85000, 850000, 3], // Burundi
      'MGA': ['Ar', 27000, 135000, 1350000, 3], // Madagascar
      'CDF': ['FC', 16500, 82500, 825000, 3], // DR Congo
      'XOF': ['CFA', 3600, 18000, 180000, 3], // West African CFA (8 countries)
      'XAF': [
        'FCFA',
        3600,
        18000,
        180000,
        3,
      ], // Central African CFA (6 countries)
      'MRU': ['UM', 238, 1190, 11900, 3], // Mauritania
      'GMD': ['D', 405, 2025, 20250, 3], // Gambia
      'CVE': ['Esc', 605, 3025, 30250, 3], // Cape Verde
      'STN': ['Db', 135, 675, 6750, 3], // São Tomé and Príncipe
      'MUR': ['₨', 275, 1375, 13750, 3], // Mauritius
      'SCR': ['₨', 81, 405, 4050, 3], // Seychelles
      'BWP': ['P', 82, 410, 4100, 3], // Botswana
      'SZL': ['L', 109, 545, 5450, 3], // Eswatini
      'LSL': ['L', 109, 545, 5450, 3], // Lesotho
      'NAD': ['N\$', 109, 545, 5450, 3], // Namibia
    };

    // OCEANIA
    final oceania = {
      'AUD': ['A\$', 19.99, 92.99, 929, 1], // Australia - Tier 1
      'NZD': ['NZ\$', 21.99, 101.99, 1019, 1], // New Zealand - Tier 1
    };

    // CENTRAL AMERICA & CARIBBEAN
    final centralAmericaCaribbean = {
      'CRC': ['₡', 6120, 29988, 299880, 2], // Costa Rica - Tier 2
      'DOP': ['RD\$', 720, 3528, 35280, 2], // Dominican Republic - Tier 2
      'HTG': ['G', 790, 3950, 39500, 3], // Haiti - Tier 3
      'NIO': ['C\$', 220, 1100, 11000, 3], // Nicaragua - Tier 3
      'HNL': ['L', 150, 750, 7500, 3], // Honduras - Tier 3
      'GTQ': ['Q', 46, 230, 2300, 3], // Guatemala - Tier 3
    };

    // Combine all continents
    final allPricing = {
      ...northAmerica,
      ...southAmerica,
      ...europe,
      ...asia,
      ...middleEast,
      ...africa,
      ...oceania,
      ...centralAmericaCaribbean,
    };

    // Look up currency
    if (allPricing.containsKey(curr)) {
      final pricing = allPricing[curr]!;
      return {
        'symbol': pricing[0],
        'premium': pricing[1],
        'expert': pricing[2],
        'deposit': pricing[3],
        'tier': pricing[4],
      };
    } else {
      // Default to INR for unknown currencies (India-first app)
      return {
        'symbol': '₹',
        'premium': 999,
        'expert': 4999,
        'deposit': 50000,
        'tier': 2,
      };
    }
  }

  Future<void> _purchasePlan(
    BuildContext context,
    SubscriptionPlan plan,
    double price,
  ) async {
    try {
      final currentUser = AuthRepository.instance.currentUser;
      if (currentUser == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to purchase a plan'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Get user details
      final profile = ProfileRepository.instance.profile.value;
      final userName = profile.profileName.isEmpty
          ? 'User'
          : profile.profileName;
      final userEmail = currentUser.email;
      final userPhone = profile.phone ?? '0000000000';

      // ✅ Determine currency based on selected payment gateway
      // Razorpay only supports INR, Stripe supports multiple currencies
      final paymentProvider = profile.paymentProvider;
      final userCurrency = AppPreferences.instance.currencyCode.value;

      // Check if user is trying to pay with Razorpay but currency is not INR
      if (paymentProvider == 'razorpay' && userCurrency != 'INR') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Razorpay only supports INR (₹). Please switch to Stripe payment gateway in Profile Settings for USD/other currencies, or change currency to INR in app settings.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
            ),
          ),
        );
        return;
      }

      final currency = paymentProvider == 'razorpay'
          ? 'INR' // Force INR for Razorpay
          : userCurrency; // Use preference for Stripe

      // Show payment confirmation dialog with recommended payment method
      if (!context.mounted) return;
      final confirmed =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Confirm Purchase'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recommended payment method info
                    PaymentMethodInfo(
                      currency: currency,
                      amount: price,
                      showDetailed: false,
                    ),
                    const SizedBox(height: 16),
                    // Purchase details
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Plan:',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                plan.name.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Amount:',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${_getCurrencySymbol(currency)}${price.toStringAsFixed(2)}/${'month'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Proceed to Payment'),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirmed) return;

      // Show loading
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Process payment via PaymentService
      final result = await PaymentService.instance.processSubscriptionPayment(
        planName: plan.name,
        amount: price,
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        currency: currency,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading

      if (result['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (result['web_redirect'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete payment in Stripe to activate your plan.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // Payment successful - activate plan
      await AppPreferences.instance.setSubscriptionPlan(plan);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 ${plan.name.toUpperCase()} plan activated!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: AppPreferences.instance.currencyCode,
        builder: (context, currency, _) {
          // Use FutureBuilder to fetch pricing from database
          return FutureBuilder<Map<String, dynamic>>(
            future: _getPricingFromDatabase(currency),
            builder: (context, snapshot) {
              // Show loading indicator while fetching
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Use fetched pricing or fallback to default
              final pricing =
                  snapshot.data ??
                  {
                    'symbol': '\$',
                    'premium': 12.99,
                    'expert': 59.99,
                    'deposit': 599.0,
                    'tier': 1,
                  };

              final symbol = pricing['symbol'] as String;
              final premiumPrice = pricing['premium'] as double;
              final expertPrice = pricing['expert'] as double;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ValueListenableBuilder<SubscriptionPlan>(
                    valueListenable: AppPreferences.instance.subscriptionPlan,
                    builder: (context, plan, _) {
                      return ValueListenableBuilder<DateTime?>(
                        valueListenable:
                            AppPreferences.instance.subscriptionExpiry,
                        builder: (context, expiry, _) {
                          // Calculate remaining time
                          Duration? remaining;
                          String? countdownText;
                          if (expiry != null &&
                              plan != SubscriptionPlan.basic) {
                            remaining = expiry.difference(DateTime.now());
                            if (remaining.isNegative) {
                              countdownText = 'Expired';
                            } else {
                              final days = remaining.inDays;
                              final hours = remaining.inHours % 24;
                              if (days > 0) {
                                countdownText = '$days days, $hours hours';
                              } else {
                                final minutes = remaining.inMinutes % 60;
                                countdownText =
                                    '$hours hours, $minutes minutes';
                              }
                            }
                          }

                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current Plan',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  plan.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (countdownText != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: remaining!.isNegative
                                          ? Colors.red.withValues(alpha: 0.3)
                                          : Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          remaining.isNegative
                                              ? Icons.error_outline
                                              : Icons.access_time,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          remaining.isNegative
                                              ? 'Plan Expired'
                                              : 'Expires in: $countdownText',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upgrade Your Experience',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Choose a plan that fits your needs',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue, width: 1),
                        ),
                        child: Text(
                          'Currency: $currency',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Payment Method Guide - Show before plan selection
                  PaymentMethodInfo(
                    currency: currency,
                    amount: premiumPrice, // Use Premium plan price as reference
                    showDetailed: true,
                  ),
                  const SizedBox(height: 16),

                  _PlanCard(
                    title: 'Basic',
                    priceLabel: 'FREE',
                    price: 0,
                    currencySymbol: symbol,
                    bullets: const [
                      'Add images to vehicle',
                      'Post requests & book trips',
                      'Standard support',
                      'Basic features access',
                    ],
                    isRecommended: false,
                    onSelect: () async {
                      await AppPreferences.instance.setSubscriptionPlan(
                        SubscriptionPlan.basic,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Basic plan selected'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 12),
                  _PlanCard(
                    title: 'Premium',
                    priceLabel:
                        '$symbol${premiumPrice.toStringAsFixed(2)}/month',
                    price: premiumPrice,
                    currencySymbol: symbol,
                    bullets: const [
                      'Everything in Basic',
                      'Verify PAN / Aadhaar',
                      'Verify RC / Driving License',
                      'Priority listing',
                      'Advanced analytics',
                    ],
                    isRecommended: true,
                    onSelect: () => _purchasePlan(
                      context,
                      SubscriptionPlan.premium,
                      premiumPrice,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PlanCard(
                    title: 'Expert',
                    priceLabel:
                        '$symbol${expertPrice.toStringAsFixed(2)}/month',
                    price: expertPrice,
                    currencySymbol: symbol,
                    depositAmount: pricing['deposit'] as double,
                    bullets: const [
                      'Everything in Premium',
                      'Expert connection badge',
                      'Priority customer support',
                      'Featured listings',
                      'Dedicated account manager',
                      'Refundable deposit (returned after 12 months)',
                    ],
                    isRecommended: false,
                    isComingSoon: true,
                    onSelect: null,
                  ),
                ],
              );
            }, // End of FutureBuilder builder
          ); // End of FutureBuilder
        },
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
  final double price;
  final String currencySymbol;
  final double? depositAmount;
  final List<String> bullets;
  final bool isRecommended;
  final VoidCallback? onSelect;
  final bool isComingSoon;

  const _PlanCard({
    required this.title,
    required this.priceLabel,
    required this.price,
    required this.currencySymbol,
    this.depositAmount,
    required this.bullets,
    required this.isRecommended,
    this.onSelect,
    this.isComingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isComingSoon
        ? Colors.orange
        : (isRecommended ? Colors.blue : Colors.grey);

    return Card(
      elevation: isRecommended ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isRecommended
            ? BorderSide(color: Colors.blue, width: 2)
            : BorderSide.none,
      ),
      child: Container(
        decoration: isRecommended
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withValues(alpha: 0.05),
                    Colors.blue.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with badges
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          priceLabel,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        // Show deposit for Expert plan
                        if (depositAmount != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.orange,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '+ $currencySymbol${depositAmount!.toStringAsFixed(0)} deposit',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '(Refundable after 12 months)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isRecommended)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'POPULAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  if (isComingSoon)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'SOON',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              // Features list
              ...bullets.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, size: 20, color: color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          b,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Action button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: isComingSoon ? null : onSelect,
                  style: FilledButton.styleFrom(
                    backgroundColor: isComingSoon
                        ? Colors.grey[300]
                        : (isRecommended ? Colors.blue : null),
                    foregroundColor: isComingSoon
                        ? Colors.grey[600]
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isComingSoon
                        ? 'Coming Soon'
                        : (price == 0 ? 'Select Free Plan' : 'Upgrade Now'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (price > 0 && !isComingSoon) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Secure payment via Razorpay/Stripe',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Extract lat,lng string from location format "Name|lat,lng|keywords"
String? _extractCoordsFromLocation(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split('|');
  if (parts.length >= 2) {
    final coords = parts[1].trim();
    if (coords.contains(',')) return coords; // "lat,lng"
  }
  // Fallback: if no pipe, check if it's already "lat,lng"
  if (raw.contains(',') && !raw.contains(' ')) return raw.trim();
  debugPrint('?? Could not extract coords from: $raw');
  return null;
}

Future<void> _openExternalMapForSlot(
  BuildContext context,
  Slot slot, {
  double? vehicleLat,
  double? vehicleLng,
  double? userLat,
  double? userLng,
}) async {
  // Try extracting coords from pipe-format string first
  // Then fall back to slot's direct lat/lng fields
  String? originCoords;
  String? destCoords;

  // Origin: from_location or base_location
  final fromCoords = _extractCoordsFromLocation(slot.fromLocation);
  final baseCoords = _extractCoordsFromLocation(slot.baseLocation);
  if (fromCoords != null) {
    originCoords = fromCoords;
  } else if (baseCoords != null) {
    originCoords = baseCoords;
  }

  // Destination: to_location
  final toCoords = _extractCoordsFromLocation(slot.toLocation);
  if (toCoords != null) {
    destCoords = toCoords;
  }

  if (originCoords == null && destCoords == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location coordinates not available')),
    );
    return;
  }

  // Build multi-stop URL using OpenStreetMap (free, no API key needed)
  // OpenStreetMap directions: https://www.openstreetmap.org/directions?route=lat1,lng1;lat2,lng2
  final waypoints = <String>[];
  if (originCoords != null) {
    final parts = originCoords.split(',');
    if (parts.length == 2) waypoints.add('${parts[0]},${parts[1]}');
  }
  if (vehicleLat != null && vehicleLng != null) {
    waypoints.add('$vehicleLat,$vehicleLng');
  }
  if (userLat != null && userLng != null) waypoints.add('$userLat,$userLng');
  if (destCoords != null) {
    final parts = destCoords.split(',');
    if (parts.length == 2) waypoints.add('${parts[0]},${parts[1]}');
  }

  final uri = Uri.parse(
    'https://www.openstreetmap.org/directions?route=${waypoints.join(';')}',
  );
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open maps')));
  }
}

// Open OpenStreetMap with lat/lng coordinates (free, no API key needed)
Future<void> _openGoogleMapsLatLng(
  BuildContext context,
  double lat,
  double lng,
) async {
  // OpenStreetMap viewer: zoom level 17 is good for local area
  final uri = Uri.parse(
    'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=17/$lat/$lng',
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
    final current = isStart ? _startTime! : _endTime!;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;

    final newDt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
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

    // Show payment confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escrow Payment Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To create this post, you need to pay ${AppPreferences.instance.currencySymbol}${budget.toStringAsFixed(2)} as escrow.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'This amount will be:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Held securely until service completion'),
            const Text('• Released to provider after successful service'),
            const Text('• Refunded to you if post is cancelled'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pay & Post'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processing payment...'),
          duration: Duration(seconds: 30),
        ),
      );
    }

    // Process escrow payment
    String? paymentId;
    try {
      final profile = ProfileRepository.instance.profile.value;
      final prefs = AppPreferences.instance;
      final currency = prefs.currencyCode.value;
      final countryCode = currency == 'INR'
          ? 'IN'
          : 'US'; // Derive country from currency

      final paymentResult = await PaymentService.instance.processPayment(
        amountInPaise: (budget * 100).toInt(),
        currency: currency,
        countryCode: countryCode,
        providerId: 'escrow',
        slotId: 'user_post_${DateTime.now().microsecondsSinceEpoch}',
        userName: profile.profileName.isNotEmpty ? profile.profileName : 'User',
        userEmail: currentUser.email,
        userPhone: profile.phone ?? '',
        description: 'Escrow for ${_serviceType.displayName} post',
        commissionAmount: 0,
      );

      if (paymentResult == null || paymentResult['error'] != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        _showError(
          'Payment cancelled or failed: ${paymentResult?['error'] ?? 'Unknown error'}',
        );
        return;
      }

      paymentId = paymentResult['payment_id'] as String?;
      if (paymentId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        _showError('Payment ID not received');
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      _showError('Payment failed: $e');
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
      escrowPaymentId: paymentId,
    );

    try {
      await UserPostRepository.instance.add(post);
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Post created with escrow payment'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      _showError(
        'Failed to create post: $e\n\nPayment was processed. Contact support with payment ID: $paymentId',
      );
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
                .map(
                  (t) => DropdownMenuItem(value: t, child: Text(t.displayName)),
                )
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
          ValueListenableBuilder<String>(
            valueListenable: AppPreferences.instance.currencyCode,
            builder: (context, currency, _) {
              final symbol = AppPreferences.instance.currencySymbol;
              return TextField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Budget ($symbol)',
                  border: const OutlineInputBorder(),
                ),
              );
            },
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
          // Parcel dimensions ? only shown for parcel service type
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                      if (p.requiresVerifiedVehicle ||
                          p.requiresExpertVehicle) ...[
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
                                    content: Text('Failed to update: $e'),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Actions',
                        onSelected: (value) async {
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
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Post'),
                                content: const Text(
                                  'Are you sure you want to delete this post?\n\nPosts with active bookings cannot be deleted.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm != true || !context.mounted) return;
                            try {
                              await UserPostRepository.instance.delete(p.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('? Post deleted'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } on ActiveBookingsException catch (e) {
                              if (!context.mounted) return;
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: Row(
                                    children: [
                                      Icon(
                                        Icons.lock_outline,
                                        color: Colors.orange[700],
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Cannot Delete Post'),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${e.activeCount} active booking${e.activeCount == 1 ? '' : 's'} must be '
                                        'completed or cancelled before this post can be deleted.',
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.orange.shade200,
                                          ),
                                        ),
                                        child: const Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Active = pending, accepted, confirmed, in_progress',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Colors.deepOrange,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'You can instead:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              '? Mark post inactive ? stops new bookings',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                            Text(
                                              '? Wait for active bookings to complete',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                            Text(
                                              '? Cancel/refund active bookings first',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to delete: ${e.toString().split('\n').first}',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
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
      return '${_cleanLoc(p.fromLocation)} ? ${_cleanLoc(p.toLocation)}';
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
      return '${_cleanLoc(p.fromLocation)} ? ${_cleanLoc(p.toLocation)}';
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
                          final location =
                              slot.baseLocation ?? slot.fromLocation;
                          final coords = _extractLatLng(location);
                          if (coords != null) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 12,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Lat: ${coords['lat']!.toStringAsFixed(6)}, Lng: ${coords['lng']!.toStringAsFixed(6)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
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
      return '${_cleanLoc(slot.fromLocation)} ? ${_cleanLoc(slot.toLocation)}';
    }
    if (slot.baseLocation != null) return _cleanLoc(slot.baseLocation);
    return 'Posted ride';
  }

  String _fmtRange(DateTime start, DateTime end) {
    // Format: 26/1 09:30 IST
    return TimezoneUtils.formatShortDateTimeWithTimezone(
      start,
      show24Hour: true,
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
          // Show all bookings (not just completed) for better visibility
          final providerBookings = allBookings
              .where((b) => b.providerId == currentUser.id)
              .toList();

          // Separate completed vs pending
          final completedBookings = providerBookings
              .where((b) => b.status == BookingStatus.completed)
              .toList();
          final pendingBookings = providerBookings
              .where(
                (b) =>
                    b.status == BookingStatus.pending ||
                    b.status == BookingStatus.accepted ||
                    b.status == BookingStatus.confirmed ||
                    b.status == BookingStatus.inProgress,
              )
              .toList();

          // Calculate total earnings (completed only for accurate earnings)
          final totalEarnings = completedBookings.fold<double>(
            0,
            (sum, booking) => sum + booking.price,
          );

          // Calculate expected earnings (pending + completed)
          final expectedEarnings = providerBookings.fold<double>(
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

          for (var booking in completedBookings) {
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
                        '${AppPreferences.instance.currencySymbol}${totalEarnings.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${completedBookings.length} completed trips',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      if (pendingBookings.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '+ ${AppPreferences.instance.currencySymbol}${(expectedEarnings - totalEarnings).toStringAsFixed(2)} pending (${pendingBookings.length} trips)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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
          '${AppPreferences.instance.currencySymbol}${amount.toStringAsFixed(2)}',
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
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot != null
                            ? '${slot.serviceType.displayName} Service'
                            : 'Service',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${booking.createdAt.day}/${booking.createdAt.month}/${booking.createdAt.year}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${AppPreferences.instance.currencySymbol}${booking.price.toStringAsFixed(2)}',
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
              _BookingTimeBanner(booking: booking),
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
                                    final currentUser =
                                        AuthRepository.instance.currentUser;
                                    if (currentUser == null) return true;

                                    await ProfileNameRegistry.instance.init();
                                    return ProfileNameRegistry.instance
                                        .isNameAvailable(
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
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    }

                                    final isAvailable = snapshot.data!;
                                    return Icon(
                                      isAvailable
                                          ? Icons.check_circle
                                          : Icons.error,
                                      color: isAvailable
                                          ? Colors.green
                                          : Colors.red,
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
                    initialValue: info.gender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) async {
                      await ProfileRepository.instance.update(gender: value);
                    },
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
                  const SizedBox(height: 24),

                  // 🎯 INR/Razorpay Banner for New Users
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Indian Payments Now Live!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '🇮🇳 Earn in INR with Razorpay\n\nDirect bank payouts for all your trip earnings. Quick setup in 2 minutes!',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // Trigger Razorpay setup
                              try {
                                await ProfileRepository.instance
                                    .updatePaymentProvider('razorpay');
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.account_balance),
                            label: const Text('Setup Razorpay Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment Provider Section
                  Text(
                    '💳 Payment Setup (For Receiving Payments)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose how you want to receive earnings from completed trips',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),

                  // Payment Provider Toggle
                  ValueListenableBuilder<ProfileInfo>(
                    valueListenable: ProfileRepository.instance.profile,
                    builder: (context, profile, _) {
                      final selectedProvider = profile.paymentProvider;
                      final isRazorpay = selectedProvider == 'razorpay';
                      final isStripe = selectedProvider == 'stripe';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Provider selection
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    try {
                                      // For new Razorpay users, show setup instructions
                                      if (!isRazorpay) {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text(
                                              '🎯 Set Up Razorpay',
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'To receive payments via Razorpay:',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                const Text(
                                                  '1. Go to Razorpay dashboard\n'
                                                  '2. Create your Razorpay Account\n'
                                                  '3. Add your bank account\n'
                                                  '4. Get your Account ID\n'
                                                  '5. Paste it below',
                                                ),
                                                const SizedBox(height: 16),
                                                TextField(
                                                  controller:
                                                      TextEditingController(),
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        'Your Razorpay Account ID',
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    prefixIcon: const Icon(
                                                      Icons.vpn_key,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(ctx);
                                                },
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: () async {
                                                  final url = Uri.parse(
                                                    'https://dashboard.razorpay.com',
                                                  );
                                                  if (await canLaunchUrl(url)) {
                                                    await launchUrl(
                                                      url,
                                                      mode: LaunchMode
                                                          .externalApplication,
                                                    );
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons.open_in_new,
                                                ),
                                                label: const Text(
                                                  'Go to Razorpay',
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      } else {
                                        // Already selected, just switch it off
                                        await ProfileRepository.instance
                                            .updatePaymentProvider('');
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isRazorpay
                                          ? Colors.blue.withValues(alpha: 0.1)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isRazorpay
                                            ? Colors.blue
                                            : Colors.grey.shade300,
                                        width: isRazorpay ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.account_balance,
                                          color: isRazorpay
                                              ? Colors.blue
                                              : Colors.grey,
                                          size: 28,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Razorpay',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isRazorpay
                                                ? Colors.blue
                                                : Colors.grey[700],
                                          ),
                                        ),
                                        Text(
                                          'Bank payout',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isRazorpay
                                                ? Colors.blue
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // TODO: Stripe payment provider - hidden for now, will be enabled later
                              // const SizedBox(width: 12),
                              // Expanded(
                              //   child: GestureDetector(
                              //     onTap: () async {
                              //       try {
                              //         await ProfileRepository.instance
                              //             .updatePaymentProvider('stripe');
                              //       } catch (e) {
                              //         if (context.mounted) {
                              //           ScaffoldMessenger.of(
                              //             context,
                              //           ).showSnackBar(
                              //             SnackBar(content: Text('Error: $e')),
                              //           );
                              //         }
                              //       }
                              //     },
                              //     child: Container(
                              //       padding: const EdgeInsets.all(12),
                              //       decoration: BoxDecoration(
                              //         color: isStripe
                              //             ? Colors.purple.withValues(alpha: 0.1)
                              //             : Colors.grey[100],
                              //         borderRadius: BorderRadius.circular(8),
                              //         border: Border.all(
                              //           color: isStripe
                              //               ? Colors.purple
                              //               : Colors.grey.shade300,
                              //           width: isStripe ? 2 : 1,
                              //         ),
                              //       ),
                              //       child: Column(
                              //         children: [
                              //           Icon(
                              //             Icons.credit_card,
                              //             color: isStripe
                              //                 ? Colors.purple
                              //                 : Colors.grey,
                              //             size: 28,
                              //           ),
                              //           const SizedBox(height: 4),
                              //           Text(
                              //             'Stripe',
                              //             style: TextStyle(
                              //               fontWeight: FontWeight.bold,
                              //               color: isStripe
                              //                   ? Colors.purple
                              //                   : Colors.grey[700],
                              //             ),
                              //           ),
                              //           Text(
                              //             'International',
                              //             style: TextStyle(
                              //               fontSize: 10,
                              //               color: Colors.grey[600],
                              //             ),
                              //           ),
                              //         ],
                              //       ),
                              //     ),
                              //   ),
                              // ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Currency Display (Read-only, based on connected account)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Currency',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _getCurrencyDisplay(profile),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isRazorpay || isStripe)
                                  const Icon(
                                    Icons.lock_outline,
                                    color: Colors.grey,
                                    size: 16,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isRazorpay
                                ? 'Currency is automatically set to INR for Razorpay'
                                : 'Razorpay is the only payment provider available',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Razorpay Details
                          if (selectedProvider == null ||
                              selectedProvider.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Text(
                                'Choose a payment gateway to set up payouts.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          if (isRazorpay) ...[
                            const SizedBox(height: 12),
                            // ✅ COMPLIANCE-SAFE: No bank details collected
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.security,
                                        color: Colors.blue.shade700,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Razorpay Account Connected',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Your bank details are securely managed by Razorpay. '
                                    'We do not store any bank account information for compliance and security.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    '✅ PCI-DSS Compliant\n'
                                    '✅ RBI Regulated\n'
                                    '✅ Bank-grade Security',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (profile.razorpayAccountId != null &&
                                      profile
                                          .razorpayAccountId!
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'Account ID: ${profile.razorpayAccountId}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ] else ...[
                                    // NEW USERS: Prompt to enter account ID
                                    const SizedBox(height: 12),
                                    const Text(
                                      '👉 Next Steps:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      '1. Click "Set Up Razorpay" below\n'
                                      '2. Create your account\n'
                                      '3. Get your Account ID\n'
                                      '4. Paste it here',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  if (profile.razorpayAccountId != null &&
                                      profile.razorpayAccountId!.isNotEmpty)
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        // Open Razorpay dashboard for bank details management
                                        final url = Uri.parse(
                                          'https://dashboard.razorpay.com/app/route',
                                        );
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(
                                            url,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.open_in_new),
                                      label: const Text(
                                        'Manage Bank Details on Razorpay',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    )
                                  else
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        // Open Razorpay dashboard for new users
                                        final url = Uri.parse(
                                          'https://dashboard.razorpay.com',
                                        );
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(
                                            url,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                      label: const Text(
                                        'Set Up Razorpay Account',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],

                          // TODO: Stripe Connect - hidden for now, will be enabled later
                          // if (isStripe) ...[
                          //   const Text(
                          //     'Stripe Connect',
                          //     style: TextStyle(fontWeight: FontWeight.w600),
                          //   ),
                          //   // ... Stripe setup UI removed - will restore later
                          // ],
                          const SizedBox(height: 8),
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
                                    'Your payment details are encrypted and secure. Only used to transfer your earnings.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
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
                              content: Text(
                                e.toString().replaceAll('Exception: ', ''),
                              ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Logged in',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
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
  final bool initialShowUserPosts;

  const PostsPage({super.key, this.initialShowUserPosts = false});

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
  SlotType? _selectedSlotType; // null = both, otherwise filter by slot type

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

  // Country filter
  final Set<String> _filterCountries = {}; // Empty = show all countries

  // Currency filter
  String? _selectedCurrency; // null = show all currencies

  // Operator filter (only for Lease)
  bool?
  _withOperator; // null = both, true = with operator, false = without operator

  // Security deposit filter (only for Lease)
  bool?
  _requiresSecurityDeposit; // null = both, true = with deposit, false = without deposit
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
  double? _minRating; // Minimum provider rating filter
  double? _maxRating; // Maximum provider rating filter
  int? _minRatingCount; // Minimum number of ratings filter
  int? _maxRatingCount; // Maximum number of ratings filter
  DateTime? _fromDateTime;
  DateTime? _toDateTime;
  double? _maxDistanceKm;

  // Resolved coordinates for base location radius search
  (double, double)? _filterBaseLatLon;

  final VehicleRepository _vehicleRepository = VehicleRepository.instance;

  @override
  void initState() {
    super.initState();
    _showUserPosts = widget.initialShowUserPosts;
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
              SizedBox(
                width: 200,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                          final messenger = ScaffoldMessenger.of(context);
                          await Future.wait([
                            VehicleRepository.instance.loadAllVehicles(),
                            CustomerVehicleRepository.instance
                                .reload(), // Use reload() instead of init()
                            SlotRepository.instance.loadAllSlots(),
                            CustomerSlotRepository.instance.init(),
                            BookingRepository.instance.refreshFromSupabase(),
                          ]);

                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Posts refreshed!'),
                                duration: Duration(seconds: 1),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      // Sort button
                      IconButton(
                        icon: const Icon(Icons.sort),
                        tooltip: 'Sort',
                        onPressed: () => _showSortBottomSheet(context),
                      ),
                      const SizedBox(width: 4),
                      // Debug button to show repository status
                      IconButton(
                        icon: const Icon(Icons.info_outline),
                        tooltip: 'Repository Status',
                        onPressed: () {
                          final providerSlots =
                              SlotRepository.instance.allSlots.length;
                          final userSlots =
                              CustomerSlotRepository.instance.allSlots.length;
                          final providerVehicles =
                              VehicleRepository.instance.allVehicles.length;
                          final userVehicles = CustomerVehicleRepository
                              .instance
                              .allVehicles
                              .length;

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
                                  Text(
                                    'Total Posts: ${providerSlots + userSlots}',
                                  ),
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
                ),
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
                                      suffixIcon:
                                          _fromSearchController.text.isEmpty
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
                                        _filterFromLocation = t.isEmpty
                                            ? null
                                            : t;
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
                                      suffixIcon:
                                          _toSearchController.text.isEmpty
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
                                        _filterToLocation = t.isEmpty
                                            ? null
                                            : t;
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
                                  _filterBaseLatLon =
                                      null; // reset until resolved
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
                                    : 'Search keyword',
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
                              label: Text(
                                _serviceLabel(service),
                                style: const TextStyle(fontSize: 14),
                              ),
                              selected: _selectedServiceType == service,
                              onSelected: (_) {
                                setState(() {
                                  // Toggle: click to select, click again to unselect
                                  _selectedServiceType =
                                      _selectedServiceType == service
                                      ? null
                                      : service;
                                  _withOperator = null; // Reset operator filter
                                  _requiresSecurityDeposit =
                                      null; // Reset deposit presence filter
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
              // Service-specific hint text
              if (_selectedServiceType != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _getServiceHint(_selectedServiceType!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
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
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort By',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: SortOption.values
                      .map(
                        (option) => ListTile(
                          leading: Icon(
                            _sortOption == option
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: _sortOption == option
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          title: Text(option.displayName),
                          selected: _sortOption == option,
                          onTap: () {
                            setState(() => _sortOption = option);
                            Navigator.pop(context);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
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
                    vehicle: item.vehicle,
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
            ...filteredSlots.map((item) {
              // Get customer profile info for customer posts
              final customerName =
                  ProfileNameRegistry.instance.getNameForUser(
                    item.slot.profileId,
                  ) ??
                  'User ${item.slot.profileId.substring(0, 6)}';

              final customerAvatar =
                  ProfileNameRegistry.instance.getAvatarForUser(
                    item.slot.profileId,
                  ) ??
                  '';

              return SlotCard(
                slot: item.slot,
                vehicle: item.vehicle,
                providerName:
                    customerName, // Show customer name instead of "Looking for service"
                providerAvatar: customerAvatar, // Show customer avatar
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
                        providerName: customerName,
                        providerAvatar: customerAvatar,
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

                  final booking = await BookingRepository.instance
                      .createBooking(
                        slotId: item.slot.id,
                        providerId: currentUser.id,
                        providerName: profile.profileName,
                        providerPhone: profile.phone,
                        userId: item.slot.profileId, // Use post owner
                        defaultCapacity: item.slot.capacity,
                        price: item.slot.price,
                        userName:
                            ProfileNameRegistry.instance.getNameForUser(
                              item.slot.profileId,
                            ) ??
                            'User',
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
              );
            }),
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

  String _getServiceHint(ServiceType type) {
    switch (type) {
      case ServiceType.passenger:
        return '🚗 Find verified drivers • Real-time GPS tracking • Transparent pricing';
      case ServiceType.parcel:
        return '📦 Ship quickly • Track deliveries live • Multiple parcel sizes';
      case ServiceType.working:
        return '💼 Find verified workers • Flexible hours • Hire instantly';
      case ServiceType.lease:
        return '🏍️ Rent vehicles • Flexible lease terms • Insurance available';
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
              providerName: e.vehicle.userName, // ? Show real name to everyone
              providerAvatar: '',
              providerRating: 5.0,
              isOffer: false,
              isUserPost: true,
            ),
          )
          .toList();
      debugPrint('?? User posts after expiry filter: ${repoItems.length}');
    } else {
      // Provider Posts tab - show ALL provider offers (common feed)
      final allProviderSlots = SlotRepository.instance.allSlots;
      debugPrint('Total provider slots: ${allProviderSlots.length}');

      final now = DateTime.now();

      repoItems = allProviderSlots
          .where(
            // Filter out expired posts (end time has passed)
            (e) {
              final isActive = e.slot.endTime.isAfter(now);
              if (!isActive && kDebugMode) {
                debugPrint(
                  '⏰ Filtered expired post: ${e.slot.id} ended ${e.slot.endTime}',
                );
              }
              return isActive;
            },
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
      debugPrint('?? Provider posts after expiry filter: ${repoItems.length}');
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
    debugPrint('?? After search filter: ${searched.length}');

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
    debugPrint('?? After date/time filter: ${dateTimeFiltered.length}');

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
      '?? After price filter (${_minPrice ?? "any"}-${_maxPrice ?? "any"}): ${priceFiltered.length}',
    );

    // Apply currency filter
    final currencyFiltered = _selectedCurrency == null
        ? priceFiltered
        : priceFiltered
              .where(
                (e) => e.slot.currencyType.toUpperCase() == _selectedCurrency,
              )
              .toList(growable: false);
    debugPrint(
      '?? After currency filter (${_selectedCurrency ?? "all"}): ${currencyFiltered.length}',
    );

    // Apply rating filter (min and max rating)
    final ratingFiltered = (_minRating == null && _maxRating == null)
        ? currencyFiltered
        : currencyFiltered
              .where((e) {
                // Get provider rating from profile
                // For now, using vehicle average_rating as proxy
                // In future, query profiles table for provider_rating
                final rating = e.vehicle.averageRating;

                // Check min condition
                if (_minRating != null && rating < _minRating!) {
                  return false;
                }

                // Check max condition
                if (_maxRating != null && rating > _maxRating!) {
                  return false;
                }

                return true;
              })
              .toList(growable: false);
    debugPrint(
      '⭐ After rating filter (${_minRating?.toStringAsFixed(1) ?? "any"}-${_maxRating?.toStringAsFixed(1) ?? "any"} stars): ${ratingFiltered.length}',
    );

    // Apply rating count filter (min and max number of ratings)
    final ratingCountFiltered =
        (_minRatingCount == null && _maxRatingCount == null)
        ? ratingFiltered
        : ratingFiltered
              .where((e) {
                // Count reviews for this vehicle's provider
                final reviews = ReviewRepository.instance.reviews.value
                    .where((r) => r.revieweeId == e.vehicle.userId)
                    .toList();
                final count = reviews.length;

                // Check min condition
                if (_minRatingCount != null && count < _minRatingCount!) {
                  return false;
                }

                // Check max condition
                if (_maxRatingCount != null && count > _maxRatingCount!) {
                  return false;
                }

                return true;
              })
              .toList(growable: false);
    debugPrint(
      '🔢 After rating count filter (${_minRatingCount ?? "any"}-${_maxRatingCount ?? "any"} ratings): ${ratingCountFiltered.length}',
    );

    // Apply service type filter
    final serviceFiltered = _selectedServiceType == null
        ? ratingCountFiltered
        : ratingCountFiltered
              .where((e) => e.slot.serviceType == _selectedServiceType)
              .toList();

    // Apply operator filter
    final operatorFiltered = _withOperator == null
        ? serviceFiltered
        : serviceFiltered
              .where((e) => e.slot.withOperator == _withOperator)
              .toList();

    // Apply security deposit filter (ALL service types)
    // Step 1: Filter by presence/absence of deposit
    final depositPresenceFiltered = _requiresSecurityDeposit == null
        ? operatorFiltered
        : operatorFiltered.where((e) {
            final hasDeposit =
                e.slot.securityDeposit != null && e.slot.securityDeposit! > 0;
            // _requiresSecurityDeposit: true = with deposit, false = without deposit
            return hasDeposit == _requiresSecurityDeposit;
          }).toList();

    // Step 2: Filter by deposit amount range (only if "with deposit" is selected)
    final depositFiltered =
        (_minSecurityDeposit == null && _maxSecurityDeposit == null)
        ? depositPresenceFiltered
        : depositPresenceFiltered
              .where((e) {
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
    final hasParcelFilter =
        _minParcelWeight != null ||
        _maxParcelWeight != null ||
        _minParcelLength != null ||
        _maxParcelLength != null ||
        _minParcelWidth != null ||
        _maxParcelWidth != null ||
        _minParcelHeight != null ||
        _maxParcelHeight != null;
    final parcelFiltered = !hasParcelFilter
        ? depositFiltered
        : depositFiltered
              .where((e) {
                if (e.slot.serviceType != ServiceType.parcel) return true;
                bool check(double? val, double? min, double? max) {
                  if (val == null) return min == null && max == null;
                  if (min != null && val < min) return false;
                  if (max != null && val > max) return false;
                  return true;
                }

                return check(
                      e.slot.maxWeight,
                      _minParcelWeight,
                      _maxParcelWeight,
                    ) &&
                    check(
                      e.slot.maxLength,
                      _minParcelLength,
                      _maxParcelLength,
                    ) &&
                    check(e.slot.maxWidth, _minParcelWidth, _maxParcelWidth) &&
                    check(e.slot.maxHeight, _minParcelHeight, _maxParcelHeight);
              })
              .toList(growable: false);

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
    final locationFiltered =
        (_filterFromLocation == null || _filterFromLocation!.trim().isEmpty) &&
            (_filterToLocation == null || _filterToLocation!.trim().isEmpty) &&
            (_filterBaseLocation == null || _filterBaseLocation!.trim().isEmpty)
        ? postModeFiltered
        : postModeFiltered
              .where((e) {
                final slot = e.slot;
                final fromNeedle = (_filterFromLocation ?? '')
                    .trim()
                    .toLowerCase();
                final toNeedle = (_filterToLocation ?? '').trim().toLowerCase();
                final baseNeedle = (_filterBaseLocation ?? '')
                    .trim()
                    .toLowerCase();

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

    // Apply country filter
    final countryFiltered = _filterCountries.isEmpty
        ? locationFiltered
        : locationFiltered
              .where((e) {
                // Extract country code from the post's location
                // Try baseLocation first (for fromRange slots), then fromLocation
                final locationToCheck =
                    (e.slot.baseLocation?.isNotEmpty ?? false)
                    ? e.slot.baseLocation
                    : e.slot.fromLocation;

                final countryCode = PaymentService.countryCodeFromLocation(
                  locationToCheck,
                );

                // If country code couldn't be determined, exclude the post
                if (countryCode == null) return false;

                // Check if the country code matches any selected countries
                return _filterCountries.contains(countryCode);
              })
              .toList(growable: false);
    debugPrint(
      '🌍 After country filter (${_filterCountries.isEmpty ? "all" : _filterCountries.join(", ")}): ${countryFiltered.length}',
    );

    final distanceFiltered = _maxDistanceKm == null
        ? countryFiltered
        : countryFiltered
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
      debugPrint('?? FINAL RESULT: ${result.length} posts after all filters');
      return result;
    }

    final result = _sortByDistance(distanceFiltered);
    debugPrint(
      '?? FINAL RESULT: ${result.length} posts after all filters (sorted by distance)',
    );
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
        sorted.sort(
          (a, b) => b.vehicle.averageRating.compareTo(a.vehicle.averageRating),
        );
        break;
      case SortOption.bookingsHighToLow:
        sorted.sort(
          (a, b) => b.vehicle.totalBookings.compareTo(a.vehicle.totalBookings),
        );
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
    // On web, skip permission_handler (not supported) and use Geolocator directly
    if (kIsWeb) {
      try {
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
          ).showSnackBar(SnackBar(content: Text('Location error: $e')));
        }
        return false;
      }
    }

    // Mobile: use permission_handler
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
      text:
          _maxDistanceKm?.toStringAsFixed(
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: maxDistanceController,
                        decoration: const InputDecoration(
                          labelText: 'Max travel time (minutes)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.schedule),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: false,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Shows services you can reach within this time',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
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
                                  setSheetState(() => businessType = 'private');
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
                        // Clarification for Fixed Route posts
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Filter fixed route posts by exact From & To locations',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
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
                        // Clarification for Base Location posts
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            border: Border.all(
                              color: Colors.green.shade200,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.green.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Shows posts within the radius of your base location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _locationAutocompleteField(
                          controller: baseLocationController,
                          label: 'Base location',
                          icon: Icons.location_on,
                          suggestions: _allLocationNames(field: 'base'),
                          onChanged: () => setSheetState(() {}),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Max Distance',
                            hintText: 'Enter distance in km',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.straighten),
                            suffixText: 'km',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          controller: maxDistanceController,
                          onChanged: (value) {
                            if (value.isEmpty) {
                              setSheetState(() {
                                _maxDistanceKm = null;
                              });
                              return;
                            }
                            final parsed = double.tryParse(value);
                            if (parsed != null && parsed > 0) {
                              setSheetState(() {
                                _maxDistanceKm = parsed;
                              });
                            }
                          },
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
                                  _selectedPostMode = _selectedPostMode == m
                                      ? null
                                      : m;
                                  // Reset deadline filter when changing mode
                                  if (_selectedPostMode !=
                                      PostMode.waitForFull) {
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
                      ValueListenableBuilder<String>(
                        valueListenable: AppPreferences.instance.currencyCode,
                        builder: (context, currencyCode, _) {
                          final symbol = AppPreferences.instance.currencySymbol;
                          return Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: minPriceController,
                                  decoration: InputDecoration(
                                    labelText: 'Min Price',
                                    border: OutlineInputBorder(),
                                    prefixText: symbol,
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: maxPriceController,
                                  decoration: InputDecoration(
                                    labelText: 'Max Price',
                                    border: OutlineInputBorder(),
                                    prefixText: symbol,
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Currency Filter
                      const Text(
                        'Currency',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Filter by currency',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        initialValue: _selectedCurrency,
                        items: const [
                          DropdownMenuItem(
                            value: null,
                            child: Text('All currencies'),
                          ),
                          // Asia
                          DropdownMenuItem(
                            value: 'INR',
                            child: Text('🇮🇳 INR - Indian Rupee'),
                          ),
                          DropdownMenuItem(
                            value: 'AED',
                            child: Text('🇦🇪 AED - UAE Dirham'),
                          ),
                          DropdownMenuItem(
                            value: 'SGD',
                            child: Text('🇸🇬 SGD - Singapore Dollar'),
                          ),
                          DropdownMenuItem(
                            value: 'JPY',
                            child: Text('🇯🇵 JPY - Japanese Yen'),
                          ),
                          DropdownMenuItem(
                            value: 'CNY',
                            child: Text('🇨🇳 CNY - Chinese Yuan'),
                          ),
                          DropdownMenuItem(
                            value: 'HKD',
                            child: Text('🇭🇰 HKD - Hong Kong Dollar'),
                          ),
                          DropdownMenuItem(
                            value: 'KRW',
                            child: Text('🇰🇷 KRW - Korean Won'),
                          ),
                          DropdownMenuItem(
                            value: 'MYR',
                            child: Text('🇲🇾 MYR - Malaysian Ringgit'),
                          ),
                          DropdownMenuItem(
                            value: 'THB',
                            child: Text('🇹🇭 THB - Thai Baht'),
                          ),
                          DropdownMenuItem(
                            value: 'IDR',
                            child: Text('🇮� IDR - Indonesian Rupiah'),
                          ),
                          DropdownMenuItem(
                            value: 'PHP',
                            child: Text('🇵🇭 PHP - Philippine Peso'),
                          ),
                          DropdownMenuItem(
                            value: 'PKR',
                            child: Text('🇵🇰 PKR - Pakistani Rupee'),
                          ),
                          DropdownMenuItem(
                            value: 'BDT',
                            child: Text('🇧🇩 BDT - Bangladeshi Taka'),
                          ),
                          DropdownMenuItem(
                            value: 'LKR',
                            child: Text('🇱🇰 LKR - Sri Lankan Rupee'),
                          ),
                          DropdownMenuItem(
                            value: 'NPR',
                            child: Text('🇳🇵 NPR - Nepalese Rupee'),
                          ),
                          DropdownMenuItem(
                            value: 'SAR',
                            child: Text('🇸🇦 SAR - Saudi Riyal'),
                          ),
                          DropdownMenuItem(
                            value: 'QAR',
                            child: Text('🇶🇦 QAR - Qatari Riyal'),
                          ),
                          DropdownMenuItem(
                            value: 'KWD',
                            child: Text('🇰🇼 KWD - Kuwaiti Dinar'),
                          ),
                          // Americas
                          DropdownMenuItem(
                            value: 'USD',
                            child: Text('🇺🇸 USD - US Dollar'),
                          ),
                          DropdownMenuItem(
                            value: 'CAD',
                            child: Text('�� CAD - Canadian Dollar'),
                          ),
                          DropdownMenuItem(
                            value: 'MXN',
                            child: Text('🇲🇽 MXN - Mexican Peso'),
                          ),
                          DropdownMenuItem(
                            value: 'BRL',
                            child: Text('🇧🇷 BRL - Brazilian Real'),
                          ),
                          // Europe
                          DropdownMenuItem(
                            value: 'EUR',
                            child: Text('🇪🇺 EUR - Euro'),
                          ),
                          DropdownMenuItem(
                            value: 'GBP',
                            child: Text('�� GBP - British Pound'),
                          ),
                          DropdownMenuItem(
                            value: 'CHF',
                            child: Text('🇨🇭 CHF - Swiss Franc'),
                          ),
                          DropdownMenuItem(
                            value: 'SEK',
                            child: Text('🇸� SEK - Swedish Krona'),
                          ),
                          DropdownMenuItem(
                            value: 'NOK',
                            child: Text('🇳🇴 NOK - Norwegian Krone'),
                          ),
                          DropdownMenuItem(
                            value: 'DKK',
                            child: Text('🇩🇰 DKK - Danish Krone'),
                          ),
                          DropdownMenuItem(
                            value: 'PLN',
                            child: Text('🇵🇱 PLN - Polish Zloty'),
                          ),
                          DropdownMenuItem(
                            value: 'CZK',
                            child: Text('🇨🇿 CZK - Czech Koruna'),
                          ),
                          // Oceania
                          DropdownMenuItem(
                            value: 'AUD',
                            child: Text('🇦🇺 AUD - Australian Dollar'),
                          ),
                          DropdownMenuItem(
                            value: 'NZD',
                            child: Text('🇳🇿 NZD - New Zealand Dollar'),
                          ),
                          // Africa
                          DropdownMenuItem(
                            value: 'ZAR',
                            child: Text('�🇦 ZAR - South African Rand'),
                          ),
                          DropdownMenuItem(
                            value: 'NGN',
                            child: Text('🇳🇬 NGN - Nigerian Naira'),
                          ),
                          DropdownMenuItem(
                            value: 'KES',
                            child: Text('🇰🇪 KES - Kenyan Shilling'),
                          ),
                        ],
                        onChanged: (value) {
                          setSheetState(() {
                            _selectedCurrency = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Rating Filter (Min and Max)
                      const Text(
                        'Provider Rating (Stars)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Min Rating',
                                hintText: '0.0',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.star),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              controller: TextEditingController(
                                text: _minRating?.toStringAsFixed(1) ?? '',
                              ),
                              onChanged: (value) {
                                if (value.isEmpty) {
                                  setSheetState(() {
                                    _minRating = null;
                                  });
                                  return;
                                }
                                final parsed = double.tryParse(value);
                                if (parsed == null) return;
                                // Limit to 0.0-5.0 range
                                if (parsed < 0.0) {
                                  setSheetState(() {
                                    _minRating = 0.0;
                                  });
                                } else if (parsed > 5.0) {
                                  setSheetState(() {
                                    _minRating = 5.0;
                                  });
                                } else {
                                  setSheetState(() {
                                    _minRating = parsed;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Max Rating',
                                hintText: '5.0',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.star),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              controller: TextEditingController(
                                text: _maxRating?.toStringAsFixed(1) ?? '',
                              ),
                              onChanged: (value) {
                                if (value.isEmpty) {
                                  setSheetState(() {
                                    _maxRating = null;
                                  });
                                  return;
                                }
                                final parsed = double.tryParse(value);
                                if (parsed == null) return;
                                // Limit to 0.0-5.0 range
                                if (parsed < 0.0) {
                                  setSheetState(() {
                                    _maxRating = 0.0;
                                  });
                                } else if (parsed > 5.0) {
                                  setSheetState(() {
                                    _maxRating = 5.0;
                                  });
                                } else {
                                  setSheetState(() {
                                    _maxRating = parsed;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Rating Count Filter (Min and Max)
                      const Text(
                        'Number of Ratings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Min Ratings',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.reviews),
                              ),
                              keyboardType: TextInputType.number,
                              controller: TextEditingController(
                                text: _minRatingCount?.toString() ?? '',
                              ),
                              onChanged: (value) {
                                if (value.isEmpty) {
                                  setSheetState(() {
                                    _minRatingCount = null;
                                  });
                                  return;
                                }
                                final parsed = int.tryParse(value);
                                if (parsed == null) return;
                                // Limit to reasonable range: 0-500
                                if (parsed < 0) {
                                  setSheetState(() {
                                    _minRatingCount = 0;
                                  });
                                } else if (parsed > 500) {
                                  setSheetState(() {
                                    _minRatingCount = 500;
                                  });
                                } else {
                                  setSheetState(() {
                                    _minRatingCount = parsed;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Max Ratings',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.reviews),
                              ),
                              keyboardType: TextInputType.number,
                              controller: TextEditingController(
                                text: _maxRatingCount?.toString() ?? '',
                              ),
                              onChanged: (value) {
                                if (value.isEmpty) {
                                  setSheetState(() {
                                    _maxRatingCount = null;
                                  });
                                  return;
                                }
                                final parsed = int.tryParse(value);
                                if (parsed == null) return;
                                // Limit to reasonable range: 0-500
                                if (parsed < 0) {
                                  setSheetState(() {
                                    _maxRatingCount = 0;
                                  });
                                } else if (parsed > 500) {
                                  setSheetState(() {
                                    _maxRatingCount = 500;
                                  });
                                } else {
                                  setSheetState(() {
                                    _maxRatingCount = parsed;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_month),
                        title: const Text('From date/time'),
                        subtitle: Text(
                          from == null ? 'Any' : _fmtDateTime(from!),
                        ),
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
                                data: MediaQuery.of(
                                  ctx,
                                ).copyWith(alwaysUse24HourFormat: true),
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
                              initialTime: TimeOfDay.fromDateTime(
                                to ?? DateTime.now(),
                              ),
                              builder: (ctx, child) => MediaQuery(
                                data: MediaQuery.of(
                                  ctx,
                                ).copyWith(alwaysUse24HourFormat: true),
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
                      // Security Deposit Filter (available for all service types)
                      const Text(
                        'Security Deposit',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      // Toggle: With / Without / Both
                      Row(
                        children: [
                          Expanded(
                            child: FilterChip(
                              label: const Text('With Deposit'),
                              selected: _requiresSecurityDeposit == true,
                              onSelected: (selected) {
                                setState(() {
                                  _requiresSecurityDeposit = selected
                                      ? true
                                      : null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilterChip(
                              label: const Text('Without'),
                              selected: _requiresSecurityDeposit == false,
                              onSelected: (selected) {
                                setState(() {
                                  _requiresSecurityDeposit = selected
                                      ? false
                                      : null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilterChip(
                              label: const Text('Both'),
                              selected: _requiresSecurityDeposit == null,
                              onSelected: (selected) {
                                setState(() {
                                  _requiresSecurityDeposit = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Amount range (only shown when "With Deposit" is selected)
                      if (_requiresSecurityDeposit == true) ...[
                        const Text(
                          'Deposit Amount Range',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minSecurityDepositController,
                                decoration: InputDecoration(
                                  labelText: 'Min Deposit',
                                  border: OutlineInputBorder(),
                                  prefixText:
                                      AppPreferences.instance.currencySymbol,
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: maxSecurityDepositController,
                                decoration: InputDecoration(
                                  labelText: 'Max Deposit',
                                  border: OutlineInputBorder(),
                                  prefixText:
                                      AppPreferences.instance.currencySymbol,
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
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
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
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
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
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
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
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
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
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
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
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
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
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
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
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
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
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
                                  _minRating = null;
                                  _maxRating = null;
                                  _minRatingCount = null;
                                  _maxRatingCount = null;
                                  _fromDateTime = null;
                                  _toDateTime = null;
                                  _nearestEnabled = false;
                                  _maxDistanceKm = null;
                                  _requiresSecurityDeposit = null;
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
                                  _selectedCurrency = null;
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
                                  maxDistanceController.text.trim(),
                                );
                                final wantsDistance =
                                    parsedMaxDistance != null &&
                                    parsedMaxDistance.isFinite &&
                                    parsedMaxDistance > 0;
                                if (wantsDistance &&
                                    _currentUserPosition == null) {
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                  await _requestUserLocation();
                                  if (!mounted) return;
                                  if (_currentUserPosition == null) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
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
                                  _minPrice = double.tryParse(
                                    minPriceController.text,
                                  );
                                  _maxPrice = double.tryParse(
                                    maxPriceController.text,
                                  );
                                  _fromDateTime = from;
                                  _toDateTime = to;
                                  _nearestEnabled = nearest;
                                  _maxDistanceKm = wantsDistance
                                      ? parsedMaxDistance
                                      : null;
                                  _minSecurityDeposit =
                                      _selectedServiceType == ServiceType.lease
                                      ? double.tryParse(
                                          minSecurityDepositController.text,
                                        )
                                      : null;
                                  _maxSecurityDeposit =
                                      _selectedServiceType == ServiceType.lease
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
                                  _toSearchController.text =
                                      _filterToLocation ?? '';
                                  _baseSearchController.text =
                                      _filterBaseLocation ?? '';
                                  _filterBaseLatLon = null;
                                  _minParcelWeight =
                                      _selectedServiceType == ServiceType.parcel
                                      ? double.tryParse(
                                          minWeightController.text,
                                        )
                                      : null;
                                  _maxParcelWeight =
                                      _selectedServiceType == ServiceType.parcel
                                      ? double.tryParse(
                                          maxWeightController.text,
                                        )
                                      : null;
                                  _minParcelLength =
                                      _selectedServiceType == ServiceType.parcel
                                      ? double.tryParse(
                                          minLengthController.text,
                                        )
                                      : null;
                                  _maxParcelLength =
                                      _selectedServiceType == ServiceType.parcel
                                      ? double.tryParse(
                                          maxLengthController.text,
                                        )
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
                                      ? double.tryParse(
                                          minHeightController.text,
                                        )
                                      : null;
                                  _maxParcelHeight =
                                      _selectedServiceType == ServiceType.parcel
                                      ? double.tryParse(
                                          maxHeightController.text,
                                        )
                                      : null;
                                });

                                final baseText = _filterBaseLocation;
                                if (baseText != null && baseText.length >= 3) {
                                  final results =
                                      await LocationAutocompleteService.instance
                                          .searchLocations(baseText);
                                  if (results.isNotEmpty && mounted) {
                                    setState(() {
                                      _filterBaseLatLon = (
                                        results.first.lat,
                                        results.first.lon,
                                      );
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
        fieldController.addListener(
          () => controller.text = fieldController.text,
        );
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
  /// Locations are stored as "Name|lat,lon" ? we return just the Name part.
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
    Vehicle? vehicle,
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

    debugPrint('?? Booking action started for slot: ${slot.id}');

    final canBook = BookingRepository.instance.canBook(slot.id, slot.capacity);
    if (!canBook) {
      debugPrint('? Cannot book: No capacity remaining');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No capacity remaining')));
      return;
    }

    debugPrint(
      '? Capacity check passed, looking for vehicle: ${slot.vehicleId}',
    );

    final vehicleToUse =
        vehicle ?? VehicleRepository.instance.getById(slot.vehicleId);
    if (vehicleToUse == null) {
      debugPrint('? Vehicle not found in VehicleRepository: ${slot.vehicleId}');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vehicle not found')));
      return;
    }

    debugPrint('? Vehicle found, showing booking sheet');

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
      // null means either: user cancelled, OR booking was already created inside the sheet (test mode / payment flow)
      // Both cases are fine ? if booking was created, the sheet already navigated to Requests tab
      debugPrint(
        '?? Sheet closed without result (booking created internally or user cancelled)',
      );
      return;
    }

    if (!mounted) return;

    // Use fallback provider info if not provided
    // Priority: 1. Operator contact (if assigned), 2. Provided contact, 3. Owner contact
    final finalProviderName = providerName ?? vehicleToUse.userName;
    final finalProviderPhone =
        providerPhone ??
        (vehicleToUse.operatorPhone ?? _providerPhone(vehicleToUse.userId));

    debugPrint('=== BOOKING DEBUG ===');
    debugPrint('Post profileId: ${slot.profileId}');
    debugPrint('Vehicle userId: ${vehicleToUse.userId}');
    debugPrint('Current user ID: ${AuthRepository.instance.currentUser?.id}');
    debugPrint('Provider ID for booking: ${slot.profileId}');
    debugPrint('====================');

    final confirmedCount = result.seatKeys.length;
    if (confirmedCount == 0) {
      debugPrint('?? No seats selected, booking already created in sheet');
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
        securityDeposit: slot.serviceType.name == 'lease'
            ? slot.securityDeposit
            : null,
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
          vehicle: vehicleToUse,
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
  DateTime? _fromDateTime;
  DateTime? _toDateTime;

  Future<DateTime?> _pickDateTime(
    BuildContext context, {
    DateTime? initial,
  }) async {
    final now = DateTime.now();
    final initDate = initial ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !context.mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initDate),
    );
    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  void _showDateTimeRangeFilter() async {
    DateTime? from = _fromDateTime;
    DateTime? to = _toDateTime;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            String fmtDT(DateTime? dt) {
              if (dt == null) return 'Not set';
              return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            }

            return AlertDialog(
              title: const Text('Filter by Date & Time'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.calendar_today,
                      color: Colors.blue,
                    ),
                    title: const Text('From'),
                    subtitle: Text(
                      fmtDT(from),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () async {
                      final picked = await _pickDateTime(ctx, initial: from);
                      if (picked != null) setDialogState(() => from = picked);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.calendar_today,
                      color: Colors.green,
                    ),
                    title: const Text('To'),
                    subtitle: Text(
                      fmtDT(to),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () async {
                      final picked = await _pickDateTime(
                        ctx,
                        initial: to ?? from,
                      );
                      if (picked != null) setDialogState(() => to = picked);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _fromDateTime = null;
                      _toDateTime = null;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _fromDateTime = from;
                      _toDateTime = to;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _clearDateFilter() {
    setState(() {
      _fromDateTime = null;
      _toDateTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requests'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_fromDateTime != null || _toDateTime != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear date filter',
              onPressed: _clearDateFilter,
            ),
          IconButton(
            icon: Icon(
              (_fromDateTime != null || _toDateTime != null)
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
              color: (_fromDateTime != null || _toDateTime != null)
                  ? Colors.blue
                  : null,
            ),
            tooltip: 'Filter by date & time range',

            onPressed: _showDateTimeRangeFilter,
          ),
        ],
      ),
      body: _RequestsBody(fromDateTime: _fromDateTime, toDateTime: _toDateTime),
    );
  }
}

class _RequestsBody extends StatefulWidget {
  final DateTime? fromDateTime;
  final DateTime? toDateTime;

  const _RequestsBody({this.fromDateTime, this.toDateTime});

  @override
  State<_RequestsBody> createState() => _RequestsBodyState();
}

class _RequestsBodyState extends State<_RequestsBody> {
  bool _isRiderView = true;
  final Map<String, TextEditingController> _otpControllers = {};

  // Helper to build a filter chip that toggles a group of statuses
  Widget _buildFilterChip(
    String label,
    Color color,
    Set<BookingStatus> statuses,
  ) {
    final isSelected = statuses.any((s) => _statusFilters.contains(s));
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _statusFilters.addAll(statuses);
          } else {
            _statusFilters.removeAll(statuses);
          }
        });
      },
      selectedColor: color.withValues(alpha: 0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Set<BookingStatus> _statusFilters = {}; // Empty = show all
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Force refresh bookings from Supabase when screen opens
    Future.delayed(const Duration(milliseconds: 100), () async {
      debugPrint('🔄 Requests screen: Refreshing bookings from Supabase...');
      await BookingRepository.instance.refreshFromSupabase();
      debugPrint(
        '✅ Bookings refreshed: ${BookingRepository.instance.bookings.value.length} bookings',
      );

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

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
                // Active group
                _buildFilterChip('Active', Colors.green, {
                  BookingStatus.pending,
                  BookingStatus.accepted,
                  BookingStatus.confirmed,
                  BookingStatus.inProgress,
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', Colors.blue, {
                  BookingStatus.completed,
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Expired', Colors.red, {
                  BookingStatus.expired,
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Disputed', Colors.deepOrange, {
                  BookingStatus.disputed,
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Cancelled', Colors.purple, {
                  BookingStatus.cancelled,
                  BookingStatus.cancelledByCustomer,
                  BookingStatus.cancelledByProvider,
                  BookingStatus.rejected,
                  BookingStatus.noShow,
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Refunded', Colors.orange, {
                  BookingStatus.refunded,
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (widget.fromDateTime != null || widget.toDateTime != null)
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
                      'Filtered: ${widget.fromDateTime != null ? _formatDateTime(widget.fromDateTime!) : 'Any'} → ${widget.toDateTime != null ? _formatDateTime(widget.toDateTime!) : 'Any'}',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (widget.fromDateTime != null || widget.toDateTime != null)
          const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ValueListenableBuilder<List<Booking>>(
                  valueListenable: BookingRepository.instance.bookings,
                  builder: (context, bookings, _) {
                    return ValueListenableBuilder<List<UserPostAcceptance>>(
                      valueListenable:
                          UserPostAcceptanceRepository.instance.acceptances,
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
                                if (b.providerId != currentUser.id &&
                                    b.providerId != 'user1') {
                                  return false;
                                }
                              }

                              // Status filter
                              if (_statusFilters.isNotEmpty &&
                                  !_statusFilters.contains(b.status)) {
                                return false;
                              }

                              // Date & time range filter
                              if (widget.fromDateTime != null ||
                                  widget.toDateTime != null) {
                                final bookingDate = b.createdAt;
                                if (widget.fromDateTime != null &&
                                    bookingDate.isBefore(
                                      widget.fromDateTime!,
                                    )) {
                                  return false;
                                }
                                if (widget.toDateTime != null &&
                                    bookingDate.isAfter(widget.toDateTime!)) {
                                  return false;
                                }
                              }

                              if (_query.isEmpty) return true;
                              return (b.providerName ?? '')
                                      .toLowerCase()
                                      .contains(_query) ||
                                  (b.userName ?? '').toLowerCase().contains(
                                    _query,
                                  ) ||
                                  b.status.name.toLowerCase().contains(
                                    _query,
                                  ) ||
                                  b.id.toLowerCase().contains(_query) ||
                                  b.slotId.toLowerCase().contains(_query);
                            })
                            .toList(growable: false);

                        final filteredAcceptances = acceptances
                            .where((a) {
                              if (_isRiderView) {
                                if (a.userId != currentUser.id) return false;
                              } else {
                                if (a.providerId != currentUser.id) {
                                  return false;
                                }
                              }

                              // Map AcceptanceStatus → BookingStatus for chip filtering
                              if (_statusFilters.isNotEmpty) {
                                final BookingStatus mappedStatus;
                                switch (a.status) {
                                  case AcceptanceStatus.pending:
                                    mappedStatus = BookingStatus.pending;
                                  case AcceptanceStatus.otpVerified:
                                  case AcceptanceStatus.paid:
                                    mappedStatus = BookingStatus.completed;
                                  case AcceptanceStatus.cancelled:
                                    mappedStatus = BookingStatus.cancelled;
                                }
                                if (!_statusFilters.contains(mappedStatus)) {
                                  return false;
                                }
                              }

                              // Date & time range filter
                              if (widget.fromDateTime != null ||
                                  widget.toDateTime != null) {
                                final acceptanceDate = a.createdAt;
                                if (widget.fromDateTime != null &&
                                    acceptanceDate.isBefore(
                                      widget.fromDateTime!,
                                    )) {
                                  return false;
                                }
                                if (widget.toDateTime != null &&
                                    acceptanceDate.isAfter(
                                      widget.toDateTime!,
                                    )) {
                                  return false;
                                }
                              }

                              if (_query.isEmpty) return true;
                              return a.status.name.toLowerCase().contains(
                                _query,
                              );
                            })
                            .toList(growable: false);

                        if (filteredBookings.isEmpty &&
                            filteredAcceptances.isEmpty) {
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
                                            title: const Text(
                                              'Clear All Bookings?',
                                            ),
                                            content: const Text(
                                              'This will delete all bookings. This action cannot be undone.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text('Clear All'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          BookingRepository
                                                  .instance
                                                  .bookings
                                                  .value =
                                              [];
                                          BookingRepository
                                                  .instance
                                                  .remainingCapacityBySlotId
                                                  .value =
                                              {};
                                          final prefs =
                                              await SharedPreferences.getInstance();
                                          await prefs.remove('bookings_data');
                                          await prefs.remove(
                                            'remaining_capacity',
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'All bookings cleared',
                                                ),
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
                        final totalCount =
                            filteredBookings.length +
                            filteredAcceptances.length;

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: totalCount,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index < filteredBookings.length) {
                              return _buildBookingCard(
                                context,
                                filteredBookings[index],
                                isRiderView: _isRiderView,
                              );
                            } else {
                              final acceptance =
                                  filteredAcceptances[index -
                                      filteredBookings.length];
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

  Widget _buildAcceptanceCard(
    BuildContext context,
    UserPostAcceptance acceptance,
  ) {
    final currentUser = AuthRepository.instance.currentUser;
    final isUserView = currentUser?.id == acceptance.userId;

    // Look up the related post for details
    UserPost? post;
    try {
      post = UserPostRepository.instance.posts.value.firstWhere(
        (p) => p.id == acceptance.postId,
      );
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
                const Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 16,
                  color: Colors.purple,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Post Request #${acceptance.postId.length > 8 ? acceptance.postId.substring(0, 8) : acceptance.postId}',
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
                '${_getServiceTypeName(post.serviceType)} ? ${_fmtDateTime(post.startTime)}',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              if (post.fromLocation != null && post.toLocation != null)
                Text(
                  '${post.fromLocation} ? ${post.toLocation}',
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
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
                      const Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Share this OTP with the provider',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
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
                            Clipboard.setData(
                              ClipboardData(text: acceptance.otp!),
                            );
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
                            const SnackBar(
                              content: Text('Please enter 6-digit OTP'),
                            ),
                          );
                          return;
                        }
                        final ok = await UserPostAcceptanceRepository.instance
                            .verifyOTP(
                              acceptanceId: acceptance.id,
                              enteredOTP: otpText,
                            );
                        if (!context.mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? '? OTP verified' : 'Invalid OTP',
                            ),
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
                    Text(
                      'OTP verified ? awaiting payment',
                      style: TextStyle(fontSize: 13),
                    ),
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
                    Text(
                      'Payment completed',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
    final Slot? slotForMap =
        bookingSlot; // Show map for all bookings, not just accepted

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
                        '${b.userAge != null ? '${b.userAge} yrs' : ''}${b.userAge != null && b.userGender != null ? ' · ' : ''}${b.userGender?.name ?? ''}${b.seatKey != null ? ' · Seat: ${b.seatKey}' : ''}',
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
            // -- Trip schedule + deadline (from booking snapshot) ----------
            _BookingTimeBanner(booking: b),
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
                    for (final e
                        in CustomerVehicleRepository.instance.allVehicles) {
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
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.map,
                                size: 18,
                                color: Colors.blue,
                              ),
                              tooltip: 'Open in OpenStreetMap',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  _openGoogleMapsLatLng(context, lat!, lng!),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.navigation,
                                size: 18,
                                color: Colors.green,
                              ),
                              tooltip: 'Track on Map',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BookingMapScreen(
                                      booking: b,
                                      slot: bookingSlot,
                                      vehicle: vehicle,
                                      isProviderView: isRiderView
                                          ? false
                                          : true,
                                    ),
                                  ),
                                );
                              },
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show time banner from booking snapshot even without slot
                  _BookingTimeBanner(booking: b),
                  const SizedBox(height: 4),
                  Text(
                    'Booked: ${_fmtDateTime(b.createdAt)}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  // Show provider info for customer (rider) view
                  if (isRiderView) ...[
                    // Fetch vehicle to show operator details
                    Builder(
                      builder: (context) {
                        // Find the vehicle to get operator details
                        Vehicle? bookingVehicle;
                        if (bookingSlot != null) {
                          for (final e
                              in VehicleRepository.instance.allVehicles) {
                            if (e.id == bookingSlot.vehicleId) {
                              bookingVehicle = e;
                              break;
                            }
                          }
                          if (bookingVehicle == null) {
                            for (final e
                                in CustomerVehicleRepository
                                    .instance
                                    .allVehicles) {
                              if (e.id == bookingSlot.vehicleId) {
                                bookingVehicle = e;
                                break;
                              }
                            }
                          }
                        }

                        final hasOperator =
                            bookingVehicle?.operatorName != null &&
                            bookingVehicle!.operatorName!.isNotEmpty;

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Profile owner info
                              Row(
                                children: [
                                  if (b.providerAvatar != null &&
                                      b.providerAvatar!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundImage: NetworkImage(
                                          b.providerAvatar!,
                                        ),
                                        onBackgroundImageError: (_, _) {},
                                        child: b.providerAvatar!.isEmpty
                                            ? const Icon(Icons.person, size: 16)
                                            : null,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      'Provider: ${b.providerName ?? _providerName(b.providerId)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Operator details (if different from owner)
                              if (hasOperator) ...[
                                const SizedBox(height: 8),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.local_taxi,
                                      size: 14,
                                      color: Colors.blue[700],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Operator: ${bookingVehicle.operatorName}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                if (bookingVehicle.operatorPhone != null &&
                                    bookingVehicle
                                        .operatorPhone!
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        size: 12,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        bookingVehicle.operatorPhone!,
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (bookingVehicle.operatorGender != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        bookingVehicle.operatorGender == 'male'
                                            ? Icons.male
                                            : Icons.female,
                                        size: 12,
                                        color:
                                            bookingVehicle.operatorGender ==
                                                'male'
                                            ? Colors.blue[700]
                                            : Colors.pink[700],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        bookingVehicle.operatorGender!
                                            .toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],

                              // Vehicle info
                              if (bookingVehicle != null) ...[
                                const SizedBox(height: 8),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.directions_car,
                                      size: 14,
                                      color: Colors.green[700],
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${bookingVehicle.name}${bookingVehicle.year != null ? " (${bookingVehicle.year})" : ""}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (bookingVehicle.registrationNumber != null &&
                                    bookingVehicle
                                        .registrationNumber!
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.numbers,
                                        size: 12,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        bookingVehicle.registrationNumber!,
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    // Provider view — show customer info
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User: ${b.userName ?? 'N/A'}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (b.userPhone != null &&
                              b.userPhone!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Contact: ${b.userPhone}',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            if (slotForMap != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (slotForMap.fromLocation != null &&
                              slotForMap.toLocation != null)
                          ? '${_cleanLoc(slotForMap.fromLocation!)} ? ${_cleanLoc(slotForMap.toLocation!)}'
                          : _cleanLoc(slotForMap.baseLocation),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open map',
                    onPressed: () {
                      // Get vehicle GPS coords for this booking
                      final slotEntry = SlotRepository.instance.allSlots
                          .where((e) => e.slot.id == slotForMap.id)
                          .firstOrNull;
                      final v = slotEntry?.vehicle;
                      final vLat = v?.lastKnownLat ?? v?.manualLat;
                      final vLng = v?.lastKnownLng ?? v?.manualLng;
                      _openExternalMapForSlot(
                        context,
                        slotForMap,
                        vehicleLat: vLat,
                        vehicleLng: vLng,
                      );
                    },
                    icon: const Icon(Icons.map_outlined),
                  ),
                ],
              ),
            ],
            // Show full card details for ALL booking statuses
            ...[
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

                // Track Vehicle Button (for active bookings with GPS)
                Builder(
                  builder: (context) {
                    // Get vehicle for this booking
                    final bookingSlotId = b.slotId;
                    final slotEntry = SlotRepository.instance.allSlots
                        .where((e) => e.slot.id == bookingSlotId)
                        .firstOrNull;
                    final vehicle = slotEntry?.vehicle;
                    final slot = slotEntry?.slot;

                    // Only show for active bookings with vehicle GPS data
                    if (vehicle != null &&
                        (b.status == BookingStatus.accepted ||
                            b.status == BookingStatus.pending) &&
                        (vehicle.lastKnownLat != null ||
                            vehicle.manualLat != null)) {
                      return Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BookingMapScreen(
                                      booking: b,
                                      slot: slot,
                                      vehicle: vehicle,
                                      isProviderView: false,
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(
                                vehicle.gpsMode == VehicleGpsMode.deviceLive
                                    ? Icons.gps_fixed
                                    : Icons.location_on,
                                size: 20,
                              ),
                              label: Text(
                                vehicle.gpsMode == VehicleGpsMode.deviceLive
                                    ? 'Track Vehicle Live'
                                    : 'View Vehicle Location',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    vehicle.gpsMode == VehicleGpsMode.deviceLive
                                    ? Colors.green
                                    : Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

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
                            if (b.otp != null &&
                                b.status != BookingStatus.completed) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'OTP: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
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
                          icon: const Icon(
                            Icons.copy,
                            size: 20,
                            color: Colors.blue,
                          ),
                          tooltip: 'Copy OTP',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: b.otp!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('OTP copied to clipboard'),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                // After end time: user can extend or request refund
                if (bookingSlot != null) ...[
                  const SizedBox(height: 6),
                  _AutoRefundSection(
                    booking: b,
                    slot: bookingSlot,
                    isRiderView: isRiderView,
                  ),
                ],
                // Refund section ? shown regardless of bookingSlot
                if (bookingSlot == null &&
                    b.tripEndTime != null &&
                    DateTime.now().isAfter(b.tripEndTime!)) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_off_outlined,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Trip time over',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          await BookingRepository.instance.markRefunded(b.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('? Refunded'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.currency_rupee,
                              size: 12,
                              color: Colors.red[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Refund',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                // Trip Media — show if active OR if media already exists
                if (b.status == BookingStatus.accepted ||
                    b.status == BookingStatus.completed ||
                    b.status == BookingStatus.pending ||
                    b.status == BookingStatus.inProgress ||
                    !b.tripMedia.isEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  TripMediaWidget(
                    booking: b,
                    isProvider: !isRiderView,
                    onUpdated: (updated) async {
                      await BookingRepository.instance.updateTripMedia(
                        b.id,
                        updated,
                      );
                    },
                  ),
                ],
                // Customer review button - ALWAYS check GPS verification
                if (b.customerCanReview) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      final currentUser = AuthRepository.instance.currentUser;
                      if (currentUser == null) return;

                      // Check if review is blocked
                      if (b.reviewBlockedReason != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('⚠️ ${b.reviewBlockedReason}'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

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
                              userName:
                                  b.providerName ?? _providerName(b.providerId),
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
                            revieweeName:
                                b.providerName ?? _providerName(b.providerId),
                            type: ReviewType.userToProvider,
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      ReviewRepository.instance.hasReviewed(
                            bookingId: b.id,
                            reviewerId:
                                AuthRepository.instance.currentUser?.id ?? '',
                          )
                          ? Icons.star
                          : Icons.star_border,
                      size: 18,
                    ),
                    label: Text(
                      ReviewRepository.instance.hasReviewed(
                            bookingId: b.id,
                            reviewerId:
                                AuthRepository.instance.currentUser?.id ?? '',
                          )
                          ? 'View Reviews'
                          : 'Leave Review',
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
                else if (bookingSlot != null &&
                    DateTime.now().isAfter(bookingSlot.endTime) &&
                    !b.otpVerified)
                  // After end time: OTP entry for provider
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.timer_off_outlined,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Trip time over - Ask extension from user',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
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
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter 6-digit OTP'),
                                  ),
                                );
                                return;
                              }
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                              try {
                                // TODO: Stripe payment verification - disabled for now
                                /*
                                if (b.paymentHeldInEscrow &&
                                    b.stripePaymentIntentId != null) {
                                  final success = await StripeService.instance
                                      .verifyOtpAndRelease(
                                        bookingId: b.id,
                                        otp: otpText,
                                      );
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  if (success) {
                                    await BookingRepository.instance
                                        .updateBookingAfterPayment(
                                          bookingId: b.id,
                                          status: BookingStatus.completed,
                                          otpVerified: true,
                                        );
                                    if (context.mounted) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('? Payment released!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      _promptForReview(
                                        context,
                                        b,
                                        isProvider: true,
                                      );
                                    }
                                  } else {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Invalid OTP'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } else {
                                */
                                {
                                  // Use repository verifyOtp (has local OTP fallback)
                                  final success = await BookingRepository
                                      .instance
                                      .verifyOtp(bookingId: b.id, otp: otpText);
                                  if (!context.mounted) return;
                                  Navigator.pop(context);

                                  if (success) {
                                    await BookingRepository.instance
                                        .updateBookingAfterPayment(
                                          bookingId: b.id,
                                          status: BookingStatus.completed,
                                          otpVerified: true,
                                        );
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '? OTP verified! Trip completed.',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    if (context.mounted) {
                                      _promptForReview(
                                        context,
                                        b,
                                        isProvider: true,
                                      );
                                    }
                                  } else {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Incorrect OTP. Please try again.',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (!context.mounted) return;
                                Navigator.pop(context);
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
                    ],
                  )
                else if (!b.otpVerified)
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
                              const SnackBar(
                                content: Text('Please enter 6-digit OTP'),
                              ),
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
                            // TODO: Stripe payment verification - disabled for now
                            /*
                            // If payment is held in escrow, verify with Stripe backend
                            if (b.paymentHeldInEscrow &&
                                b.stripePaymentIntentId != null) {
                              final success = await StripeService.instance
                                  .verifyOtpAndRelease(
                                    bookingId: b.id,
                                    otp: otpText,
                                  );

                              if (!context.mounted) return;
                              Navigator.pop(context); // Close loading

                              if (success) {
                                // Update local booking status
                                await BookingRepository.instance
                                    .updateBookingAfterPayment(
                                      bookingId: b.id,
                                      status: BookingStatus.completed,
                                      otpVerified: true,
                                    );

                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '? Payment released! Funds transferred to your account.',
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 4),
                                  ),
                                );

                                // Prompt for review
                                if (context.mounted) {
                                  _promptForReview(
                                    context,
                                    b,
                                    isProvider: true,
                                  );
                                }
                              } else {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Invalid OTP. Please try again.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } else {
                            */
                            {
                              // Use repository verifyOtp (has local OTP fallback)
                              final success = await BookingRepository.instance
                                  .verifyOtp(bookingId: b.id, otp: otpText);

                              if (!context.mounted) return;
                              Navigator.pop(context);

                              if (success) {
                                await BookingRepository.instance
                                    .updateBookingAfterPayment(
                                      bookingId: b.id,
                                      status: BookingStatus.completed,
                                      otpVerified: true,
                                    );

                                if (b.securityDeposit != null &&
                                    b.securityDeposit! > 0) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '? OTP verified! Security deposit of ${AppPreferences.instance.formatMoney(b.securityDeposit!.toInt())} refunded to user.',
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                } else {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '? OTP verified! Trip completed.',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }

                                if (context.mounted) {
                                  _promptForReview(
                                    context,
                                    b,
                                    isProvider: true,
                                  );
                                }
                              } else {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Incorrect OTP. Please try again.',
                                    ),
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
                // Provider review button - ALWAYS check GPS verification
                if (!isRiderView && b.providerCanReview) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      final currentUser = AuthRepository.instance.currentUser;
                      if (currentUser == null) return;

                      // Check if review is blocked
                      if (b.reviewBlockedReason != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('⚠️ ${b.reviewBlockedReason}'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

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
                            reviewerId:
                                AuthRepository.instance.currentUser?.id ?? '',
                          )
                          ? Icons.star
                          : Icons.star_border,
                      size: 18,
                    ),
                    label: Text(
                      ReviewRepository.instance.hasReviewed(
                            bookingId: b.id,
                            reviewerId:
                                AuthRepository.instance.currentUser?.id ?? '',
                          )
                          ? 'View Reviews'
                          : 'Leave Review',
                    ),
                  ),
                ],
                // Trip Media for Provider — show if active OR if media already exists
                if (b.status == BookingStatus.accepted ||
                    b.status == BookingStatus.completed ||
                    b.status == BookingStatus.pending ||
                    b.status == BookingStatus.inProgress ||
                    !b.tripMedia.isEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  TripMediaWidget(
                    booking: b,
                    isProvider: !isRiderView,
                    onUpdated: (updated) async {
                      await BookingRepository.instance.updateTripMedia(
                        b.id,
                        updated,
                      );
                    },
                  ),
                ],
              ],
              if (isRiderView) ...[const SizedBox(height: 12)],

              // -- Expired state ----------------------------------------
              if (b.status == BookingStatus.expired) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.timer_off,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Booking Expired',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isRiderView
                            ? 'The service was not completed within the deadline. Your payment has been refunded.'
                            : 'This booking expired ? trip not completed within deadline. Payment refunded to customer.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],

              // -- Disputed state ---------------------------------------
              if (b.status == BookingStatus.disputed) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.deepOrange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.gavel,
                            size: 16,
                            color: Colors.deepOrange[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Dispute Raised',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange[700],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This booking is under review by support. Payment is held until resolved.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepOrange[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── DISPUTE FEATURE DISABLED FOR LAUNCH ─────────────────────────
              // Decision: Launch without disputes (self-healing system is enough)
              // See: WHY_NO_DISPUTES_NEEDED.md
              // TODO: Re-enable after 3-6 months if support tickets show it's needed
              //
              // -- Raise dispute (expired bookings - both customer and provider can dispute) --
              // if (b.status == BookingStatus.expired) ...[
              //   const SizedBox(height: 10),
              //   OutlinedButton.icon(
              //     onPressed: () => _showRaiseDisputeDialog(context, b),
              //     icon: const Icon(Icons.report_problem_outlined, size: 16),
              //     label: Text(
              //       isRiderView ? 'Raise a Dispute' : 'Contest Expiry',
              //       style: const TextStyle(fontSize: 13),
              //     ),
              //     style: OutlinedButton.styleFrom(
              //       foregroundColor: Colors.deepOrange,
              //       side: const BorderSide(color: Colors.deepOrange),
              //       padding:
              //           const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              //       minimumSize: Size.zero,
              //       tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              //     ),
              //   ),
              // ],
            ],
          ],
        ),
      ),
    );
  }

  static String _statusLabel(BookingStatus status) => status.label;

  // Removed _showRaiseDisputeDialog - disputes are now handled via AI chat directly

  static Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.accepted:
      case BookingStatus.confirmed:
        return Colors.green;
      case BookingStatus.inProgress:
        return Colors.teal;
      case BookingStatus.completed:
        return Colors.blue;
      case BookingStatus.rejected:
      case BookingStatus.noShow:
        return Colors.red;
      case BookingStatus.refunded:
      case BookingStatus.cancelledByCustomer:
      case BookingStatus.cancelledByProvider:
      case BookingStatus.cancelled:
        return Colors.purple;
      case BookingStatus.disputed:
        return Colors.deepOrange;
      case BookingStatus.expired:
        return Colors.grey;
    }
  }

  static String _fmtDateTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $h:$m';
  }

  String _providerName(String providerId) {
    // Try ProfileNameRegistry first
    final registryName = ProfileNameRegistry.instance.getNameForUser(
      providerId,
    );
    if (registryName != null && registryName.isNotEmpty) return registryName;
    // Try vehicle repos
    try {
      final vehicle = VehicleRepository.instance.allVehicles.firstWhere(
        (v) => v.userId == providerId,
      );
      return vehicle.userName;
    } catch (_) {
      try {
        final vehicle = CustomerVehicleRepository.instance.allVehicles
            .firstWhere((v) => v.userId == providerId);
        return vehicle.userName;
      } catch (_) {
        return 'Provider';
      }
    }
  }

  String _providerPhone(String providerId) {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser != null &&
        (providerId == currentUser.id || providerId == 'user1')) {
      return ProfileRepository.instance.profile.value.phone ??
          '+91 90000 00000';
    }
    return '+91 90000 00000';
  }

  void _promptForReview(
    BuildContext context,
    Booking booking, {
    required bool isProvider,
  }) {
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
      return ProfileRepository.instance.profile.value.phone ??
          '+91 90000 00000';
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
                onPressed: _extraHours > 1
                    ? () => setState(() => _extraHours--)
                    : null,
              ),
              Text(
                '$_extraHours hr${_extraHours > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _extraHours < 12
                    ? () => setState(() => _extraHours++)
                    : null,
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Extension request sent to provider (+$_extraHours hr${_extraHours > 1 ? 's' : ''})',
                ),
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
    // Listen to booking updates
    return ValueListenableBuilder<List<Booking>>(
      valueListenable: BookingRepository.instance.bookings,
      builder: (context, bookings, _) {
        // Get the latest booking status
        final booking = bookings.firstWhere(
          (b) => b.id == widget.booking.id,
          orElse: () => widget.booking,
        );

        final now = DateTime.now();
        final hasEnded = now.isAfter(widget.slot.endTime);

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

        // No-show detection: lease + deposit + OTP never verified
        final deposit = booking.securityDeposit ?? 0.0;
        final isNoShow =
            !booking.otpVerified &&
            deposit > 0 &&
            widget.slot.serviceType == ServiceType.lease;

        if (isNoShow) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Colors.orange[700],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.isRiderView
                        ? 'No-show: ride price will be refunded. Security deposit kept by provider.'
                        : 'Customer no-show: security deposit (${AppPreferences.instance.formatMoney(deposit.toInt())}) kept.',
                    style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                  ),
                ),
              ],
            ),
          );
        }

        // Provider view: Show refund option
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
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  await BookingRepository.instance.markRefunded(booking.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('💰 Refunded'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.currency_rupee,
                      size: 12,
                      color: Colors.red[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Refund',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
                await BookingRepository.instance.markRefunded(booking.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('💰 Refunded'),
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
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Standalone time banner using only booking fields (no Slot needed).
/// Shows trip schedule, deadline countdown, and overdue warning.
class _BookingTimeBanner extends StatefulWidget {
  final Booking booking;
  const _BookingTimeBanner({required this.booking});

  @override
  State<_BookingTimeBanner> createState() => _BookingTimeBannerState();
}

class _BookingTimeBannerState extends State<_BookingTimeBanner> {
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
    if (d.isNegative || d == Duration.zero) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _fmtDate(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month} $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final now = DateTime.now();

    if (b.status.isTerminal) return const SizedBox.shrink();

    final rows = <Widget>[];

    // Trip schedule
    if (b.tripStartTime != null && b.tripEndTime != null) {
      final IconData icon;
      final String label;
      final Color color;

      if (now.isBefore(b.tripStartTime!)) {
        final diff = b.tripStartTime!.difference(now);
        icon = Icons.schedule;
        label = 'Starts in ${_fmt(diff)}  (${_fmtDate(b.tripStartTime!)})';
        color = Colors.blue;
      } else if (now.isBefore(b.tripEndTime!)) {
        final diff = b.tripEndTime!.difference(now);
        icon = Icons.play_circle_outline;
        label = 'In progress ? ends in ${_fmt(diff)}';
        color = Colors.green;
      } else {
        icon = Icons.timer_off_outlined;
        label = 'Trip time ended  (${_fmtDate(b.tripEndTime!)})';
        color = Colors.grey;
      }
      rows.add(_timeRow(icon, label, color));
    }

    // Deadline
    if (b.deadlineTime != null) {
      if (b.isOverdue) {
        rows.add(
          _timeRow(
            Icons.warning_amber_rounded,
            'OVERDUE ? deadline was ${_fmtDate(b.deadlineTime!)}',
            Colors.red,
            bold: true,
          ),
        );
      } else {
        final remaining = b.deadlineTime!.difference(now);
        final isUrgent = remaining.inHours < 1;
        rows.add(
          _timeRow(
            Icons.hourglass_bottom,
            'Deadline in ${_fmt(remaining)}  (${_fmtDate(b.deadlineTime!)})',
            isUrgent ? Colors.orange : Colors.grey.shade600,
            bold: isUrgent,
          ),
        );
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _timeRow(
    IconData icon,
    String label,
    Color color, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class CountdownText extends StatefulWidget {
  final DateTime endTime;
  final DateTime? startTime;
  final String? bookingId;

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
      return Text(
        'Auto-refunded',
        style: TextStyle(fontSize: 11, color: Colors.red[400]),
      );
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

    // In progress ? counting to end time (no text, just return empty)
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
          // Show all bookings (not just completed) for better visibility
          final userBookings = allBookings
              .where((b) => b.userId == currentUser.id)
              .toList();

          // Separate completed vs pending
          final completedBookings = userBookings
              .where((b) => b.status == BookingStatus.completed)
              .toList();
          final pendingBookings = userBookings
              .where(
                (b) =>
                    b.status == BookingStatus.pending ||
                    b.status == BookingStatus.accepted ||
                    b.status == BookingStatus.confirmed ||
                    b.status == BookingStatus.inProgress,
              )
              .toList();

          // Calculate total spending (completed only for accurate spending)
          final totalSpending = completedBookings.fold<double>(
            0,
            (sum, booking) => sum + booking.price,
          );

          // Calculate total committed (pending + completed)
          final totalCommitted = userBookings.fold<double>(
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

          for (var booking in completedBookings) {
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
                        '${completedBookings.length} completed trips',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      if (pendingBookings.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '+ ${AppPreferences.instance.currencySymbol}${(totalCommitted - totalSpending).toStringAsFixed(2)} pending (${pendingBookings.length} trips)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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
                  child: const Icon(
                    Icons.payment,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot != null
                            ? '${slot.serviceType.displayName} Service'
                            : 'Service',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${booking.createdAt.day}/${booking.createdAt.month}/${booking.createdAt.year}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                ValueListenableBuilder<String>(
                  valueListenable: AppPreferences.instance.currencyCode,
                  builder: (context, _, _) {
                    return Text(
                      AppPreferences.instance.formatMoney(
                        booking.price.toInt(),
                      ),
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
              _BookingTimeBanner(booking: booking),
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
                    Icon(
                      Icons.person_outline,
                      size: 100,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Login to access your profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
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
                        // Rating Display
                        if (info.providerTotalReviews > 0 ||
                            info.customerTotalReviews > 0) ...[
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              if (info.providerTotalReviews > 0)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.business,
                                      size: 14,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.star,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      info.providerRating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '(${info.providerTotalReviews})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              if (info.customerTotalReviews > 0)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      size: 14,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.star,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      info.customerRating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '(${info.customerTotalReviews})',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
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
                              color: _isCustomerMode
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
                              color: !_isCustomerMode
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
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help & Support'),
                onTap: () async {
                  // Show support dialog with contact email
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.support_agent, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Help & Support'),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Need help? We\'re here for you!',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          const Text('📧 Email Support:'),
                          const SizedBox(height: 4),
                          SelectableText(
                            'vaultwheelsin@gmail.com',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '⏱️ Response Time: Within 24 hours',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                        FilledButton.icon(
                          onPressed: () async {
                            final email = 'vaultwheelsin@gmail.com';
                            final subject = 'Support Request';
                            final uri = Uri(
                              scheme: 'mailto',
                              path: email,
                              query: 'subject=$subject',
                            );
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not open email app. Please email: vaultwheelsin@gmail.com',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.email),
                          label: const Text('Send Email'),
                        ),
                      ],
                    ),
                  );
                },
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
            final double sheetHeight = constraints.maxHeight < 420
                ? constraints.maxHeight * 0.95
                : 400;
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
                        child: Text(
                          'Create Post',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _isCustomerMode
                              ? 'Select a vehicle you need, then create posts'
                              : 'Select your vehicle, then create posts',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
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
                                builder: (_) => VehicleListScreen(
                                  isUserMode: _isCustomerMode,
                                ),
                              ),
                            );
                          },
                          icon: Icon(
                            _isCustomerMode
                                ? Icons.search
                                : Icons.directions_car,
                          ),
                          label: Text(
                            _isCustomerMode
                                ? 'Choose Needed Vehicle'
                                : 'Choose Your Vehicle',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isCustomerMode
                                ? Colors.orange
                                : Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
  String? _paymentType;
  SubscriptionPlan? _activatedPlan;
  bool _loading = true;
  Booking? _booking;
  SlotEntry? _slotEntry;
  bool _isProcessing = false; // Prevent double processing

  @override
  void initState() {
    super.initState();
    // Defer the async work to avoid build conflicts
    Future.microtask(() => _extractBookingIdAndLoadDetails());
  }

  Map<String, String> _routeQueryParameters() {
    try {
      final uri = Uri.base;
      if (uri.queryParameters.isNotEmpty) return uri.queryParameters;

      final queryStart = uri.fragment.indexOf('?');
      if (queryStart < 0 || queryStart == uri.fragment.length - 1) {
        return const {};
      }
      return Uri.splitQueryString(uri.fragment.substring(queryStart + 1));
    } catch (e) {
      debugPrint('Error parsing URL parameters: $e');
      return const {};
    }
  }

  Future<void> _extractBookingIdAndLoadDetails() async {
    if (_isProcessing || !mounted) return; // Prevent re-entry and check mounted
    _isProcessing = true;

    try {
      // Extract booking_id from URL query parameters
      final params = _routeQueryParameters();
      debugPrint('🔍 Payment success params: $params');

      _bookingId = params['booking_id'];
      _paymentType = params['type'];
      final planName = params['plan'];
      final sessionId = params['session_id']; // Stripe session ID
      final slotId = params['slot_id'];
      final postId = params['post_id'];
      final providerId = params['provider_id'];

      // ─────────────────────────────────────────────────────────────────────
      // If we have a Stripe session but no booking, create the booking now
      // ─────────────────────────────────────────────────────────────────────
      if (sessionId != null &&
          _bookingId == null &&
          (slotId != null || postId != null)) {
        debugPrint('📦 Creating booking from Stripe session: $sessionId');

        final currentUser = AuthRepository.instance.currentUser;
        if (currentUser != null && providerId != null) {
          try {
            // Get slot details to create booking
            final slot = SlotRepository.instance.allSlots
                .where((s) => s.slot.id == slotId)
                .firstOrNull
                ?.slot;

            if (slot != null) {
              // Create booking with Stripe payment intent
              final booking = await BookingRepository.instance.createBooking(
                slotId: slotId!,
                providerId: providerId,
                providerName: slot.providerName,
                userId: currentUser.id,
                defaultCapacity: slot.capacity,
                price: slot.price, // double, not int
                stripePaymentIntentId:
                    sessionId, // Use session ID as payment intent
                countdownEndTime: DateTime.now().add(const Duration(hours: 1)),
                paymentMethod: 'stripe',
                // slot details
                serviceType: slot.serviceType,
                postMode: slot.postMode,
                bookingMode: slot.bookingMode.name == 'full'
                    ? booking_types.BookingMode.full
                    : booking_types.BookingMode.shared,
                vehicleId: slot.vehicleId,
                slotStartTime: slot.startTime,
                slotEndTime: slot.endTime,
                slotCapacity: slot.capacity,
                pickupOption: slot.pickupOption.name,
                withOperator: slot.withOperator,
                // location
                routeType: slot.slotType.name == 'fromTo'
                    ? 'from_to'
                    : 'base_range',
                fromAddress: slot.fromLocation?.split('|').first,
                toAddress: slot.toLocation?.split('|').first,
                baseAddress: slot.baseLocation?.split('|').first,
                rangeKm: slot.radius,
              );

              if (booking != null) {
                _bookingId = booking.id;
                debugPrint(
                  '✅ Created booking ${booking.id} from Stripe payment',
                );
              }
            }
          } catch (e) {
            debugPrint('❌ Error creating booking from Stripe session: $e');
          }
        }
      }

      if (_paymentType == 'subscription' && planName != null) {
        _activatedPlan = SubscriptionPlan.values.firstWhere(
          (p) => p.name == planName.toLowerCase(),
          orElse: () => SubscriptionPlan.basic,
        );
        if (_activatedPlan != SubscriptionPlan.basic) {
          // Save to local preferences (for quick access)
          await AppPreferences.instance.setSubscriptionPlan(_activatedPlan!);

          // ✅ CRITICAL: Save to backend database (source of truth)
          try {
            final expiresAt = DateTime.now().add(const Duration(days: 30));
            final paymentId =
                params['payment_id'] ??
                params['razorpay_payment_id'] ??
                sessionId ??
                'unknown';

            await ProfileRepository.instance.updateSubscription(
              plan: _activatedPlan!.name,
              expiresAt: expiresAt,
              paymentId: paymentId,
            );

            debugPrint(
              '✅ Subscription saved to backend: ${_activatedPlan!.name}',
            );
          } catch (e) {
            debugPrint('❌ Failed to save subscription to backend: $e');
            // Don't fail the whole flow, but log the error
          }
        }
      }

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

      // Safety check: only setState if widget is still mounted
    } catch (e, stackTrace) {
      debugPrint('❌ Error in payment success screen: $e');
      debugPrint('Stack trace: $stackTrace');
      // Error captured in debug logs
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                child: const Icon(Icons.check, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Payment Successful!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),
              Text(
                _paymentType == 'subscription'
                    ? '${(_activatedPlan?.name ?? 'premium').toUpperCase()} plan activated.'
                    : 'Your booking has been confirmed.',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
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
                          const Icon(
                            Icons.confirmation_number,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Booking ID',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey,
                            ),
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
                            const Icon(
                              Icons.event_available,
                              size: 16,
                              color: Colors.grey,
                            ),
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
                            const Icon(
                              Icons.directions_car,
                              size: 16,
                              color: Colors.grey,
                            ),
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
              if (_paymentType != 'subscription') ...[
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
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
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
    var params = uri.queryParameters;
    if (params.isEmpty) {
      final queryStart = uri.fragment.indexOf('?');
      if (queryStart >= 0 && queryStart < uri.fragment.length - 1) {
        params = Uri.splitQueryString(uri.fragment.substring(queryStart + 1));
      }
    }
    _bookingId = params['booking_id'];
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                child: const Icon(Icons.close, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Payment Cancelled',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your payment was not completed.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              if (_bookingId != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'The booking has been cancelled and no charges were made.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
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
