enum ReviewType { userToProvider, providerToUser }

class Review {
  final String id;
  final String bookingId;
  final String reviewerId; // Who wrote the review
  final String revieweeId; // Who is being reviewed
  final ReviewType type;
  final double rating; // 1-5 stars
  final String? comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.bookingId,
    required this.reviewerId,
    required this.revieweeId,
    required this.type,
    required this.rating,
    this.comment,
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
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    // Support both camelCase (local storage) and snake_case (Supabase)
    final typeStr = json['type'] ?? json['review_type'];
    
    return Review(
      id: json['id'],
      bookingId: json['bookingId'] ?? json['booking_id'],
      reviewerId: json['reviewerId'] ?? json['reviewer_id'],
      revieweeId: json['revieweeId'] ?? json['reviewee_id'],
      type: typeStr != null 
          ? ReviewType.values.firstWhere(
              (e) => e.name == typeStr || _mapReviewType(typeStr) == e.name,
              orElse: () => ReviewType.userToProvider,
            )
          : ReviewType.userToProvider,
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'],
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at']),
    );
  }
  
  // Map Supabase review_type to enum name
  static String _mapReviewType(String dbType) {
    switch (dbType) {
      case 'customer_to_provider':
        return 'userToProvider';
      case 'provider_to_customer':
        return 'providerToUser';
      default:
        return dbType;
    }
  }
}



