import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/slot.dart';
import '../models/service_type.dart';
import '../models/slot_type.dart';
import '../models/pickup_mode.dart';
import '../models/post_mode.dart';
import 'slot_repository.dart';
import 'customer_slot_repository.dart';

/// AI-powered search and recommendation service for posts
class AISearchService {
  AISearchService._();
  static final AISearchService instance = AISearchService._();

  /// Search posts using AI-powered natural language understanding
  /// Example queries:
  /// - "cheap ride from Chennai to Bangalore tomorrow"
  /// - "luxury car for wedding next week"
  /// - "truck for moving furniture this weekend"
  Future<AISearchResult> searchWithAI(String query) async {
    try {
      debugPrint('🤖 AI Search: "$query"');
      
      // Call Supabase Edge Function for AI search
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'ai-search-posts',
        body: {'query': query},
      );

      if (response.status != 200) {
        throw Exception('AI search failed: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;
      
      return AISearchResult(
        query: query,
        intent: SearchIntent.fromJson(data['intent'] as Map<String, dynamic>),
        suggestions: (data['suggestions'] as List?)
            ?.map((s) => s.toString())
            .toList() ?? [],
        matchedPostIds: (data['matched_post_ids'] as List?)
            ?.map((id) => id.toString())
            .toList() ?? [],
      );
    } catch (e) {
      debugPrint('❌ AI search error: $e');
      // Fallback to local keyword-based search
      return _fallbackSearch(query);
    }
  }

  /// Get AI-powered recommendations based on user behavior and preferences
  Future<List<AIRecommendation>> getRecommendations({
    String? userId,
    int limit = 10,
  }) async {
    try {
      debugPrint('🤖 Getting AI recommendations for user: $userId');
      
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'ai-recommend-posts',
        body: {
          'user_id': userId,
          'limit': limit,
        },
      );

      if (response.status != 200) {
        throw Exception('AI recommendations failed: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;
      final recommendations = (data['recommendations'] as List)
          .map((r) => AIRecommendation.fromJson(r as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Got ${recommendations.length} AI recommendations');
      return recommendations;
    } catch (e) {
      debugPrint('❌ AI recommendations error: $e');
      // Fallback to simple recommendations
      return _fallbackRecommendations(limit);
    }
  }

  /// Analyze a post and generate AI insights
  Future<PostInsights> analyzePost(Slot slot) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'ai-analyze-post',
        body: {'post_id': slot.id},
      );

      if (response.status != 200) {
        throw Exception('AI analysis failed: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;
      return PostInsights.fromJson(data);
    } catch (e) {
      debugPrint('❌ AI analysis error: $e');
      return PostInsights(
        postId: slot.id,
        priceAnalysis: 'Price analysis unavailable',
        demandLevel: 'Unknown',
        suggestions: [],
      );
    }
  }

  /// Fallback search using local keyword matching
  AISearchResult _fallbackSearch(String query) {
    final lowerQuery = query.toLowerCase();
    
    // Get all slots (not SlotEntry, just Slot objects)
    final allSlots = [
      ...SlotRepository.instance.allSlotsRaw,
      ...CustomerSlotRepository.instance.allSlotsRaw,
    ];

    // Extract intent from keywords
    ServiceType? serviceType;
    SlotType? slotType;
    final List<String> suggestions = [];

    // Service type detection
    if (lowerQuery.contains('passenger') || lowerQuery.contains('ride') || lowerQuery.contains('taxi')) {
      serviceType = ServiceType.passenger;
      suggestions.add('Try filtering by "Passenger" service');
    } else if (lowerQuery.contains('parcel') || lowerQuery.contains('delivery') || lowerQuery.contains('package')) {
      serviceType = ServiceType.parcel;
      suggestions.add('Try filtering by "Parcel" service');
    } else if (lowerQuery.contains('lease') || lowerQuery.contains('rent') || lowerQuery.contains('rental')) {
      serviceType = ServiceType.lease;
      suggestions.add('Try filtering by "Lease" service');
    }

    // Route type detection
    if (lowerQuery.contains('from') && lowerQuery.contains('to')) {
      slotType = SlotType.fromTo;
      suggestions.add('Searching for point-to-point routes');
    } else if (lowerQuery.contains('nearby') || lowerQuery.contains('around') || lowerQuery.contains('near')) {
      slotType = SlotType.fromRange;
      suggestions.add('Searching for services in your area');
    }

    // Price detection
    double? maxPrice;
    final priceMatch = RegExp(r'under\s+(\d+)').firstMatch(lowerQuery);
    if (priceMatch != null) {
      maxPrice = double.tryParse(priceMatch.group(1)!);
      if (maxPrice != null) {
        suggestions.add('Filtering by price under ${maxPrice.toStringAsFixed(0)}');
      }
    }

    // Filter posts based on detected intent
    final matchedPostIds = allSlots.where((slot) {
      bool matches = true;

      if (serviceType != null && slot.serviceType != serviceType) {
        matches = false;
      }

      if (slotType != null && slot.slotType != slotType) {
        matches = false;
      }

      if (maxPrice != null && slot.price > maxPrice) {
        matches = false;
      }

      // Location matching
      final locations = [
        slot.fromLocation,
        slot.toLocation,
        slot.baseLocation,
      ].where((l) => l != null).join(' ').toLowerCase();

      if (!locations.contains(lowerQuery.split(' ').where((w) => w.length > 3).join('|'))) {
        // Check if any significant word from query appears in locations
        final queryWords = lowerQuery.split(' ').where((w) => w.length > 3);
        if (queryWords.isNotEmpty) {
          final hasMatch = queryWords.any((word) => locations.contains(word));
          if (!hasMatch && serviceType == null && slotType == null) {
            matches = false;
          }
        }
      }

      return matches;
    }).map((s) => s.id).toList();

    return AISearchResult(
      query: query,
      intent: SearchIntent(
        serviceType: serviceType,
        slotType: slotType,
        maxPrice: maxPrice,
        locations: [],
      ),
      suggestions: suggestions.isEmpty 
          ? ['Try using keywords like "passenger", "parcel", "lease", "from", "to", "nearby"']
          : suggestions,
      matchedPostIds: matchedPostIds,
    );
  }

  /// Fallback recommendations using simple heuristics
  List<AIRecommendation> _fallbackRecommendations(int limit) {
    final allSlots = SlotRepository.instance.allSlotsRaw;
    
    // Sort by rating and recent bookings
    final sorted = List<Slot>.from(allSlots)
      ..sort((a, b) {
        // Prioritize active posts
        if (a.isAvailable != b.isAvailable) {
          return a.isAvailable ? -1 : 1;
        }
        // Then by creation date (newest first)
        return b.createdAt.compareTo(a.createdAt);
      });

    return sorted.take(limit).map((slot) {
      return AIRecommendation(
        postId: slot.id,
        score: 0.8,
        reason: 'Popular in your area',
        tags: [slot.serviceType.displayName, slot.slotType.displayName],
      );
    }).toList();
  }
}

/// Result from AI search
class AISearchResult {
  final String query;
  final SearchIntent intent;
  final List<String> suggestions;
  final List<String> matchedPostIds;

  AISearchResult({
    required this.query,
    required this.intent,
    required this.suggestions,
    required this.matchedPostIds,
  });

  factory AISearchResult.fromJson(Map<String, dynamic> json) {
    return AISearchResult(
      query: json['query'] as String,
      intent: SearchIntent.fromJson(json['intent'] as Map<String, dynamic>),
      suggestions: (json['suggestions'] as List).map((s) => s.toString()).toList(),
      matchedPostIds: (json['matched_post_ids'] as List).map((id) => id.toString()).toList(),
    );
  }
}

/// Extracted search intent from natural language query
class SearchIntent {
  final ServiceType? serviceType;
  final SlotType? slotType;
  final PickupMode? pickupMode;
  final PostMode? postMode;
  final double? minPrice;
  final double? maxPrice;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> locations;
  final int? passengers;

  SearchIntent({
    this.serviceType,
    this.slotType,
    this.pickupMode,
    this.postMode,
    this.minPrice,
    this.maxPrice,
    this.startDate,
    this.endDate,
    this.locations = const [],
    this.passengers,
  });

  factory SearchIntent.fromJson(Map<String, dynamic> json) {
    return SearchIntent(
      serviceType: json['service_type'] != null
          ? ServiceType.values.firstWhere(
              (e) => e.name == json['service_type'],
              orElse: () => ServiceType.passenger,
            )
          : null,
      slotType: json['slot_type'] != null
          ? SlotType.values.firstWhere(
              (e) => e.name == json['slot_type'],
              orElse: () => SlotType.fromTo,
            )
          : null,
      minPrice: json['min_price'] as double?,
      maxPrice: json['max_price'] as double?,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      locations: (json['locations'] as List?)?.map((l) => l.toString()).toList() ?? [],
      passengers: json['passengers'] as int?,
    );
  }
}

/// AI recommendation for a post
class AIRecommendation {
  final String postId;
  final double score; // 0.0 to 1.0
  final String reason;
  final List<String> tags;

  AIRecommendation({
    required this.postId,
    required this.score,
    required this.reason,
    required this.tags,
  });

  factory AIRecommendation.fromJson(Map<String, dynamic> json) {
    return AIRecommendation(
      postId: json['post_id'] as String,
      score: (json['score'] as num).toDouble(),
      reason: json['reason'] as String,
      tags: (json['tags'] as List).map((t) => t.toString()).toList(),
    );
  }
}

/// AI insights about a post
class PostInsights {
  final String postId;
  final String priceAnalysis; // e.g., "20% below market average"
  final String demandLevel; // e.g., "High", "Medium", "Low"
  final List<String> suggestions; // e.g., ["Consider lowering price by 10%"]

  PostInsights({
    required this.postId,
    required this.priceAnalysis,
    required this.demandLevel,
    required this.suggestions,
  });

  factory PostInsights.fromJson(Map<String, dynamic> json) {
    return PostInsights(
      postId: json['post_id'] as String,
      priceAnalysis: json['price_analysis'] as String,
      demandLevel: json['demand_level'] as String,
      suggestions: (json['suggestions'] as List).map((s) => s.toString()).toList(),
    );
  }
}
