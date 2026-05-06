import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class AIService {
  static final AIService instance = AIService._();
  AIService._();

  final _functions = FirebaseFunctions.instance;

  /// Moderate text content for inappropriate material
  Future<ContentModerationResult?> moderateContent({
    required String text,
    required ContentType type,
  }) async {
    try {
      final callable = _functions.httpsCallable('moderateContent');
      final result = await callable.call({
        'text': text,
        'type': type.name,
      });

      if (result.data['success'] == true) {
        return ContentModerationResult.fromJson(result.data['analysis']);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Content moderation failed: $e');
      return null;
    }
  }

  /// Analyze images for quality and appropriateness
  Future<List<ImageAnalysisResult>?> analyzeImages({
    required List<String> imageUrls,
    required ImageType type,
  }) async {
    try {
      final callable = _functions.httpsCallable('analyzeImages');
      final result = await callable.call({
        'imageUrls': imageUrls,
        'type': type.name,
      });

      if (result.data['success'] == true) {
        final results = result.data['results'] as List;
        return results
            .map((r) => ImageAnalysisResult.fromJson(r))
            .toList();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Image analysis failed: $e');
      return null;
    }
  }

  /// Generate smart suggestions for various use cases
  Future<SuggestionResult?> generateSuggestions({
    required SuggestionType type,
    required Map<String, dynamic> inputData,
    String? context,
  }) async {
    try {
      final callable = _functions.httpsCallable('generateSuggestions');
      final result = await callable.call({
        'type': type.name,
        'data': inputData,
        'context': context,
      });

      if (result.data['success'] == true) {
        return SuggestionResult.fromJson(result.data['suggestions']);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Suggestions generation failed: $e');
      return null;
    }
  }

  /// Quick content check - returns true if content is safe
  Future<bool> isContentSafe(String text, {ContentType type = ContentType.general}) async {
    final result = await moderateContent(text: text, type: type);
    return result?.approved ?? false;
  }

  /// Quick image check - returns true if all images are appropriate
  Future<bool> areImagesAppropriate(List<String> imageUrls, {ImageType type = ImageType.vehicle}) async {
    final results = await analyzeImages(imageUrls: imageUrls, type: type);
    if (results == null) return false;
    
    return results.every((result) => result.success && (result.analysis?.appropriate ?? false));
  }
}

// Enums
enum ContentType {
  general,
  vehicleDescription,
  userReview,
  chatMessage,
}

enum ImageType {
  vehicle,
  profile,
  general,
}

enum SuggestionType {
  vehicleTitle,
  routeOptimization,
  pricingSuggestion,
}

// Data Models
class ContentModerationResult {
  final bool approved;
  final String? reason;
  final double confidence;
  final String? suggestions;
  final String? sentiment;
  final String? severity;

  ContentModerationResult({
    required this.approved,
    this.reason,
    required this.confidence,
    this.suggestions,
    this.sentiment,
    this.severity,
  });

  factory ContentModerationResult.fromJson(Map<String, dynamic> json) {
    return ContentModerationResult(
      approved: json['approved'] ?? false,
      reason: json['reason'],
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      suggestions: json['suggestions'],
      sentiment: json['sentiment'],
      severity: json['severity'],
    );
  }
}

class ImageAnalysisResult {
  final String imageUrl;
  final bool success;
  final String? error;
  final ImageAnalysis? analysis;

  ImageAnalysisResult({
    required this.imageUrl,
    required this.success,
    this.error,
    this.analysis,
  });

  factory ImageAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ImageAnalysisResult(
      imageUrl: json['imageUrl'],
      success: json['success'] ?? false,
      error: json['error'],
      analysis: json['analysis'] != null 
          ? ImageAnalysis.fromJson(json['analysis'])
          : null,
    );
  }
}

class ImageAnalysis {
  final bool appropriate;
  final String quality;
  final String? description;
  final List<String> issues;
  final bool? isVehicle;
  final bool? hasFace;
  final String? condition;

  ImageAnalysis({
    required this.appropriate,
    required this.quality,
    this.description,
    this.issues = const [],
    this.isVehicle,
    this.hasFace,
    this.condition,
  });

  factory ImageAnalysis.fromJson(Map<String, dynamic> json) {
    return ImageAnalysis(
      appropriate: json['appropriate'] ?? false,
      quality: json['quality'] ?? 'fair',
      description: json['description'],
      issues: json['issues'] != null 
          ? List<String>.from(json['issues'])
          : [],
      isVehicle: json['isVehicle'],
      hasFace: json['hasFace'],
      condition: json['condition'],
    );
  }
}

class SuggestionResult {
  final dynamic suggestions;

  SuggestionResult({required this.suggestions});

  factory SuggestionResult.fromJson(Map<String, dynamic> json) {
    return SuggestionResult(suggestions: json);
  }

  // Helper getters for different suggestion types
  List<String>? get titleSuggestions {
    if (suggestions is Map && suggestions['suggestions'] is List) {
      return List<String>.from(suggestions['suggestions']);
    }
    return null;
  }

  Map<String, dynamic>? get routeOptimization {
    if (suggestions is Map && suggestions['suggestions'] is Map) {
      return Map<String, dynamic>.from(suggestions['suggestions']);
    }
    return null;
  }

  Map<String, dynamic>? get pricingSuggestion {
    if (suggestions is Map && suggestions['suggestions'] is Map) {
      return Map<String, dynamic>.from(suggestions['suggestions']);
    }
    return null;
  }
}

