// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../models/vehicle.dart';
import '../../models/slot.dart';
import '../../models/slot_type.dart';
import '../../models/service_type.dart';
import '../../models/pickup_mode.dart';
import '../../models/post_mode.dart';
import '../../services/slot_repository.dart';
import '../../services/auth_repository.dart';
import '../../services/profile_repository.dart';
import '../../services/content_filter_service.dart';
import '../../services/app_preferences.dart';
import '../../widgets/location_field.dart';

class CreateSlotScreen extends StatefulWidget {
  final Vehicle vehicle;

  const CreateSlotScreen({super.key, required this.vehicle});

  @override
  State<CreateSlotScreen> createState() => _CreateSlotScreenState();
}

class _CreateSlotScreenState extends State<CreateSlotScreen> {
  SlotType _slotType = SlotType.fromTo;
  ServiceType _serviceType =
      ServiceType.passenger; // Add service type selection
  PostMode _postMode = PostMode.instant; // Add post mode selection

  // Controllers
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _baseController = TextEditingController();
  final _radiusController = TextEditingController(text: '10');
  final _capacityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _startTime;
  DateTime? _endTime;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // Set default times — use Duration addition to handle day overflow
    final now = DateTime.now();
    final start = now.add(const Duration(hours: 1));
    _startTime = DateTime(start.year, start.month, start.day, start.hour, 0);
    _endTime = _startTime!.add(const Duration(hours: 4));
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _baseController.dispose();
    _radiusController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Get currency symbol from provider's connected payment account
  String _getProviderCurrencySymbol() {
    final profile = ProfileRepository.instance.profile.value;

    // CRITICAL: Check payment provider FIRST
    // Razorpay MUST always be INR, regardless of bankCurrency
    if (profile.paymentProvider == 'razorpay') {
      return '₹'; // Razorpay only supports INR
    }

    final currency = profile.bankCurrency;

    if (currency != null && currency.isNotEmpty) {
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
      };
      return currencySymbols[currency] ?? currency;
    }
    return AppPreferences.instance.currencySymbol;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Slot'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Vehicle Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.directions_car, size: 40, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.vehicle.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.vehicle.type,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Service Type Selection
          const Text(
            'Service Type',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Service Type Options
          Column(
            children: [
              InkWell(
                onTap: () =>
                    setState(() => _serviceType = ServiceType.passenger),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Radio<ServiceType>(
                        value: ServiceType.passenger,
                        groupValue: _serviceType,
                        onChanged: (value) =>
                            setState(() => _serviceType = value!),
                      ),
                      const Icon(Icons.people, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Passenger', style: TextStyle(fontSize: 16)),
                            Text(
                              'Transport people from one place to another',
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
              InkWell(
                onTap: () => setState(() => _serviceType = ServiceType.parcel),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Radio<ServiceType>(
                        value: ServiceType.parcel,
                        groupValue: _serviceType,
                        onChanged: (value) =>
                            setState(() => _serviceType = value!),
                      ),
                      const Icon(Icons.local_shipping, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Parcel', style: TextStyle(fontSize: 16)),
                            Text(
                              'Deliver packages and goods',
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
              InkWell(
                onTap: () => setState(() => _serviceType = ServiceType.lease),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Radio<ServiceType>(
                        value: ServiceType.lease,
                        groupValue: _serviceType,
                        onChanged: (value) =>
                            setState(() => _serviceType = value!),
                      ),
                      const Icon(Icons.handshake, color: Colors.green),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Help Vehicle',
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              'Help others with vehicle needs',
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

          const SizedBox(height: 24),

          // Post Mode Selection
          const Text(
            'Booking Mode',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Post Mode Options
          Column(
            children: [
              InkWell(
                onTap: () => setState(() => _postMode = PostMode.instant),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Radio<PostMode>(
                        value: PostMode.instant,
                        groupValue: _postMode,
                        onChanged: (value) =>
                            setState(() => _postMode = value!),
                      ),
                      const Icon(Icons.flash_on, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instant Booking',
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              'Customers can book individual seats immediately',
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
              InkWell(
                onTap: () => setState(() => _postMode = PostMode.waitForFull),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Radio<PostMode>(
                        value: PostMode.waitForFull,
                        groupValue: _postMode,
                        onChanged: (value) =>
                            setState(() => _postMode = value!),
                      ),
                      const Icon(Icons.groups, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Wait for Full',
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              'Wait until all seats are filled before confirming',
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
              InkWell(
                onTap: () => setState(() => _postMode = PostMode.fullPost),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Radio<PostMode>(
                        value: PostMode.fullPost,
                        groupValue: _postMode,
                        onChanged: (value) =>
                            setState(() => _postMode = value!),
                      ),
                      const Icon(Icons.directions_car, color: Colors.green),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Full Post Mode',
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              'Customer must book all remaining slots in this post',
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

          const SizedBox(height: 24),

          // 1. Slot Type Selection
          const Text(
            'Slot Type',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _slotType = SlotType.fromTo),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Radio<SlotType>(
                    value: SlotType.fromTo,
                    groupValue: _slotType,
                    onChanged: (value) => setState(() => _slotType = value!),
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Point to Point', style: TextStyle(fontSize: 16)),
                        Text(
                          'Fixed route (e.g., Airport to City)',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _slotType = SlotType.fromRange),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Radio<SlotType>(
                    value: SlotType.fromRange,
                    groupValue: _slotType,
                    onChanged: (value) => setState(() => _slotType = value!),
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Area Service', style: TextStyle(fontSize: 16)),
                        Text(
                          'Service within radius (e.g., City taxi)',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2. Location Fields (conditional)
          const Text(
            'Location Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (_slotType == SlotType.fromTo) ...[
            LocationField(
              controller: _fromController,
              labelText: 'From Location *',
              hintText: 'e.g., Mumbai Airport',
            ),
            const SizedBox(height: 12),
            LocationField(
              controller: _toController,
              labelText: 'To Location *',
              hintText: 'e.g., Pune Station',
            ),
          ] else ...[
            LocationField(
              controller: _baseController,
              labelText: 'Base Location *',
              hintText: 'e.g., City Center',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _radiusController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Service Radius (km) *',
                hintText: 'e.g., 10',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.radar),
                suffixText: 'km',
              ),
            ),
          ],

          const SizedBox(height: 24),

          // 3. Time Selection
          const Text(
            'Time Schedule',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _startTime == null
                        ? 'Start Time *'
                        : _formatDateTime(_startTime!),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => _pickDateTime(isStart: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _endTime == null
                        ? 'End Time *'
                        : _formatDateTime(_endTime!),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => _pickDateTime(isStart: false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 4. Capacity & Price
          const Text(
            'Capacity & Pricing',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Capacity *',
                    hintText: '4',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people),
                    suffixText: 'seats',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ValueListenableBuilder<ProfileInfo>(
                  valueListenable: ProfileRepository.instance.profile,
                  builder: (context, profile, _) {
                    return TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Price *',
                        hintText: '500',
                        border: const OutlineInputBorder(),
                        prefixText: '${_getProviderCurrencySymbol()} ',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 5. Notes (Optional)
          const Text(
            'Additional Terms (Optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Any special instructions or requirements...',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 32),

          // 6. Create Button
          FilledButton(
            onPressed: _isCreating ? null : _createSlot,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isCreating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create Slot', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    // Pick date
    final date = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startTime ?? DateTime.now())
          : (_endTime ?? DateTime.now().add(const Duration(hours: 4))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    if (!mounted) return;

    // Pick time
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        isStart
            ? (_startTime ?? DateTime.now())
            : (_endTime ?? DateTime.now().add(const Duration(hours: 4))),
      ),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null) return;

    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _startTime = dateTime;
        // Auto-adjust end time if needed
        if (_endTime != null && _endTime!.isBefore(_startTime!)) {
          _endTime = _startTime!.add(const Duration(hours: 4));
        }
      } else {
        _endTime = dateTime;
      }
    });
  }

  Future<void> _createSlot() async {
    // Validation
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
      final radius = double.tryParse(_radiusController.text);
      if (radius == null || radius <= 0) {
        _showError('Please enter valid radius');
        return;
      }
    }

    if (_startTime == null || _endTime == null) {
      _showError('Please select start and end times');
      return;
    }

    if (_endTime!.isBefore(_startTime!)) {
      _showError('End time must be after start time');
      return;
    }

    final capacity = int.tryParse(_capacityController.text);
    if (capacity == null || capacity <= 0) {
      _showError('Please enter valid capacity');
      return;
    }

    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      _showError('Please enter valid price');
      return;
    }

    // Validate notes for contact information
    final notes = _notesController.text.trim();
    if (notes.isNotEmpty) {
      final errorMessage = ContentFilterService.instance.validateTerms(notes);
      if (errorMessage != null) {
        _showError(errorMessage);
        return;
      }
    }

    setState(() => _isCreating = true);

    try {
      // Guest-first: Check if user is logged in
      final currentUser = AuthRepository.instance.currentUser;
      if (currentUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to create slots'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pushNamed(context, '/login');
        return;
      }

      // Create slot
      final slot = Slot(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        profileId: currentUser.id,
        vehicleId: widget.vehicle.id,
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
        price: price,
        capacity: capacity,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        images: [],
        isAvailable: true,
        createdAt: DateTime.now(),
        pickupOption: PickupMode.providerPickup,
        withOperator: false, // Default to false for now
        postMode: _postMode, // Add post mode
        waitForFullDeadlineHours: _postMode == PostMode.waitForFull
            ? 2
            : null, // Default 2 hours
      );

      // Save to Supabase
      await SlotRepository.instance.addSlot(slot);

      if (!mounted) return;

      // Show success and go back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Slot created successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, slot);
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to create slot: $e');
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}
