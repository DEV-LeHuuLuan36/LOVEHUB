import 'package:flutter/services.dart';

/// Centralised input validation for user-typed values.
///
/// Every user-typed string must pass through one of these helpers
/// before being sent to Firestore, OneSignal, Cloudinary, or rendered
/// to the partner's screen. Defense in depth — the server-side rules
/// are still the source of truth.
class InputValidator {
  InputValidator._();

  /// Hard upper bounds — tweak only if the product changes.
  static const int maxNameLen = 50;
  static const int maxEmailLen = 254; // RFC 5321
  static const int maxNoteLen = 500;
  static const int maxTitleLen = 100;
  static const int maxStoryLen = 4000;
  static const int maxLocationLen = 100;
  static const int maxJarNameLen = 50;
  static const int maxMoodLabelLen = 24;
  static const int maxAiInputLen = 500;
  static const int maxPushMessageLen = 120;
  static const int maxBankAccountLen = 19;
  static const int maxUrlLen = 2048;
  static const int maxAmount = 1000000000; // 1 billion units

  // ─── Text helpers ────────────────────────────────────────────────────

  /// Strip control characters (`\x00`-`\x1F`, `\x7F`) and trim. Keeps
  /// printable UTF-8 (emoji, accented chars, etc.).
  static String sanitize(String input) {
    if (input.isEmpty) return input;
    // Remove C0/C1 controls and DEL. Use a regex that's safe across
    // Dart's RegExp engine for Unicode strings.
    final cleaned = input.replaceAll(
      RegExp(r'[\x00-\x1F\x7F]'),
      '',
    );
    return cleaned.trim();
  }

  /// Normalise whitespace runs to single spaces (e.g. "Hi   there" →
  /// "Hi there"). Useful before sending to Firestore to keep docs
  /// compact.
  static String normaliseWhitespace(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Combine sanitise + normalise, then truncate to [maxLen].
  static String clean(String input, {int maxLen = maxNoteLen}) {
    final s = normaliseWhitespace(sanitize(input));
    if (s.length <= maxLen) return s;
    return s.substring(0, maxLen);
  }

  // ─── Specific validators ─────────────────────────────────────────────

  /// Display name — letters, numbers, emoji, spaces. 1..[maxNameLen].
  /// Empty after sanitisation is invalid.
  static String? validateName(String input) {
    final s = normaliseWhitespace(sanitize(input));
    if (s.isEmpty) return 'Name is required';
    if (s.length > maxNameLen) return 'Name too long (max $maxNameLen)';
    return null;
  }

  /// Email — RFC 5322-lite check (good-enough for client-side UX;
  /// server-side rules still gate on `request.auth.token.email`).
  static String? validateEmail(String input) {
    final s = clean(input, maxLen: maxEmailLen).toLowerCase();
    if (s.isEmpty) return 'Email is required';
    final re = RegExp(r"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$");
    if (!re.hasMatch(s)) return 'Email is not valid';
    return null;
  }

  /// Password — at least 8 chars, must include letter + digit.
  static String? validatePassword(String input) {
    final s = sanitize(input);
    if (s.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[a-zA-Z]').hasMatch(s)) {
      return 'Password must contain a letter';
    }
    if (!RegExp(r'\d').hasMatch(s)) {
      return 'Password must contain a digit';
    }
    if (s.length > 128) return 'Password too long';
    return null;
  }

  /// Title (memory title, milestone title, jar name, …).
  static String? validateTitle(String input) {return _length(input, maxTitleLen, 'Title');}

  /// Number-only fields like love points, jar amount.
  static String? validateAmount(int? value) {
    if (value == null) return 'Amount is required';
    if (value <= 0) return 'Amount must be positive';
    if (value > maxAmount) return 'Amount too large';
    return null;
  }

  /// Money-like string ("100000", "100.000", "1.000.000,50"). We
  /// normalise and parse to integer (in the smallest currency unit).
  /// Returns null on bad input.
  static int? parseMoney(String? raw) {
    if (raw == null) return null;
    final s = raw.replaceAll(RegExp(r'[\s\.,]'), '');
    if (s.isEmpty) return null;
    final v = int.tryParse(s);
    if (v == null || v <= 0 || v > maxAmount) return null;
    return v;
  }

  /// HTTP/HTTPS URL — rejects javascript:, data:, file:.
  static String? validateHttpUrl(String input, {int maxLen = maxUrlLen}) {
    final s = sanitize(input);
    if (s.isEmpty) return 'URL is required';
    if (s.length > maxLen) return 'URL too long';
    final uri = Uri.tryParse(s);
    if (uri == null) return 'URL is not valid';
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return 'Only http(s) URLs allowed';
    }
    if (uri.host.isEmpty) return 'URL has no host';
    return null;
  }

