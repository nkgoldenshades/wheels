import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../vehicle/vehicle_list_screen.dart';
import '../../models/service_type.dart';
import '../../models/slot_type.dart';
import '../../models/post_mode.dart';
import '../../models/demand_plan.dart';
import '../../services/app_preferences.dart';
import '../../services/auth_repository.dart';
import '../../services/profile_repository.dart';
import '../../services/payment_service.dart';
import '../../models/vehicle.dart';
import '../../models/slot.dart';
import '../../models/pickup_mode.dart';
import '../../services/slot_repository.dart';
import '../../services/customer_slot_repository.dart';
import '../../services/content_filter_service.dart';
import '../../controllers/seat_layout_controller.dart';
import '../../models/seat_layout.dart';
import '../../models/simple_seat_layout.dart'; // Add SimpleSeatLayout import
import '../../screens/add_flow/seat_layout_builder_screen.dart';
import '../../services/seat_layout_repository.dart';
import '../../widgets/location_autocomplete_field.dart';
import '../../services/location_autocomplete_service.dart';
import '../../utils/timezone_utils.dart';
import '../../widgets/post_media_upload_widget.dart';

class CreatePostScreen extends StatefulWidget {
  final ServiceType serviceType;
  final Vehicle? initialVehicle;
  final bool isUserMode;

