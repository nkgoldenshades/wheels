import 'package:flutter/material.dart';

import '../models/slot.dart';
import '../models/slot_type.dart';
import '../models/seat_layout.dart';
import '../models/booking.dart';
import '../models/passenger.dart';
import '../services/app_preferences.dart';
import '../services/booking_repository.dart';
import '../services/seat_layout_repository.dart';
import '../services/passenger_repository.dart';
import '../services/profile_repository.dart';
import '../services/razorpay_service.dart';
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
  final String? seatKey;
  final SeatGender userGender;
  final String userName;
  final int userAge;
  final String? userPhone;
  final String? userEmail;

  const BookingConfirmResult({
    required this.seatKey,
    required this.userGender,
    required this.userName,
    required this.userAge,
    required this.userPhone,
    required this.userEmail,
  });
}

class BookingConfirmSheet extends StatefulWidget {
  final Slot slot;
  final bool isOffer;

  const BookingConfirmSheet({
    super.key,
    required this.slot,
    required this.isOffer,
  });

  @override
  State<BookingConfirmSheet> createState() => _BookingConfirmSheetState();
}

class _BookingConfirmSheetState extends State<BookingConfirmSheet> {
  Set<String> _selectedSeats = {};
  
  // Multiple passenger forms - one per seat
  List<PassengerFormData> _passengerForms = [];
  
  bool _savePassengers = false;

  static const double _cellSize = 56;

  @override
  void initState() {
    super.initState();
    _selectedSeats = {};
    _passengerForms = [];
    
    // Initialize Razorpay
    try {
      RazorpayService.instance.initialize();
    } catch (e) {
      debugPrint('Failed to initialize Razorpay: $e');
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
  
  void _updatePassengerFormsCount() {
    final seatsCount = _selectedSeats.length;
    if (seatsCount == 0) return;
    
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
              if (_passengerForms.isNotEmpty && _selectedSeats.isNotEmpty)
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
                        'Passenger ${index + 1} - Seat: ${cell?.seatName ?? seatKey}',
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
                      onPressed: () async {
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
                          final age = int.tryParse(ageText);
                          if (age == null || age <= 0 || age > 120) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Invalid age for Passenger ${i + 1} (1-120)'),
                              ),
                            );
                            return;
                          }
                        }

                        if (layout != null && _selectedSeats.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select at least one seat'),
                            ),
                          );
                          return;
                        }

                        // Save all passengers if requested
                        if (_savePassengers) {
                          for (final form in _passengerForms) {
                            final age = int.parse(form.ageController.text.trim());
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

                        // Return first passenger data and first seat for now
                        if (_passengerForms.isEmpty) {
                          Navigator.pop(context);
                          return;
                        }
                        
                        final firstForm = _passengerForms.first;
                        final age = int.parse(firstForm.ageController.text.trim());
                        final phone = firstForm.phoneController.text.trim();
                        final email = firstForm.emailController.text.trim();
                        
                        // Calculate total amount
                        final totalAmount = _calculateTotalPrice();
                        final amountInPaise = (totalAmount * 100).toInt();
                        
                        final currentUser = AuthRepository.instance.currentUser;
                        
                        if (currentUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please login to continue')),
                          );
                          return;
                        }
                        
                        // Show loading while creating order
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                        
                        try {
                          // SECURE: Create order on server
                          final order = await PaymentService.instance.createOrder(
                            amount: amountInPaise,
                            receipt: 'booking_${DateTime.now().millisecondsSinceEpoch}',
                            notes: {
                              'slot_id': widget.slot.id,
                              'user_id': currentUser.id,
                              'seat_keys': _selectedSeats.join(','),
                            },
                          );
                          
                          if (!context.mounted) return;
                          Navigator.pop(context); // Close loading
                          
                          // Open Razorpay with server-generated order ID
                          RazorpayService.instance.openCheckout(
                            amount: order['amount'],
                            orderId: order['orderId'], // Real Razorpay order ID
                            name: firstForm.nameController.text.trim(),
                            description: 'Booking for ${widget.slot.fromLocation ?? widget.slot.baseLocation}',
                            email: email.isNotEmpty ? email : 'user@quickohunt.com',
                            contact: phone.isNotEmpty ? phone : '9999999999',
                            onSuccess: (response) async {
                              if (!context.mounted) return;
                              
                              // Show verifying dialog
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const AlertDialog(
                                  content: Row(
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(width: 16),
                                      Text('Verifying payment...'),
                                    ],
                                  ),
                                ),
                              );
                              
                              try {
                                // SECURE: Verify payment on server
                                final verified = await PaymentService.instance.verifyPayment(
                                  razorpayOrderId: response.orderId!,
                                  razorpayPaymentId: response.paymentId!,
                                  razorpaySignature: response.signature!,
                                );
                                
                                if (!context.mounted) return;
                                Navigator.pop(context); // Close verifying dialog
                                
                                if (verified['verified'] == true) {
                                  // Payment verified - NOW confirm booking
                                  Navigator.pop(
                                    context,
                                    BookingConfirmResult(
                                      seatKey: _selectedSeats.isEmpty ? null : _selectedSeats.first,
                                      userGender: firstForm.gender,
                                      userName: firstForm.nameController.text.trim(),
                                      userAge: age,
                                      userPhone: phone.isEmpty ? null : phone,
                                      userEmail: email.isEmpty ? null : email,
                                    ),
                                  );
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✅ Payment verified! Booking confirmed.'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  // Verification failed
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('❌ Payment verification failed. Contact support.'),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 10),
                                    ),
                                  );
                                }
                              } catch (e) {
                                // Network error during verification
                                if (!context.mounted) return;
                                Navigator.pop(context); // Close verifying dialog
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Verification error: $e\nPlease contact support with payment ID: ${response.paymentId}'),
                                    backgroundColor: Colors.orange,
                                    duration: const Duration(seconds: 10),
                                  ),
                                );
                              }
                            },
                            onFailure: (response) {
                              if (!context.mounted) return;
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Payment failed: ${response.message}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            },
                          );
                        } catch (e) {
                          // Error creating order
                          if (!context.mounted) return;
                          Navigator.pop(context); // Close loading
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to create order: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Text('Pay & Confirm'),
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
    if (_selectedSeats.isEmpty) {
      return widget.slot.price;
    }
    
    final layout = SeatLayoutRepository.instance.getLayout(
      widget.slot.seatLayoutOwnerId ?? '',
    );
    
    if (layout == null) return widget.slot.price;
    
    double total = 0.0;
    for (final seatKey in _selectedSeats) {
      final cell = layout.cells[seatKey];
      if (cell != null && cell.price != null) {
        total += cell.price!;
      }
    }
    
    return total > 0 ? total : widget.slot.price;
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
