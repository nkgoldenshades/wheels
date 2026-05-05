import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../services/booking_repository.dart';

class BookingStatusScreen extends StatelessWidget {
  final Booking booking;

  const BookingStatusScreen({
    super.key,
    required this.booking,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Status'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<Booking>>(
        valueListenable: BookingRepository.instance.bookings,
        builder: (context, bookings, _) {
          final current = bookings.firstWhere(
            (b) => b.id == booking.id,
            orElse: () => booking,
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Progress',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _Step(
                  title: 'Pending',
                  active: true,
                  done: current.status.index >= BookingStatus.pending.index,
                ),
                const SizedBox(height: 10),
                _Step(
                  title: 'Accepted',
                  active: current.status == BookingStatus.accepted,
                  done: current.status.index >= BookingStatus.accepted.index,
                ),
                const SizedBox(height: 10),
                _Step(
                  title: 'OTP Verified',
                  active: current.status == BookingStatus.completed,
                  done: current.status.index >= BookingStatus.completed.index,
                ),
                const SizedBox(height: 10),
                _Step(
                  title: 'Rejected',
                  active: current.status == BookingStatus.rejected,
                  done: current.status.index >= BookingStatus.rejected.index,
                ),
                const Spacer(),
                if (current.status == BookingStatus.pending)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        BookingRepository.instance.markAccepted(current.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Marked as Accepted ✅')),
                        );
                      },
                      child: const Text('Mark Accepted (MVP)'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String title;
  final bool active;
  final bool done;

  const _Step({
    required this.title,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? Colors.green : Colors.grey;

    return Row(
      children: [
        Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: color),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: active ? FontWeight.bold : FontWeight.w600,
            color: active ? Colors.black : Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

