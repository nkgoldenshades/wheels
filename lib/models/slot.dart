import 'service_type.dart';
import 'slot_type.dart';
import 'pickup_mode.dart';

class Slot {
  final String id;
  final String vehicleId;
  final ServiceType serviceType;
  final SlotType slotType;
  final String? seatLayoutOwnerId;
  final bool requiresApproval;
  final String? fromLocation;
  final String? toLocation;
  final String? baseLocation;
  final double? radius;
  final DateTime startTime;
  final DateTime endTime;
  final double price;
  final int capacity;
  final String? notes;
  final List<String> images;
  final bool isAvailable;
  final DateTime createdAt;
  final PickupMode pickupOption;
  
  // Parcel-specific fields
  final double? maxWeight; // in kg
  final double? maxLength; // in cm
  final double? maxWidth; // in cm
  final double? maxHeight; // in cm

  // Lease-specific fields
  final String? leaseDuration; // hourly, daily, weekly, monthly
  final double? securityDeposit; // deposit amount
  final int? mileageLimit; // km per day
  final String? fuelPolicy; // full-to-full, included, etc.
  final bool? insuranceIncluded;
  final String? leaseTerms; // additional terms and conditions
  
  // Operator availability
  final bool withOperator; // true = with operator, false = without operator

  Slot({
    required this.id,
    required this.vehicleId,
    required this.serviceType,
    required this.slotType,
    this.seatLayoutOwnerId,
    this.requiresApproval = true,
    this.fromLocation,
    this.toLocation,
    this.baseLocation,
    this.radius,
    required this.startTime,
    required this.endTime,
    required this.price,
    required this.capacity,
    this.notes,
    required this.images,
    this.isAvailable = true,
    required this.createdAt,
    required this.pickupOption,
    this.maxWeight,
    this.maxLength,
    this.maxWidth,
    this.maxHeight,
    this.leaseDuration,
    this.securityDeposit,
    this.mileageLimit,
    this.fuelPolicy,
    this.insuranceIncluded,
    this.leaseTerms,
    this.withOperator = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'service_type': serviceType.name,
      'slot_type': slotType.name,
      'seat_layout_owner_id': seatLayoutOwnerId,
      'requires_approval': requiresApproval,
      'from_location': fromLocation,
      'to_location': toLocation,
      'base_location': baseLocation,
      'radius': radius,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'price': price,
      'capacity': capacity,
      'notes': notes,
      'images': images,
      'is_available': isAvailable,
      'created_at': createdAt.toIso8601String(),
      'pickup_option': pickupOption.name,
      'max_weight': maxWeight,
      'max_length': maxLength,
      'max_width': maxWidth,
      'max_height': maxHeight,
      'lease_duration': leaseDuration,
      'security_deposit': securityDeposit,
      'mileage_limit': mileageLimit,
      'fuel_policy': fuelPolicy,
      'insurance_included': insuranceIncluded,
      'lease_terms': leaseTerms,
      'with_operator': withOperator,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory Slot.fromJson(Map<String, dynamic> json) {
    return Slot(
      id: json['id'],
      vehicleId: json['vehicle_id'] ?? json['vehicleId'],
      serviceType: ServiceType.values.firstWhere(
        (s) => s.name == (json['service_type'] ?? json['serviceType']),
      ),
      slotType: SlotType.values.firstWhere(
        (s) => s.name == (json['slot_type'] ?? json['slotType']),
      ),
      seatLayoutOwnerId: json['seat_layout_owner_id'] ?? json['seatLayoutOwnerId'],
      requiresApproval: json['requires_approval'] ?? json['requiresApproval'] ?? true,
      fromLocation: json['from_location'] ?? json['fromLocation'],
      toLocation: json['to_location'] ?? json['toLocation'],
      baseLocation: json['base_location'] ?? json['baseLocation'],
      radius: (json['radius'] as num?)?.toDouble(),
      startTime: DateTime.parse(json['start_time'] ?? json['startTime']),
      endTime: DateTime.parse(json['end_time'] ?? json['endTime']),
      price: (json['price'] as num).toDouble(),
      capacity: json['capacity'],
      notes: json['notes'],
      images: List<String>.from(json['images'] ?? []),
      isAvailable: json['is_available'] ?? json['isAvailable'] ?? true,
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      pickupOption: PickupMode.values.firstWhere(
        (p) => p.name == (json['pickup_option'] ?? json['pickupOption']),
      ),
      maxWeight: (json['max_weight'] ?? json['maxWeight'] as num?)?.toDouble(),
      maxLength: (json['max_length'] ?? json['maxLength'] as num?)?.toDouble(),
      maxWidth: (json['max_width'] ?? json['maxWidth'] as num?)?.toDouble(),
      maxHeight: (json['max_height'] ?? json['maxHeight'] as num?)?.toDouble(),
      leaseDuration: json['lease_duration'] ?? json['leaseDuration'],
      securityDeposit: (json['security_deposit'] ?? json['securityDeposit'] as num?)?.toDouble(),
      mileageLimit: json['mileage_limit'] ?? json['mileageLimit'],
      fuelPolicy: json['fuel_policy'] ?? json['fuelPolicy'],
      insuranceIncluded: json['insurance_included'] ?? json['insuranceIncluded'],
      leaseTerms: json['lease_terms'] ?? json['leaseTerms'],
      withOperator: json['with_operator'] ?? json['withOperator'] ?? false,
    );
  }
}