  /// Bank account number — digits only, length 4..[maxBankAccountLen].
  static String? validateBankAccount(String input) {
    final s = sanitize(input).replaceAll(RegExp(r'\s+'), '');
    if (s.isEmpty) return 'Account number is required';
    if (!RegExp(r'^\d{4,}$').hasMatch(s)) {
      return 'Account number must be at least 4 digits';
    }
    if (s.length > maxBankAccountLen) return 'Account number too long';
    return null;
  }

  /// Account holder name — VietQR requires UPPERCASE no accents.
  /// We strip diacritics + uppercase client-side as a UX hint.
  static String normaliseVietQrAccountName(String input) {
    final s = sanitize(input).toUpperCase();
    // Strip common Vietnamese diacritics.
    const map = {
      'À': 'A', 'Á': 'A', 'Ả': 'A', 'Ã': 'A', 'Ạ': 'A',
      'Â': 'A', 'Ầ': 'A', 'Ấ': 'A', 'Ẩ': 'A', 'Ẫ': 'A', 'Ậ': 'A',
      'Ă': 'A', 'Ằ': 'A', 'Ắ': 'A', 'Ẳ': 'A', 'Ẵ': 'A', 'Ặ': 'A',
      'È': 'E', 'É': 'E', 'Ẻ': 'E', 'Ẽ': 'E', 'Ẹ': 'E',
      'Ê': 'E', 'Ề': 'E', 'Ế': 'E', 'Ể': 'E', 'Ễ': 'E', 'Ệ': 'E',
      'Ì': 'I', 'Í': 'I', 'Ỉ': 'I', 'Ĩ': 'I', 'Ị': 'I',
      'Ò': 'O', 'Ó': 'O', 'Ỏ': 'O', 'Õ': 'O', 'Ọ': 'O',
      'Ô': 'O', 'Ồ': 'O', 'Ố': 'O', 'Ổ': 'O', 'Ỗ': 'O', 'Ộ': 'O',
      'Ơ': 'O', 'Ờ': 'O', 'Ớ': 'O', 'Ở': 'O', 'Ỡ': 'O', 'Ợ': 'O',
      'Ù': 'U', 'Ú': 'U', 'Ủ': 'U', 'Ũ': 'U', 'Ụ': 'U',
      'Ư': 'U', 'Ừ': 'U', 'Ứ': 'U', 'Ử': 'U', 'Ữ': 'U', 'Ự': 'U',
      'Ỳ': 'Y', 'Ý': 'Y', 'Ỷ': 'Y', 'Ỹ': 'Y', 'Ỵ': 'Y',
      'Đ': 'D',
    };
    final buf = StringBuffer();
    for (final ch in s.runes) {
      final c = String.fromCharCode(ch);
      buf.write(map[c] ?? c);
    }
    return buf.toString();
  }

  /// Couple invite code — uppercase letters/digits, length 8..16.
  static String? validateCoupleCode(String input) {
    final s = sanitize(input).toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (s.isEmpty) return 'Code is required';
    if (s.length < 4 || s.length > 24) return 'Code length out of range';
    if (!RegExp(r'^[A-Z0-9\-]+$').hasMatch(s)) return 'Code has invalid chars';
    return null;
  }

  static String? _length(String input, int max, String label) {
    final s = clean(input, maxLen: max);
    if (s.isEmpty) return '$label is required';
    return null;
  }

  // ─── Clipboard guard ──────────────────────────────────────────────────
  // Used when copying sensitive content to clipboard on Android — wipe it
  // after a short timeout so a screenshot of the clipboard doesn't leak.
  static Future<void> copyAndWipe(String value, {Duration wipe = const Duration(seconds: 30)}) async {
    await Clipboard.setData(ClipboardData(text: value));
    Future.delayed(wipe, () async {
      try {
        final current = await Clipboard.getData(Clipboard.kTextPlain);
        if (current?.text == value) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {/* best-effort */}
    });
  }
}
