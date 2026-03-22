import 'package:flutter/material.dart';

import '../models/slot.dart';
import '../models/slot_type.dart';
import '../models/seat_layout.dart';
import '../models/booking.dart';
import '../models/passenger.dart';
import '../services/app_preferences.dart';
import '../services/booking_repository.dart';
import '../services/seat_layout_repository.dart';
import '../app_tab_controller.dart';
import '../services/passenger_repository.dart';
import '../services/profile_repository.dart';
import '../services/stripe_service.dart';
import '../services/payment_service.dart';
import '../services/auth_repository.dart';

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
    final SeatLayout? layout = layoutOwnerId == null
        ? null
        : SeatLayoutRepository.instance.getLayout(layoutOwnerId);

    final hasSeatLayout = layout != null;

    final remainingCapacity = BookingRepository.instance.getRemainingCapacity(
      slot.id,
      slot.capacity,
    );

    if (!hasSeatLayout) {
      if (_quantity < 1) {
        _quantity = 1;
      }
      if (remainingCapacity > 0 && _quantity > remainingCapacity) {
        _quantity = remainingCapacity;
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
              b.status != BookingStatus.rejected,
        )
        .map((b) => b.seatKey!)
        .toSet();

    // Validate selected seats against all passenger genders
    if (layout != null) {
      _selectedSeats.removeWhere((seatKey) {
        final selected = layout.cells[seatKey];
        if (selected == null ||
            selected.type != CellType.seat ||
            selected.isLocked) {
          return true;
        }
        // Check if any passenger gender matches this seat
        if (selected.gender == SeatGender.any) return false;
        return !_passengerForms.any((form) => 
          form.gender == SeatGender.any || form.gender == selected.gender
        );
      });
    }

    // Calculate total price for all selected seats
    final totalPrice = layout != null && _selectedSeats.isNotEmpty
        ? _selectedSeats.fold<int>(
            0,
            (sum, seatKey) => sum + (layout.cells[seatKey]?.price ?? 0),
          )
        : slot.price.toInt();

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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: SizedBox(
                    height: layout.rows * _cellSize,
                    width: layout.cols * _cellSize,
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
                        final isSelected = _selectedSeats.contains(key);
                        final isLocked = cell?.isLocked ?? false;
                        final seatGender = cell?.gender ?? SeatGender.any;
                        
                        // Check if any passenger can sit here
                        final genderMatch = seatGender == SeatGender.any ||
                            _passengerForms.any((form) => 
                              form.gender == SeatGender.any || form.gender == seatGender
                            );

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
                            setState(() {
                              if (isSelected) {
                                _selectedSeats.remove(key);
                              } else {
                                if (_selectedSeats.length >= remainingCapacity) {
                                  return;
                                }
                                _selectedSeats.add(key);
                              }
                              _updatePassengerFormsCount();
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.green.shade700
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                cell?.seatName ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isBooked || isLocked
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Cart summary
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedSeats.map((seatKey) {
                            final cell = layout.cells[seatKey];
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
                                // Show dialog to select which form to fill
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
              if (!hasSeatLayout) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Quantity',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: remainingCapacity <= 0 || _quantity <= 1
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
                      onPressed: remainingCapacity <= 0 || _quantity >= remainingCapacity
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
                                // Validate all passenger forms
                                for (int i = 0; i < _passengerForms.length; i++) {
                                  final form = _passengerForms[i];
                                  final name = form.nameController.text.trim();
                                  
                                  if (name.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Please enter name for Passenger ${i + 1}'),
                                      ),
                                    );
                                    return;
                                  }

                                  final phone = form.phoneController.text.trim();
                                  if (phone.isNotEmpty && phone.length < 8) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Invalid phone for Passenger ${i + 1}'),
                                      ),
                                    );
                                    return;
                                  }

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
                                    final age = ageText.isEmpty ? 18 : int.parse(ageText);
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
                                      final ageText = f.ageController.text.trim();
                                      return ageText.isEmpty ? 18 : int.parse(ageText);
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
                                  // Calculate application fee (10% commission)
                                  final commissionAmount = (amountInPaise * 0.1).toInt();

                                  // Detect country from slot location to route payment gateway
                                  final slotLocation = (widget.slot.fromLocation?.isNotEmpty ?? false)
                                      ? widget.slot.fromLocation
                                      : widget.slot.baseLocation;
                                  final countryCode = PaymentService.countryCodeFromLocation(slotLocation);
                                  final currency = (countryCode == 'IN') ? 'inr' : 'usd';

                                  // Route to Razorpay (India) or Stripe (international)
                                  final profile = ProfileRepository.instance.profile.value;
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

                                    // Web redirect: payment is pending, user was sent to checkout
                                    if (isWebRedirect) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '🔗 Redirected to ${gateway.contains('razorpay') ? 'Razorpay' : 'Stripe'} checkout. '
                                            'Complete payment there — your booking will be confirmed automatically.',
                                          ),
                                          backgroundColor: Colors.blue,
                                          duration: const Duration(seconds: 8),
                                        ),
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
                                    final localBooking = await BookingRepository.instance.createBooking(
                                      slotId: widget.slot.id,
                                      providerId: widget.providerId,
                                      userId: currentUser.id,
                                      defaultCapacity: widget.slot.capacity,
                                      price: basePrice,
                                      seatKey: _selectedSeats.isNotEmpty ? _selectedSeats.first : null,
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
                                    );

                                    if (localBooking != null && context.mounted) {
                                      Navigator.pop(context);
                                      
                                      // Go to Requests tab
                                      mainTabIndex.value = 1;
                                      Navigator.of(context).popUntil((route) => route.isFirst);

                                      final gatewayLabel = gateway == 'razorpay' ? 'Razorpay' : 'Stripe';
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '✅ Booking confirmed via $gatewayLabel! OTP: ${otp ?? "Check Requests"}',
                                          ),
                                          backgroundColor: Colors.green,
                                          duration: const Duration(seconds: 5),
                                        ),
                                      );
                                    }
                                  } else {
                                    final reason = bookingResult?['error'] as String?;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(reason ?? 'Payment cancelled.'),
                                        backgroundColor: Colors.black54,
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
  
  double _calculateTotalPrice() {
    double basePrice;
    if (_selectedSeats.isEmpty) {
      basePrice = widget.slot.price;
    } else {
      final layout = SeatLayoutRepository.instance.getLayout(
        widget.slot.seatLayoutOwnerId ?? '',
      );

      if (layout == null) {
        basePrice = widget.slot.price;
      } else {
        double total = 0.0;
        for (final seatKey in _selectedSeats) {
          final cell = layout.cells[seatKey];
          if (cell != null && cell.price != null) {
            total += cell.price!;
          }
        }
        basePrice = total > 0 ? total : widget.slot.price;
      }
    }

    // Add security deposit for lease slots
    final isLease = widget.slot.serviceType.name == 'lease';
    final deposit = isLease ? (widget.slot.securityDeposit ?? 0.0) : 0.0;
    return basePrice + deposit;
  }

  static String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
