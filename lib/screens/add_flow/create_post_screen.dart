import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../vehicle/vehicle_list_screen.dart';
import '../../models/service_type.dart';
import '../../models/slot_type.dart';
import '../../services/app_preferences.dart';
import '../../models/vehicle.dart';
import '../../models/slot.dart';
import '../../models/pickup_mode.dart';
import '../../services/slot_repository.dart';
import '../../services/user_slot_repository.dart';
import '../../services/content_filter_service.dart';
import '../../controllers/seat_layout_controller.dart';
import '../../models/seat_layout.dart';
import '../../screens/add_flow/seat_layout_builder_screen.dart';
import '../../services/seat_layout_repository.dart';
import '../../widgets/location_autocomplete_field.dart';
import '../../services/location_autocomplete_service.dart';

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

  // Pickup mode
  PickupMode _pickupMode = PickupMode.customerPickup;

  // Notes
  final _notesController = TextEditingController();

  // Working mode (only for working service)
  String _workingMode = 'On-site';

  bool _isPosting = false;

  String? _seatLayoutOwnerId;

  bool get _hasSeatLayoutSeats {
    final ownerId = _seatLayoutOwnerId;
    if (ownerId == null) return false;
    final layout = SeatLayoutRepository.instance.getLayout(ownerId);
    final seatCount =
        layout?.cells.values.where((c) => c.type == CellType.seat).length ?? 0;
    return seatCount > 0;
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
    _startTime = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    _endTime = DateTime(now.year, now.month, now.day, now.hour + 9, 0);
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _baseController.dispose();
    _radiusController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    _maxWeightController.dispose();
    _maxLengthController.dispose();
    _maxWidthController.dispose();
    _maxHeightController.dispose();
    _securityDepositController.dispose();
    _leaseTermsController.dispose();
    super.dispose();
  }

  Future<void> _selectTime({required bool isStart}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _startTime! : _endTime!),
    );
    if (picked != null) {
      final date = (isStart ? _startTime! : _endTime!);
      final newDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        picked.hour,
        picked.minute,
      );
      setState(() {
        if (isStart) {
          _startTime = newDateTime;
          // Ensure end time is after start time
          if (_endTime != null && _endTime!.isBefore(_startTime!)) {
            _endTime = _startTime!.add(const Duration(hours: 2));
          }
        } else {
          _endTime = newDateTime;
        }
      });
    }
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

  Future<LocationSuggestion?> _maybeGeocode(String text) async {
    if (text.isEmpty) return null;
    if (text.length < 3) return null;

    try {
      final results = await LocationAutocompleteService.instance.searchLocations(
        text,
      );
      if (results.isNotEmpty) return results.first;
    } catch (_) {}
    return null;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    double toRad(double deg) => deg * (3.141592653589793 / 180.0);
    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);
    final a = (dLat / 2) * (dLat / 2) +
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

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _showError('Unable to open maps');
    }
  }

  Future<void> _selectDate({required bool isStart}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startTime! : _endTime!,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      final time = TimeOfDay.fromDateTime(isStart ? _startTime! : _endTime!);
      final newDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      );
      setState(() {
        if (isStart) {
          _startTime = newDateTime;
        } else {
          _endTime = newDateTime;
        }
      });
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

    if (_useSimpleSeating) {
      if (_priceController.text.trim().isEmpty) {
        _showError('Please enter price');
        return false;
      }
    } else {
      final ownerId = _seatLayoutOwnerId;
      final layout = ownerId == null
          ? null
          : SeatLayoutRepository.instance.getLayout(ownerId);
      final seatCount =
          layout?.cells.values.where((c) => c.type == CellType.seat).length ??
          0;

      if (layout == null || seatCount <= 0) {
        _showError('Please add a seat layout with at least 1 seat');
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

    setState(() => _isPosting = true);

    try {
      if (_slotType == SlotType.fromTo) {
        _fromSuggestion ??= await _maybeGeocode(
          _fromController.text.trim(),
        );
        _toSuggestion ??= await _maybeGeocode(
          _toController.text.trim(),
        );
      } else {
        _baseSuggestion ??= await _maybeGeocode(
          _baseController.text.trim(),
        );
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

      final int derivedCapacity = useLayout ? seatCells.length : _capacity;
      final int minSeatPrice = useLayout
          ? (seatCells
                    .map((c) => c.price)
                    .whereType<int>()
                    .fold<int?>(
                      null,
                      (min, p) => min == null ? p : (p < min ? p : min),
                    ) ??
                0)
          : 0;

      final double derivedPrice = useLayout
          ? minSeatPrice.toDouble()
          : (double.tryParse(_priceController.text) ?? 0);

      // Determine actual service type based on operator toggle for Lease
      final ServiceType actualServiceType = widget.serviceType == ServiceType.lease
          ? (_withOperator ? ServiceType.working : ServiceType.lease)
          : widget.serviceType;
      
      // Set withOperator based on service type
      final bool operatorValue = widget.serviceType == ServiceType.lease
          ? _withOperator
          : true; // Passenger and Parcel always have operators

      final slot = Slot(
        id: slotId,
        vehicleId: _selectedVehicle!.id,
        serviceType: actualServiceType,
        slotType: _slotType,
        seatLayoutOwnerId: layoutOwnerId,
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
        images: const [],
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
        leaseDuration: null, // No duration selection - just time frame and total price
        securityDeposit: widget.serviceType == ServiceType.lease
            ? double.tryParse(_securityDepositController.text)
            : null,
        mileageLimit: null,
        fuelPolicy: widget.serviceType == ServiceType.lease
            ? _fuelPolicy
            : null,
        insuranceIncluded: widget.serviceType == ServiceType.lease
            ? _insuranceIncluded
            : null,
        leaseTerms: widget.serviceType == ServiceType.lease &&
                _leaseTermsController.text.trim().isNotEmpty
            ? _leaseTermsController.text.trim()
            : null,
        withOperator: operatorValue,
      );

      if (widget.isUserMode) {
        await UserSlotRepository.instance.addSlot(slot);
      } else {
        await SlotRepository.instance.addSlot(slot);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Posted live ✅')));
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

            // Time Section
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
            if (widget.serviceType == ServiceType.parcel && _useSimpleSeating) ...[
              _buildParcelDimensionsSection(),
              const SizedBox(height: 20),
            ],

            // Lease Details (only for lease service)
            if (widget.serviceType == ServiceType.lease) ...[
              _buildLeaseDetailsSection(),
              const SizedBox(height: 20),
            ],

            // Pickup Mode
            _buildPickupModeSection(),
            const SizedBox(height: 20),
            
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
              MaterialPageRoute(builder: (context) => VehicleListScreen(isUserMode: widget.isUserMode)),
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
                      Icon(Icons.directions_car, color: Colors.blue.shade700),
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
                hint: 'Start location',
                icon: Icons.location_on,
                onLocationSelected: (suggestion) {
                  _fromSuggestion = suggestion;
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Icon(Icons.arrow_downward, color: Colors.grey),
              ),
              LocationAutocompleteField(
                controller: _toController,
                label: 'To',
                hint: 'Destination',
                icon: Icons.flag,
                onLocationSelected: (suggestion) {
                  _toSuggestion = suggestion;
                },
              ),
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
                label: const Text('From in Maps', style: TextStyle(fontSize: 12)),
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
            Builder(builder: (context) {
              final dist = _haversineKm(
                _fromSuggestion!.lat, _fromSuggestion!.lon,
                _toSuggestion!.lat, _toSuggestion!.lon,
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
            }),
          ],
        ] else ...[
          LocationAutocompleteField(
            controller: _baseController,
            label: 'Base Location',
            hint: 'Service area center',
            icon: Icons.home,
            onLocationSelected: (suggestion) {
              _baseSuggestion = suggestion;
              debugPrint('Base location selected: ${suggestion.displayName}');
              debugPrint('Coordinates: ${suggestion.lat}, ${suggestion.lon}');
            },
          ),
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
                  const Text(
                    'Start Time',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      await _selectDate(isStart: true);
                      await _selectTime(isStart: true);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time),
                          const SizedBox(width: 8),
                          Text(
                            _startTime != null
                                ? '${_startTime!.day}/${_startTime!.month} ${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                                : 'Select start time',
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
                  const Text(
                    'End Time',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      await _selectDate(isStart: false);
                      await _selectTime(isStart: false);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time),
                          const SizedBox(width: 8),
                          Text(
                            _endTime != null
                                ? '${_endTime!.day}/${_endTime!.month} ${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                                : 'Select end time',
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
          Builder(builder: (context) {
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
          }),
        ],
      ],
    );
  }

  Widget _buildPriceCapacitySection() {
    final hasLayoutSeats = _hasSeatLayoutSeats;
    final isLeaseOrWorking = widget.serviceType == ServiceType.lease || 
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          color:
                              _useSimpleSeating ? Colors.green : Colors.grey,
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              prefixIcon: const Icon(Icons.currency_rupee),
              prefixText: AppPreferences.instance.currencySymbol,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

  Widget _buildLeaseDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🚗 Lease Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        // Security Deposit (only for self-drive / without operator)
        if (!_withOperator)
          TextFormField(
            controller: _securityDepositController,
            decoration: const InputDecoration(
              labelText: 'Security Deposit (₹)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.security),
              helperText: 'Refundable deposit for self-drive',
            ),
            keyboardType: TextInputType.number,
          ),
        if (!_withOperator) const SizedBox(height: 12),
        
        // Fuel Policy
        DropdownButtonFormField<String>(
          initialValue: _fuelPolicy,
          decoration: const InputDecoration(
            labelText: 'Fuel Policy',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.local_gas_station),
          ),
          items: ['Full-to-Full', 'Fuel Included', 'Pay as You Go'].map((policy) {
            return DropdownMenuItem(
              value: policy,
              child: Text(policy),
            );
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

  Widget _buildOperatorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '👨‍✈️ Operator Availability',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SwitchListTile(
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
    if (!mounted) return;
    setState(() {
      _useSimpleSeating = false;
    });
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
      ],
    );
  }
}
