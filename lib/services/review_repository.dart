import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review.dart';
import '../models/service_type.dart';

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
      // First load from Supabase (source of truth)
      await _loadFromSupabase();

      // Then load from local storage as fallback/cache
      if (reviews.value.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final reviewsData = prefs.getString(_storageKey);
        if (reviewsData != null) {
          final List<dynamic> jsonList = jsonDecode(reviewsData);
          reviews.value = jsonList
              .map((e) => Review.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading reviews: $e');
    }
  }

  Future<void> _loadFromSupabase() async {
    try {
      final supabase = Supabase.instance.client;

      // Load all reviews (they're public data for ratings)
      final response = await supabase
          .from('reviews')
          .select()
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        debugPrint('✅ No reviews found in Supabase');
        return;
      }

      final loadedReviews = (response as List)
          .map((json) => Review.fromJson(json as Map<String, dynamic>))
          .toList();

      reviews.value = loadedReviews;
      await _persist(); // Save to local storage

      debugPrint('✅ Loaded ${loadedReviews.length} reviews from Supabase');
    } catch (e) {
      debugPrint('❌ Failed to load reviews from Supabase: $e');
      // Don't throw - allow app to continue with local data
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
    ServiceType? serviceType,
    required double rating,
    String? comment,
    List<String> mediaUrls = const [],
    bool hasOperator = false,
  }) async {
    final review = Review(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      bookingId: bookingId,
      reviewerId: reviewerId,
      revieweeId: revieweeId,
      type: type,
      serviceType: serviceType,
      hasOperator: hasOperator,
      rating: rating,
      comment: comment,
      mediaUrls: mediaUrls,
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

      // Map enum to reviewer_role (DB column name)
      final reviewerRole = review.type == ReviewType.userToProvider
          ? 'customer'
          : 'provider';

      // Determine customer/provider IDs based on role
      final customerId = review.type == ReviewType.userToProvider
          ? review.reviewerId
          : review.revieweeId;
      final providerId = review.type == ReviewType.userToProvider
          ? review.revieweeId
          : review.reviewerId;

      // Build trip_data JSON with only essential fields
      final tripData = {
        'service_type': review.serviceType?.name,
        'has_operator': review.hasOperator,
      };

      await supabase.from('reviews').insert({
        'id': review.id,
        'booking_id': int.tryParse(review.bookingId) ?? review.bookingId,
        'reviewer_id': review.reviewerId,
        'profile_customer_id': customerId,
        'profile_provider_id': providerId,
        'reviewer_role': reviewerRole,
        'rating': review.rating.round(),
        'comment': review.comment,
        'media_urls': review.mediaUrls.isEmpty
            ? null
            : review.mediaUrls, // review_media URLs
        'trip_data': tripData, // Only service_type and has_operator
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
