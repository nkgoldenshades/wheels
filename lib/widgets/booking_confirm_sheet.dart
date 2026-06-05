import 'package:flutter/material.dart';

import '../models/slot.dart' hide BookingMode;
import '../models/slot_type.dart';
import '../models/seat_layout.dart';
import '../models/simple_seat_layout.dart';
import '../models/booking.dart';
import '../models/passenger.dart';
import '../models/service_type.dart';
import '../models/post_mode.dart';
import '../services/app_preferences.dart';
import '../utils/timezone_utils.dart';
import '../services/booking_repository.dart';
import '../services/seat_layout_repository.dart';
import '../app_tab_controller.dart';
import '../services/passenger_repository.dart';
import '../services/profile_repository.dart';
import '../services/stripe_service.dart';
import '../services/payment_service.dart';
import '../services/auth_repository.dart';
import '../services/vehicle_repository.dart';

class PassengerFormData {
  final TextEditingController nameController;
  final TextEditingController ageController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  SeatGender gender;

  PassengerFormData({
    String? initialName,
    String? initialPhone,
  })  : nameController = TextEditingController(text: initialName ?? ''),
        ageController = TextEditingController(),
        phoneController = TextEditingController(text: initialPhone ?? ''),
        emailController = TextEditingController(),
        gender = SeatGender.any;

  void dispose() {
    nameController.dispose();
    ageController.dispose();
    phoneController.dispose();
    emailController.dispose();
  }
}

class BookingConfirmResult {
  final List<String?> seatKeys;
  final List<SeatGender> userGenders;
  final List<String> userNames;
  final List<int> userAges;
  final List<String?> userPhones;
  final List<String?> userEmails;

  const BookingConfirmResult({
    required this.seatKeys,
    required this.userGenders,
    required this.userNames,
    required this.userAges,
    required this.userPhones,
    required this.userEmails,
  });
}

class BookingConfirmSheet extends StatefulWidget {
  final Slot slot;
  final bool isOffer;
  final String providerId;

  const BookingConfirmSheet({
    super.key,
    required this.slot,
    this.isOffer = true,
    required this.providerId,
  });

  @override
  State<BookingConfirmSheet> createState() => _BookingConfirmSheetState();
}

class _BookingConfirmSheetState extends State<BookingConfirmSheet> {
  Set<String> _selectedSeats = {};

  int _quantity = 1;

  bool _orderLoadingDialogShown = false;
  bool _isProcessing = false;
  
  // Multiple passenger forms - one per seat
  List<PassengerFormData> _passengerForms = [];
  
  bool _savePassengers = false;

  static const double _cellSize = 56;

  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    _selectedSeats = {};
    _passengerForms = [];
    _quantity = 1;
    
    // Initialize Stripe (no-op for Razorpay/India path)
    try {
      StripeService.instance.init();
    } catch (e) {
      debugPrint('Failed to initialize Stripe: $e');
    }
    
