import 'package:flutter/foundation.dart';
import 'service_type.dart';

enum VehicleGpsMode { deviceLive, externalLink, manual }

class Vehicle {
  final String id;
  final String userId; // Add userId to associate vehicle with user
  final String userName; // Owner's display name
  final String name;
  final String type;
  final String? brand;
  final String? model;
  final String? color;
  final int? year;
  final String? registrationNumber; // Required by law
  final int? seatingCapacity;
  final List<ServiceType> capabilities;
  final String? profileImage; // Single thumbnail/profile image
  final List<String> galleryImages; // Additional photos
  final String? videoUrl; // Optional video (base64 or URL)
  final DateTime createdAt;
  final VehicleGpsMode gpsMode;
  final String? gpsExternalLink;
  final double? manualLat;
  final double? manualLng;
  final double? lastKnownLat;
  final double? lastKnownLng;

  final bool isVerifiedToggle;
  final bool isExpertToggle;

  // Rating and statistics
  final double averageRating;
  final int totalRatings;
  final int totalBookings;
  final int activePostsCount;

  // Registration Certificate (RC) - MANDATORY
  final String? rcFrontUrl; // Front image of RC
  final String? rcBackUrl; // Back image of RC
  final bool rcVerified;
  final DateTime? rcVerifiedAt;

  // Insurance - MANDATORY
  final String? insuranceNumber; // Policy number
  final DateTime? insuranceExpiry; // Expiry date
  final String? insuranceDocumentUrl; // Insurance document
  final bool insuranceVerified;
  final DateTime? insuranceVerifiedAt;

  // Pollution Certificate (PUC) - OPTIONAL but increases trust
  final String? pollutionCertificateUrl;
  final DateTime? pollutionExpiry;

  // Fitness Certificate - OPTIONAL but increases trust
  final String? fitnessCertificateUrl;
  final DateTime? fitnessExpiry;

  // Personal identity documents removed for legal safety
  // Trust built through ratings and trip history instead

  // Operator information (optional - person who operates/handles this vehicle)
  final String? operatorName;
  final String? operatorPhone;
  final String? operatorGender; // 'male', 'female', or null
  final String? operatorPhoto; // base64 or URL
  final String? operatorLicense; // License number for records
  final DateTime? operatorDob; // Date of birth

  // Operator Document (single upload - can be image or PDF)
  final String? operatorDocumentUrl; // Single document upload
  final bool operatorDocumentVerified;

  // Currency and country (for pricing)
  final String currency; // INR, USD, EUR, etc.
  final String countryCode; // IN, US, GB, etc.

  /// True only when all mandatory docs are verified and none expired
  bool get isFullyVerified {
    final insuranceValid =
        insuranceVerified &&
        (insuranceExpiry == null || insuranceExpiry!.isAfter(DateTime.now()));
    final pollutionValid =
        pollutionCertificateUrl == null ||
        pollutionExpiry == null ||
        pollutionExpiry!.isAfter(DateTime.now());
    final fitnessValid =
        fitnessCertificateUrl == null ||
        fitnessExpiry == null ||
        fitnessExpiry!.isAfter(DateTime.now());

    return rcVerified &&
        insuranceValid &&
        dlVerified &&
        pollutionValid &&
        fitnessValid;
  }

  /// True when mandatory documents are present (but may not be verified)
  bool get hasMandatoryDocuments {
    return registrationNumber != null &&
        (rcFrontUrl != null || rcBackUrl != null) &&
        insuranceNumber != null &&
        insuranceDocumentUrl != null;
  }

