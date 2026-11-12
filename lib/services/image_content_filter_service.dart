import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

/// Service to detect and filter images containing contact information
/// Uses ML Kit Text Recognition to read text from images
/// Blocks images with phone numbers, emails, social media handles, etc.
class ImageContentFilterService {
  static final ImageContentFilterService instance =
      ImageContentFilterService._();
  ImageContentFilterService._();

  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Validate image file for prohibited content (phone, email, contact info)
  /// Returns error message if blocked, null if OK
  Future<String?> validateImage(XFile imageFile) async {
    try {
      debugPrint(
        '🔍 Scanning image for contact information: ${imageFile.name}',
      );

      // Read image file
      final File file = File(imageFile.path);
      final InputImage inputImage = InputImage.fromFile(file);

      // Extract text from image using ML Kit
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      final extractedText = recognizedText.text.toLowerCase();

      debugPrint('📝 Extracted text from image: "$extractedText"');

      // Check for prohibited content
      final error = _checkProhibitedContent(extractedText);
      if (error != null) {
        debugPrint('❌ Image blocked: $error');
        return error;
      }

      debugPrint('✅ Image passed validation');
      return null; // Image is OK
    } catch (e) {
      // If ML Kit fails, allow the image (don't block on technical error)
      debugPrint('⚠️ Image validation error (allowing image): $e');
      return null;
    }
  }

  /// Check extracted text for prohibited patterns
  String? _checkProhibitedContent(String text) {
    final lower = text.toLowerCase();
    final normalized = _normalizeText(text);

    // 0. Check for profanity and abuse words (NO AI needed - just word list)
    if (_containsAbusiveLanguage(lower, normalized)) {
      return '❌ Image blocked: Contains offensive language';
    }

    // 1. Check for phone numbers
    if (_containsPhoneNumber(text, normalized)) {
      return '❌ Image blocked: Contains phone number';
    }

    // 2. Check for emails
    if (_containsEmail(text, normalized)) {
      return '❌ Image blocked: Contains email address';
    }

    // 3. Check for social media handles
    if (_containsSocialMedia(lower)) {
      return '❌ Image blocked: Contains social media information';
    }

    // 4. Check for URLs/links
    if (_containsURL(lower, normalized)) {
      return '❌ Image blocked: Contains links or URLs';
    }

    // 5. Check for contact hints
    if (_containsContactHints(lower)) {
      return '❌ Image blocked: Contains contact instructions';
    }

    // 6. Check for QR codes or barcodes (pattern detection)
    if (_mightContainQRCode(text)) {
      return '❌ Image blocked: May contain QR code or contact code';
    }

    return null; // No prohibited content
  }

  /// Remove spaces, special chars, normalize for detection
  String _normalizeText(String text) {
    return text
        .replaceAll(RegExp(r'[\s\-\.\(\)\[\]_/\\|]+'), '')
        .replaceAll(RegExp(r'[oO]', caseSensitive: false), '0')
        .replaceAll(RegExp(r'[iIlL]', caseSensitive: false), '1')
        .replaceAll(RegExp(r'[eE]', caseSensitive: false), '3')
        .replaceAll(RegExp(r'[aA@]', caseSensitive: false), '4')
        .replaceAll(RegExp(r'[sS\$]', caseSensitive: false), '5')
        .replaceAll(RegExp(r'[gG]', caseSensitive: false), '6')
        .replaceAll(RegExp(r'[tT]', caseSensitive: false), '7')
        .replaceAll(RegExp(r'[bB]', caseSensitive: false), '8')
        .replaceAll(RegExp(r'[gG]', caseSensitive: false), '9');
  }

  /// Detect phone numbers in text
  bool _containsPhoneNumber(String original, String normalized) {
    // Check normalized for 10+ consecutive digits
    if (RegExp(r'\d{10,}').hasMatch(normalized)) {
      return true;
    }

    // Check for Indian phone patterns
    if (RegExp(r'(\+91|0091|91)[\s\-]?\d').hasMatch(original)) {
      return true;
    }

    // Check for trigger words + numbers
    if (RegExp(
      r'(call|phone|mobile|contact|whatsapp|wa|telegram|number|reach|dial)[\s\S]{0,20}\d{6,}',
      caseSensitive: false,
    ).hasMatch(original)) {
      return true;
    }

    // Check for patterns like "nine four four five"
    if (RegExp(
      r'(zero|one|two|three|four|five|six|seven|eight|nine)[\s\-]+(zero|one|two|three|four|five|six|seven|eight|nine)',
      caseSensitive: false,
    ).hasMatch(original)) {
      return true;
    }

    // Check if text has suspiciously high digit density (>40% digits)
    final digitCount = original.replaceAll(RegExp(r'[^\d]'), '').length;
    final totalChars = original.replaceAll(RegExp(r'\s'), '').length;
    if (totalChars > 10 && digitCount / totalChars > 0.4) {
      return true;
    }

    return false;
  }

