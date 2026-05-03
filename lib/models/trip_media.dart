/// Represents the trip_media JSONB column in the bookings table.
///
/// Structure:
/// {
///   "start": {
///     "provider": {"images": [], "video_url": null, "uploaded_at": null},
///     "customer": {"images": [], "video_url": null, "uploaded_at": null}
///   },
///   "end": {
///     "provider": {"images": [], "video_url": null, "uploaded_at": null},
///     "customer": {"images": [], "video_url": null, "uploaded_at": null}
///   }
/// }
library;

class TripMediaParty {
  final List<String> images;   // Supabase Storage URLs
  final String? videoUrl;      // Single Supabase Storage URL (≤30 sec)
  final DateTime? uploadedAt;  // When this party submitted their media

  const TripMediaParty({
    this.images = const [],
    this.videoUrl,
    this.uploadedAt,
  });

  bool get hasMedia => images.isNotEmpty || videoUrl != null;

  TripMediaParty copyWith({
    List<String>? images,
    String? videoUrl,
    DateTime? uploadedAt,
    bool clearVideo = false,
  }) {
    return TripMediaParty(
      images: images ?? this.images,
      videoUrl: clearVideo ? null : (videoUrl ?? this.videoUrl),
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'images': images,
        'video_url': videoUrl,
        'uploaded_at': uploadedAt?.toUtc().toIso8601String(),
      };

  factory TripMediaParty.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TripMediaParty();
    final rawImages = json['images'];
    final rawUploadedAt = json['uploaded_at'];
    return TripMediaParty(
      images: rawImages is List
          ? List<String>.from(rawImages.whereType<String>())
          : const [],
      videoUrl: json['video_url'] as String?,
      uploadedAt: rawUploadedAt != null
          ? DateTime.tryParse(rawUploadedAt as String)?.toLocal()
          : null,
    );
  }
}

class TripMediaPhase {
  final TripMediaParty provider;
  final TripMediaParty customer;

  const TripMediaPhase({
    this.provider = const TripMediaParty(),
    this.customer = const TripMediaParty(),
  });

  bool get hasAnyMedia => provider.hasMedia || customer.hasMedia;

  TripMediaPhase copyWith({
    TripMediaParty? provider,
    TripMediaParty? customer,
  }) {
    return TripMediaPhase(
      provider: provider ?? this.provider,
      customer: customer ?? this.customer,
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider.toJson(),
        'customer': customer.toJson(),
      };

  factory TripMediaPhase.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TripMediaPhase();
    return TripMediaPhase(
      provider:
          TripMediaParty.fromJson(json['provider'] as Map<String, dynamic>?),
      customer:
          TripMediaParty.fromJson(json['customer'] as Map<String, dynamic>?),
    );
  }
}

class TripMedia {
  final TripMediaPhase start;
  final TripMediaPhase end;

  const TripMedia({
    this.start = const TripMediaPhase(),
    this.end = const TripMediaPhase(),
  });

  TripMedia copyWith({
    TripMediaPhase? start,
    TripMediaPhase? end,
  }) {
    return TripMedia(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  Map<String, dynamic> toJson() => {
        'start': start.toJson(),
        'end': end.toJson(),
      };

  factory TripMedia.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TripMedia();
    return TripMedia(
      start: TripMediaPhase.fromJson(json['start'] as Map<String, dynamic>?),
      end: TripMediaPhase.fromJson(json['end'] as Map<String, dynamic>?),
    );
  }

  static const TripMedia empty = TripMedia();

  bool get isEmpty => !start.hasAnyMedia && !end.hasAnyMedia;
}
