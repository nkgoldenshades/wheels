// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../models/event_delivery_mode.dart';
import '../../services/event_repository.dart';
import '../../services/auth_repository.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventNameController = TextEditingController();
  final _customTypeController = TextEditingController();
  String? _selectedEventType;
  final List<String> _eventTypes = ['Hotels', 'Functions', 'Shop', 'Other'];

  @override
  void dispose() {
    _eventNameController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Event Name
              TextFormField(
                controller: _eventNameController,
                decoration: const InputDecoration(
                  labelText: 'Event Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.event),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter event name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Event Type
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Event Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _eventTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedEventType = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select event type';
                  }
                  return null;
                },
              ),

              // Custom Type Input (if Other is selected)
              if (_selectedEventType == 'Other') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _customTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Event Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit),
                  ),
                  validator: (value) {
                    if (_selectedEventType == 'Other' && (value == null || value.isEmpty)) {
                      return 'Please enter custom event type';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 32),

              // Create Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createEvent,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Create Event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    final eventType = _selectedEventType == 'Other'
        ? _customTypeController.text
        : _selectedEventType!;

    // Create event with minimal required fields
    // Event type is stored in the title for now
    final now = DateTime.now();
    final event = Event(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: currentUser.id,
      title: _eventNameController.text,
      location: 'TBD', // Default location
      radiusKm: 10, // Default radius
      startTime: now,
      endTime: now.add(const Duration(hours: 2)), // Default 2 hours duration
      description: 'Type: $eventType',
      deliveryMode: EventDeliveryMode.customerComesToEvent,
      createdAt: now,
      images: [],
    );

    try {
      await EventRepository.instance.addEvent(event);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create event: $e')),
        );
      }
    }
  }
}



