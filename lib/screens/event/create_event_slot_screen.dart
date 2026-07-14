// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/event.dart';
import '../../models/event_slot.dart';
import '../../models/slot_type.dart';
import '../../models/seat_layout.dart';
import '../../services/event_slot_repository.dart';
import '../../services/seat_layout_repository.dart';
import '../../services/profile_repository.dart';
import '../../services/content_filter_service.dart';
import '../../services/app_preferences.dart';
import '../../controllers/seat_layout_controller.dart';
import '../add_flow/seat_layout_builder_screen.dart';

class CreateEventSlotScreen extends StatefulWidget {
  final Event event;

  const CreateEventSlotScreen({super.key, required this.event});

  @override
  State<CreateEventSlotScreen> createState() => _CreateEventSlotScreenState();
}

class _CreateEventSlotScreenState extends State<CreateEventSlotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  SlotType _slotType = SlotType.fromTo;
  bool _useSimpleCapacity = true;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _fromLocationController = TextEditingController();
  final _toLocationController = TextEditingController();
  final _baseLocationController = TextEditingController();
  final _radiusController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  String? _profileImageBase64;
  final List<String> _descriptionImagesBase64 = [];
  String? _shortVideoPath;
  String? _seatLayoutOwnerId;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _fromLocationController.dispose();
    _toLocationController.dispose();
    _baseLocationController.dispose();
    _radiusController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Get currency symbol from provider's connected payment account
  String _getProviderCurrencySymbol() {
    final profile = ProfileRepository.instance.profile.value;
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
        title: const Text('Create Event Slot'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Event Info
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Creating slot for:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.event.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Slot Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Profile Image
            const Text(
              'Profile Image',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_profileImageBase64 != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(_profileImageBase64!),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                      onPressed: () =>
                          setState(() => _profileImageBase64 = null),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _pickProfileImage,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Add Profile Image'),
              ),
            const SizedBox(height: 16),

            // Description Images
            const Text(
              'Description Images',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_descriptionImagesBase64.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _descriptionImagesBase64.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(_descriptionImagesBase64[index]),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(24, 24),
                              ),
                              onPressed: () => setState(() {
                                _descriptionImagesBase64.removeAt(index);
                              }),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            OutlinedButton.icon(
              onPressed: _pickDescriptionImages,
              icon: const Icon(Icons.add_photo_alternate),
              label: Text(
                _descriptionImagesBase64.isEmpty
                    ? 'Add Description Images'
                    : 'Add More Images (${_descriptionImagesBase64.length})',
              ),
            ),
            const SizedBox(height: 16),

            // Short Video
            const Text(
              'Short Video (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_shortVideoPath != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.video_library),
                  title: Text(_shortVideoPath!.split('/').last),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _shortVideoPath = null),
                  ),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.video_library),
                label: const Text('Add Short Video'),
              ),
            const SizedBox(height: 16),

            // Slot Type Selection
            const Text(
              'Slot Type',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            RadioListTile<SlotType>(
              title: const Text('Point-to-Point (From → To)'),
              value: SlotType.fromTo,
              groupValue: _slotType,
              onChanged: (value) => setState(() => _slotType = value!),
            ),
            RadioListTile<SlotType>(
              title: const Text('Area Service (From + Range)'),
              value: SlotType.fromRange,
              groupValue: _slotType,
              onChanged: (value) => setState(() => _slotType = value!),
            ),
            const SizedBox(height: 16),

            // Location Fields
            if (_slotType == SlotType.fromTo) ...[
              TextFormField(
                controller: _fromLocationController,
                decoration: const InputDecoration(
                  labelText: 'From Location',
                  hintText: 'e.g., Chennai Central',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _toLocationController,
                decoration: const InputDecoration(
                  labelText: 'To Location',
                  hintText: 'e.g., Bangalore City Junction',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
            ] else ...[
              TextFormField(
                controller: _baseLocationController,
                decoration: const InputDecoration(
                  labelText: 'Base Location',
                  hintText: 'e.g., Mumbai CST',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.my_location),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _radiusController,
                decoration: const InputDecoration(
                  labelText: 'Service Radius (km)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.radar),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  if (double.tryParse(value!) == null) return 'Invalid number';
                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),

            // Start Date & Time
            const Text(
              'Start Date & Time',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickStartDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _startDate == null
                          ? 'Pick Date'
                          : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickStartTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _startTime == null
                          ? 'Pick Time'
                          : _startTime!.format(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // End Date & Time
            const Text(
              'End Date & Time',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickEndDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _endDate == null
                          ? 'Pick Date'
                          : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickEndTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _endTime == null
                          ? 'Pick Time'
                          : _endTime!.format(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Capacity Mode Selection
            const Text(
              'Capacity Setup',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  RadioListTile<bool>(
                    title: const Text('Simple Capacity'),
                    subtitle: const Text('Set total capacity and price'),
                    value: true,
                    groupValue: _useSimpleCapacity,
                    onChanged: (value) =>
                        setState(() => _useSimpleCapacity = value!),
                  ),
                  RadioListTile<bool>(
                    title: const Text('Seat Layout'),
                    subtitle: const Text('Design custom seat arrangement'),
                    value: false,
                    groupValue: _useSimpleCapacity,
                    onChanged: (value) =>
                        setState(() => _useSimpleCapacity = value!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Simple Capacity Fields
            if (_useSimpleCapacity) ...[
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(
                  labelText: 'Capacity',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  if (int.tryParse(value!) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Price (${_getProviderCurrencySymbol()})',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  if (double.tryParse(value!) == null) return 'Invalid number';
                  return null;
                },
              ),
            ] else ...[
              // Seat Layout Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.event_seat, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _seatLayoutOwnerId == null
                              ? 'No layout added'
                              : 'Layout ready (tap edit to update)',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openSeatLayoutBuilder,
                        icon: const Icon(Icons.grid_on_outlined, size: 18),
                        label: Text(
                          _seatLayoutOwnerId == null ? 'Add' : 'Edit',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Terms (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Create Button
            ElevatedButton(
              onPressed: _createSlot,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Create Slot'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _startDate = date);
    }
  }

  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time != null) {
      setState(() => _startTime = time);
    }
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _endDate = date);
    }
  }

  Future<void> _pickEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time != null) {
      setState(() => _endTime = time);
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _profileImageBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _pickDescriptionImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      for (final image in images) {
        final bytes = await image.readAsBytes();
        setState(() {
          _descriptionImagesBase64.add(base64Encode(bytes));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick images: $e')));
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );

      if (video != null) {
        setState(() {
          _shortVideoPath = video.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick video: $e')));
      }
    }
  }

  Future<void> _openSeatLayoutBuilder() async {
    final ownerId =
        _seatLayoutOwnerId ??
        'event_slot_${DateTime.now().millisecondsSinceEpoch.toString()}';
    _seatLayoutOwnerId ??= ownerId;

    final existing = SeatLayoutRepository.instance.getLayout(ownerId);
    final initial =
        existing ??
        SeatLayout(
          id: 'layout_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Event Slot Layout',
          rows: 5,
          cols: 5,
          cells: {},
        );

    final controller = SeatLayoutController(initialLayout: initial);

    final saved = await Navigator.push<SeatLayout>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SeatLayoutBuilderScreen(controller: controller, ownerId: ownerId),
      ),
    );

    if (saved == null) return;
    await SeatLayoutRepository.instance.upsert(ownerId: ownerId, layout: saved);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _createSlot() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start date and time')),
      );
      return;
    }

    if (_endDate == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select end date and time')),
      );
      return;
    }

    // Validate capacity/layout
    int finalCapacity;
    double finalPrice;

    if (_useSimpleCapacity) {
      // Simple mode validation already done by form validators
      finalCapacity = int.parse(_capacityController.text);
      finalPrice = double.parse(_priceController.text);
    } else {
      // Layout mode validation
      final ownerId = _seatLayoutOwnerId;
      if (ownerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add a seat layout')),
        );
        return;
      }

      final layout = SeatLayoutRepository.instance.getLayout(ownerId);
      final seatCells =
          layout?.cells.values.where((c) => c.type == CellType.seat).toList() ??
          [];

      if (seatCells.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least 1 seat to the layout'),
          ),
        );
        return;
      }

      finalCapacity = seatCells.length;
      finalPrice = seatCells
          .map((c) => c.price ?? 0.0)
          .reduce((a, b) => a < b ? a : b)
          .toDouble();
    }

    final startDateTime = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );

    final endDateTime = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      _endTime!.hour,
      _endTime!.minute,
    );

    if (endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    // Validate notes for contact information
    final notes = _notesController.text.trim();
    if (notes.isNotEmpty) {
      final errorMessage = ContentFilterService.instance.validateContent(notes);
      if (errorMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
        return;
      }
    }

    // Convert video path to base64 if exists
    String? videoBase64;
    if (_shortVideoPath != null) {
      try {
        final bytes = await XFile(_shortVideoPath!).readAsBytes();
        videoBase64 = base64Encode(bytes);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to process video: $e')),
          );
        }
        return;
      }
    }

    final slot = EventSlot(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      eventId: widget.event.id,
      name: _nameController.text,
      description: _descriptionController.text,
      slotType: _slotType,
      fromLocation: _slotType == SlotType.fromTo
          ? _fromLocationController.text
          : null,
      toLocation: _slotType == SlotType.fromTo
          ? _toLocationController.text
          : null,
      baseLocation: _slotType == SlotType.fromRange
          ? _baseLocationController.text
          : null,
      radius: _slotType == SlotType.fromRange
          ? double.parse(_radiusController.text)
          : null,
      startTime: startDateTime,
      endTime: endDateTime,
      price: finalPrice,
      capacity: finalCapacity,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      profileImage: _profileImageBase64,
      descriptionImages: _descriptionImagesBase64,
      shortVideo: videoBase64,
      seatLayoutId: _useSimpleCapacity ? null : _seatLayoutOwnerId,
      createdAt: DateTime.now(),
    );

    await EventSlotRepository.instance.addEventSlot(slot);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event slot created successfully')),
      );
      Navigator.pop(context);
    }
  }
}
