import 'service_type.dart';
import 'slot_type.dart';
import 'pickup_mode.dart';
import 'user_tier.dart';
import 'post_mode.dart';
import 'post_status.dart';
import 'simple_seat_layout.dart';
import 'edit_history.dart';
import '../services/app_preferences.dart';

enum BookingMode {
  shared, // Multiple customers (default)
  full, // One customer takes all (charter)
}

class Slot {
  final String id;
  final String profileId; // Owner of the post (from posts.profile_id)
  final String? providerName; // Provider name from profiles.full_name (JOIN)
  final String vehicleId;
  final ServiceType serviceType;
  final SlotType slotType;
  final String? seatLayoutOwnerId;
  final SimpleSeatLayout? seatLayoutStructure; // Direct JSON structure
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
  final String? fuelPolicy; // full-to-full, included, etc.
  final bool? insuranceIncluded;
  final String? leaseTerms; // additional terms and conditions

  // Operator availability
  final bool withOperator; // true = with operator, false = without operator

  // FINAL BOOKING SYSTEM (Simple & Clean)
  final BookingMode bookingMode; // 'shared' or 'full'
  final UserTier minCustomerTier; // Minimum tier required to book
  final double?
  fullVehiclePrice; // Price for full charter (if booking_mode = 'full')

  // Post Mode - How this post can be booked
  final PostMode postMode; // 'instant', 'wait_for_full', or 'full_vehicle'

  // Post lifecycle status
  final PostStatus postStatus;

  // Wait for full deadline (hours before start time)
  final int? waitForFullDeadlineHours; // Only used when postMode = waitForFull

  // Demand plan and rating requirements (who can book this)
  final String? demandPlan; // 'basic', 'verified', 'expert'
  final double? minRatings; // Minimum customer rating required
  final double? maxRatings; // Maximum customer rating allowed
  final int? minNoRatings; // Minimum number of ratings required
  final int? maxNoRatings; // Maximum number of ratings allowed

  // Edit history - track all changes made to this post
  final EditHistory editHistory;

  // Escrow payment ID for customer posts (when customer pre-pays)
  final String? escrowPaymentId;

  // Currency type for this post (based on location country)
  final String currencyType; // 'INR', 'USD', 'GBP', 'EUR'

  /// Get currency symbol for this slot based on its currencyType
  String get currencySymbol {
    switch (currencyType.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      case 'EUR':
        return '€';
      default:
        return '₹'; // Default to rupee
    }
  }

  Slot({
    required this.id,
    required this.profileId,
    this.providerName,
    required this.vehicleId,
    required this.serviceType,
    required this.slotType,
    this.seatLayoutOwnerId,
    this.seatLayoutStructure,
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
    this.fuelPolicy,
    this.insuranceIncluded,
    this.leaseTerms,
    this.withOperator = false,
    this.bookingMode = BookingMode.shared,
    this.minCustomerTier = UserTier.basic,
    this.fullVehiclePrice,
    this.postMode = PostMode.instant,
    this.postStatus = PostStatus.active,
    this.waitForFullDeadlineHours,
    this.demandPlan,
    this.minRatings,
    this.maxRatings,
    this.minNoRatings,
    this.maxNoRatings,
    EditHistory? editHistory,
    this.escrowPaymentId,
    String? currencyType,
  }) : currencyType =
           currencyType ?? AppPreferences.instance.currencyCode.value,
       editHistory = editHistory ?? EditHistory.empty();

