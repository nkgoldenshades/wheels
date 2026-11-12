import 'package:flutter/material.dart';
import '../services/user_post_repository.dart';
import '../models/slot_type.dart';
import '../models/service_type.dart';
import '../models/vehicle.dart';
import '../services/vehicle_repository.dart';
import '../services/auth_repository.dart';
import '../services/app_preferences.dart';

class AcceptanceConfirmResult {
  final String operatorName;
  final String operatorPhone;
  final String? operatorGender;
  final String vehicleType;
  final String? vehicleId;

  const AcceptanceConfirmResult({
    required this.operatorName,
    required this.operatorPhone,
    this.operatorGender,
    required this.vehicleType,
    this.vehicleId,
  });
}

class AcceptanceConfirmSheet extends StatefulWidget {
  final UserPost post;

  const AcceptanceConfirmSheet({super.key, required this.post});

  @override
  State<AcceptanceConfirmSheet> createState() => _AcceptanceConfirmSheetState();
}

class _AcceptanceConfirmSheetState extends State<AcceptanceConfirmSheet> {
  final _operatorNameController = TextEditingController();
  final _operatorPhoneController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  String? _selectedGender;
  Vehicle? _selectedVehicle;

  @override
  void initState() {
    super.initState();
    _loadVehicleData();
  }

  void _loadVehicleData() {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser != null) {
      final providerVehicles = VehicleRepository.instance.allVehicles
          .where((v) => v.userId == currentUser.id)
          .toList();
      if (providerVehicles.isNotEmpty) {
        setState(() {
          _selectedVehicle = providerVehicles.first;
          _operatorNameController.text = _selectedVehicle!.operatorName ?? '';
          _operatorPhoneController.text = _selectedVehicle!.operatorPhone ?? '';
          _vehicleTypeController.text =
              '${_selectedVehicle!.name}${_selectedVehicle!.year != null ? " (${_selectedVehicle!.year})" : ""}';
          _selectedGender = _selectedVehicle!.operatorGender;
        });
      }
    }
  }

  @override
  void dispose() {
    _operatorNameController.dispose();
    _operatorPhoneController.dispose();
    _vehicleTypeController.dispose();
    super.dispose();
  }

  void _confirm() {
    // Validate required fields
    if (_operatorNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operator name is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_operatorPhoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operator phone is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_vehicleTypeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehicle type is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      AcceptanceConfirmResult(
        operatorName: _operatorNameController.text.trim(),
        operatorPhone: _operatorPhoneController.text.trim(),
        operatorGender: _selectedGender,
        vehicleType: _vehicleTypeController.text.trim(),
        vehicleId: _selectedVehicle?.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final location = post.slotType == SlotType.fromTo
        ? '${post.fromLocation} → ${post.toLocation}'
        : 'Based in ${post.baseLocation} · ${post.radius?.toInt()} km range';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirm acceptance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Request details
              _Row(icon: Icons.place, text: location),
              const SizedBox(height: 8),
              _Row(
                icon: Icons.access_time,
                text:
                    '${_formatTime(post.startTime)} – ${_formatTime(post.endTime)}',
              ),
              const SizedBox(height: 8),
              _Row(
                icon: Icons.people,
                text:
                    '${post.persons} ${post.serviceType == ServiceType.passenger ? "passenger(s)" : "unit(s)"}',
              ),
              const SizedBox(height: 8),

              // Customer budget
              ValueListenableBuilder<String>(
                valueListenable: AppPreferences.instance.currencyCode,
                builder: (context, _, _) {
                  return _Row(
                    icon: Icons.payments,
                    text:
                        'Budget: ${AppPreferences.instance.formatMoney(post.budget.toInt())}',
                  );
                },
              ),

              // Terms/notes banner
              if (post.notes != null && post.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                              'Customer Requirements',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              post.notes!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Parcel dimensions if applicable
              if (post.serviceType == ServiceType.parcel) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2,
                            size: 16,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Parcel Dimensions',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (post.parcelWeight != null)
                        Text(
                          'Weight: ${post.parcelWeight} kg',
                          style: const TextStyle(fontSize: 13),
                        ),
                      if (post.parcelLength != null)
                        Text(
                          'Length: ${post.parcelLength} cm',
                          style: const TextStyle(fontSize: 13),
                        ),
                      if (post.parcelWidth != null)
                        Text(
                          'Width: ${post.parcelWidth} cm',
                          style: const TextStyle(fontSize: 13),
                        ),
                      if (post.parcelHeight != null)
                        Text(
                          'Height: ${post.parcelHeight} cm',
                          style: const TextStyle(fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 24),

              // Operator & Vehicle Details Form
              const Text(
                'Your Operator & Vehicle Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _operatorNameController,
                decoration: const InputDecoration(
                  labelText: 'Operator Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                  helperText: 'Required',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _operatorPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Operator Phone *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  helperText: 'Required',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Operator Gender (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people_outline),
                ),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _vehicleTypeController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_car),
                  helperText: 'e.g., Toyota Innova (2020)',
                ),
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: 24),

              // Confirm button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'ACCEPT REQUEST',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}