  Vehicle({
    required this.id,
    required this.userId,
    required this.userName,
    required this.name,
    required this.type,
    this.brand,
    this.model,
    this.color,
    this.year,
    this.registrationNumber,
    this.seatingCapacity,
    required this.capabilities,
    this.profileImage,
    this.galleryImages = const [],
    this.videoUrl,
    required this.createdAt,
    this.gpsMode = VehicleGpsMode.deviceLive,
    this.gpsExternalLink,
    this.manualLat,
    this.manualLng,
    this.lastKnownLat,
    this.lastKnownLng,
    this.isVerifiedToggle = false,
    this.isExpertToggle = false,
    this.averageRating = 0.0,
    this.totalRatings = 0,
    this.totalBookings = 0,
    this.activePostsCount = 0,
    // RC Documents
    this.rcFrontUrl,
    this.rcBackUrl,
    this.rcVerified = false,
    this.rcVerifiedAt,
    // Insurance
    this.insuranceNumber,
    this.insuranceExpiry,
    this.insuranceDocumentUrl,
    this.insuranceVerified = false,
    this.insuranceVerifiedAt,
    // Pollution Certificate
    this.pollutionCertificateUrl,
    this.pollutionExpiry,
    // Fitness Certificate
    this.fitnessCertificateUrl,
    this.fitnessExpiry,
    // Driver's License
    this.dlVerified = false,
    this.dlVerifiedAt,
    this.dlImageBase64,
    // Identity Documents
    this.aadhaarVerified = false,
    this.aadhaarVerifiedAt,
    this.aadhaarImageBase64,
    this.panVerified = false,
    this.panVerifiedAt,
    this.panImageBase64,
    // Operator
    this.operatorName,
    this.operatorPhone,
    this.operatorGender,
    this.operatorPhoto,
    this.operatorLicense,
    this.operatorDob,
    // Operator Document
    this.operatorDocumentUrl,
    this.operatorDocumentVerified = false,
    // Currency and country
    this.currency = 'INR',
    this.countryCode = 'IN',
  });