  Slot copyWith({
    String? id,
    String? profileId,
    String? providerName,
    String? vehicleId,
    ServiceType? serviceType,
    SlotType? slotType,
    String? seatLayoutOwnerId,
    SimpleSeatLayout? seatLayoutStructure,
    bool? requiresApproval,
    String? fromLocation,
    bool setFromLocationNull = false,
    String? toLocation,
    bool setToLocationNull = false,
    String? baseLocation,
    bool setBaseLocationNull = false,
    double? radius,
    bool setRadiusNull = false,
    DateTime? startTime,
    DateTime? endTime,
    double? price,
    int? capacity,
    String? notes,
    bool setNotesNull = false,
    List<String>? images,
    bool? isAvailable,
    DateTime? createdAt,
    PickupMode? pickupOption,
    double? maxWeight,
    bool setMaxWeightNull = false,
    double? maxLength,
    bool setMaxLengthNull = false,
    double? maxWidth,
    bool setMaxWidthNull = false,
    double? maxHeight,
    bool setMaxHeightNull = false,
    String? leaseDuration,
    bool setLeaseDurationNull = false,
    double? securityDeposit,
    bool setSecurityDepositNull = false,
    String? fuelPolicy,
    bool setFuelPolicyNull = false,
    bool? insuranceIncluded,
    bool setInsuranceIncludedNull = false,
    String? leaseTerms,
    bool setLeaseTermsNull = false,
    bool? withOperator,
    BookingMode? bookingMode,
    UserTier? minCustomerTier,
    double? fullVehiclePrice,
    bool setFullVehiclePriceNull = false,
    PostMode? postMode,
    PostStatus? postStatus,
    int? waitForFullDeadlineHours,
    String? demandPlan,
    double? minRatings,
    double? maxRatings,
    int? minNoRatings,
    int? maxNoRatings,
    EditHistory? editHistory,
    String? escrowPaymentId,
    String? currencyType,
  }) {
    return Slot(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      providerName: providerName ?? this.providerName,
      vehicleId: vehicleId ?? this.vehicleId,
      serviceType: serviceType ?? this.serviceType,
      slotType: slotType ?? this.slotType,
      seatLayoutOwnerId: seatLayoutOwnerId ?? this.seatLayoutOwnerId,
      seatLayoutStructure: seatLayoutStructure ?? this.seatLayoutStructure,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      fromLocation: setFromLocationNull
          ? null
          : (fromLocation ?? this.fromLocation),
      toLocation: setToLocationNull ? null : (toLocation ?? this.toLocation),
      baseLocation: setBaseLocationNull
          ? null
          : (baseLocation ?? this.baseLocation),
      radius: setRadiusNull ? null : (radius ?? this.radius),
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      price: price ?? this.price,
      capacity: capacity ?? this.capacity,
      notes: setNotesNull ? null : (notes ?? this.notes),
      images: images ?? this.images,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      pickupOption: pickupOption ?? this.pickupOption,
      maxWeight: setMaxWeightNull ? null : (maxWeight ?? this.maxWeight),
      maxLength: setMaxLengthNull ? null : (maxLength ?? this.maxLength),
      maxWidth: setMaxWidthNull ? null : (maxWidth ?? this.maxWidth),
      maxHeight: setMaxHeightNull ? null : (maxHeight ?? this.maxHeight),
      leaseDuration: setLeaseDurationNull
          ? null
          : (leaseDuration ?? this.leaseDuration),
      securityDeposit: setSecurityDepositNull
          ? null
          : (securityDeposit ?? this.securityDeposit),
      fuelPolicy: setFuelPolicyNull ? null : (fuelPolicy ?? this.fuelPolicy),
      insuranceIncluded: setInsuranceIncludedNull
          ? null
          : (insuranceIncluded ?? this.insuranceIncluded),
      leaseTerms: setLeaseTermsNull ? null : (leaseTerms ?? this.leaseTerms),
      withOperator: withOperator ?? this.withOperator,
      bookingMode: bookingMode ?? this.bookingMode,
      minCustomerTier: minCustomerTier ?? this.minCustomerTier,
      fullVehiclePrice: setFullVehiclePriceNull
          ? null
          : (fullVehiclePrice ?? this.fullVehiclePrice),
      postMode: postMode ?? this.postMode,
      postStatus: postStatus ?? this.postStatus,
      waitForFullDeadlineHours:
          waitForFullDeadlineHours ?? this.waitForFullDeadlineHours,
      demandPlan: demandPlan ?? this.demandPlan,
      minRatings: minRatings ?? this.minRatings,
      maxRatings: maxRatings ?? this.maxRatings,
      minNoRatings: minNoRatings ?? this.minNoRatings,
      maxNoRatings: maxNoRatings ?? this.maxNoRatings,
      editHistory: editHistory ?? this.editHistory,
      escrowPaymentId: escrowPaymentId ?? this.escrowPaymentId,
      currencyType: currencyType ?? this.currencyType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'vehicle_id': vehicleId,
      'service_type': serviceType.name,
      'slot_type': slotType.name, // local JSON cache key (not Supabase)
      'seat_layout_owner_id': seatLayoutOwnerId,
      'slot_layout_structure': seatLayoutStructure?.toJson(),
      'requires_approval': requiresApproval,
      'from_location': fromLocation,
      'to_location': toLocation,
      'base_location': baseLocation,
      'radius': radius,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
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
      'fuel_policy': fuelPolicy,
      'insurance_included': insuranceIncluded,
      'lease_terms': leaseTerms,
      'with_operator': withOperator,
      'booking_mode': bookingMode.name,
      'min_customer_tier': minCustomerTier.name,
      'full_vehicle_price': fullVehiclePrice,
      'postmode': postMode.dbValue,
      'post_status': postStatus.dbValue,
      'wait_for_full_deadline_hours': waitForFullDeadlineHours,
      'demand_plan': demandPlan,
      'min_ratings': minRatings,
      'max_ratings': maxRatings,
      'min_no_ratings': minNoRatings,
      'max_no_ratings': maxNoRatings,
      'edit_history': editHistory.toJson(),
      'escrow_payment_id': escrowPaymentId,
      'currency_type': currencyType,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory Slot.fromJson(Map<String, dynamic> json) {
    // provider_name is not a DB column — populated elsewhere (e.g. JOIN or local cache)
    String? providerName = json['provider_name'];
    if (providerName == null) {
      if (json['public_profiles'] != null && json['public_profiles'] is Map) {
        providerName = json['public_profiles']['full_name'];
      } else if (json['profiles'] != null && json['profiles'] is Map) {
        providerName = json['profiles']['full_name'];
      }
    }

    // Live DB column is `is_active`; local cache uses `is_available` — support both
    final isActive =
        json['is_active'] ??
        json['is_available'] ??
        json['isAvailable'] ??
        true;

    // Live DB column is `terms`; local cache uses `notes` — support both
    final notes = json['terms'] ?? json['notes'];

    return Slot(
      id: json['id'],
      profileId: json['profile_id'] ?? json['profileId'] ?? '',
      providerName: providerName,
      vehicleId: json['vehicle_id'] ?? json['vehicleId'],
      serviceType: ServiceType.values.firstWhere(
        (s) => s.name == (json['service_type'] ?? json['serviceType']),
        orElse: () => ServiceType.passenger,
      ),
      slotType: SlotType.values.firstWhere(
        (s) => s.name == (json['slot_type'] ?? json['slotType']),
        orElse: () => SlotType.fromTo,
      ),
      seatLayoutOwnerId:
          json['seat_layout_owner_id'] ?? json['seatLayoutOwnerId'],
      seatLayoutStructure:
          (json['slot_layout_structure'] ?? json['seat_layout_structure']) !=
              null
          ? SimpleSeatLayout.fromJson(
              (json['slot_layout_structure'] ?? json['seat_layout_structure'])
                  as Map<String, dynamic>,
            )
          : null,
      requiresApproval:
          json['requires_approval'] ?? json['requiresApproval'] ?? true,
      fromLocation: json['from_location'] ?? json['fromLocation'],
      toLocation: json['to_location'] ?? json['toLocation'],
      baseLocation: json['base_location'] ?? json['baseLocation'],
      radius: (json['radius'] as num?)?.toDouble(),
      startTime: DateTime.parse(
        json['start_time'] ?? json['startTime'],
      ).toLocal(),
      endTime: DateTime.parse(json['end_time'] ?? json['endTime']).toLocal(),
      price: (json['price'] as num).toDouble(),
      capacity: json['capacity'] as int? ?? 1,
      notes: notes as String?,
      images: List<String>.from(json['images'] ?? []),
      isAvailable: isActive as bool,
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      pickupOption: PickupMode.values.firstWhere(
        (p) => p.name == (json['pickup_option'] ?? json['pickupOption']),
        orElse: () => PickupMode.customerPickup,
      ),
      maxWeight: (json['max_weight'] ?? json['maxWeight'] as num?)?.toDouble(),
      maxLength: (json['max_length'] ?? json['maxLength'] as num?)?.toDouble(),
      maxWidth: (json['max_width'] ?? json['maxWidth'] as num?)?.toDouble(),
      maxHeight: (json['max_height'] ?? json['maxHeight'] as num?)?.toDouble(),
      // lease_duration / lease_terms / insurance_included are not live DB columns
      // — kept in local cache only
      leaseDuration: json['lease_duration'] ?? json['leaseDuration'],
      securityDeposit:
          (json['security_deposit'] ?? json['securityDeposit'] as num?)
              ?.toDouble(),
      fuelPolicy: json['fuel_policy'] ?? json['fuelPolicy'],
      insuranceIncluded:
          json['insurance_included'] ?? json['insuranceIncluded'],
      leaseTerms: json['lease_terms'] ?? json['leaseTerms'],
      withOperator: json['with_operator'] ?? json['withOperator'] ?? false,
      // booking_mode / min_customer_tier / full_vehicle_price are not live DB columns
      // — default safely
      bookingMode: json['booking_mode'] != null || json['bookingMode'] != null
          ? BookingMode.values.firstWhere(
              (e) => e.name == (json['booking_mode'] ?? json['bookingMode']),
              orElse: () => BookingMode.shared,
            )
          : BookingMode.shared,
      minCustomerTier:
          json['min_customer_tier'] != null || json['minCustomerTier'] != null
          ? UserTier.values.firstWhere(
              (e) =>
                  e.name ==
                  (json['min_customer_tier'] ?? json['minCustomerTier']),
              orElse: () => UserTier.basic,
            )
          : UserTier.basic,
      fullVehiclePrice:
          (json['full_vehicle_price'] ?? json['fullVehiclePrice'] as num?)
              ?.toDouble(),
      postMode: json['postmode'] != null || json['postMode'] != null
          ? PostModeExtension.fromDbValue(json['postmode'] ?? json['postMode'])
          : PostMode.instant,
      postStatus: PostStatusX.fromFields(
        isAvailable: isActive,
        endTime: DateTime.parse(json['end_time'] ?? json['endTime']),
        // post_status is not a live DB column — derive from is_active + end_time only
        explicitStatus: null,
      ),
      // wait_for_full_deadline_hours is not a live DB column
      waitForFullDeadlineHours:
          json['wait_for_full_deadline_hours'] ??
          json['waitForFullDeadlineHours'],
      // Demand plan and rating requirements from live DB
      demandPlan: json['demand_plan'] ?? json['demandPlan'],
      minRatings: (json['min_ratings'] ?? json['minRatings'] as num?)
          ?.toDouble(),
      maxRatings: (json['max_ratings'] ?? json['maxRatings'] as num?)
          ?.toDouble(),
      minNoRatings: json['min_no_ratings'] ?? json['minNoRatings'],
      maxNoRatings: json['max_no_ratings'] ?? json['maxNoRatings'],
      // Live DB column is `Edittimesanddetails`; local cache uses `edit_history`
      editHistory: EditHistory.fromJson(
        json['Edittimesanddetails'] ??
            json['edit_history'] ??
            json['editHistory'],
      ),
      escrowPaymentId: json['escrow_payment_id'] ?? json['escrowPaymentId'],
      currencyType: json['currency_type'] ?? json['currencyType'] ?? 'INR',
    );
  }
}
