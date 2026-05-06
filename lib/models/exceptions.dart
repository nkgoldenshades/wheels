/// Thrown when a post delete is blocked because active bookings exist.
class ActiveBookingsException implements Exception {
  final int activeCount;

  ActiveBookingsException(this.activeCount);

  @override
  String toString() =>
      'ActiveBookingsException: $activeCount active booking(s) prevent deletion.';
}