    // Pre-fill first form with profile data (safely)
    try {
      final profile = ProfileRepository.instance.profile.value;
      _addPassengerForm(
        initialName: profile.profileName.isEmpty ? null : profile.profileName,
        initialPhone: profile.phone?.isEmpty ?? true ? null : profile.phone,
      );
    } catch (e) {
      debugPrint('Failed to load profile: $e');
      _addPassengerForm(); // Add empty form as fallback
    }
  }
  
  @override
  void dispose() {
    for (final form in _passengerForms) {
      form.dispose();
    }
    super.dispose();
  }
  
  void _addPassengerForm({String? initialName, String? initialPhone}) {
    setState(() {
      _passengerForms.add(
        PassengerFormData(
          initialName: initialName,
          initialPhone: initialPhone,
        ),
      );
    });
  }

  void _scheduleSyncPassengerFormsCount() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) return;

      final desired = _selectedSeats.isEmpty ? _quantity : _selectedSeats.length;
      if (desired <= 0) return;
      if (_passengerForms.length == desired) return;

      setState(() {
        while (_passengerForms.length < desired) {
          _passengerForms.add(PassengerFormData());
        }
        while (_passengerForms.length > desired) {
          _passengerForms.removeLast().dispose();
        }
      });
    });
  }
  
  void _updatePassengerFormsCount() {
    final seatsCount = _selectedSeats.isEmpty ? _quantity : _selectedSeats.length;
    if (seatsCount <= 0) return;
    
    setState(() {
      // Add or remove forms to match seat count
      while (_passengerForms.length < seatsCount) {
        _addPassengerForm();
      }
      while (_passengerForms.length > seatsCount) {
        _passengerForms.removeLast().dispose();
      }
    });
  }

  void _selectPassenger(Passenger p, int formIndex) {
    if (formIndex >= _passengerForms.length) return;
    setState(() {
      final form = _passengerForms[formIndex];
      form.nameController.text = p.name;
      form.ageController.text = p.age.toString();
      form.gender = p.gender;
    });
  }

  void _showOrderLoadingDialog() {
    if (!mounted) return;
    _orderLoadingDialogShown = true;
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _closeOrderLoadingDialogIfAny() {
    if (!_orderLoadingDialogShown) return;
    _orderLoadingDialogShown = false;
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }
  
  void _showPassengerFormSelector(Passenger p) {
    if (_passengerForms.isEmpty) return;
    
    if (_passengerForms.length == 1) {
      _selectPassenger(p, 0);
      return;
    }
    
    final seatsList = _selectedSeats.toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Fill form for ${p.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_passengerForms.length, (index) {
            final seatKey = index < seatsList.length ? seatsList[index] : '';
            return ListTile(
              title: Text('Passenger ${index + 1} - Seat: $seatKey'),
              onTap: () {
                Navigator.pop(context);
                _selectPassenger(p, index);
              },
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final location = slot.slotType == SlotType.fromTo
        ? '${slot.fromLocation} → ${slot.toLocation}'
        : 'Based in ${slot.baseLocation} · ${slot.radius?.toInt()} km range';

    final layoutOwnerId = slot.seatLayoutOwnerId;
    // First try the local repository (for layouts the user created)
    SeatLayout? layout = layoutOwnerId == null
        ? null
        : SeatLayoutRepository.instance.getLayout(layoutOwnerId);

    // Fallback: convert SimpleSeatLayout from the slot itself (loaded from Supabase)
    if (layout == null && slot.seatLayoutStructure != null) {
      layout = _simpleSeatLayoutToSeatLayout(slot.seatLayoutStructure!);
    }

    // Debug: log layout status
    debugPrint('🪑 Layout check: ownerId=${slot.seatLayoutOwnerId}, '
        'structure=${slot.seatLayoutStructure != null ? "present (${slot.seatLayoutStructure!.layout.length} items)" : "null"}, '
        'layout=${layout != null ? "resolved" : "null → showing capacity"}');

    final hasSeatLayout = layout != null;

    final remainingCapacity = BookingRepository.instance.getRemainingCapacity(
      slot.id,
      slot.capacity,
    );

    // For Full Post mode, force quantity to all remaining slots
    final isFullPostMode = slot.postMode == PostMode.fullPost;
    
    if (!hasSeatLayout) {
      if (isFullPostMode) {
        // Full post mode: must book all remaining slots in this post
        _quantity = remainingCapacity > 0 ? remainingCapacity : slot.capacity;
      } else {
        if (_quantity < 1) {
          _quantity = 1;
        }
        if (remainingCapacity > 0 && _quantity > remainingCapacity) {
          _quantity = remainingCapacity;
        }
      }
      if (_passengerForms.isEmpty) {
        _passengerForms.add(PassengerFormData());
      }
      _scheduleSyncPassengerFormsCount();
    }

    final bookedSeatKeys = BookingRepository.instance.bookings.value
        .where(
          (b) =>
              b.slotId == slot.id &&
              b.seatKey != null &&
              b.status.isActive,
        )
        .map((b) => b.seatKey!)
        .toSet();

    // Validate selected seats against all passenger genders
    if (layout != null) {
      _selectedSeats.removeWhere((seatKey) {
        final selected = layout!.cells[seatKey];
        if (selected == null || selected.type != CellType.seat || selected.isLocked) return true;
        if (selected.gender == SeatGender.any) return false;
        return !_passengerForms.any((form) =>
          form.gender == SeatGender.any || form.gender == selected.gender);
      });
    }

    // Calculate total price for all selected seats
    final int totalPrice;
    if (isFullPostMode) {
      totalPrice = slot.price.toInt() * (remainingCapacity > 0 ? remainingCapacity : slot.capacity);
    } else if (layout != null && _selectedSeats.isNotEmpty) {
      totalPrice = _selectedSeats.fold<int>(
        0,
        (sum, seatKey) => sum + (layout!.cells[seatKey]?.price ?? 0),
      );
    } else {
      totalPrice = slot.price.toInt() * _quantity;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isOffer ? 'Confirm booking' : 'Confirm accept',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _Row(icon: Icons.place, text: location),
              const SizedBox(height: 8),
              _Row(
                icon: Icons.access_time,
                text:
                    '${_formatTime(slot.startTime)} – ${_formatTime(slot.endTime)}',
              ),
              const SizedBox(height: 8),
              // Terms/notes banner
              if (slot.notes != null && slot.notes!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.gavel, size: 16, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Terms & Notes',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              slot.notes!,
                              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              ValueListenableBuilder<String>(
                valueListenable: AppPreferences.instance.currencyCode,
                builder: (context, _, _) {
                  if (layout != null && _selectedSeats.isEmpty) {
                    return const _Row(
                      icon: Icons.payments,
                      text: 'Select seat(s) to see price',
                    );
                  }
                  final isLease = slot.serviceType.name == 'lease';
                  final deposit = isLease ? (slot.securityDeposit ?? 0.0) : 0.0;
                  
                  // Full post mode: show breakdown
                  if (isFullPostMode) {
                    final quantity = remainingCapacity > 0 ? remainingCapacity : slot.capacity;
                    final pricePerSeat = slot.price.toInt();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Row(
                          icon: Icons.info_outline,
                          text: 'Full Post Mode: All $quantity slots',
                        ),
                        const SizedBox(height: 4),
                        _Row(
                          icon: Icons.payments,
                          text: '${AppPreferences.instance.formatMoney(pricePerSeat)} × $quantity = ${AppPreferences.instance.formatMoney(totalPrice)}',
                        ),
                      ],
                    );
                  }
                  
                  if (isLease && deposit > 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Row(
                          icon: Icons.payments,
                          text: 'Lease: ${AppPreferences.instance.formatMoney(totalPrice)}',
                        ),
                        const SizedBox(height: 4),
                        _Row(
                          icon: Icons.security,
                          text: 'Security deposit: ${AppPreferences.instance.formatMoney(deposit.toInt())} (refundable on handover)',
                        ),
                        const SizedBox(height: 4),
                        _Row(
                          icon: Icons.receipt_long,
                          text: 'Total: ${AppPreferences.instance.formatMoney((totalPrice + deposit).toInt())}',
                        ),
                      ],
                    );
                  }
                  return _Row(
                    icon: Icons.payments,
                    text: AppPreferences.instance.formatMoney(totalPrice),
                  );
                },
              ),
              const Divider(height: 24),
              
              // Seat Layout (show first if available)
              if (layout != null) ...[
                const Text(
                  'Select your seat',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _SeatGrid(
                  layout: layout,
                  cellSize: _cellSize,
                  bookedSeatKeys: bookedSeatKeys,
                  selectedSeats: _selectedSeats,
                  remainingCapacity: remainingCapacity,
                  passengerForms: _passengerForms,
                  onSeatToggled: (key) {
                    setState(() {
                      if (_selectedSeats.contains(key)) {
                        _selectedSeats.remove(key);
                      } else {
                        if (_selectedSeats.length >= remainingCapacity) return;
                        _selectedSeats.add(key);
                      }
                      _updatePassengerFormsCount();
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (_selectedSeats.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shopping_cart, size: 16, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Selected: ${_selectedSeats.length} seat(s)',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedSeats.map((seatKey) {
                            final cell = layout!.cells[seatKey];
                            return Chip(
                              label: Text(cell?.seatName ?? seatKey),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setState(() {
                                  _selectedSeats.remove(seatKey);
                                  _updatePassengerFormsCount();
                                });
                              },
                              backgroundColor: Colors.green.shade100,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Divider(height: 24),
              ],
              
              // Parcel sender details OR passenger forms
              if (widget.slot.serviceType == ServiceType.parcel) ...[
                const Text(
                  '📦 Sender Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passengerForms.isNotEmpty ? _passengerForms[0].nameController : TextEditingController(),
                  decoration: const InputDecoration(
                    labelText: 'Sender name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passengerForms.isNotEmpty ? _passengerForms[0].phoneController : TextEditingController(),
                  decoration: const InputDecoration(
                    labelText: 'Sender phone *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passengerForms.isNotEmpty ? _passengerForms[0].emailController : TextEditingController(),
                  decoration: const InputDecoration(
                    labelText: 'Recipient contact *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.contact_phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passengerForms.isNotEmpty ? _passengerForms[0].ageController : TextEditingController(),
                  decoration: const InputDecoration(
                    labelText: 'Parcel description (optional)',
                    hintText: 'e.g. Documents, Electronics, Clothes',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory_2),
                  ),
                ),
                const SizedBox(height: 8),
              ] else ...[
              ValueListenableBuilder<List<Passenger>>(
                valueListenable: PassengerRepository.instance.savedPassengers,
                builder: (context, saved, _) {
                  if (saved.isEmpty || _passengerForms.isEmpty) return const SizedBox();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saved Passengers (tap to quick-fill)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: saved.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final p = saved[index];
                            return ActionChip(
                              avatar: const Icon(
                                Icons.person_outline,
                                size: 16,
                              ),
                              label: Text(p.name),
                              onPressed: () {
                                _showPassengerFormSelector(p);
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
              // Multiple passenger forms
              if (_passengerForms.isNotEmpty && (hasSeatLayout ? _selectedSeats.isNotEmpty : true))
                ...List.generate(_passengerForms.length, (index) {
                  final form = _passengerForms[index];
                  final seatsList = _selectedSeats.toList();
                  final seatKey = index < seatsList.length ? seatsList[index] : '';
                  final cell = layout?.cells[seatKey];
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (index > 0) const Divider(height: 24),
                      Text(
                        hasSeatLayout
                            ? 'Passenger ${index + 1} - Seat: ${cell?.seatName ?? seatKey}'
                            : 'Passenger ${index + 1}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: form.nameController,
                      decoration: const InputDecoration(
                        labelText: 'Passenger name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: form.ageController,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cake),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: form.phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone number (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: form.emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SeatGender>(
                      initialValue: form.gender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: SeatGender.any, child: Text('Any')),
                        DropdownMenuItem(value: SeatGender.male, child: Text('Male')),
                        DropdownMenuItem(
                          value: SeatGender.female,
                          child: Text('Female'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          form.gender = v;
                        });
                      },
                    ),
                  ],
                );
              }),
              CheckboxListTile(
                value: _savePassengers,
                onChanged: (v) => setState(() => _savePassengers = v ?? false),
                title: const Text(
                  'Save all passengers for future use',
                  style: TextStyle(fontSize: 13),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              ], // end else (non-parcel)
              if (!hasSeatLayout) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      isFullPostMode ? 'All Remaining Slots' : 'Quantity',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: isFullPostMode || remainingCapacity <= 0 || _quantity <= 1
                          ? null
                          : () {
                              setState(() {
                                _quantity -= 1;
                                _updatePassengerFormsCount();
                              });
                            },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$_quantity'),
                    IconButton(
                      onPressed: isFullPostMode || remainingCapacity <= 0 || _quantity >= remainingCapacity
                          ? null
                          : () {
                              setState(() {
                                _quantity += 1;
                                _updatePassengerFormsCount();
                              });
                            },
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                if (isFullPostMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Must book all ${remainingCapacity > 0 ? remainingCapacity : slot.capacity} remaining slots in this post',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : () async {
                              if (_isProcessing) return;
                              setState(() {
                                _isProcessing = true;
                              });

                              bool shouldResetProcessing = true;

                              try {
                                final isParcel = widget.slot.serviceType == ServiceType.parcel;

                                // Validate forms
                                for (int i = 0; i < _passengerForms.length; i++) {
                                  final form = _passengerForms[i];
                                  final name = form.nameController.text.trim();
                                  
                                  if (name.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isParcel
                                            ? 'Please enter sender name'
                                            : 'Please enter name for Passenger ${i + 1}'),
                                      ),
                                    );
                                    return;
                                  }

                                  final phone = form.phoneController.text.trim();
                                  if (isParcel && phone.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please enter sender phone')),
                                    );
                                    return;
                                  }
                                  if (phone.isNotEmpty && phone.length < 8) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isParcel
                                            ? 'Invalid sender phone number'
                                            : 'Invalid phone for Passenger ${i + 1}'),
                                      ),
                                    );
                                    return;
                                  }

                                  // Recipient contact required for parcel
                                  if (isParcel) {
                                    final recipient = form.emailController.text.trim();
                                    if (recipient.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please enter recipient contact')),
                                      );
                                      return;
                                    }
                                    if (recipient.length < 8) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Invalid recipient contact number')),
                                      );
                                      return;
                                    }
                                  }

                                  // Skip email/age validation for parcel
                                  if (!isParcel) {
                                  final email = form.emailController.text.trim();
                                  if (email.isNotEmpty && !email.contains('@')) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Invalid email for Passenger ${i + 1}'),
                                      ),
                                    );
                                    return;
                                  }

                                  final ageText = form.ageController.text.trim();
                                  final age = ageText.isEmpty ? 18 : int.tryParse(ageText);
                                  if (age == null || age <= 0 || age > 120) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Invalid age for Passenger ${i + 1} (1-120)'),
                                      ),
                                    );
                                    return;
                                  }
                                  } // end if (!isParcel)
                                }

                                if (hasSeatLayout && _selectedSeats.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please select at least one seat'),
                                    ),
                                  );
                                  return;
                                }

                                if (!hasSeatLayout && remainingCapacity <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('No capacity remaining'),
                                    ),
                                  );
                                  return;
                                }

                                // Save all passengers if requested
                                if (_savePassengers) {
                                  for (final form in _passengerForms) {
                                    final ageText = form.ageController.text.trim();
                                    final age = ageText.isEmpty ? 18 : (int.tryParse(ageText) ?? 18);
                                    await PassengerRepository.instance.savePassenger(
                                      Passenger(
                                        id: DateTime.now().millisecondsSinceEpoch
                                            .toString(),
                                        name: form.nameController.text.trim(),
                                        age: age,
                                        gender: form.gender,
                                      ),
                                    );
                                  }
                                }

                                if (!context.mounted) return;

                                if (_passengerForms.isEmpty) {
                                  Navigator.pop(context);
                                  return;
                                }

                                final seatKeysOrdered = hasSeatLayout
                                    ? _selectedSeats.toList(growable: false)
                                    : List<String?>.filled(_quantity, null, growable: false);

                                final ages = _passengerForms
                                    .map((f) {
                                      if (isParcel) return 0; // not applicable for parcel
                                      final ageText = f.ageController.text.trim();
                                      return ageText.isEmpty ? 18 : (int.tryParse(ageText) ?? 18);
                                    })
                                    .toList(growable: false);

                                final phones = _passengerForms
                                    .map((f) {
                                      final t = f.phoneController.text.trim();
                                      return t.isEmpty ? null : t;
                                    })
                                    .toList(growable: false);

                                final emails = _passengerForms
                                    .map((f) {
                                      final t = f.emailController.text.trim();
                                      return t.isEmpty ? null : t;
                                    })
                                    .toList(growable: false);

                                final names = _passengerForms
                                    .map((f) => f.nameController.text.trim())
                                    .toList(growable: false);

                                final genders = _passengerForms
                                    .map((f) => f.gender)
                                    .toList(growable: false);
                                
                                // Calculate total amount
                                final isLease = widget.slot.serviceType.name == 'lease';
                                final deposit = isLease ? (widget.slot.securityDeposit ?? 0.0) : 0.0;
                                final basePrice = _calculateTotalPrice() - deposit;
                                final totalAmount = _calculateTotalPrice();
                                final amountInPaise = (totalAmount * 100).toInt();

                                if (amountInPaise < 100) {
                                  // Free booking or amount < 1 INR (Razorpay minimum is ₹1)
                                  Navigator.pop(
                                    context,
                                    BookingConfirmResult(
                                      seatKeys: seatKeysOrdered,
                                      userGenders: genders,
                                      userNames: names,
                                      userAges: ages,
                                      userPhones: phones,
                                      userEmails: emails,
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✅ Booking confirmed (Free/Coupon applied).'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  return;
                                }
                                
                                final currentUser = AuthRepository.instance.currentUser;
                                
                                if (currentUser == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please login to continue')),
                                  );
                                  return;
                                }

                                _showOrderLoadingDialog();
                                
                                try {
                                  // Calculate application fee (5% commission - covers gateway fees + profit)
                                  final commissionAmount = (amountInPaise * 0.05).toInt();

                                  // Detect country from slot location to route payment gateway
                                  final slotLocation = (widget.slot.fromLocation?.isNotEmpty ?? false)
                                      ? widget.slot.fromLocation
                                      : widget.slot.baseLocation;
                                  // Default to 'IN' if country can't be detected (India-first app)
                                  final countryCode = PaymentService.countryCodeFromLocation(slotLocation) ?? 'IN';
                                  final currency = (countryCode == 'IN') ? 'inr' : 'usd';

                                  final profile = ProfileRepository.instance.profile.value;

                                  // Always use the real payment gateway (test keys work with real Razorpay test flow)
                                  final bookingResult = await PaymentService.instance.processPayment(
                                    amountInPaise: amountInPaise,
                                    currency: currency,
                                    countryCode: countryCode,
                                    providerId: widget.providerId,
                                    slotId: widget.slot.id,
                                    userName: names.isNotEmpty ? names.first : 'User',
                                    userEmail: emails.isNotEmpty && emails.first != null
                                        ? emails.first!
                                        : '',
                                    userPhone: phones.isNotEmpty && phones.first != null
                                        ? phones.first!
                                        : (profile.phone ?? ''),
                                    description: 'Booking: ${(widget.slot.fromLocation?.isNotEmpty ?? false) ? widget.slot.fromLocation! : (widget.slot.baseLocation ?? '')}',
                                    commissionAmount: commissionAmount,
                                  );

                                  if (!context.mounted) return;
                                  _closeOrderLoadingDialogIfAny();

                                  if (bookingResult != null && bookingResult['error'] == null) {
                                    // Extract booking details (works for both Razorpay and Stripe)
                                    final paymentIntentId = bookingResult['payment_intent_id'] as String?;
                                    final clientSecret = bookingResult['client_secret'] as String?;
                                    final otp = bookingResult['otp'] as String?;
                                    final countdownEndStr = bookingResult['countdown_end_time'] as String?;
                                    final gateway = bookingResult['gateway'] as String? ?? 'stripe';
                                    final isWebRedirect = bookingResult['web_redirect'] == true;

                                    debugPrint('📱 Payment result: gateway=$gateway, webRedirect=$isWebRedirect, otp=$otp');

                                    // Web redirect: payment is pending, user was sent to checkout
                                    if (isWebRedirect) {
                                      // Don't create local booking yet - wait for payment completion
                                      Navigator.pop(context);
                                      
                                      // Show popup dialog instead of just snackbar
                                      _showWebPaymentPendingDialog(
                                        context,
                                        gateway.contains('razorpay') ? 'Razorpay' : 'Stripe',
                                      );
                                      return;
                                    }
                                    
                                    DateTime? countdownEnd;
                                    if (countdownEndStr != null) {
                                      try {
                                        countdownEnd = DateTime.parse(countdownEndStr);
                                      } catch (_) {}
                                    }

                                    // Create local booking with payment details
                                    // Get the selected seat's raw display name (e.g. "A2")
                                    final selectedSeatKey = _selectedSeats.isNotEmpty ? _selectedSeats.first : null;
                                    final selectedCell = selectedSeatKey != null
                                        ? SeatLayoutRepository.instance
                                            .getLayout(widget.slot.seatLayoutOwnerId ?? '')
                                            ?.cells[selectedSeatKey]
                                        : null;
                                    final seatKeyRaw = selectedCell?.seatName ?? selectedSeatKey;

                                    final localBooking = await BookingRepository.instance.createBooking(
                                      slotId: widget.slot.id,
                                      providerId: widget.providerId,
                                      // ── provider snapshot from slot ──────────
                                      providerName: widget.slot.providerName,
                                      userId: currentUser.id,
                                      defaultCapacity: widget.slot.capacity,
                                      price: basePrice,
                                      seatKey: selectedSeatKey,
                                      seatKeyRaw: seatKeyRaw,
                                      userName: names.isNotEmpty ? names.first : null,
                                      userAge: ages.isNotEmpty ? ages.first : null,
                                      userPhone: phones.isNotEmpty ? phones.first : null,
                                      userEmail: emails.isNotEmpty ? emails.first : null,
                                      userGender: genders.isNotEmpty ? genders.first : null,
                                      stripePaymentIntentId: paymentIntentId,
                                      stripeClientSecret: clientSecret,
                                      countdownEndTime: countdownEnd,
                                      otp: otp,
                                      securityDeposit: deposit > 0 ? deposit : null,
                                      termsSnapshot: widget.slot.notes?.isNotEmpty == true
                                          ? widget.slot.notes
                                          : null,
                                      // ── slot details snapshot ─────────────────
                                      serviceType: widget.slot.serviceType,
                                      postMode: widget.slot.postMode,
                                      bookingMode: widget.slot.bookingMode.name == 'full'
                                          ? BookingMode.full
                                          : BookingMode.shared,
                                      vehicleId: widget.slot.vehicleId,
                                      slotStartTime: widget.slot.startTime,
                                      slotEndTime: widget.slot.endTime,
                                      slotCapacity: widget.slot.capacity,
                                      pickupOption: widget.slot.pickupOption.name,
                                      withOperator: widget.slot.withOperator,
                                      fuelPolicy: widget.slot.fuelPolicy,
                                      maxWeight: widget.slot.maxWeight,
                                      maxLength: widget.slot.maxLength,
                                      maxWidth: widget.slot.maxWidth,
                                      maxHeight: widget.slot.maxHeight,
                                      // lease-specific snapshot
                                      leaseDuration: widget.slot.leaseDuration,
                                      insuranceIncluded: widget.slot.insuranceIncluded,
                                      leaseTerms: widget.slot.leaseTerms,
                                      waitForFullDeadlineHours: widget.slot.waitForFullDeadlineHours,
                                      // slot_layout: full layout JSONB snapshot
                                      slotLayoutSnapshot: widget.slot.seatLayoutStructure?.toJson(),
                                      // provider vehicle images snapshot
                                      providerImageUrls: () {
                                        final v = VehicleRepository.instance
                                            .getById(widget.slot.vehicleId);
                                        if (v == null) return <String>[];
                                        return [
                                          if (v.profileImage != null &&
                                              v.profileImage!.isNotEmpty)
                                            v.profileImage!,
                                          ...v.galleryImages
                                              .where((e) => e.isNotEmpty),
                                        ];
                                      }(),
                                      // payment method
                                      paymentMethod: gateway.contains('razorpay')
                                          ? 'razorpay'
                                          : 'stripe',
                                      // ── location snapshot from slot ──────────
                                      routeType: widget.slot.slotType.name == 'fromTo'
                                          ? 'from_to'
                                          : 'base_range',
                                      fromAddress: _locName(widget.slot.fromLocation),
                                      fromLat: _locLat(widget.slot.fromLocation),
                                      fromLng: _locLng(widget.slot.fromLocation),
                                      toAddress: _locName(widget.slot.toLocation),
                                      toLat: _locLat(widget.slot.toLocation),
                                      toLng: _locLng(widget.slot.toLocation),
                                      baseAddress: _locName(widget.slot.baseLocation),
                                      baseLat: _locLat(widget.slot.baseLocation),
                                      baseLng: _locLng(widget.slot.baseLocation),
                                      rangeKm: widget.slot.radius,
                                    );

                                    if (localBooking != null && context.mounted) {
                                      // Don't return result - booking already created
                                      // Just close the sheet
                                      Navigator.pop(context);
                                      
                                      // Go to Requests tab
                                      mainTabIndex.value = 1;
                                      Navigator.of(context).popUntil((route) => route.isFirst);

                                      final gatewayLabel = gateway == 'razorpay' ? 'Razorpay' : 'Stripe';
                                      
                                      // Show success popup dialog with OTP
                                      _showPaymentSuccessDialog(
                                        context,
                                        gatewayLabel,
                                        otp,
                                        localBooking.id,
                                      );
                                    }
                                  } else {
                                    final reason = bookingResult?['error'] as String?;
                                    final message = (reason != null && reason.isNotEmpty)
                                        ? reason
                                        : 'Payment cancelled.';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(message),
                                        backgroundColor: Colors.black87,
                                        duration: const Duration(seconds: 6),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (!context.mounted) return;
                                  _closeOrderLoadingDialogIfAny();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              } finally {
                                if (mounted && shouldResetProcessing) {
                                  setState(() {
                                    _isProcessing = false;
                                  });
                                }
                              }
                            },
                      child: _isProcessing 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Pay & Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Convert SimpleSeatLayout (from Supabase) to SeatLayout (for UI display).
  /// Used when the layout is not in the local SeatLayoutRepository.
  SeatLayout _simpleSeatLayoutToSeatLayout(SimpleSeatLayout simple) {
    final cells = <String, LayoutCell>{};
    int maxRow = 0;
    int maxCol = 0;

    for (final item in simple.layout) {
      final row = item.row;
      final col = item.col;
      if (row > maxRow) maxRow = row;
      if (col > maxCol) maxCol = col;

      final key = '$row:$col';
      SeatGender gender = SeatGender.any;
      if (item is PassengerSeat) {
        final g = item.allowedGender.toLowerCase();
        if (g == 'male') {
          gender = SeatGender.male;
        } else if (g == 'female') { gender = SeatGender.female; }
      }

      cells[key] = LayoutCell(
        row: row,
        col: col,
        type: item.isGap ? CellType.space : CellType.seat,
        seatName: item.key,
        price: item.price,
        gender: gender,
        isLocked: item.isLocked || item.isBooked,
      );
    }

    return SeatLayout(
      id: widget.slot.id,
      name: 'Seat Layout',
      rows: maxRow + 1,
      cols: maxCol + 1,
      cells: cells,
    );
  }

  double _calculateTotalPrice() {
    final isFullPostMode = widget.slot.postMode == PostMode.fullPost;
    final remainingCapacity = BookingRepository.instance.getRemainingCapacity(
      widget.slot.id,
      widget.slot.capacity,
    );
    
    double basePrice;
    
    if (isFullPostMode) {
      // Full post mode: price × remaining capacity
      final quantity = remainingCapacity > 0 ? remainingCapacity : widget.slot.capacity;
      basePrice = widget.slot.price * quantity;
    } else if (_selectedSeats.isEmpty) {
      basePrice = widget.slot.price * _quantity;
    } else {
      final layout = SeatLayoutRepository.instance.getLayout(
        widget.slot.seatLayoutOwnerId ?? '',
      );

      if (layout == null) {
        basePrice = widget.slot.price * _quantity;
      } else {
        double total = 0.0;
        for (final seatKey in _selectedSeats) {
          final cell = layout.cells[seatKey];
          if (cell != null && cell.price != null) {
            total += cell.price!;
          }
        }
        basePrice = total > 0 ? total : widget.slot.price * _quantity;
      }
    }

    // Add security deposit for lease slots
    final isLease = widget.slot.serviceType.name == 'lease';
    final deposit = isLease ? (widget.slot.securityDeposit ?? 0.0) : 0.0;
    return basePrice + deposit;
  }

  static String _formatTime(DateTime time) {
    return TimezoneUtils.formatTimeWithTimezone(time, show24Hour: true);
  }

  // ── Location string helpers ─────────────────────────────────────────────
  // Location strings are stored as "Display Name|lat,lng|keywords"

  static String? _locName(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return raw.contains('|') ? raw.split('|').first.trim() : raw.trim();
  }

  static double? _locLat(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('|');
    if (parts.length < 2) return null;
    final coords = parts[1].split(',');
    if (coords.isEmpty) return null;
    return double.tryParse(coords[0].trim());
  }

  static double? _locLng(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('|');
    if (parts.length < 2) return null;
    final coords = parts[1].split(',');
    if (coords.length < 2) return null;
    return double.tryParse(coords[1].trim());
  }

  /// Show success dialog after payment completion
  void _showPaymentSuccessDialog(
    BuildContext context,
    String gatewayLabel,
    String? otp,
    String bookingId,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Payment Successful!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your booking has been confirmed via $gatewayLabel.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (otp != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your OTP Code:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          otp,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Share this code with the provider to complete your booking.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Booking ID: $bookingId',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Navigate to Requests tab
              mainTabIndex.value = 1;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('View My Bookings'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Navigate to Requests tab
              mainTabIndex.value = 1;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show pending dialog for web payment redirect
  void _showWebPaymentPendingDialog(BuildContext context, String gatewayLabel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.open_in_new, color: Colors.orange[600], size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Opening $gatewayLabel',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You will be redirected to $gatewayLabel to complete your payment.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Important',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Complete the payment on the checkout page\n'
                    '• Your booking will be confirmed automatically\n'
                    '• Check "My Bookings" tab after payment',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Row({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Stateless seat grid widget — avoids closure null-safety issues with layout
class _SeatGrid extends StatelessWidget {
  final SeatLayout layout;
  final double cellSize;
  final Set<String> bookedSeatKeys;
  final Set<String> selectedSeats;
  final int remainingCapacity;
  final List<PassengerFormData> passengerForms;
  final void Function(String key) onSeatToggled;

  const _SeatGrid({
    required this.layout,
    required this.cellSize,
    required this.bookedSeatKeys,
    required this.selectedSeats,
    required this.remainingCapacity,
    required this.passengerForms,
    required this.onSeatToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: layout.rows * cellSize,
        width: layout.cols * cellSize,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: layout.cols,
            childAspectRatio: 1,
          ),
          itemCount: layout.rows * layout.cols,
          itemBuilder: (context, index) {
            final row = index ~/ layout.cols;
            final col = index % layout.cols;
            final key = '$row:$col';
            final cell = layout.cells[key];
            final type = cell?.type ?? CellType.empty;

            if (type == CellType.space || type == CellType.empty) {
              return const SizedBox.expand();
            }

            final isBooked = bookedSeatKeys.contains(key);
            final isSelected = selectedSeats.contains(key);
            final isLocked = cell?.isLocked ?? false;
            final seatGender = cell?.gender ?? SeatGender.any;

            final genderMatch = seatGender == SeatGender.any ||
                passengerForms.any((f) =>
                    f.gender == SeatGender.any || f.gender == seatGender);

            Color bgColor;
            if (isBooked) {
              bgColor = Colors.red.shade300;
            } else if (isLocked) {
              bgColor = Colors.grey.shade400;
            } else if (isSelected) {
              bgColor = Colors.green;
            } else if (!genderMatch) {
              bgColor = Colors.orange.shade200;
            } else {
              bgColor = Colors.blue.shade100;
            }

            return GestureDetector(
              onTap: () {
                if (isBooked || isLocked || !genderMatch) return;
                onSeatToggled(key);
              },
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected ? Colors.green.shade700 : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    cell?.seatName ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isBooked || isLocked ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}



