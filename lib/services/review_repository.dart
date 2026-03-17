import 'package:flutter/foundation.dart';

class VehicleReview {
  final String id;
  final String vehicleId;
  final String reviewerName;
  final double rating;
  final String? comment;
  final DateTime createdAt;

  const VehicleReview({
    required this.id,
    required this.vehicleId,
    required this.reviewerName,
    required this.rating,
    this.comment,
    required this.createdAt,
  });
}

class BookingReview {
  final String id;
  final String bookingId;
  final String providerId;
  final String userId;
  final double rating;
  final String? comment;
  final DateTime createdAt;

  const BookingReview({
    required this.id,
    required this.bookingId,
    required this.providerId,
    required this.userId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });
}

class ReviewRepository {
  ReviewRepository._();

  static final ReviewRepository instance = ReviewRepository._();

  final ValueNotifier<List<VehicleReview>> _vehicleReviews =
      ValueNotifier<List<VehicleReview>>(<VehicleReview>[]);

  final ValueNotifier<List<BookingReview>> _bookingReviews =
      ValueNotifier<List<BookingReview>>(<BookingReview>[]);

  ValueListenable<List<VehicleReview>> get vehicleReviews => _vehicleReviews;
  ValueListenable<List<BookingReview>> get bookingReviews => _bookingReviews;

  List<VehicleReview> getReviewsForVehicle(String vehicleId) {
    return _vehicleReviews.value.where((r) => r.vehicleId == vehicleId).toList();
  }

  List<BookingReview> getReviewsForProvider(String providerId) {
    return _bookingReviews.value.where((r) => r.providerId == providerId).toList();
  }

  List<BookingReview> getReviewsForUser(String userId) {
    return _bookingReviews.value.where((r) => r.userId == userId).toList();
  }

  void addReview({
    required String vehicleId,
    required String reviewerName,
    required double rating,
    String? comment,
  }) {
    final newReview = VehicleReview(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      vehicleId: vehicleId,
      reviewerName: reviewerName,
      rating: rating,
      comment: comment?.trim().isEmpty == true ? null : comment?.trim(),
      createdAt: DateTime.now(),
    );

    _vehicleReviews.value = [newReview, ..._vehicleReviews.value];
  }

  void addBookingReview({
    required String bookingId,
    required String providerId,
    required String userId,
    required double rating,
    String? comment,
  }) {
    final newReview = BookingReview(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      bookingId: bookingId,
      providerId: providerId,
      userId: userId,
      rating: rating,
      comment: comment?.trim().isEmpty == true ? null : comment?.trim(),
      createdAt: DateTime.now(),
    );

    _bookingReviews.value = [newReview, ..._bookingReviews.value];
  }
}
