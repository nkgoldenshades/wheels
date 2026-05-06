import 'package:flutter/material.dart';

import '../../models/event.dart';
import '../../services/event_repository.dart';
import '../add_flow/event_screen.dart';
import 'event_detail_screen.dart';
import 'create_event_slot_screen.dart';

class EventsListScreen extends StatelessWidget {
  const EventsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final eventRepository = EventRepository.instance;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Events'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push<Event>(
            context,
            MaterialPageRoute(
              builder: (context) => const EventScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: ValueListenableBuilder<List<Event>>(
        valueListenable: eventRepository.eventsListenable,
        builder: (context, events, _) {
          if (events.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No events posted yet',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final sorted = [...events]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return ValueListenableBuilder<Map<String, bool>>(
            valueListenable: eventRepository.onlineStatusListenable,
            builder: (context, onlineStatus, _) {
              return ListView.builder(
                itemCount: sorted.length,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  final event = sorted[index];
                  final isOnline = eventRepository.isOnline(event.id);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(event.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${event.location} (${event.radiusKm} km)'),
                              Text(
                                '${_formatDate(event.startTime)} - ${_formatDate(event.endTime)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOnline ? Colors.green : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: isOnline,
                                onChanged: (value) =>
                                    eventRepository.setOnlineStatus(event.id, value),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EventDetailScreen(event: event),
                              ),
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CreateEventSlotScreen(event: event),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Create Slot'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}


