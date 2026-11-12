import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Reusable image compression helper
/// Compresses images to reduce storage size and improve upload speed
class ImageCompressionHelper {
  /// Compress image from base64 string
  /// Returns compressed image as Uint8List (PNG format)
  /// 
  /// Parameters:
  /// - base64Image: Base64 encoded image string
  /// - targetWidth: Target width in pixels (default: 512)
  /// - targetHeight: Target height in pixels (default: 512)
  /// 
  /// Returns compressed image bytes or null if compression fails
  static Future<Uint8List?> compressBase64Image(
    String base64Image, {
    int targetWidth = 512,
    int targetHeight = 512,
  }) async {
    try {
      // Remove data:image prefix if present
      String base64Data = base64Image;
      if (base64Data.contains(',')) {
        base64Data = base64Data.split(',').last;
      }

      // Decode base64 to bytes
      final bytes = base64Decode(base64Data);
      
      return await compressImageBytes(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
    } catch (e) {
      print('❌ Error compressing base64 image: $e');
      return null;
    }
  }

  /// Compress image from bytes
  /// Returns compressed image as Uint8List (PNG format)
  /// 
  /// Parameters:
  /// - imageBytes: Raw image bytes
  /// - targetWidth: Target width in pixels (default: 512)
  /// - targetHeight: Target height in pixels (default: 512)
  /// 
  /// Returns compressed image bytes or null if compression fails
  static Future<Uint8List?> compressImageBytes(
    Uint8List imageBytes, {
    int targetWidth = 512,
    int targetHeight = 512,
  }) async {
    try {
      // Decode image
      final ui.Codec codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );

      // Get first frame
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      // Convert to PNG bytes
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        print('❌ Failed to convert image to bytes');
        return null;
      }

      final compressedBytes = byteData.buffer.asUint8List();
      
      print('✅ Image compressed: ${imageBytes.length} → ${compressedBytes.length} bytes '
          '(${((1 - compressedBytes.length / imageBytes.length) * 100).toStringAsFixed(1)}% reduction)');

      return compressedBytes;
    } catch (e) {
      print('❌ Error compressing image bytes: $e');
      return null;
    }
  }

  /// Get recommended compression sizes for different image types
  static const Map<String, Map<String, int>> recommendedSizes = {
    'profile': {'width': 512, 'height': 512},
    'vehicle': {'width': 1024, 'height': 1024},
    'post': {'width': 1024, 'height': 1024},
    'trip': {'width': 800, 'height': 800},
    'review': {'width': 800, 'height': 800},
    'layout': {'width': 512, 'height': 512},
  };
}
