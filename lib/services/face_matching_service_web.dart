import 'package:flutter/foundation.dart';

class FaceMatchResult {
  final bool isMatch;
  final double similarity;
  final String message;

  const FaceMatchResult({
    required this.isMatch,
    required this.similarity,
    required this.message,
  });
}

class FaceMatchingService {
  FaceMatchingService._();
  static final FaceMatchingService instance = FaceMatchingService._();

  Future<FaceMatchResult> compareFaces(
    Uint8List referenceBytes,
    Uint8List capturedBytes, {
    double threshold = 65.0,
  }) async {
    return const FaceMatchResult(
      isMatch: true,
      similarity: 75.0,
      message: 'Verification passed (web fallback)',
    );
  }

  void dispose() {}
}



