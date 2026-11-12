/// Represents automatic GPS location confirmation (separate from trip_media)
/// Stored in location_confirmations JSONB column
library;

class LocationConfirmationParty {
  final double? gpsLat;
  final double? gpsLng;
  final double? gpsAccuracy;
  final DateTime? confirmedAt;
  final bool isConfirmed;

  const LocationConfirmationParty({
    this.gpsLat,
    this.gpsLng,
    this.gpsAccuracy,
    this.confirmedAt,
    this.isConfirmed = false,
  });

  LocationConfirmationParty copyWith({
    double? gpsLat,
    double? gpsLng,
    double? gpsAccuracy,
    DateTime? confirmedAt,
    bool? isConfirmed,
  }) {
    return LocationConfirmationParty(
      gpsLat: gpsLat ?? this.gpsLat,
      gpsLng: gpsLng ?? this.gpsLng,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      isConfirmed: isConfirmed ?? this.isConfirmed,
    );
  }

  Map<String, dynamic> toJson() => {
        if (gpsLat != null) 'gps_lat': gpsLat,
        if (gpsLng != null) 'gps_lng': gpsLng,
        if (gpsAccuracy != null) 'gps_accuracy': gpsAccuracy,
        if (confirmedAt != null) 'confirmed_at': confirmedAt!.toUtc().toIso8601String(),
        'is_confirmed': isConfirmed,
      };

  factory LocationConfirmationParty.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LocationConfirmationParty();
    return LocationConfirmationParty(
      gpsLat: (json['gps_lat'] as num?)?.toDouble(),
      gpsLng: (json['gps_lng'] as num?)?.toDouble(),
      gpsAccuracy: (json['gps_accuracy'] as num?)?.toDouble(),
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.tryParse(json['confirmed_at'] as String)?.toLocal()
          : null,
      isConfirmed: json['is_confirmed'] as bool? ?? false,
    );
  }
}

class LocationConfirmationPhase {
  final LocationConfirmationParty provider;
  final LocationConfirmationParty customer;

  const LocationConfirmationPhase({
    this.provider = const LocationConfirmationParty(),
    this.customer = const LocationConfirmationParty(),
  });

  bool get bothConfirmed => provider.isConfirmed && customer.isConfirmed;
  bool get anyConfirmed => provider.isConfirmed || customer.isConfirmed;

  LocationConfirmationPhase copyWith({
    LocationConfirmationParty? provider,
    LocationConfirmationParty? customer,
  }) {
    return LocationConfirmationPhase(
      provider: provider ?? this.provider,
      customer: customer ?? this.customer,
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider.toJson(),
        'customer': customer.toJson(),
      };

  factory LocationConfirmationPhase.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LocationConfirmationPhase();
    return LocationConfirmationPhase(
      provider: LocationConfirmationParty.fromJson(
        json['provider'] as Map<String, dynamic>?,
      ),
      customer: LocationConfirmationParty.fromJson(
        json['customer'] as Map<String, dynamic>?,
      ),
    );
  }
}

class LocationConfirmations {
  final LocationConfirmationPhase pickup;   // Start location
  final LocationConfirmationPhase dropoff;  // End location

  const LocationConfirmations({
    this.pickup = const LocationConfirmationPhase(),
    this.dropoff = const LocationConfirmationPhase(),
  });

  LocationConfirmations copyWith({
    LocationConfirmationPhase? pickup,
    LocationConfirmationPhase? dropoff,
  }) {
    return LocationConfirmations(
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
    );
  }

  Map<String, dynamic> toJson() => {
        'pickup': pickup.toJson(),
        'dropoff': dropoff.toJson(),
      };

  factory LocationConfirmations.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LocationConfirmations();
    return LocationConfirmations(
      pickup: LocationConfirmationPhase.fromJson(
        json['pickup'] as Map<String, dynamic>?,
      ),
      dropoff: LocationConfirmationPhase.fromJson(
        json['dropoff'] as Map<String, dynamic>?,
      ),
    );
  }

  static const LocationConfirmations empty = LocationConfirmations();
}
