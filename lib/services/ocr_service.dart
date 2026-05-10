import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// Result from scanning a vehicle document image.
class VehicleOcrResult {
  final String? vehicleName; // e.g. "MARUTI SWIFT"
  final int? year;           // e.g. 2021
  final String rawText;      // full OCR output for debugging

  const VehicleOcrResult({
    this.vehicleName,
    this.year,
    required this.rawText,
  });
}

class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  /// Scan [imageBytes] and extract vehicle name + year hints.
  Future<VehicleOcrResult?> scanVehicleDocument(Uint8List imageBytes) async {
    // On web: use Google Cloud Vision API via HTTP
    if (kIsWeb) {
      return await _scanWithCloudVision(imageBytes);
    }

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    File? tempFile;

    try {
      // Write bytes to a temp file so ML Kit can read it
      final dir = await getTemporaryDirectory();
      tempFile = File('${dir.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);

      final inputImage = InputImage.fromFilePath(tempFile.path);
      final recognized = await textRecognizer.processImage(inputImage);
      final rawText = recognized.text;

      debugPrint('[OCR] Raw text:\n$rawText');

      return VehicleOcrResult(
        vehicleName: _extractVehicleName(rawText),
        year: _extractYear(rawText),
        rawText: rawText,
      );
    } catch (e) {
      debugPrint('[OCR] Error: $e');
      return null;
    } finally {
      await textRecognizer.close();
      try { await tempFile?.delete(); } catch (_) {}
    }
  }

  /// Try to extract a vehicle make/model from OCR text.
  /// RC books typically have lines like "MARUTI SUZUKI SWIFT" or "HONDA ACTIVA".
  String? _extractVehicleName(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // Known vehicle makes to look for
    const makes = [
      'MARUTI', 'SUZUKI', 'HONDA', 'TOYOTA', 'HYUNDAI', 'KIA', 'TATA',
      'MAHINDRA', 'FORD', 'VOLKSWAGEN', 'SKODA', 'RENAULT', 'NISSAN',
      'BAJAJ', 'HERO', 'TVS', 'ROYAL ENFIELD', 'YAMAHA', 'KAWASAKI',
      'ASHOK LEYLAND', 'EICHER', 'VOLVO', 'MERCEDES', 'BMW', 'AUDI',
      'TESLA', 'MG', 'JEEP', 'ISUZU', 'FORCE',
    ];

    for (final line in lines) {
      final upper = line.toUpperCase();
      for (final make in makes) {
        if (upper.contains(make)) {
          // Return the line cleaned up, max 40 chars
          final cleaned = line.replaceAll(RegExp(r'[^a-zA-Z0-9 \-]'), '').trim();
          if (cleaned.length >= 3) return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
        }
      }
    }

    // Fallback: look for "MAKE/MODEL" or "VEHICLE MODEL" label patterns
    final modelPattern = RegExp(r'(?:MAKE|MODEL|VEHICLE)[^\n:]*[:\s]+([A-Z][A-Z0-9 \-]{2,30})', caseSensitive: false);
    final match = modelPattern.firstMatch(text);
    if (match != null) return match.group(1)?.trim();

    return null;
  }

  /// Extract a 4-digit year (1980–2030) from OCR text.
  int? _extractYear(String text) {
    final yearPattern = RegExp(r'\b(19[89]\d|20[0-3]\d)\b');
    final matches = yearPattern.allMatches(text).toList();
    if (matches.isEmpty) return null;

    // Prefer years that appear near "year", "mfg", "manufacture", "reg" keywords
    final contextPattern = RegExp(
      r'(?:year|mfg|manufacture|registration|reg\.?\s*date)[^\d]*(19[89]\d|20[0-3]\d)',
      caseSensitive: false,
    );
    final ctxMatch = contextPattern.firstMatch(text);
    if (ctxMatch != null) return int.tryParse(ctxMatch.group(1)!);

    // Otherwise return the most recent year found (likely manufacture year)
    final years = matches.map((m) => int.parse(m.group(0)!)).toList()..sort();
    return years.last;
  }

  /// Web fallback: use Google Cloud Vision API for OCR
  Future<VehicleOcrResult?> _scanWithCloudVision(Uint8List imageBytes) async {
    try {
      // Note: In production, use a backend proxy to avoid exposing API key
      // For now, use the Firebase Vision API endpoint
      const apiKey = 'AIzaSyAuto-detect'; // Replace with actual key or use backend
      final base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [{'type': 'TEXT_DETECTION', 'maxResults': 1}],
            }
          ]
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('[OCR Web] Cloud Vision failed: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final responses = data['responses'] as List?;
      if (responses == null || responses.isEmpty) return null;

      final textAnnotations = responses[0]['textAnnotations'] as List?;
      if (textAnnotations == null || textAnnotations.isEmpty) return null;

      final rawText = textAnnotations[0]['description'] as String? ?? '';
      debugPrint('[OCR Web] Raw text:\n$rawText');

      return VehicleOcrResult(
        vehicleName: _extractVehicleName(rawText),
        year: _extractYear(rawText),
        rawText: rawText,
      );
    } catch (e) {
      debugPrint('[OCR Web] Error: $e');
      return null;
    }
  }
}



