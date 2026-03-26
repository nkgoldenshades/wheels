import 'service_type.dart';

enum VehicleGpsMode { deviceLive, externalLink, manual }

class Vehicle {
  final String id;
  final String userId; // Add userId to associate vehicle with user
  final String userName; // Owner's display name
  final String name;
  final String type;
  final int? year;
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

  // Document verification status
  final bool rcVerified;
  final DateTime? rcVerifiedAt;
  final String? rcImageBase64;
  final bool insuranceVerified;
  final DateTime? insuranceVerifiedAt;
  final DateTime? insuranceExpiryDate;
  final String? insuranceImageBase64;
  final bool dlVerified;
  final DateTime? dlVerifiedAt;
  final String? dlImageBase64;
  final bool aadhaarVerified;
  final DateTime? aadhaarVerifiedAt;
  final String? aadhaarImageBase64;
  final bool panVerified;
  final DateTime? panVerifiedAt;
  final String? panImageBase64;

  // Operator information (optional - person who operates/handles this vehicle)
  final String? operatorName;
  final String? operatorPhone;
  final String? operatorPhoto; // base64 or URL
  final String? operatorLicense; // License number for records

  /// True only when all mandatory + optional docs are verified and none expired
  bool get isFullyVerified {
    final insuranceValid = insuranceVerified &&
        (insuranceExpiryDate == null || insuranceExpiryDate!.isAfter(DateTime.now()));
    return rcVerified && insuranceValid && dlVerified && aadhaarVerified && panVerified;
  }

  Vehicle({
    required this.id,
    required this.userId,
    required this.userName,
    required this.name,
    required this.type,
    this.year,
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
    this.rcVerified = false,
    this.rcVerifiedAt,
    this.rcImageBase64,
    this.insuranceVerified = false,
    this.insuranceVerifiedAt,
    this.insuranceExpiryDate,
    this.insuranceImageBase64,
    this.dlVerified = false,
    this.dlVerifiedAt,
    this.dlImageBase64,
    this.aadhaarVerified = false,
    this.aadhaarVerifiedAt,
    this.aadhaarImageBase64,
    this.panVerified = false,
    this.panVerifiedAt,
    this.panImageBase64,
    this.operatorName,
    this.operatorPhone,
    this.operatorPhoto,
    this.operatorLicense,
  });

