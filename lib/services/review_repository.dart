import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review.dart';

class ReviewRepository {
  ReviewRepository._();
  static final ReviewRepository instance = ReviewRepository._();

  static const _storageKey = 'reviews_data';

  final ValueNotifier<List<Review>> reviews = ValueNotifier<List<Review>>([]);

  Future<void> init() async {
    await _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reviewsData = prefs.getString(_storageKey);
      if (reviewsData != null) {
        final List<dynamic> jsonList = jsonDecode(reviewsData);
        reviews.value = jsonList
            .map((e) => Review.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading reviews: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reviewsData = jsonEncode(
        reviews.value.map((e) => e.toJson()).toList(),
      );
      await prefs.setString(_storageKey, reviewsData);
    } catch (e) {
      debugPrint('Error persisting reviews: $e');
    }
  }

  /// Add a new review
  Future<Review> addReview({
    required String bookingId,
    required String reviewerId,
    required String revieweeId,
    required ReviewType type,
    required double rating,
    String? comment,
  }) async {
    final review = Review(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      bookingId: bookingId,
      reviewerId: reviewerId,
      revieweeId: revieweeId,
      type: type,
      rating: rating,
      comment: comment,
      createdAt: DateTime.now(),
    );

    reviews.value = [review, ...reviews.value];
    await _persist();
    
    // Sync to Supabase
    await _syncReviewToSupabase(review);
    
    return review;
  }

  Future<void> _syncReviewToSupabase(Review review) async {
    try {
      final supabase = Supabase.instance.client;
      
      await supabase.from('reviews').insert({
        'id': review.id,
        'booking_id': review.bookingId,
        'reviewer_id': review.reviewerId,
        'reviewee_id': review.revieweeId,
        'rating': review.rating,
        'comment': review.comment,
        'created_at': review.createdAt.toIso8601String(),
      });

      debugPrint('✅ Review synced to Supabase: ${review.id}');
    } catch (e) {
      debugPrint('❌ Failed to sync review to Supabase: $e');
    }
  }

  /// Check if user has already reviewed a booking
  bool hasReviewed({required String bookingId, required String reviewerId}) {
    return reviews.value.any(
      (r) => r.bookingId == bookingId && r.reviewerId == reviewerId,
    );
  }

  /// Get reviews for a specific user/provider
  List<Review> getReviewsForUser(String userId) {
    return reviews.value.where((r) => r.revieweeId == userId).toList();
  }

  /// Get reviews by a specific user
  List<Review> getReviewsByUser(String userId) {
    return reviews.value.where((r) => r.reviewerId == userId).toList();
  }

  /// Get average rating for a user
  double getAverageRating(String userId) {
    final userReviews = getReviewsForUser(userId);
    if (userReviews.isEmpty) return 0.0;
    
    final sum = userReviews.fold<double>(0, (sum, r) => sum + r.rating);
    return sum / userReviews.length;
  }

  /// Get review for a specific booking
  Review? getReviewForBooking({
    required String bookingId,
    required String reviewerId,
  }) {
    try {
      return reviews.value.firstWhere(
        (r) => r.bookingId == bookingId && r.reviewerId == reviewerId,
      );
    } catch (_) {
      return null;
    }
  }
}
