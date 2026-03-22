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
    return Review(
      id: json['id'],
      bookingId: json['bookingId'],
      reviewerId: json['reviewerId'],
      revieweeId: json['revieweeId'],
      type: ReviewType.values.firstWhere((e) => e.name == json['type']),
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
