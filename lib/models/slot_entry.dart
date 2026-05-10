import 'slot.dart';
import 'vehicle.dart';

/// Wrapper class that combines a Slot with its associated Vehicle
/// Used for displaying slot information with vehicle context
class SlotEntry {
  final Slot slot;
  final Vehicle vehicle;

  const SlotEntry({
    required this.slot,
    required this.vehicle,
  });

  Map<String, dynamic> toJson() {
    return {
      'slot': slot.toJson(),
      'vehicle': vehicle.toJson(),
    };
  }

  factory SlotEntry.fromJson(Map<String, dynamic> json) {
    return SlotEntry(
      slot: Slot.fromJson(json['slot']),
      vehicle: Vehicle.fromJson(json['vehicle']),
    );
  }
}