  Vehicle copyWith({
    String? id,
    String? userId,
    String? userName,
    String? name,
    String? type,
    int? year,
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
    bool? rcVerified,
    DateTime? rcVerifiedAt,
    String? rcImageBase64,
    bool? insuranceVerified,
    DateTime? insuranceVerifiedAt,
    DateTime? insuranceExpiryDate,
    String? insuranceImageBase64,
    bool? dlVerified,
    DateTime? dlVerifiedAt,
    String? dlImageBase64,
    bool? aadhaarVerified,
    DateTime? aadhaarVerifiedAt,
    String? aadhaarImageBase64,
    bool? panVerified,
    DateTime? panVerifiedAt,
    String? panImageBase64,
    String? operatorName,
    String? operatorPhone,
    String? operatorPhoto,
    String? operatorLicense,
  }) {
    return Vehicle(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      name: name ?? this.name,
      type: type ?? this.type,
      year: year ?? this.year,
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
      rcVerified: rcVerified ?? this.rcVerified,
      rcVerifiedAt: rcVerifiedAt ?? this.rcVerifiedAt,
      rcImageBase64: rcImageBase64 ?? this.rcImageBase64,
      insuranceVerified: insuranceVerified ?? this.insuranceVerified,
      insuranceVerifiedAt: insuranceVerifiedAt ?? this.insuranceVerifiedAt,
      insuranceExpiryDate: insuranceExpiryDate ?? this.insuranceExpiryDate,
      insuranceImageBase64: insuranceImageBase64 ?? this.insuranceImageBase64,
      dlVerified: dlVerified ?? this.dlVerified,
      dlVerifiedAt: dlVerifiedAt ?? this.dlVerifiedAt,
      dlImageBase64: dlImageBase64 ?? this.dlImageBase64,
      aadhaarVerified: aadhaarVerified ?? this.aadhaarVerified,
      aadhaarVerifiedAt: aadhaarVerifiedAt ?? this.aadhaarVerifiedAt,
      aadhaarImageBase64: aadhaarImageBase64 ?? this.aadhaarImageBase64,
      panVerified: panVerified ?? this.panVerified,
      panVerifiedAt: panVerifiedAt ?? this.panVerifiedAt,
      panImageBase64: panImageBase64 ?? this.panImageBase64,
      operatorName: operatorName ?? this.operatorName,
      operatorPhone: operatorPhone ?? this.operatorPhone,
      operatorPhoto: operatorPhoto ?? this.operatorPhoto,
      operatorLicense: operatorLicense ?? this.operatorLicense,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'name': name,
      'type': type,
      'year': year,
      'capabilities': capabilities.map((e) => e.name).toList(),
      'profile_image': profileImage,
      'gallery_images': galleryImages,
      'video_url': videoUrl,
      'created_at': createdAt.toIso8601String(),
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
      'active_posts_count': activePostsCount,
      'rc_verified': rcVerified,
      'rc_verified_at': rcVerifiedAt?.toIso8601String(),
      'rc_image': rcImageBase64,
      'insurance_verified': insuranceVerified,
      'insurance_verified_at': insuranceVerifiedAt?.toIso8601String(),
      'insurance_expiry_date': insuranceExpiryDate?.toIso8601String(),
      'insurance_image': insuranceImageBase64,
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
      'operator_photo': operatorPhoto,
      'operator_license': operatorLicense,
      'is_online': true, // Default to online when creating
      'is_user_vehicle': false, // Will be set by repository
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    // Support both camelCase (local) and snake_case (Supabase)
    return Vehicle(
      id: json['id'],
      userId: json['user_id'] ?? json['userId'],
      userName: json['user_name'] ?? json['userName'] ?? 'Unknown User',
      name: json['name'],
      type: json['type'],
      year: json['year'],
      capabilities: (json['capabilities'] as List)
          .map((e) => ServiceType.values.firstWhere((s) => s.name == e))
          .toList(),
      profileImage: json['profile_image'] ?? json['profileImage'],
      galleryImages: json['gallery_images'] != null 
          ? List<String>.from(json['gallery_images'])
          : (json['galleryImages'] != null ? List<String>.from(json['galleryImages']) : []),
      videoUrl: json['video_url'] ?? json['videoUrl'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      gpsMode: VehicleGpsMode.values.firstWhere(
        (m) => m.name == (json['gps_mode'] ?? json['gpsMode']),
        orElse: () => VehicleGpsMode.deviceLive,
      ),
      gpsExternalLink: json['gps_external_link'] ?? json['gpsExternalLink'],
      manualLat: (json['manual_lat'] ?? json['manualLat'] as num?)?.toDouble(),
      manualLng: (json['manual_lng'] ?? json['manualLng'] as num?)?.toDouble(),
      lastKnownLat: (json['last_known_lat'] ?? json['lastKnownLat'] as num?)?.toDouble(),
      lastKnownLng: (json['last_known_lng'] ?? json['lastKnownLng'] as num?)?.toDouble(),
      isVerifiedToggle: json['is_verified_toggle'] ?? json['isVerifiedToggle'] ?? false,
      isExpertToggle: json['is_expert_toggle'] ?? json['isExpertToggle'] ?? false,
      averageRating: (json['average_rating'] ?? json['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: json['total_ratings'] ?? json['totalRatings'] ?? 0,
      totalBookings: json['total_bookings'] ?? json['totalBookings'] ?? 0,
      activePostsCount: json['active_posts_count'] ?? json['activePostsCount'] ?? 0,
      rcVerified: json['rc_verified'] ?? json['rcVerified'] ?? false,
      rcVerifiedAt: json['rc_verified_at'] != null || json['rcVerifiedAt'] != null
          ? DateTime.parse(json['rc_verified_at'] ?? json['rcVerifiedAt'])
          : null,
      rcImageBase64: json['rc_image'] ?? json['rcImage'],
      insuranceVerified: json['insurance_verified'] ?? json['insuranceVerified'] ?? false,
      insuranceVerifiedAt: json['insurance_verified_at'] != null || json['insuranceVerifiedAt'] != null
          ? DateTime.parse(json['insurance_verified_at'] ?? json['insuranceVerifiedAt'])
          : null,
      insuranceExpiryDate: json['insurance_expiry_date'] != null || json['insuranceExpiryDate'] != null
          ? DateTime.parse(json['insurance_expiry_date'] ?? json['insuranceExpiryDate'])
          : null,
      insuranceImageBase64: json['insurance_image'] ?? json['insuranceImage'],
      dlVerified: json['dl_verified'] ?? json['dlVerified'] ?? false,
      dlVerifiedAt: json['dl_verified_at'] != null || json['dlVerifiedAt'] != null
          ? DateTime.parse(json['dl_verified_at'] ?? json['dlVerifiedAt'])
          : null,
      dlImageBase64: json['dl_image'] ?? json['dlImage'],
      aadhaarVerified: json['aadhaar_verified'] ?? json['aadhaarVerified'] ?? false,
      aadhaarVerifiedAt: json['aadhaar_verified_at'] != null || json['aadhaarVerifiedAt'] != null
          ? DateTime.parse(json['aadhaar_verified_at'] ?? json['aadhaarVerifiedAt'])
          : null,
      aadhaarImageBase64: json['aadhaar_image'] ?? json['aadhaarImage'],
      panVerified: json['pan_verified'] ?? json['panVerified'] ?? false,
      panVerifiedAt: json['pan_verified_at'] != null || json['panVerifiedAt'] != null
          ? DateTime.parse(json['pan_verified_at'] ?? json['panVerifiedAt'])
          : null,
      panImageBase64: json['pan_image'] ?? json['panImage'],
      operatorName: json['operator_name'] ?? json['operatorName'],
      operatorPhone: json['operator_phone'] ?? json['operatorPhone'],
      operatorPhoto: json['operator_photo'] ?? json['operatorPhoto'],
      operatorLicense: json['operator_license'] ?? json['operatorLicense'],
    );
  }
}