  const CreatePostScreen({
    super.key,
    required this.serviceType,
    this.initialVehicle,
    this.isUserMode = false,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  // Vehicle
  Vehicle? _selectedVehicle;

  // Slot type
  SlotType _slotType = SlotType.fromTo;

  // Location
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _baseController = TextEditingController();
  final _radiusController = TextEditingController(text: '10');

  LocationSuggestion? _fromSuggestion;
  LocationSuggestion? _toSuggestion;
  LocationSuggestion? _baseSuggestion;

  // Time
  DateTime? _startTime;
  DateTime? _endTime;

  // Price and capacity
  final _priceController = TextEditingController();
  int _capacity = 1;

  // Parcel dimensions (only for parcel service)
  final _maxWeightController = TextEditingController();
  final _maxLengthController = TextEditingController();
  final _maxWidthController = TextEditingController();
  final _maxHeightController = TextEditingController();

  // Lease fields (only for lease service)
  final _securityDepositController = TextEditingController();
  String _fuelPolicy = 'Full-to-Full';
  bool _insuranceIncluded = false;
  final _leaseTermsController = TextEditingController();

  // Operator availability
  bool _withOperator = false;

  // Seating mode: simple (price+capacity) or layout-based
  bool _useSimpleSeating = true;

  // Post mode: instant, wait_for_full, full_vehicle
  PostMode _postMode = PostMode.instant;

  // Wait for full deadline (manual input)
  final _deadlineHoursController = TextEditingController(text: '2');
  final _deadlineMinutesController = TextEditingController(text: '0');

  // Pickup mode
  PickupMode _pickupMode = PickupMode.customerPickup;

  // Notes
  final _notesController = TextEditingController();

  // Post Media
  List<String> _postMediaUrls = []; // Store media URLs for saving

  // Demand plan and rating requirements
  DemandPlan _demandPlan = DemandPlan.basic;
  double? _minRatings;
  int? _minNoRatings;

  // Working mode (only for working service)
  String _workingMode = 'On-site';

  bool _isPosting = false;

  String? _seatLayoutOwnerId;
  SimpleSeatLayout? _builtSeatLayout; // Store the actual layout structure

  bool get _hasSeatLayoutSeats {
    // Check in-memory SeatLayoutRepository first
    final ownerId = _seatLayoutOwnerId;
    if (ownerId != null) {
      final layout = SeatLayoutRepository.instance.getLayout(ownerId);
      final seatCount =
          layout?.cells.values.where((c) => c.type == CellType.seat).length ??
          0;
      if (seatCount > 0) return true;
    }
    // Fallback: check _builtSeatLayout JSON (persists across hot reloads on web)
    return (_builtSeatLayout?.layout.where((item) => !item.isGap).isNotEmpty) ??
        false;
  }

  @override
  void initState() {
    super.initState();
    _selectedVehicle = widget.initialVehicle;
    _setDefaultTimes();

    _fromController.addListener(() {
      final s = _fromSuggestion;
      if (s == null) return;
      if (!_isControllerTextStillForSuggestion(_fromController.text, s)) {
        _fromSuggestion = null;
      }
    });
    _toController.addListener(() {
      final s = _toSuggestion;
      if (s == null) return;
      if (!_isControllerTextStillForSuggestion(_toController.text, s)) {
        _toSuggestion = null;
      }
    });
    _baseController.addListener(() {
      final s = _baseSuggestion;
      if (s == null) return;
      if (!_isControllerTextStillForSuggestion(_baseController.text, s)) {
        _baseSuggestion = null;
      }
    });
  }

  void _setDefaultTimes() {
    final now = DateTime.now();
    // Use Duration addition to handle day overflow correctly
    final start = now.add(const Duration(hours: 1));
    _startTime = DateTime(start.year, start.month, start.day, start.hour, 0);
    final end = _startTime!.add(const Duration(hours: 8));
    _endTime = DateTime(end.year, end.month, end.day, end.hour, 0);
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _baseController.dispose();
    _radiusController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    _deadlineHoursController.dispose();
    _deadlineMinutesController.dispose();
    _maxWeightController.dispose();
    _maxLengthController.dispose();
    _maxWidthController.dispose();
    _maxHeightController.dispose();
    _securityDepositController.dispose();
    _leaseTermsController.dispose();
    super.dispose();
  }

  Future<void> _selectTime({required bool isStart}) async {
    // Fix: Handle null values safely (don't force-unwrap)
    final current = isStart
        ? (_startTime ?? DateTime.now().add(const Duration(hours: 1)))
        : (_endTime ??
              _startTime ??
              DateTime.now().add(const Duration(hours: 9)));
    final now = DateTime.now();

    // Get timezone for the relevant location
    String tzLabel = TimezoneUtils.getTimezoneAbbreviation();
    final suggestion = isStart
        ? _fromSuggestion
        : (_toSuggestion ?? _fromSuggestion ?? _baseSuggestion);
    if (suggestion != null && (suggestion.lat != 0 || suggestion.lon != 0)) {
      tzLabel = await TimezoneUtils.getTimezoneFromCoords(
        suggestion.lat,
        suggestion.lon,
      );
    }

    // Show timezone hint to user before picking
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.schedule, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                'Setting ${isStart ? 'start' : 'end'} time in $tzLabel timezone',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Step 1: Pick date
    if (!mounted) return;
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: current.isBefore(now) ? now : current,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Select date ($tzLabel)',
    );
    if (pickedDate == null || !mounted) return;

    // Step 2: Pick time
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      helpText: 'Select time ($tzLabel)',
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (pickedTime == null) return;

    final newDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Validate that the selected time is not in the past
    if (newDateTime.isBefore(now)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot select a time in the past'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      if (isStart) {
        _startTime = newDateTime;
        if (_endTime != null && _endTime!.isBefore(_startTime!)) {
          _endTime = _startTime!.add(const Duration(hours: 2));
        }
      } else {
        _endTime = newDateTime;
      }
    });
  }

  String _formatLocationValue({
    required String typedText,
    required LocationSuggestion? suggestion,
  }) {
    if (suggestion != null) {
      final label = _getShortName(suggestion.displayName);
      final geo = suggestion.geo;
      final coords = '${suggestion.lat},${suggestion.lon}';
      if (geo != null) {
        final keywords = [
          geo.district ?? geo.stateDistrict,
          geo.state,
          geo.postcode,
          geo.country,
          geo.countryCode?.toUpperCase(),
        ].whereType<String>().where((s) => s.isNotEmpty).join(',');
        return '$label|$coords|$keywords';
      }
      return '$label|$coords';
    }
    return typedText;
  }

  String _getShortName(String displayName) {
    final parts = displayName.split(',');
    if (parts.length >= 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    return parts[0].trim();
  }

  /// Determine currency type based on user's connected bank account
  /// Uses the bankCurrency field from user profile
  String _determineCurrencyType() {
    final currentUser = ProfileRepository.instance.profile.value;

    // Use the currency of the connected bank account
    final bankCurrency = currentUser.bankCurrency;

    if (bankCurrency != null && bankCurrency.isNotEmpty) {
      // Return the currency from the user's bank account
      return bankCurrency.toUpperCase();
    }

    // Fallback: check payment provider
    final paymentProvider = currentUser.paymentProvider;

    if (paymentProvider == 'razorpay') {
      // Razorpay only supports INR
      return 'INR';
    } else if (paymentProvider == 'stripe') {
      // Stripe default to USD
      return 'USD';
    }

    // Default to INR if no bank currency or payment provider
    return 'INR';
  }

  Future<LocationSuggestion?> _maybeGeocode(String text) async {
    if (text.isEmpty) return null;
    if (text.length < 3) return null;

    try {
      final results = await LocationAutocompleteService.instance
          .searchLocations(text);
      if (results.isNotEmpty) return results.first;
    } catch (_) {}
    return null;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    double toRad(double deg) => deg * (3.141592653589793 / 180.0);
    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);
    final a =
        (dLat / 2) * (dLat / 2) +
        toRad(lat1).abs() * toRad(lat2).abs() * (dLon / 2) * (dLon / 2);
    return r * 2 * (a < 1 ? a : 1);
  }

  bool _isControllerTextStillForSuggestion(
    String controllerText,
    LocationSuggestion suggestion,
  ) {
    final text = controllerText.trim();
    if (text.isEmpty) return false;

    if (suggestion.type.toLowerCase() == 'current') {
      return text == _getShortName(suggestion.displayName);
    }

    final dn = suggestion.displayName.trim();
    if (text == dn) return true;

    final lowerText = text.toLowerCase();
    final lowerDn = dn.toLowerCase();
    return lowerDn.contains(lowerText);
  }

  Uri? _buildMapsUri({
    required String typedText,
    required LocationSuggestion? suggestion,
  }) {
    if (suggestion != null && (suggestion.lat != 0 || suggestion.lon != 0)) {
      return Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${suggestion.lat},${suggestion.lon}',
      );
    }
    final query = typedText.trim();
    if (query.isEmpty) return null;
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
  }

  Future<void> _openInMaps({
    required String typedText,
    required LocationSuggestion? suggestion,
  }) async {
    final uri = _buildMapsUri(typedText: typedText, suggestion: suggestion);
    if (uri == null) {
      _showError('Please enter a location first');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showError('Unable to open maps');
    }
  }

  bool _validateForm() {
    if (_selectedVehicle == null) {
      _showError('Please select a vehicle');
      return false;
    }

    if (_slotType == SlotType.fromTo) {
      if (_fromController.text.trim().isEmpty ||
          _toController.text.trim().isEmpty) {
        _showError('Please enter both from and to locations');
        return false;
      }
    } else {
      if (_baseController.text.trim().isEmpty) {
        _showError('Please enter base location');
        return false;
      }
    }

    if (_startTime == null || _endTime == null) {
      _showError('Please select time range');
      return false;
    }

    // If _builtSeatLayout has items, we are in layout mode regardless of the toggle state
    final effectivelyLayoutMode =
        !_useSimpleSeating ||
        (_builtSeatLayout?.layout.where((item) => !item.isGap).isNotEmpty ??
            false);

    debugPrint(
      '🔍 Validate: _useSimpleSeating=$_useSimpleSeating, effectivelyLayoutMode=$effectivelyLayoutMode, builtSeats=${_builtSeatLayout?.layout.length}',
    );

    if (!effectivelyLayoutMode) {
      if (_priceController.text.trim().isEmpty) {
        _showError('Please enter price');
        return false;
      }
    } else {
      final ownerId = _seatLayoutOwnerId;
      final layout = ownerId == null
          ? null
          : SeatLayoutRepository.instance.getLayout(ownerId);
      final seats =
          layout?.cells.values.where((c) => c.type == CellType.seat).toList() ??
          [];

      // Fallback: check _builtSeatLayout JSON (handles hot reload / web refresh
      // where SeatLayoutRepository in-memory cache is cleared)
      final builtSeats =
          _builtSeatLayout?.layout.where((item) => !item.isGap).toList() ?? [];

      if (seats.isEmpty && builtSeats.isEmpty) {
        _showError('Please add a seat layout with at least 1 seat');
        return false;
      }

      // Validate price from JSON (builtSeats) — covers all service types in layout mode
      for (final item in builtSeats) {
        if (item.price <= 0) {
          _showError(
            'All seats/compartments must have a price set in the layout',
          );
          return false;
        }
      }
      // Also check in-memory seats if JSON not available
      if (builtSeats.isEmpty) {
        for (final seat in seats) {
          if (seat.price == null || seat.price! <= 0) {
            _showError('All seats must have a price set');
            return false;
          }
        }
      }

      // For parcel layout: also check dimensions
      if (widget.serviceType == ServiceType.parcel) {
        for (final seat in seats) {
          final name = seat.seatName ?? '';
          if (!name.contains('L:') ||
              !name.contains('B:') ||
              !name.contains('H:') ||
              !name.contains('W:')) {
            _showError(
              'All compartments must have dimensions filled (Length, Breadth, Height, Weight)',
            );
            return false;
          }
        }
      }
    }

    // Parcel: max dimensions are mandatory so customers know what fits.
    // In layout mode, dimensions are stored per-compartment — skip top-level check.
    if (widget.serviceType == ServiceType.parcel && _useSimpleSeating) {
      final weight = double.tryParse(_maxWeightController.text.trim());
      final length = double.tryParse(_maxLengthController.text.trim());
      final width = double.tryParse(_maxWidthController.text.trim());
      final height = double.tryParse(_maxHeightController.text.trim());

      if (weight == null || weight <= 0) {
        _showError('Please enter max parcel weight (kg)');
        return false;
      }
      if (length == null || length <= 0) {
        _showError('Please enter max parcel length (cm)');
        return false;
      }
      if (width == null || width <= 0) {
        _showError('Please enter max parcel width (cm)');
        return false;
      }
      if (height == null || height <= 0) {
        _showError('Please enter max parcel height (cm)');
        return false;
      }
    }

    // Security deposit is optional for all service types
    // If entered, must be > 0
    final depositText = _securityDepositController.text.trim();
    if (depositText.isNotEmpty) {
      final deposit = double.tryParse(depositText);
      if (deposit == null || deposit <= 0) {
        _showError('Security deposit must be a positive number');
        return false;
      }
    }

    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _fmtTime24(DateTime d) {
    return TimezoneUtils.formatShortDateTimeWithTimezone(d, show24Hour: true);
  }

  int? _calculateDeadlineHours() {
    final hours = int.tryParse(_deadlineHoursController.text) ?? 0;
    final minutes = int.tryParse(_deadlineMinutesController.text) ?? 0;

    // Convert to total hours (rounded up if there are minutes)
    if (hours == 0 && minutes == 0) return null;

    // If there are minutes, round up to next hour
    // e.g., 2 hours 30 minutes = 3 hours
    return minutes > 0 ? hours + 1 : hours;
  }

  Future<void> _postSlot() async {
    if (!_validateForm()) return;

    // Validate notes content for prohibited contact info
    final notes = _notesController.text.trim();
    if (notes.isNotEmpty) {
      final termsError = ContentFilterService.instance.validateTerms(notes);
      if (termsError != null) {
        _showError(termsError);
        return;
      }
    }

    // ══════════════════════════════════════════════════════════
    // 💳 PAYMENT PROVIDER VALIDATION (Provider Posts Only)
    // ══════════════════════════════════════════════════════════
    // For provider posts (not customer posts), validate that user has
    // connected their payment account before allowing post creation
    if (!widget.isUserMode) {
      final currentUser = ProfileRepository.instance.profile.value;

      // Check if user has any payment provider connected
      final hasPaymentProvider =
          currentUser.paymentProvider != null &&
          currentUser.paymentProvider!.isNotEmpty;

      // Validation: Must have selected a payment provider (Stripe or Razorpay)
      // Bank details can be added later when withdrawing money
      if (!hasPaymentProvider) {
        // Show error dialog with guidance
        final shouldNavigate = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.payment, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text('Choose Payment Provider'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Razorpay (India) or Stripe (International) to start creating posts.\n\n'
                  'You can add bank details later when you want to withdraw earnings.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
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
                            Icons.info,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Why is this required?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Just click Razorpay or Stripe to activate\n'
                        '• Start creating posts immediately\n'
                        '• Add bank details when withdrawing',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Choose your payment provider in Profile Settings to start posting.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('Go to Settings'),
              ),
            ],
          ),
        );

        if (shouldNavigate == true && mounted) {
          // Navigate to profile settings (payment section)
          Navigator.pushNamed(context, '/profile');
        }
        return; // Block post creation
      }

      // Validation passed: User has selected payment provider
      debugPrint(
        '✅ Payment provider selected: ${currentUser.paymentProvider} '
        '(Bank details optional until withdrawal)',
      );
    }

    // CUSTOMER MODE: Process escrow payment before creating post
    // When isUserMode=true, customer must pay the post price as escrow
    // This money is held until service completion, then released to provider
    String? escrowPaymentId;
    if (widget.isUserMode) {
      // In layout mode, derive price from the total of all seat prices in the layout
      double? price;
      if (!_useSimpleSeating ||
          (_builtSeatLayout?.layout.isNotEmpty ?? false)) {
        final builtSeats =
            _builtSeatLayout?.layout
                .where((item) => !item.isGap && item.price > 0)
                .toList() ??
            [];
        if (builtSeats.isNotEmpty) {
          price = builtSeats
              .map((s) => s.price.toDouble())
              .fold<double>(0.0, (sum, p) => sum + p);
        }
      }
      price ??= double.tryParse(_priceController.text.trim());
      if (price == null || price <= 0) {
        _showError('Please enter a valid price');
        return;
      }

      // Calculate platform fee (5%)
      const double platformFeePercent = 5.0;
      final servicePrice = price;
      final platformFee = servicePrice * platformFeePercent / 100;
      final totalEscrow = servicePrice + platformFee;

      // Show payment confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Escrow Payment Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Price breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Service price:'),
                  Text(
                    '${_getProviderCurrencySymbol()}${servicePrice.toStringAsFixed(2)}',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Platform fee (${platformFeePercent.toInt()}%):'),
                  Text(
                    '${_getProviderCurrencySymbol()}${platformFee.toStringAsFixed(2)}',
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total escrow:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_getProviderCurrencySymbol()}${totalEscrow.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
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
      try {
        final currentUser = AuthRepository.instance.currentUser;
        if (currentUser == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          _showError('User not authenticated');
          return;
        }

        // Import required services
        final prefs = AppPreferences.instance;
        final currency = prefs.currencyCode.value;
        final countryCode = currency == 'INR' ? 'IN' : 'US';

        // Get PaymentService - need to import it
        final paymentService = PaymentService.instance;
        final paymentResult = await paymentService.processPayment(
          amountInPaise: (totalEscrow * 100).toInt(),
          currency: currency,
          countryCode: countryCode,
          providerId: 'escrow',
          slotId: 'customer_post_${DateTime.now().microsecondsSinceEpoch}',
          userName: currentUser.email,
          userEmail: currentUser.email,
          userPhone: '',
          description: 'Escrow for ${widget.serviceType.displayName} post',
          commissionAmount: (platformFee * 100).toInt(),
        );

        if (paymentResult == null || paymentResult['error'] != null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          final errorMsg =
              paymentResult?['error']?.toString() ?? 'Unknown error';
          _showError('Payment cancelled or failed: $errorMsg');
          return;
        }

        escrowPaymentId = paymentResult['payment_id'] as String?;
        if (escrowPaymentId == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          _showError('Payment ID not received');
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Payment successful, creating post...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        _showError('Payment failed: $e');
        return;
      }
    }

    setState(() => _isPosting = true);

    try {
      if (_slotType == SlotType.fromTo) {
        _fromSuggestion ??= await _maybeGeocode(_fromController.text.trim());
        _toSuggestion ??= await _maybeGeocode(_toController.text.trim());
      } else {
        _baseSuggestion ??= await _maybeGeocode(_baseController.text.trim());
      }

      final slotId = DateTime.now().millisecondsSinceEpoch.toString();

      final bool useLayout = !_useSimpleSeating;
      final String? layoutOwnerId = useLayout
          ? (_seatLayoutOwnerId ?? slotId)
          : null;
      if (useLayout) {
        _seatLayoutOwnerId ??= layoutOwnerId;
      }

      final seatLayout = layoutOwnerId == null
          ? null
          : SeatLayoutRepository.instance.getLayout(layoutOwnerId);

      final seatCells =
          seatLayout?.cells.values
              .where((c) => c.type == CellType.seat)
              .toList(growable: false) ??
          const <LayoutCell>[];

      final int derivedCapacity = useLayout
          ? (seatCells.isNotEmpty
                ? seatCells.length
                : (_builtSeatLayout?.layout.where((i) => !i.isGap).length ??
                      _capacity))
          : _capacity;

      // Get min seat price — try in-memory layout first, fall back to JSON
      final int minSeatPrice = useLayout
          ? (seatCells.isNotEmpty
                ? (seatCells
                          .map((c) => c.price)
                          .whereType<int>()
                          .fold<int?>(
                            null,
                            (min, p) => min == null ? p : (p < min ? p : min),
                          ) ??
                      0)
                : (_builtSeatLayout?.layout
                          .where((i) => !i.isGap && i.price > 0)
                          .map((i) => i.price)
                          .fold<int?>(
                            null,
                            (min, p) => min == null ? p : (p < min ? p : min),
                          ) ??
                      0))
          : 0;

      final double derivedPrice = useLayout
          ? minSeatPrice.toDouble()
          : (double.tryParse(_priceController.text) ?? 0);

      // Determine actual service type based on operator toggle for Lease
      final ServiceType actualServiceType =
          widget.serviceType == ServiceType.lease
          ? (_withOperator ? ServiceType.working : ServiceType.lease)
          : widget.serviceType;

      // Set withOperator based on service type
      final bool operatorValue = widget.serviceType == ServiceType.lease
          ? _withOperator
          : true; // Passenger and Parcel always have operators

      // Guest-first: Check if user is logged in before creating post
      final currentUser = AuthRepository.instance.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to create posts'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pushNamed(context, '/login');
        return;
      }

      final slot = Slot(
        id: slotId,
        profileId: currentUser.id, // Post owner (null-safe)
        vehicleId: _selectedVehicle!.id,
        serviceType: actualServiceType,
        slotType: _slotType,
        seatLayoutOwnerId: layoutOwnerId,
        seatLayoutStructure:
            _builtSeatLayout, // Add the actual layout structure
        requiresApproval: false,
        fromLocation: _slotType == SlotType.fromTo
            ? _formatLocationValue(
                typedText: _fromController.text.trim(),
                suggestion: _fromSuggestion,
              )
            : null,
        toLocation: _slotType == SlotType.fromTo
            ? _formatLocationValue(
                typedText: _toController.text.trim(),
                suggestion: _toSuggestion,
              )
            : null,
        baseLocation: _slotType == SlotType.fromRange
            ? _formatLocationValue(
                typedText: _baseController.text.trim(),
                suggestion: _baseSuggestion,
              )
            : null,
        radius: _slotType == SlotType.fromRange
            ? double.tryParse(_radiusController.text)
            : null,
        startTime: _startTime!,
        endTime: _endTime!,
        price: derivedPrice,
        capacity: derivedCapacity,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        images: _postMediaUrls, // Store post media URLs
        createdAt: DateTime.now(),
        pickupOption: _pickupMode,
        maxWeight: widget.serviceType == ServiceType.parcel
            ? double.tryParse(_maxWeightController.text)
            : null,
        maxLength: widget.serviceType == ServiceType.parcel
            ? double.tryParse(_maxLengthController.text)
            : null,
        maxWidth: widget.serviceType == ServiceType.parcel
            ? double.tryParse(_maxWidthController.text)
            : null,
        maxHeight: widget.serviceType == ServiceType.parcel
            ? double.tryParse(_maxHeightController.text)
            : null,
        leaseDuration:
            null, // No duration selection - just time frame and total price
        securityDeposit: double.tryParse(_securityDepositController.text),
        fuelPolicy: widget.serviceType == ServiceType.lease
            ? _fuelPolicy
            : null,
        insuranceIncluded: widget.serviceType == ServiceType.lease
            ? _insuranceIncluded
            : null,
        leaseTerms:
            widget.serviceType == ServiceType.lease &&
                _leaseTermsController.text.trim().isNotEmpty
            ? _leaseTermsController.text.trim()
            : null,
        withOperator: operatorValue,
        bookingMode: widget.serviceType == ServiceType.lease
            ? BookingMode
                  .full // Lease is always full vehicle
            : (_postMode == PostMode.waitForFull
                  ? BookingMode.full
                  : BookingMode.shared),
        postMode: _postMode, // Add post mode
        waitForFullDeadlineHours: _postMode == PostMode.waitForFull
            ? _calculateDeadlineHours()
            : null,
        demandPlan: _demandPlan.dbValue, // Add demand plan
        minRatings: _minRatings, // Add rating requirements
        minNoRatings: _minNoRatings,
        escrowPaymentId:
            escrowPaymentId, // Add escrow payment ID for customer posts
        currencyType:
            _determineCurrencyType(), // Auto-detect currency from location
      );

      // Debug: Verify seat layout structure before saving
      if (_builtSeatLayout == null) {
        debugPrint('⚠️ WARNING: Seat layout structure is NULL');
      } else {
        debugPrint('✅ Seat layout structure: ${_builtSeatLayout!.toJson()}');
      }

      if (widget.isUserMode) {
        await CustomerSlotRepository.instance.addSlot(slot);
      } else {
        await SlotRepository.instance.addSlot(slot);
      }

      // Refresh posts from Supabase to show the newly created post
      if (widget.isUserMode) {
        await CustomerSlotRepository.instance.loadSlots();
      } else {
        await SlotRepository.instance.loadSlots();
      }

      if (mounted) {
        final snackBarMessage = widget.isUserMode
            ? 'Posted live ✅ Find it in Posts > User Requests tab'
            : 'Posted live ✅';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackBarMessage),
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to post: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  /// Get currency symbol from provider's connected payment account
  String _getProviderCurrencySymbol() {
    // Always use the user's selected currency from settings
    // Not the provider's bank currency
    return AppPreferences.instance.currencySymbol;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create ${widget.serviceType.displayName} Post'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle Selection
            _buildVehicleSelector(),
            const SizedBox(height: 20),

            // Slot Type
            _buildSlotTypeSelector(),
            const SizedBox(height: 20),

            // Location Section
            _buildLocationSection(),
            const SizedBox(height: 20),

            // Time Window
            _buildTimeSection(),
            const SizedBox(height: 20),

            // Price and Capacity
            _buildPriceCapacitySection(),
            const SizedBox(height: 20),

            // Working Mode (only for working service)
            if (widget.serviceType == ServiceType.working) ...[
              _buildWorkingModeSection(),
              const SizedBox(height: 20),
            ],

            // Parcel Dimensions (only for parcel service in simple mode)
            if (widget.serviceType == ServiceType.parcel &&
                _useSimpleSeating) ...[
              _buildParcelDimensionsSection(),
              const SizedBox(height: 20),
            ],

            // Security Deposit (only shown in simple mode - layout mode has per-compartment deposits)
            if (_useSimpleSeating) ...[
              _buildSecurityDepositSection(),
              const SizedBox(height: 20),
            ],

            // Lease Details (only for lease service - fuel, insurance, terms)
            if (widget.serviceType == ServiceType.lease) ...[
              _buildLeaseDetailsSection(),
              const SizedBox(height: 20),
            ],

            // Pickup Mode
            _buildPickupModeSection(),
            const SizedBox(height: 20),

            // Post Mode (Booking Strategy) - Not applicable for Lease
            if (widget.serviceType != ServiceType.lease) ...[
              _buildPostModeSection(),
              const SizedBox(height: 20),
            ],

            // Operator Availability (only for Lease service)
            if (widget.serviceType == ServiceType.lease) ...[
              _buildOperatorSection(),
              const SizedBox(height: 20),
            ],

            // Seating Setup (only for Passenger/Parcel, not for Lease/Working)
            if (!_useSimpleSeating &&
                widget.serviceType != ServiceType.lease &&
                widget.serviceType != ServiceType.working) ...[
              _buildSeatingSetupSection(),
              const SizedBox(height: 20),
            ],

            // Notes
            _buildNotesSection(),
            const SizedBox(height: 20),

            // Post Media
            _buildPostMediaSection(),
            const SizedBox(height: 20),

            // Demand Plan and Rating Requirements
            _buildDemandPlanSection(),
            const SizedBox(height: 100), // Space for floating button
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isPosting ? null : _postSlot,
        backgroundColor: _isPosting ? Colors.grey : Colors.blue,
        label: _isPosting
            ? const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Posting...'),
                ],
              )
            : const Text('🚀 Post live'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildVehicleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🚗 Vehicle',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final result = await Navigator.push<Vehicle>(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    VehicleListScreen(isUserMode: widget.isUserMode),
              ),
            );
            if (result != null) {
              setState(() => _selectedVehicle = result);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _selectedVehicle != null
                ? Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _selectedVehicle!.profileImage != null
                            ? Builder(
                                builder: (context) {
                                  final image = _selectedVehicle!.profileImage!;
                                  if (image.startsWith('http://') ||
                                      image.startsWith('https://')) {
                                    return Image.network(
                                      image,
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              width: 32,
                                              height: 32,
                                              color: Colors.blue.withValues(
                                                alpha: 0.12,
                                              ),
                                              child: Icon(
                                                Icons.directions_car,
                                                color: Colors.blue.shade700,
                                                size: 18,
                                              ),
                                            );
                                          },
                                    );
                                  }

                                  try {
                                    final bytes = base64Decode(image);
                                    return Image.memory(
                                      bytes,
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              width: 32,
                                              height: 32,
                                              color: Colors.blue.withValues(
                                                alpha: 0.12,
                                              ),
                                              child: Icon(
                                                Icons.directions_car,
                                                color: Colors.blue.shade700,
                                                size: 18,
                                              ),
                                            );
                                          },
                                    );
                                  } catch (_) {
                                    return Container(
                                      width: 32,
                                      height: 32,
                                      color: Colors.blue.withValues(
                                        alpha: 0.12,
                                      ),
                                      child: Icon(
                                        Icons.directions_car,
                                        color: Colors.blue.shade700,
                                        size: 18,
                                      ),
                                    );
                                  }
                                },
                              )
                            : Container(
                                width: 32,
                                height: 32,
                                color: Colors.blue.withValues(alpha: 0.12),
                                child: Icon(
                                  Icons.directions_car,
                                  color: Colors.blue.shade700,
                                  size: 18,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedVehicle!.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_selectedVehicle!.type} • ${_selectedVehicle!.year}',
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  )
                : const Row(
                    children: [
                      Icon(Icons.add_circle_outline, color: Colors.grey),
                      SizedBox(width: 12),
                      Text(
                        'Select vehicle',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Spacer(),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlotTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📍 Route Type',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _slotType = SlotType.fromTo),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _slotType == SlotType.fromTo
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.transparent,
                    border: Border.all(
                      color: _slotType == SlotType.fromTo
                          ? Colors.blue
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.route,
                        color: _slotType == SlotType.fromTo
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'From → To',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _slotType == SlotType.fromTo
                              ? Colors.blue
                              : Colors.black,
                        ),
                      ),
                      const Text(
                        'Specific route',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _slotType = SlotType.fromRange),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _slotType == SlotType.fromRange
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.transparent,
                    border: Border.all(
                      color: _slotType == SlotType.fromRange
                          ? Colors.blue
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: _slotType == SlotType.fromRange
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Base + Range',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _slotType == SlotType.fromRange
                              ? Colors.blue
                              : Colors.black,
                        ),
                      ),
                      const Text(
                        'Service area',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📍 Location',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_slotType == SlotType.fromTo) ...[
          Column(
            children: [
              LocationAutocompleteField(
                controller: _fromController,
                label: 'From',
                hint: 'e.g., Mumbai Airport',
                icon: Icons.location_on,
                onLocationSelected: (suggestion) {
                  _fromSuggestion = suggestion;
                },
              ),
              if (_fromSuggestion != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.gps_fixed,
                        size: 12,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Lat: ${_fromSuggestion!.lat.toStringAsFixed(6)}, Lon: ${_fromSuggestion!.lon.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Icon(Icons.arrow_downward, color: Colors.grey),
              ),
              LocationAutocompleteField(
                controller: _toController,
                label: 'To',
                hint: 'e.g., Pune Station',
                icon: Icons.flag,
                onLocationSelected: (suggestion) {
                  _toSuggestion = suggestion;
                },
              ),
              if (_toSuggestion != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.gps_fixed,
                        size: 12,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Lat: ${_toSuggestion!.lat.toStringAsFixed(6)}, Lon: ${_toSuggestion!.lon.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => _openInMaps(
                  typedText: _fromController.text,
                  suggestion: _fromSuggestion,
                ),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text(
                  'From in Maps',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openInMaps(
                  typedText: _toController.text,
                  suggestion: _toSuggestion,
                ),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('To in Maps', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (_fromSuggestion != null && _toSuggestion != null) ...[
            const SizedBox(height: 4),
            Builder(
              builder: (context) {
                final dist = _haversineKm(
                  _fromSuggestion!.lat,
                  _fromSuggestion!.lon,
                  _toSuggestion!.lat,
                  _toSuggestion!.lon,
                );
                return Row(
                  children: [
                    const Icon(Icons.straighten, size: 14, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(
                      '~${dist.toStringAsFixed(1)} km between locations',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
                );
              },
            ),
          ],
        ] else ...[
          LocationAutocompleteField(
            controller: _baseController,
            label: 'Base Location',
            hint: 'e.g., City Center',
            icon: Icons.home,
            onLocationSelected: (suggestion) {
              _baseSuggestion = suggestion;
            },
          ),
          if (_baseSuggestion != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'Lat: ${_baseSuggestion!.lat.toStringAsFixed(6)}, Lon: ${_baseSuggestion!.lon.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 11, color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openInMaps(
                typedText: _baseController.text,
                suggestion: _baseSuggestion,
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open Base in Maps'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _radiusController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Range (km)',
                    hintText: 'Service radius',
                    prefixIcon: Icon(Icons.radar),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⏰ Time Window',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<String>(
                    future: _fromSuggestion != null
                        ? TimezoneUtils.getTimezoneFromCoords(
                            _fromSuggestion!.lat,
                            _fromSuggestion!.lon,
                          )
                        : Future.value(TimezoneUtils.getTimezoneAbbreviation()),
                    builder: (context, snap) {
                      final tz =
                          snap.data ?? TimezoneUtils.getTimezoneAbbreviation();
                      return Text(
                        'Start Time ($tz)',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _selectTime(isStart: true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _startTime != null
                                ? _fmtTime24(_startTime!)
                                : 'Select start date & time',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<String>(
                    future: (_toSuggestion ?? _baseSuggestion) != null
                        ? TimezoneUtils.getTimezoneFromCoords(
                            (_toSuggestion ?? _baseSuggestion)!.lat,
                            (_toSuggestion ?? _baseSuggestion)!.lon,
                          )
                        : Future.value(TimezoneUtils.getTimezoneAbbreviation()),
                    builder: (context, snap) {
                      final tz =
                          snap.data ?? TimezoneUtils.getTimezoneAbbreviation();
                      return Text(
                        'End Time ($tz)',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _selectTime(isStart: false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _endTime != null
                                ? _fmtTime24(_endTime!)
                                : 'Select end date & time',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_startTime != null && _endTime != null) ...[
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final diff = _endTime!.difference(_startTime!);
              final hours = diff.inHours;
              final minutes = diff.inMinutes % 60;
              final isNegative = diff.isNegative;
              return Row(
                children: [
                  Icon(
                    isNegative ? Icons.warning_amber : Icons.timer_outlined,
                    size: 14,
                    color: isNegative ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isNegative
                        ? 'End time is before start time'
                        : 'Duration: ${hours > 0 ? '${hours}h ' : ''}${minutes}m',
                    style: TextStyle(
                      fontSize: 12,
                      color: isNegative ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPriceCapacitySection() {
    final hasLayoutSeats = _hasSeatLayoutSeats;
    final isLeaseOrWorking =
        widget.serviceType == ServiceType.lease ||
        widget.serviceType == ServiceType.working;

    if (hasLayoutSeats && _useSimpleSeating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _useSimpleSeating = false);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💰 Seating Mode',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        // Hide layout option for Lease/Working services
        if (!hasLayoutSeats && !isLeaseOrWorking)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _useSimpleSeating = true),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _useSimpleSeating
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: _useSimpleSeating
                            ? Colors.green
                            : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _useSimpleSeating
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: _useSimpleSeating ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Simple (price + capacity)',
                            maxLines: 2,
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _useSimpleSeating = false),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: !_useSimpleSeating
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.transparent,
                      border: Border.all(
                        color: !_useSimpleSeating
                            ? Colors.blue
                            : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          !_useSimpleSeating
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: !_useSimpleSeating ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Layout-based',
                            maxLines: 2,
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.grid_on_outlined, color: Colors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Layout-based seating enabled',
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (_useSimpleSeating) ...[
          const Text(
            '💰 Price & Capacity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: widget.serviceType == ServiceType.lease
                  ? 'Total Lease Price'
                  : 'Price per ${widget.serviceType == ServiceType.working
                        ? 'job'
                        : widget.serviceType == ServiceType.parcel
                        ? 'parcel'
                        : 'seat'}',
              hintText: 'Enter amount',
              prefixText: _getProviderCurrencySymbol(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // Hide capacity for Lease service (entire vehicle is booked)
          if (widget.serviceType != ServiceType.lease)
            Row(
              children: [
                const Text(
                  'Capacity: ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _capacity > 1
                          ? () => setState(() => _capacity--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      _capacity.toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _capacity++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                Text(
                  widget.serviceType == ServiceType.working
                      ? 'jobs'
                      : widget.serviceType == ServiceType.parcel
                      ? 'parcels'
                      : 'seats',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
        ],
      ],
    );
  }

  Widget _buildWorkingModeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔧 Working Mode',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _workingMode = 'On-site'),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 68),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _workingMode == 'On-site'
                        ? Colors.purple.withValues(alpha: 0.1)
                        : Colors.transparent,
                    border: Border.all(
                      color: _workingMode == 'On-site'
                          ? Colors.purple
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'On-site',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _workingMode == 'On-site'
                          ? Colors.purple
                          : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _workingMode = 'Remote'),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _workingMode == 'Remote'
                        ? Colors.purple.withValues(alpha: 0.1)
                        : Colors.transparent,
                    border: Border.all(
                      color: _workingMode == 'Remote'
                          ? Colors.purple
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Remote',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _workingMode == 'Remote'
                          ? Colors.purple
                          : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildParcelDimensionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📦 Maximum Parcel Dimensions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _maxWeightController,
                decoration: const InputDecoration(
                  labelText: 'Max Weight (kg)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.scale),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _maxLengthController,
                decoration: const InputDecoration(
                  labelText: 'Max Length (cm)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.straighten),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _maxWidthController,
                decoration: const InputDecoration(
                  labelText: 'Max Width (cm)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.width_normal),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _maxHeightController,
                decoration: const InputDecoration(
                  labelText: 'Max Height (cm)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.height),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityDepositSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔒 Security Deposit',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _securityDepositController,
          decoration: InputDecoration(
            labelText: 'Security Deposit Amount (optional)',
            border: const OutlineInputBorder(),
            prefixText: '${_getProviderCurrencySymbol()} ',
            helperText: 'Refundable deposit held until service completion',
            hintText: 'Enter amount or leave empty for no deposit',
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        Text(
          'Security deposit protects against no-shows and damages. Leave empty if not required.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildLeaseDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🚗 Lease Specific Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Fuel Policy
        DropdownButtonFormField<String>(
          initialValue: _fuelPolicy,
          decoration: const InputDecoration(
            labelText: 'Fuel Policy',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.local_gas_station),
          ),
          items: ['Full-to-Full', 'Fuel Included', 'Pay as You Go'].map((
            policy,
          ) {
            return DropdownMenuItem(value: policy, child: Text(policy));
          }).toList(),
          onChanged: (value) => setState(() => _fuelPolicy = value!),
        ),
        const SizedBox(height: 12),

        // Insurance Included
        SwitchListTile(
          title: const Text('Insurance Included'),
          subtitle: const Text('Is insurance included in the lease price?'),
          value: _insuranceIncluded,
          onChanged: (value) => setState(() => _insuranceIncluded = value),
          secondary: const Icon(Icons.shield),
        ),
      ],
    );
  }

  Widget _buildPickupModeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🚶 Pickup Option',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    setState(() => _pickupMode = PickupMode.customerPickup),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _pickupMode == PickupMode.customerPickup
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.transparent,
                    border: Border.all(
                      color: _pickupMode == PickupMode.customerPickup
                          ? Colors.blue
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _pickupMode == PickupMode.customerPickup
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: _pickupMode == PickupMode.customerPickup
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Customer comes to pickup',
                          maxLines: 2,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    setState(() => _pickupMode = PickupMode.providerPickup),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 68),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _pickupMode == PickupMode.providerPickup
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.transparent,
                    border: Border.all(
                      color: _pickupMode == PickupMode.providerPickup
                          ? Colors.blue
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _pickupMode == PickupMode.providerPickup
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: _pickupMode == PickupMode.providerPickup
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Provider comes to customer',
                          maxLines: 2,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPostModeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🎯 Booking Mode',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: RadioGroup<PostMode>(
            groupValue: _postMode,
            onChanged: (v) {
              if (v != null) setState(() => _postMode = v);
            },
            child: Column(
              children: [
                // Instant Booking
                InkWell(
                  onTap: () => setState(() => _postMode = PostMode.instant),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Radio<PostMode>(value: PostMode.instant),
                        const Icon(Icons.flash_on, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Instant Booking',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Customers can book immediately',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                // Wait for Full
                InkWell(
                  onTap: () => setState(() => _postMode = PostMode.waitForFull),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Radio<PostMode>(value: PostMode.waitForFull),
                        const Icon(Icons.groups, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Wait for Full',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Wait until all seats are filled',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Deadline input (only for Wait for Full)
                if (_postMode == PostMode.waitForFull) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _deadlineHoursController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Hours',
                              hintText: '0-48',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _deadlineMinutesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Minutes',
                              hintText: '0-59',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: Text(
                      'Deadline before start time',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
                const Divider(),
                // Full Post Mode
                InkWell(
                  onTap: () => setState(() => _postMode = PostMode.fullPost),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Radio<PostMode>(value: PostMode.fullPost),
                        const Icon(Icons.directions_car, color: Colors.green),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Full Post Mode',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Customer must book all remaining slots',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '👨‍✈️ Operator Availability',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Material(
          borderRadius: BorderRadius.circular(8),
          child: SwitchListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            title: const Text('With Operator'),
            subtitle: Text(
              _withOperator
                  ? 'Service includes an operator'
                  : 'Self-service (no operator)',
            ),
            value: _withOperator,
            onChanged: (value) {
              setState(() {
                _withOperator = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSeatingSetupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🎟 Seating Setup (optional)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _seatLayoutOwnerId == null
                      ? 'No layout added'
                      : 'Layout ready (tap edit to update)',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openSeatLayoutBuilder,
                icon: const Icon(Icons.grid_on_outlined, size: 18),
                label: Text(_seatLayoutOwnerId == null ? 'Add' : 'Edit'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openSeatLayoutBuilder() async {
    final ownerId =
        _seatLayoutOwnerId ??
        'draft_${DateTime.now().millisecondsSinceEpoch.toString()}';
    _seatLayoutOwnerId ??= ownerId;

    final existing = SeatLayoutRepository.instance.getLayout(ownerId);
    final initial =
        existing ??
        SeatLayout(
          id: 'layout_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Layout',
          rows: 8,
          cols: 8,
          cells: const <String, LayoutCell>{},
        );

    final controller = SeatLayoutController(initialLayout: initial);

    final saved = await Navigator.push<SeatLayout>(
      context,
      MaterialPageRoute(
        builder: (context) => SeatLayoutBuilderScreen(
          controller: controller,
          ownerId: ownerId,
          serviceType: widget.serviceType,
        ),
      ),
    );

    if (saved == null) return;
    SeatLayoutRepository.instance.upsert(ownerId: ownerId, layout: saved);

    // Convert SeatLayout to SimpleSeatLayout for database storage
    _builtSeatLayout = _convertToSimpleSeatLayout(saved);
    debugPrint('📦 Seat Layout Structure: ${_builtSeatLayout?.toJson()}');

    if (!mounted) return;
    setState(() {
      _useSimpleSeating = false;
    });
  }

  /// Convert SeatLayout (UI model) to SimpleSeatLayout (DB model)
  SimpleSeatLayout _convertToSimpleSeatLayout(SeatLayout layout) {
    final items = <LayoutItem>[];

    // Convert each cell to a LayoutItem
    layout.cells.forEach((key, cell) {
      if (cell.type == CellType.seat) {
        // Convert SeatGender enum to string
        String genderStr = 'Any';
        if (cell.gender == SeatGender.male) {
          genderStr = 'Male';
        } else if (cell.gender == SeatGender.female) {
          genderStr = 'Female';
        }

        items.add(
          PassengerSeat(
            key: cell.seatName ?? key,
            matrix: '${cell.row}x${cell.col}',
            allowedGender: genderStr,
            price: cell.price ?? 0,
            status: cell.isLocked ? SlotStatus.locked : SlotStatus.available,
            bookingId: null,
          ),
        );
      } else if (cell.type == CellType.space) {
        // Space cells are gaps in the layout
        items.add(
          PassengerSeat(
            key: 'gap_${cell.row}x${cell.col}',
            matrix: '${cell.row}x${cell.col}',
            allowedGender: 'Any',
            price: 0,
            status: SlotStatus.gap,
            bookingId: null,
          ),
        );
      }
    });

    return SimpleSeatLayout(
      type: widget.serviceType == ServiceType.passenger
          ? 'passenger'
          : 'parcel',
      layout: items,
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📝 Terms (Optional)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Add any additional information...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPostMediaSection() {
    final tempPostId = 'draft_${DateTime.now().millisecondsSinceEpoch}';
    return PostMediaUploadWidget(
      initialMedia: const [],
      postId: tempPostId,
      onMediaChanged: (media) {
        setState(() {
          _postMediaUrls = media.map((item) => item.url).toList();
        });
      },
    );
  }

  Widget _buildDemandPlanSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '👥 Customer Requirements (Optional)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Who can book this service - defaults to everyone',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        // ignore: deprecated_member_use
        ...DemandPlan.values.map(
          (plan) => RadioListTile<DemandPlan>(
            contentPadding: EdgeInsets.zero,
            title: Text(plan.displayName),
            subtitle: Text(
              plan.description,
              style: const TextStyle(fontSize: 12),
            ),
            value: plan,
            groupValue: _demandPlan, // ignore: deprecated_member_use
            // ignore: deprecated_member_use
            onChanged: (value) {
              // ignore: deprecated_member_use
              setState(() => _demandPlan = value!);
            },
          ),
        ),

        const SizedBox(height: 16),
        const Text(
          '⭐ Rating Requirements (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Min Customer Rating',
                  hintText: '4.0',
                  helperText: 'Minimum rating',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (v) {
                  setState(() => _minRatings = double.tryParse(v));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Min Number of Ratings',
                  hintText: '10',
                  helperText: 'Reviews received',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  setState(() => _minNoRatings = int.tryParse(v));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