  /// Detect email addresses
  bool _containsEmail(String original, String normalized) {
    // Standard email pattern
    if (RegExp(
      r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    ).hasMatch(original)) {
      return true;
    }

    // Obfuscated emails: "user at gmail dot com"
    if (RegExp(
      r'[\w]+[\s]*(at|@)[\s]*[\w]+[\s]*(dot|\.)[\s]*(com|in|org|net)',
      caseSensitive: false,
    ).hasMatch(original)) {
      return true;
    }

    return false;
  }

  /// Detect social media handles
  bool _containsSocialMedia(String lower) {
    final patterns = [
      r'instagram',
      r'facebook',
      r'fb',
      r'twitter',
      r'linkedin',
      r'snapchat',
      r'tiktok',
      r'telegram',
      r'whatsapp',
      r'@[\w]+',
    ];

    for (final pattern in patterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lower)) {
        return true;
      }
    }

    return false;
  }

  /// Detect URLs and links
  bool _containsURL(String lower, String normalized) {
    final patterns = [
      r'https?://',
      r'www\.',
      r'\.com',
      r'\.in',
      r'\.org',
      r'\.net',
      r'\.co',
    ];

    for (final pattern in patterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lower)) {
        return true;
      }
    }

    return false;
  }

  /// Detect contact hints and bypass attempts
  bool _containsContactHints(String lower) {
    final hints = [
      r'dm\s*me',
      r'direct\s*message',
      r'message\s*me\s*on',
      r'contact\s*me\s*on',
      r'reach\s*me\s*at',
      r'find\s*me\s*on',
      r'add\s*me\s*on',
      r'text\s*me',
      r'call\s*me',
      r'ping\s*me',
      r'whatsapp',
      r'telegram',
      r'outside\s*app',
      r'off\s*platform',
      r'personal\s*number',
      r'my\s*number',
      r'share\s*contact',
      r'give\s*me\s*your\s*number',
      r'send\s*me\s*your\s*number',
      r'share\s*your\s*number',
      r'drop\s*your\s*number',
      r'inbox\s*me',
      r'pm\s*me',
    ];

    for (final hint in hints) {
      if (RegExp(hint, caseSensitive: false).hasMatch(lower)) {
        return true;
      }
    }

    return false;
  }

  /// Detect if image might contain QR code or barcode
  /// This is a heuristic check - looks for excessive repeated patterns
  bool _mightContainQRCode(String text) {
    // QR codes often appear as random looking characters
    // Check for excessive non-alphanumeric patterns or very dense text
    final specialChars = text.replaceAll(RegExp(r'[a-zA-Z0-9\s]'), '').length;
    final totalChars = text.length;

    if (totalChars > 5 && specialChars / totalChars > 0.3) {
      return true; // Likely contains QR code or barcode
    }

    return false;
  }

  /// Detect abusive, profane, and offensive language in images
  bool _containsAbusiveLanguage(String lower, String normalized) {
    // Common profanity and abuse words (expanded list for Indian English context)
    final abusiveWords = [
      // Common curse words (multiple variations)
      r'\bf[*u]ck', r'f[*u]cking', r'f[*u]cker',
      r'\bsh[*i]t', r'sh[*i]tty',
      r'\bass[*h]ole', r'\bassh[*i]ole',
      r'\bb[*i]tch', r'b[*i]tches',
      r'\bd[*a]mn', r'd[*a]mned',
      r'\bhell', r'\bcrap',

      // Slurs and derogatory terms
      r'\bidiot', r'\bstupid', r'\bdumb', r'\bmoron',
      r'\bprick', r'\basshole', r'\bwanker',
      r'\bsuck', r'sucks',

      // Harassment and threat terms
      r'\bgo\s*die', r'\bkill\s*yourself', r'\bkys',
      r'\bgo\s*to\s*hell', r'\bdestroy',
      r'\bstfu', r'\bshut\s*up',

      // Discriminatory terms (variations)
      r'\bn[*i]g+', // Common slur variations
      r'\bgay\s*', // When used as insult
      r'\bretard',

      // Indian context abuse words (Hinglish and Hindi)
      r'\bbhosdi', r'\bmadarchod', r'\bsala',
      r'\bbhen\s*chod', r'\bbakchodi',
      r'\bullo', r'\bchutiya',

      // Harassment phrases
      r'\byou\s*suck', r'\byou\s*suck', r'\byou\s*are\s*gay',
      r'\byou\s*are\s*stupid', r'\byou\s*are\s*dumb',
    ];

    final lowerWithSpaces = ' $lower ';

    for (final word in abusiveWords) {
      if (RegExp(word, caseSensitive: false).hasMatch(lowerWithSpaces)) {
        return true;
      }
    }

    // Check normalized version for obfuscated variations
    for (final word in abusiveWords) {
      if (RegExp(word, caseSensitive: false).hasMatch(normalized)) {
        return true;
      }
    }

    return false;
  }

  /// Dispose of resources
  void dispose() {
    _textRecognizer.close();
  }
}
