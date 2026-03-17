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
  
  // Rating and statistics
  final double averageRating;
  final int totalRatings;
  final int totalBookings;
  final int activePostsCount;

  // Document verification status
  final bool rcVerified;
  final DateTime? rcVerifiedAt;
  final bool insuranceVerified;
  final DateTime? insuranceVerifiedAt;
  final DateTime? insuranceExpiryDate;
  final bool dlVerified;
  final DateTime? dlVerifiedAt;
  final bool aadhaarVerified;
  final DateTime? aadhaarVerifiedAt;
  final bool panVerified;
  final DateTime? panVerifiedAt;

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
    this.averageRating = 0.0,
    this.totalRatings = 0,
    this.totalBookings = 0,
    this.activePostsCount = 0,
    this.rcVerified = false,
    this.rcVerifiedAt,
    this.insuranceVerified = false,
    this.insuranceVerifiedAt,
    this.insuranceExpiryDate,
    this.dlVerified = false,
    this.dlVerifiedAt,
    this.aadhaarVerified = false,
    this.aadhaarVerifiedAt,
    this.panVerified = false,
    this.panVerifiedAt,
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
    double? averageRating,
    int? totalRatings,
    int? totalBookings,
    int? activePostsCount,
    bool? rcVerified,
    DateTime? rcVerifiedAt,
    bool? insuranceVerified,
    DateTime? insuranceVerifiedAt,
    DateTime? insuranceExpiryDate,
    bool? dlVerified,
    DateTime? dlVerifiedAt,
    bool? aadhaarVerified,
    DateTime? aadhaarVerifiedAt,
    bool? panVerified,
    DateTime? panVerifiedAt,
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
      averageRating: averageRating ?? this.averageRating,
      totalRatings: totalRatings ?? this.totalRatings,
      totalBookings: totalBookings ?? this.totalBookings,
      activePostsCount: activePostsCount ?? this.activePostsCount,
      rcVerified: rcVerified ?? this.rcVerified,
      rcVerifiedAt: rcVerifiedAt ?? this.rcVerifiedAt,
      insuranceVerified: insuranceVerified ?? this.insuranceVerified,
      insuranceVerifiedAt: insuranceVerifiedAt ?? this.insuranceVerifiedAt,
      insuranceExpiryDate: insuranceExpiryDate ?? this.insuranceExpiryDate,
      dlVerified: dlVerified ?? this.dlVerified,
      dlVerifiedAt: dlVerifiedAt ?? this.dlVerifiedAt,
      aadhaarVerified: aadhaarVerified ?? this.aadhaarVerified,
      aadhaarVerifiedAt: aadhaarVerifiedAt ?? this.aadhaarVerifiedAt,
      panVerified: panVerified ?? this.panVerified,
      panVerifiedAt: panVerifiedAt ?? this.panVerifiedAt,
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
      'average_rating': averageRating,
      'total_ratings': totalRatings,
      'total_bookings': totalBookings,
      'active_posts_count': activePostsCount,
      'rc_verified': rcVerified,
      'rc_verified_at': rcVerifiedAt?.toIso8601String(),
      'insurance_verified': insuranceVerified,
      'insurance_verified_at': insuranceVerifiedAt?.toIso8601String(),
      'insurance_expiry_date': insuranceExpiryDate?.toIso8601String(),
      'dl_verified': dlVerified,
      'dl_verified_at': dlVerifiedAt?.toIso8601String(),
      'aadhaar_verified': aadhaarVerified,
      'aadhaar_verified_at': aadhaarVerifiedAt?.toIso8601String(),
      'pan_verified': panVerified,
      'pan_verified_at': panVerifiedAt?.toIso8601String(),
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
      averageRating: (json['average_rating'] ?? json['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: json['total_ratings'] ?? json['totalRatings'] ?? 0,
      totalBookings: json['total_bookings'] ?? json['totalBookings'] ?? 0,
      activePostsCount: json['active_posts_count'] ?? json['activePostsCount'] ?? 0,
      rcVerified: json['rc_verified'] ?? json['rcVerified'] ?? false,
      rcVerifiedAt: json['rc_verified_at'] != null || json['rcVerifiedAt'] != null
          ? DateTime.parse(json['rc_verified_at'] ?? json['rcVerifiedAt'])
          : null,
      insuranceVerified: json['insurance_verified'] ?? json['insuranceVerified'] ?? false,
      insuranceVerifiedAt: json['insurance_verified_at'] != null || json['insuranceVerifiedAt'] != null
          ? DateTime.parse(json['insurance_verified_at'] ?? json['insuranceVerifiedAt'])
          : null,
      insuranceExpiryDate: json['insurance_expiry_date'] != null || json['insuranceExpiryDate'] != null
          ? DateTime.parse(json['insurance_expiry_date'] ?? json['insuranceExpiryDate'])
          : null,
      dlVerified: json['dl_verified'] ?? json['dlVerified'] ?? false,
      dlVerifiedAt: json['dl_verified_at'] != null || json['dlVerifiedAt'] != null
          ? DateTime.parse(json['dl_verified_at'] ?? json['dlVerifiedAt'])
          : null,
      aadhaarVerified: json['aadhaar_verified'] ?? json['aadhaarVerified'] ?? false,
      aadhaarVerifiedAt: json['aadhaar_verified_at'] != null || json['aadhaarVerifiedAt'] != null
          ? DateTime.parse(json['aadhaar_verified_at'] ?? json['aadhaarVerifiedAt'])
          : null,
      panVerified: json['pan_verified'] ?? json['panVerified'] ?? false,
      panVerifiedAt: json['pan_verified_at'] != null || json['panVerifiedAt'] != null
          ? DateTime.parse(json['pan_verified_at'] ?? json['panVerifiedAt'])
          : null,
    );
  }
}
