enum ReviewType { userToProvider, providerToUser }

class Review {
  final String id;
  final String bookingId;
  final String reviewerId; // Who wrote the review
  final String revieweeId; // Who is being reviewed
  final ReviewType type;
  final double rating; // 1-5 stars
  final String? comment;
  final List<String> mediaUrls; // photos attached to review
  final DateTime createdAt;

  Review({
    required this.id,
    required this.bookingId,
    required this.reviewerId,
    required this.revieweeId,
    required this.type,
    required this.rating,
    this.comment,
    this.mediaUrls = const [],
    required this.createdAt,
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
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'],
      mediaUrls: mediaUrls,
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at']),
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
