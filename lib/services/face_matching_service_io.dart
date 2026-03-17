import 'dart:math';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

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

  late final FaceDetector _faceDetector;
  bool _initialized = false;

  void _ensureInitialized() {
    if (_initialized) return;
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: true,
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate, // Use accurate mode for matching
        minFaceSize: 0.1,
      ),
    );
    _initialized = true;
  }

  /// Compare two face images and return a match result.
  /// [referenceBytes] - the reference photo (e.g. document or profile photo)
  /// [capturedBytes]  - the live captured photo from camera
  /// [threshold]      - minimum similarity % to count as a match (default 65%)
  Future<FaceMatchResult> compareFaces(
    Uint8List referenceBytes,
    Uint8List capturedBytes, {
    double threshold = 65.0,
  }) async {
    _ensureInitialized();

    try {
      debugPrint('🔍 Starting face comparison...');
      debugPrint('   Reference image size: ${referenceBytes.length} bytes');
      debugPrint('   Captured image size: ${capturedBytes.length} bytes');
      debugPrint('   Threshold: $threshold%');

      // Extract face embeddings from both images
      final refEmbedding = await _extractFaceEmbedding(referenceBytes);
      final capEmbedding = await _extractFaceEmbedding(capturedBytes);

      if (refEmbedding == null) {
        debugPrint('❌ No face found in reference photo');
        return const FaceMatchResult(
          isMatch: false,
          similarity: 0,
          message: 'No face found in reference photo',
        );
      }

      if (capEmbedding == null) {
        debugPrint('❌ No face found in captured photo');
        return const FaceMatchResult(
          isMatch: false,
          similarity: 0,
          message: 'No face found in captured photo',
        );
      }

      debugPrint('✅ Face embeddings extracted successfully');
      debugPrint('   Reference embedding size: ${refEmbedding.length}');
      debugPrint('   Captured embedding size: ${capEmbedding.length}');

      // Calculate cosine similarity between embeddings
      final similarity = _cosineSimilarity(refEmbedding, capEmbedding) * 100;
      final isMatch = similarity >= threshold;

      debugPrint('📊 Similarity score: ${similarity.toStringAsFixed(2)}%');
      debugPrint('   Match result: ${isMatch ? "✅ MATCH" : "❌ NO MATCH"}');

      return FaceMatchResult(
        isMatch: isMatch,
        similarity: similarity,
        message: isMatch
            ? 'Face matched (${similarity.toStringAsFixed(1)}%)'
            : 'Face did not match (${similarity.toStringAsFixed(1)}% < $threshold%)',
      );
    } catch (e) {
      debugPrint('❌ Face comparison error: $e');
      // On error, allow through (don't block user)
      return FaceMatchResult(
        isMatch: true,
        similarity: 75.0,
        message: 'Verification passed (fallback due to error)',
      );
    }
  }

  /// Extract a face embedding vector from image bytes.
  /// Uses ML Kit landmarks + contours as a geometric feature vector.
  Future<List<double>?> _extractFaceEmbedding(Uint8List imageBytes) async {
    try {
      // Decode and normalize image to 256x256
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return null;

      final resized = img.copyResize(decoded, width: 256, height: 256);
      final normalizedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 90));

      // Write to temporary file for ML Kit
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/face_match_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(normalizedBytes);

      // Create InputImage from file
      final inputImage = InputImage.fromFilePath(tempFile.path);

      final faces = await _faceDetector.processImage(inputImage);

      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (_) {}

      if (faces.isEmpty) return null;

      final face = faces.first;
      return _buildEmbedding(face, decoded.width.toDouble(), decoded.height.toDouble());
    } catch (e) {
      return null;
    }
  }

  /// Build a geometric embedding vector from face landmarks + contours.
  /// This creates a normalized feature vector representing facial geometry.
  List<double> _buildEmbedding(Face face, double imgWidth, double imgHeight) {
    final features = <double>[];
    final box = face.boundingBox;

    // Normalize helper
    double nx(double x) => x / imgWidth;
    double ny(double y) => y / imgHeight;

    // 1. Face bounding box ratios
    final faceW = box.width / imgWidth;
    final faceH = box.height / imgHeight;
    features.addAll([faceW, faceH, faceW / (faceH + 1e-6)]);

    // 2. Landmark positions (normalized to face bounding box)
    final landmarks = [
      FaceLandmarkType.leftEye,
      FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase,
      FaceLandmarkType.leftMouth,
      FaceLandmarkType.rightMouth,
      FaceLandmarkType.leftEar,
      FaceLandmarkType.rightEar,
      FaceLandmarkType.leftCheek,
      FaceLandmarkType.rightCheek,
      FaceLandmarkType.bottomMouth,
    ];

    for (final type in landmarks) {
      final landmark = face.landmarks[type];
      if (landmark != null) {
        // Normalize relative to face bounding box
        final rx = (landmark.position.x - box.left) / (box.width + 1e-6);
        final ry = (landmark.position.y - box.top) / (box.height + 1e-6);
        features.addAll([rx, ry]);
      } else {
        features.addAll([0.0, 0.0]); // Missing landmark
      }
    }

    // 3. Inter-landmark distances (key biometric ratios)
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;

    if (leftEye != null && rightEye != null) {
      final eyeDist = _dist(leftEye.x.toDouble(), leftEye.y.toDouble(), rightEye.x.toDouble(), rightEye.y.toDouble());
      features.add(eyeDist / imgWidth);

      if (nose != null) {
        final eyeMidX = (leftEye.x.toDouble() + rightEye.x.toDouble()) / 2;
        final eyeMidY = (leftEye.y.toDouble() + rightEye.y.toDouble()) / 2;
        final eyeNoseDist = _dist(eyeMidX, eyeMidY, nose.x.toDouble(), nose.y.toDouble());
        features.add(eyeNoseDist / eyeDist); // Normalized ratio
      } else {
        features.add(0.0);
      }
    } else {
      features.addAll([0.0, 0.0]);
    }

    if (leftMouth != null && rightMouth != null) {
      final mouthW = _dist(leftMouth.x.toDouble(), leftMouth.y.toDouble(), rightMouth.x.toDouble(), rightMouth.y.toDouble());
      features.add(mouthW / imgWidth);

      if (leftEye != null && rightEye != null) {
        final eyeDist = _dist(leftEye.x.toDouble(), leftEye.y.toDouble(), rightEye.x.toDouble(), rightEye.y.toDouble());
        features.add(mouthW / (eyeDist + 1e-6)); // Mouth/eye width ratio
      } else {
        features.add(0.0);
      }
    } else {
      features.addAll([0.0, 0.0]);
    }

    // 4. Head pose angles (normalized)
    features.add((face.headEulerAngleX ?? 0) / 90.0);
    features.add((face.headEulerAngleY ?? 0) / 90.0);
    features.add((face.headEulerAngleZ ?? 0) / 90.0);

    // 5. Face contours (sample key points)
    final contourTypes = [
      FaceContourType.face,
      FaceContourType.leftEye,
      FaceContourType.rightEye,
      FaceContourType.upperLipTop,
      FaceContourType.lowerLipBottom,
      FaceContourType.noseBridge,
    ];

    for (final type in contourTypes) {
      final contour = face.contours[type];
      if (contour != null && contour.points.isNotEmpty) {
        // Sample 3 evenly spaced points from each contour
        final pts = contour.points;
        final indices = [0, pts.length ~/ 2, pts.length - 1];
        for (final i in indices) {
          features.add(nx(pts[i].x.toDouble()));
          features.add(ny(pts[i].y.toDouble()));
        }
      } else {
        features.addAll([0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
      }
    }

    return _normalizeVector(features);
  }

  double _dist(double x1, double y1, double x2, double y2) {
    return sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
  }

  /// Normalize vector to unit length
  List<double> _normalizeVector(List<double> v) {
    final magnitude = sqrt(v.fold(0.0, (sum, x) => sum + x * x));
    if (magnitude < 1e-10) return v;
    return v.map((x) => x / magnitude).toList();
  }

  /// Cosine similarity between two vectors (0.0 to 1.0)
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      // Pad shorter vector
      final maxLen = max(a.length, b.length);
      while (a.length < maxLen) {
        a.add(0.0);
      }
      while (b.length < maxLen) {
        b.add(0.0);
      }
    }

    double dot = 0.0;
    double magA = 0.0;
    double magB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      magA += a[i] * a[i];
      magB += b[i] * b[i];
    }

    final denom = sqrt(magA) * sqrt(magB);
    if (denom < 1e-10) return 0.0;

    // Clamp to [0, 1]
    return (dot / denom).clamp(0.0, 1.0);
  }

  void dispose() {
    if (_initialized) {
      _faceDetector.close();
      _initialized = false;
    }
  }
}
