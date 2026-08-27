class ContentFilterService {
  static final ContentFilterService instance = ContentFilterService._();
  ContentFilterService._();

  /// Validates text content and returns error message if invalid, null if valid
  String? validateContent(String text) {
    if (text.trim().isEmpty) {
      return 'Content cannot be empty';
    }

    // Normalize text for detection
    final normalized = _normalizeText(text);
    final lower = text.toLowerCase();

    // 0. Check for profanity and abuse words FIRST
    if (_containsAbusiveLanguage(lower, normalized)) {
      return '❌ Offensive language is not allowed. Please be respectful.';
    }

    // 1. Check for phone numbers
    if (_containsPhoneNumber(text, normalized)) {
      return 'Phone numbers are not allowed. Use in-app messaging.';
    }

    // 2. Check for emails
    if (_containsEmail(text, normalized)) {
      return 'Email addresses are not allowed. Use in-app messaging.';
    }

    // 3. Check for social media
    if (_containsSocialMedia(lower)) {
      return 'Social media handles are not allowed. Use in-app messaging.';
    }

    // 4. Check for URLs
    if (_containsURL(lower, normalized)) {
      return 'URLs and links are not allowed.';
    }

    // 5. Check for contact hints
    if (_containsContactHints(lower)) {
      return 'Contact hints are not allowed. Use in-app messaging.';
    }

    return null; // Content is valid
  }

  /// Validates terms field specifically - ensures meaningful text only
  String? validateTerms(String text) {
    if (text.trim().isEmpty) {
      return null; // Terms are optional, empty is OK
    }

    // Check minimum meaningful length (at least 5 characters)
    if (text.trim().length < 5) {
      return 'Terms must be at least 5 characters if provided';
    }

    // Check for minimum word count (at least 2 words)
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length < 2) {
      return 'Please write meaningful terms (at least 2 words)';
    }

    // Check for contact information (phone, email, URLs)
    final normalized = _normalizeText(text);
    final lower = text.toLowerCase();

    // Check for profanity and abuse words FIRST
    if (_containsAbusiveLanguage(lower, normalized)) {
      return '❌ Offensive language is not allowed. Please be respectful.';
    }

    if (_containsPhoneNumber(text, normalized)) {
      return 'Phone numbers are not allowed. Use in-app messaging.';
    }

    if (_containsEmail(text, normalized)) {
      return 'Email addresses are not allowed. Use in-app messaging.';
    }

    if (_containsURL(lower, normalized)) {
      return 'URLs and links are not allowed.';
    }

    if (_containsSocialMedia(lower)) {
      return 'Social media handles are not allowed. Use in-app messaging.';
    }

    if (_containsContactHints(lower)) {
      return 'Contact hints are not allowed. Use in-app messaging.';
    }

    // Check for gibberish (too many repeated characters)
    if (RegExp(r'(.)\1{5,}').hasMatch(text)) {
      return 'Please write meaningful terms, not repeated characters';
    }

    return null; // Terms are valid
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

  /// Detect phone numbers (even with spaces/special chars)
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

    // Check for mixed letter-number patterns (e.g., "w9 h8 a9", "a1 b2 c3")
    // Count how many single-letter + digit patterns exist
    final mixedPattern = RegExp(r'[a-zA-Z]\d', caseSensitive: false);
    final matches = mixedPattern.allMatches(original);
    if (matches.length >= 5) {
      // If 5+ letter-digit combos, likely hiding a phone number
      return true;
    }

    // Check for alternating letters and numbers with spaces (e.g., "w 9 h 8")
    final alternatingPattern = RegExp(
      r'([a-zA-Z]\s*\d\s*){5,}',
      caseSensitive: false,
    );
    if (alternatingPattern.hasMatch(original)) {
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

    // Check normalized for email-like patterns
    if (RegExp(r'\w+@\w+\.\w+').hasMatch(normalized)) {
      return true;
    }

    return false;
  }

  /// Detect social media handles
  bool _containsSocialMedia(String lower) {
    // Instagram, Facebook, Twitter, etc.
    final patterns = [
      r'instagram\.com',
      r'facebook\.com',
      r'fb\.com',
      r'twitter\.com',
      r'linkedin\.com',
      r'snapchat',
      r'tiktok',
      r'@[\w]+', // @username
      r'insta\s*id',
      r'fb\s*id',
      r'telegram\s*id',
      r'whatsapp\s*group',
      r'discord',
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
    // Standard URL patterns
    final patterns = [
      r'https?://',
      r'www\.',
      r'\.com',
      r'\.in',
      r'\.org',
      r'\.net',
      r'\.co',
      r'bit\.ly',
      r'tinyurl',
    ];

    for (final pattern in patterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lower)) {
        return true;
      }
    }

    // Check for domain-like patterns in normalized text
    if (RegExp(r'\w+\.(com|in|org|net|co)').hasMatch(normalized)) {
      return true;
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
      r'outside\s*app',
      r'off\s*platform',
      r'personal\s*number',
      r'my\s*number',
      r'share\s*contact',
      r'give\s*me\s*your\s*number',
      r'send\s*me\s*your\s*number',
      r'what\s*is\s*your\s*number',
      r'whats\s*your\s*number',
      r'share\s*your\s*number',
      r'drop\s*your\s*number',
      r'leave\s*your\s*number',
      r'inbox\s*me',
      r'pm\s*me',
      r'private\s*message',
    ];

    for (final hint in hints) {
      if (RegExp(hint, caseSensitive: false).hasMatch(lower)) {
        return true;
      }
    }

    return false;
  }

  /// Detect abusive, profane, and offensive language
  /// Checks for common curse words, slurs, and harassment terms
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

    final lowerWithSpaces = ' $lower '; // Add spaces to match word boundaries

    for (final word in abusiveWords) {
      if (RegExp(word, caseSensitive: false).hasMatch(lowerWithSpaces)) {
        return true;
      }
    }

    // Check normalized version for obfuscated variations (with *, -, etc.)
    for (final word in abusiveWords) {
      if (RegExp(word, caseSensitive: false).hasMatch(normalized)) {
        return true;
      }
    }

    // Check for repeated abuse (same word multiple times)
    if (RegExp(
      r'(fuck|shit|ass|damn|hell|stupid|idiot)\s+(fuck|shit|ass|damn|hell|stupid|idiot)',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }

    return false;
  }
}
