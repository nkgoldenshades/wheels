import '../models/service_type.dart';

enum ReviewType { userToProvider, providerToUser }

class Review {
  final String id;
  final String bookingId;
  final String reviewerId; // Who wrote the review
  final String revieweeId; // Who is being reviewed
  final ReviewType type;
  final ServiceType? serviceType; // Service type (from trip_data)
  final bool hasOperator; // Whether trip had operator (from trip_data)
  final double rating; // 1-5 stars
  final String? comment;
  final List<String> mediaUrls; // photos attached to review
  final DateTime createdAt;

  // Additional trip metadata (stored in JSON)
  final int? tripDurationMinutes;
  final double? distanceKm;
  final String? vehicleType;
  final bool pickupVerified;
  final bool dropoffVerified;
  final Map<String, dynamic> tripData; // Raw JSON data

  Review({
    required this.id,
    required this.bookingId,
    required this.reviewerId,
    required this.revieweeId,
    required this.type,
    this.serviceType,
    this.hasOperator = false,
    required this.rating,
    this.comment,
    this.mediaUrls = const [],
    required this.createdAt,
    this.tripDurationMinutes,
    this.distanceKm,
    this.vehicleType,
    this.pickupVerified = false,
    this.dropoffVerified = false,
    this.tripData = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookingId': bookingId,
      'reviewerId': reviewerId,
      'revieweeId': revieweeId,
      'type': type.name,
      'rating': rating,
      'comment': comment,
      'mediaUrls': mediaUrls,
      'createdAt': createdAt.toIso8601String(),
      'trip_data': {
        'service_type': serviceType?.name,
        'has_operator': hasOperator,
        'trip_duration_minutes': tripDurationMinutes,
        'distance_km': distanceKm,
        'vehicle_type': vehicleType,
        'pickup_verified': pickupVerified,
        'dropoff_verified': dropoffVerified,
      },
    };
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] ?? json['reviewer_role'];
    final reviewerRole = json['reviewer_role'] as String?;

    // Determine revieweeId from DB columns
    String revieweeId;
    if (json['revieweeId'] != null) {
      revieweeId = json['revieweeId'];
    } else if (json['reviewee_id'] != null) {
      revieweeId = json['reviewee_id'];
    } else if (reviewerRole == 'customer') {
      revieweeId = json['profile_provider_id'] ?? '';
    } else {
      revieweeId = json['profile_customer_id'] ?? '';
    }

    // Parse trip_data JSON
    Map<String, dynamic> tripData = {};
    ServiceType? serviceType;
    bool hasOperator = false;
    int? tripDurationMinutes;
    double? distanceKm;
    String? vehicleType;
    bool pickupVerified = false;
    bool dropoffVerified = false;

    final rawTripData = json['trip_data'];
    if (rawTripData is Map<String, dynamic>) {
      tripData = rawTripData;

      // Extract service_type from trip_data
      final serviceTypeStr = tripData['service_type'];
      if (serviceTypeStr != null) {
        try {
          serviceType = ServiceType.values.firstWhere(
            (e) => e.name == serviceTypeStr,
            orElse: () => ServiceType.passenger,
          );
        } catch (e) {
          serviceType = ServiceType.passenger;
        }
      }

      // Extract has_operator from trip_data
      final hasOp = tripData['has_operator'];
      if (hasOp is bool) {
        hasOperator = hasOp;
      } else if (hasOp is String) {
        hasOperator = hasOp.toLowerCase() == 'true';
      }

      // Extract other trip metadata
      tripDurationMinutes = tripData['trip_duration_minutes'] as int?;
      distanceKm = (tripData['distance_km'] as num?)?.toDouble();
      vehicleType = tripData['vehicle_type'] as String?;

      final pickup = tripData['pickup_verified'];
      if (pickup is bool) {
        pickupVerified = pickup;
      }

      final dropoff = tripData['dropoff_verified'];
      if (dropoff is bool) {
        dropoffVerified = dropoff;
      }
    }

    // Parse media urls — DB stores as json array
    List<String> mediaUrls = [];
    final rawMedia = json['mediaUrls'] ?? json['media_urls'];
    if (rawMedia is List) {
      mediaUrls = rawMedia.map((e) => e.toString()).toList();
    }

    return Review(
      id: json['id'],
      bookingId: (json['bookingId'] ?? json['booking_id']).toString(),
      reviewerId: json['reviewerId'] ?? json['reviewer_id'],
      revieweeId: revieweeId,
      type: typeStr != null
          ? ReviewType.values.firstWhere(
              (e) => e.name == typeStr || _mapReviewType(typeStr) == e.name,
              orElse: () => ReviewType.userToProvider,
            )
          : ReviewType.userToProvider,
      serviceType: serviceType,
      hasOperator: hasOperator,
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'],
      mediaUrls: mediaUrls,
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at']),
      tripDurationMinutes: tripDurationMinutes,
      distanceKm: distanceKm,
      vehicleType: vehicleType,
      pickupVerified: pickupVerified,
      dropoffVerified: dropoffVerified,
      tripData: tripData,
    );
  }

  static String _mapReviewType(String dbType) {
    switch (dbType) {
      case 'customer_to_provider':
      case 'customer':
        return 'userToProvider';
      case 'provider_to_customer':
      case 'provider':
        return 'providerToUser';
      default:
        return dbType;
    }
  }
}