  Vehicle copyWith({
    String? id,
    String? userId,
    String? userName,
    String? name,
    String? type,
    String? brand,
    String? model,
    String? color,
    int? year,
    String? registrationNumber,
    int? seatingCapacity,
    List<ServiceType>? capabilities,
    String? profileImage,
    List<String>? galleryImages,
    String? videoUrl,
    DateTime? createdAt,
    VehicleGpsMode? gpsMode,
    String? gpsExternalLink,
    double? manualLat,
    double? manualLng,
    double? lastKnownLat,
    double? lastKnownLng,
    bool? isVerifiedToggle,
    bool? isExpertToggle,
    double? averageRating,
    int? totalRatings,
    int? totalBookings,
    int? activePostsCount,
    // RC Documents
    String? rcFrontUrl,
    String? rcBackUrl,
    bool? rcVerified,
    DateTime? rcVerifiedAt,
    // Insurance
    String? insuranceNumber,
    DateTime? insuranceExpiry,
    String? insuranceDocumentUrl,
    bool? insuranceVerified,
    DateTime? insuranceVerifiedAt,
    // Pollution Certificate
    String? pollutionCertificateUrl,
    DateTime? pollutionExpiry,
    // Fitness Certificate
    String? fitnessCertificateUrl,
    DateTime? fitnessExpiry,
    // Driver's License
    bool? dlVerified,
    DateTime? dlVerifiedAt,
    String? dlImageBase64,
    // Identity Documents
    bool? aadhaarVerified,
    DateTime? aadhaarVerifiedAt,
    String? aadhaarImageBase64,
    bool? panVerified,
    DateTime? panVerifiedAt,
    String? panImageBase64,
    // Operator
    String? operatorName,
    String? operatorPhone,
    String? operatorGender,
    String? operatorPhoto,
    String? operatorLicense,
    DateTime? operatorDob,
    // Operator Document
    String? operatorDocumentUrl,
    bool? operatorDocumentVerified,
    // Currency and country
    String? currency,
    String? countryCode,
  }) {
    return Vehicle(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      name: name ?? this.name,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      color: color ?? this.color,
      year: year ?? this.year,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      seatingCapacity: seatingCapacity ?? this.seatingCapacity,
      capabilities: capabilities ?? this.capabilities,
      profileImage: profileImage ?? this.profileImage,
      galleryImages: galleryImages ?? this.galleryImages,
      videoUrl: videoUrl ?? this.videoUrl,
      createdAt: createdAt ?? this.createdAt,
      gpsMode: gpsMode ?? this.gpsMode,
      gpsExternalLink: gpsExternalLink ?? this.gpsExternalLink,
      manualLat: manualLat ?? this.manualLat,
      manualLng: manualLng ?? this.manualLng,
      lastKnownLat: lastKnownLat ?? this.lastKnownLat,
      lastKnownLng: lastKnownLng ?? this.lastKnownLng,
      isVerifiedToggle: isVerifiedToggle ?? this.isVerifiedToggle,
      isExpertToggle: isExpertToggle ?? this.isExpertToggle,
      averageRating: averageRating ?? this.averageRating,
      totalRatings: totalRatings ?? this.totalRatings,
      totalBookings: totalBookings ?? this.totalBookings,
      activePostsCount: activePostsCount ?? this.activePostsCount,
      // RC Documents
      rcFrontUrl: rcFrontUrl ?? this.rcFrontUrl,
      rcBackUrl: rcBackUrl ?? this.rcBackUrl,
      rcVerified: rcVerified ?? this.rcVerified,
      rcVerifiedAt: rcVerifiedAt ?? this.rcVerifiedAt,
      // Insurance
      insuranceNumber: insuranceNumber ?? this.insuranceNumber,
      insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
      insuranceDocumentUrl: insuranceDocumentUrl ?? this.insuranceDocumentUrl,
      insuranceVerified: insuranceVerified ?? this.insuranceVerified,
      insuranceVerifiedAt: insuranceVerifiedAt ?? this.insuranceVerifiedAt,
      // Pollution Certificate
      pollutionCertificateUrl:
          pollutionCertificateUrl ?? this.pollutionCertificateUrl,
      pollutionExpiry: pollutionExpiry ?? this.pollutionExpiry,
      // Fitness Certificate
      fitnessCertificateUrl:
          fitnessCertificateUrl ?? this.fitnessCertificateUrl,
      fitnessExpiry: fitnessExpiry ?? this.fitnessExpiry,
      // Driver's License
      dlVerified: dlVerified ?? this.dlVerified,
      dlVerifiedAt: dlVerifiedAt ?? this.dlVerifiedAt,
      dlImageBase64: dlImageBase64 ?? this.dlImageBase64,
      // Identity Documents
      aadhaarVerified: aadhaarVerified ?? this.aadhaarVerified,
      aadhaarVerifiedAt: aadhaarVerifiedAt ?? this.aadhaarVerifiedAt,
      aadhaarImageBase64: aadhaarImageBase64 ?? this.aadhaarImageBase64,
      panVerified: panVerified ?? this.panVerified,
      panVerifiedAt: panVerifiedAt ?? this.panVerifiedAt,
      panImageBase64: panImageBase64 ?? this.panImageBase64,
      // Operator
      operatorName: operatorName ?? this.operatorName,
      operatorPhone: operatorPhone ?? this.operatorPhone,
      operatorGender: operatorGender ?? this.operatorGender,
      operatorPhoto: operatorPhoto ?? this.operatorPhoto,
      operatorLicense: operatorLicense ?? this.operatorLicense,
      operatorDob: operatorDob ?? this.operatorDob,
      // Operator Document
      operatorDocumentUrl: operatorDocumentUrl ?? this.operatorDocumentUrl,
      operatorDocumentVerified:
          operatorDocumentVerified ?? this.operatorDocumentVerified,
      // Currency and country
      currency: currency ?? this.currency,
      countryCode: countryCode ?? this.countryCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': userId, // Use profile_id to match schema
      'vehicle_type': type,
      'brand': brand,
      'model': model,
      'color': color,
      'registration_number': registrationNumber,
      'seating_capacity': seatingCapacity,
      'vehicle_photo_url': profileImage,
      'gallery_images': galleryImages,
      'video_url': videoUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'is_online': true, // Default to online when serializing
      // RC Documents
      'rc_front_url': rcFrontUrl,
      'rc_back_url': rcBackUrl,
      'is_verified': rcVerified,
      'verified_at': rcVerifiedAt?.toIso8601String(),

      // Insurance
      'insurance_number': insuranceNumber,
      'insurance_expiry': insuranceExpiry?.toIso8601String(),
      'insurance_document_url': insuranceDocumentUrl,

      // Pollution Certificate
      'pollution_certificate_url': pollutionCertificateUrl,
      'pollution_expiry': pollutionExpiry?.toIso8601String(),

      // Fitness Certificate
      'fitness_certificate_url': fitnessCertificateUrl,
      'fitness_expiry': fitnessExpiry?.toIso8601String(),

      // Statistics
      'total_trips': totalBookings,
      'total_reviews': totalRatings,
      'active_posts_count': activePostsCount,

      // Legacy fields for compatibility
      'user_name': userName,
      'name': name,
      'year': year,
      'capabilities': capabilities.map((e) => e.name).toList(),
      'gps_mode': gpsMode.name,
      'gps_external_link': gpsExternalLink,
      'manual_lat': manualLat,
      'manual_lng': manualLng,
      'last_known_lat': lastKnownLat,
      'last_known_lng': lastKnownLng,
      'is_verified_toggle': isVerifiedToggle,
      'is_expert_toggle': isExpertToggle,
      'average_rating': averageRating,
      'total_ratings': totalRatings,
      'total_bookings': totalBookings,
      'dl_verified': dlVerified,
      'dl_verified_at': dlVerifiedAt?.toIso8601String(),
      'dl_image': dlImageBase64,
      'aadhaar_verified': aadhaarVerified,
      'aadhaar_verified_at': aadhaarVerifiedAt?.toIso8601String(),
      'aadhaar_image': aadhaarImageBase64,
      'pan_verified': panVerified,
      'pan_verified_at': panVerifiedAt?.toIso8601String(),
      'pan_image': panImageBase64,
      'operator_name': operatorName,
      'operator_phone': operatorPhone,
      'operator_gender': operatorGender,
      'operator_photo': operatorPhoto,
      'operator_license': operatorLicense,
      'operator_dob': operatorDob?.toIso8601String().split('T').first,
      'operator_document_url': operatorDocumentUrl,
      'operator_document_verified': operatorDocumentVerified,
      'currency': currency,
      'country_code': countryCode,
    };
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    // Support both camelCase (local) and snake_case (Supabase)

    final userName =
        json['profile_name'] ?? // ✅ From vehicles query with join
        json['user_name'] ??
        json['userName'] ??
        json['full_name'] ??
        json['operator_name'] ??
        'Unknown User';

    // Only log if userName is Unknown User (to debug issues)
    if (kDebugMode && userName == 'Unknown User') {
      debugPrint(
        '⚠️ Vehicle.fromJson: id=${json['id']}, profile_name=${json['profile_name']}, user_name=${json['user_name']} → Unknown User',
      );
    }

    return Vehicle(
      id: json['id'],
      userId: json['profile_id'] ?? json['user_id'] ?? json['userId'],
      userName: userName,
      name:
          json['vehicle_name'] ??
          json['name'] ??
          '${json['brand'] ?? ''} ${json['model'] ?? ''}'.trim(),
      type: json['vehicle_type'] ?? json['type'],
      brand: json['brand'],
      model: json['model'],
      color: json['color'],
      year: json['year'],
      registrationNumber: json['registration_number'],
      seatingCapacity: json['seating_capacity'],
      capabilities: json['capabilities'] != null
          ? (json['capabilities'] as List)
                .map((e) => ServiceType.values.firstWhere((s) => s.name == e))
                .toList()
          : <ServiceType>[],
      profileImage:
          json['vehicle_photo_url'] ??
          json['profile_image'] ??
          json['profileImage'],
      galleryImages: json['gallery_images'] != null
          ? List<String>.from(json['gallery_images'])
          : (json['galleryImages'] != null
                ? List<String>.from(json['galleryImages'])
                : []),
      videoUrl: json['video_url'] ?? json['videoUrl'],
      createdAt: DateTime.parse(
        json['created_at'] ??
            json['createdAt'] ??
            DateTime.now().toIso8601String(),
      ),
      gpsMode: json['gps_mode'] != null || json['gpsMode'] != null
          ? VehicleGpsMode.values.firstWhere(
              (m) => m.name == (json['gps_mode'] ?? json['gpsMode']),
              orElse: () => VehicleGpsMode.deviceLive,
            )
          : VehicleGpsMode.deviceLive,
      gpsExternalLink: json['gps_external_link'] ?? json['gpsExternalLink'],
      manualLat: (json['manual_lat'] ?? json['manualLat'] as num?)?.toDouble(),
      manualLng: (json['manual_lng'] ?? json['manualLng'] as num?)?.toDouble(),
      lastKnownLat: (json['last_known_lat'] ?? json['lastKnownLat'] as num?)
          ?.toDouble(),
      lastKnownLng: (json['last_known_lng'] ?? json['lastKnownLng'] as num?)
          ?.toDouble(),
      isVerifiedToggle:
          json['is_verified_toggle'] ?? json['isVerifiedToggle'] ?? false,
      isExpertToggle:
          json['is_expert_toggle'] ?? json['isExpertToggle'] ?? false,
      averageRating:
          (json['average_rating'] ?? json['averageRating'] as num?)
              ?.toDouble() ??
          0.0,
      totalRatings:
          json['total_reviews'] ??
          json['total_ratings'] ??
          json['totalRatings'] ??
          0,
      totalBookings:
          json['total_trips'] ??
          json['total_bookings'] ??
          json['totalBookings'] ??
          0,
      activePostsCount:
          json['active_posts_count'] ?? json['activePostsCount'] ?? 0,

      // RC Documents
      rcFrontUrl: json['rc_front_url'],
      rcBackUrl: json['rc_back_url'],
      rcVerified:
          json['is_verified'] ??
          json['rc_verified'] ??
          json['rcVerified'] ??
          false,
      rcVerifiedAt:
          json['verified_at'] != null ||
              json['rc_verified_at'] != null ||
              json['rcVerifiedAt'] != null
          ? DateTime.parse(
              json['verified_at'] ??
                  json['rc_verified_at'] ??
                  json['rcVerifiedAt'],
            )
          : null,

      // Insurance
      insuranceNumber: json['insurance_number'],
      insuranceExpiry: json['insurance_expiry'] != null
          ? DateTime.parse(json['insurance_expiry'])
          : (json['insurance_expiry_date'] != null ||
                    json['insuranceExpiryDate'] != null
                ? DateTime.parse(
                    json['insurance_expiry_date'] ??
                        json['insuranceExpiryDate'],
                  )
                : null),
      insuranceDocumentUrl: json['insurance_document_url'],
      insuranceVerified:
          json['insurance_verified'] ?? json['insuranceVerified'] ?? false,
      insuranceVerifiedAt:
          json['insurance_verified_at'] != null ||
              json['insuranceVerifiedAt'] != null
          ? DateTime.parse(
              json['insurance_verified_at'] ?? json['insuranceVerifiedAt'],
            )
          : null,

      // Pollution Certificate
      pollutionCertificateUrl: json['pollution_certificate_url'],
      pollutionExpiry: json['pollution_expiry'] != null
          ? DateTime.parse(json['pollution_expiry'])
          : null,

      // Fitness Certificate
      fitnessCertificateUrl: json['fitness_certificate_url'],
      fitnessExpiry: json['fitness_expiry'] != null
          ? DateTime.parse(json['fitness_expiry'])
          : null,

      // Driver's License
      dlVerified: json['dl_verified'] ?? json['dlVerified'] ?? false,
      dlVerifiedAt:
          json['dl_verified_at'] != null || json['dlVerifiedAt'] != null
          ? DateTime.parse(json['dl_verified_at'] ?? json['dlVerifiedAt'])
          : null,
      dlImageBase64: json['dl_image'] ?? json['dlImage'],

      // Identity Documents
      aadhaarVerified:
          json['aadhaar_verified'] ?? json['aadhaarVerified'] ?? false,
      aadhaarVerifiedAt:
          json['aadhaar_verified_at'] != null ||
              json['aadhaarVerifiedAt'] != null
          ? DateTime.parse(
              json['aadhaar_verified_at'] ?? json['aadhaarVerifiedAt'],
            )
          : null,
      aadhaarImageBase64: json['aadhaar_image'] ?? json['aadhaarImage'],
      panVerified: json['pan_verified'] ?? json['panVerified'] ?? false,
      panVerifiedAt:
          json['pan_verified_at'] != null || json['panVerifiedAt'] != null
          ? DateTime.parse(json['pan_verified_at'] ?? json['panVerifiedAt'])
          : null,
      panImageBase64: json['pan_image'] ?? json['panImage'],

      // Operator
      operatorName: json['operator_name'] ?? json['operatorName'],
      operatorPhone: json['operator_phone'] ?? json['operatorPhone'],
      operatorGender: json['operator_gender'] ?? json['operatorGender'],
      operatorPhoto: json['operator_photo'] ?? json['operatorPhoto'],
      operatorLicense: json['operator_license'] ?? json['operatorLicense'],
      operatorDob: json['operator_dob'] != null || json['operatorDob'] != null
          ? DateTime.tryParse(json['operator_dob'] ?? json['operatorDob'])
          : null,

      // Operator Document
      operatorDocumentUrl:
          json['operator_document_url'] ?? json['operatorDocumentUrl'],
      operatorDocumentVerified:
          json['operator_document_verified'] ??
          json['operatorDocumentVerified'] ??
          false,

      // Currency and country
      currency: json['currency'] ?? 'INR',
      countryCode: json['country_code'] ?? json['countryCode'] ?? 'IN',
    );
  }
}
