import 'package:waketok/domain/source/saved_pool_failure.dart';
import 'package:waketok/domain/source/saved_pool_record.dart';

/// Cap 22.5: visual naming budget (CJK-wide weight 3, else 1).
const int kSavedPoolDisplayNameMaxWeight = 32;

/// Trim; blank (including whitespace-only) becomes `null`.
///
/// Does **not** enforce [kSavedPoolDisplayNameMaxWeight] — callers that persist
/// must use [requireSavedPoolDisplayName]. Display of legacy over-budget names
/// stays untruncated here.
String? normalizeSavedPoolDisplayName(String raw) {
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Uniqueness key: trim already applied; case-insensitive, no locale fold.
String savedPoolDisplayNameKey(String trimmedDisplayName) {
  return trimmedDisplayName.toLowerCase();
}

/// Visual weight: each Unicode scalar is 3 if East Asian Width W/F (incl.
/// ideographs, kana, Hangul, fullwidth forms), else 1. No locale tables.
int savedPoolDisplayNameWeight(String text) {
  var weight = 0;
  for (final rune in text.runes) {
    weight += isSavedPoolWideWeightRune(rune) ? 3 : 1;
  }
  return weight;
}

bool savedPoolDisplayNameWithinWeightLimit(String trimmedDisplayName) {
  return savedPoolDisplayNameWeight(trimmedDisplayName) <=
      kSavedPoolDisplayNameMaxWeight;
}

/// Longest prefix of [text] whose visual weight ≤ [kSavedPoolDisplayNameMaxWeight].
///
/// Used when bulk IME commit / paste would otherwise reject the whole string.
String truncateSavedPoolDisplayNameToWeightLimit(String text) {
  if (savedPoolDisplayNameWithinWeightLimit(text)) {
    return text;
  }
  final buffer = StringBuffer();
  var weight = 0;
  for (final rune in text.runes) {
    final add = isSavedPoolWideWeightRune(rune) ? 3 : 1;
    if (weight + add > kSavedPoolDisplayNameMaxWeight) {
      break;
    }
    buffer.writeCharCode(rune);
    weight += add;
  }
  return buffer.toString();
}

/// Unicode East Asian Width **W** or **F** (not Ambiguous). Condensed ranges
/// aligned with UCD EastAsianWidth — visual width, not "Chinese only".
bool isSavedPoolWideWeightRune(int cp) {
  if (cp < 0x1100) {
    return false;
  }
  // Hangul Jamo
  if (cp <= 0x115F) {
    return true;
  }
  if (cp == 0x2329 || cp == 0x232A) {
    return true;
  }
  // CJK Radicals Supplement .. CJK Symbols and Punctuation (through 303E)
  if (cp >= 0x2E80 && cp <= 0x303E) {
    return true;
  }
  // Hiragana .. CJK Compatibility (3040–33FF; skips 303F Neutral)
  if (cp >= 0x3040 && cp <= 0x33FF) {
    return true;
  }
  // CJK Unified Ideographs Extension A
  if (cp >= 0x3400 && cp <= 0x4DBF) {
    return true;
  }
  // CJK Unified Ideographs + Yi
  if (cp >= 0x4E00 && cp <= 0xA48C) {
    return true;
  }
  // Yi Radicals
  if (cp >= 0xA490 && cp <= 0xA4C6) {
    return true;
  }
  // Hangul Syllables
  if (cp >= 0xAC00 && cp <= 0xD7A3) {
    return true;
  }
  // CJK Compatibility Ideographs
  if (cp >= 0xF900 && cp <= 0xFAFF) {
    return true;
  }
  // Vertical forms / CJK compatibility forms
  if (cp >= 0xFE10 && cp <= 0xFE19) {
    return true;
  }
  if (cp >= 0xFE30 && cp <= 0xFE6F) {
    return true;
  }
  // Halfwidth and Fullwidth Forms (fullwidth band + fullwidth currency)
  if (cp >= 0xFF01 && cp <= 0xFF60) {
    return true;
  }
  if (cp >= 0xFFE0 && cp <= 0xFFE6) {
    return true;
  }
  // CJK Unified Ideographs Extension B..F / Compatibility Supplement (planes)
  if (cp >= 0x20000 && cp <= 0x2FFFD) {
    return true;
  }
  if (cp >= 0x30000 && cp <= 0x3FFFD) {
    return true;
  }
  return false;
}

/// Throws [SavedPoolInvalidName] when empty after trim, or
/// [SavedPoolNameTooLong] when over the visual weight budget.
String requireSavedPoolDisplayName(String raw) {
  final normalized = normalizeSavedPoolDisplayName(raw);
  if (normalized == null) {
    throw const SavedPoolInvalidName();
  }
  if (!savedPoolDisplayNameWithinWeightLimit(normalized)) {
    throw const SavedPoolNameTooLong();
  }
  return normalized;
}

/// True when [trimmedName]'s key collides with another preset.
bool savedPoolDisplayNameTaken({
  required String trimmedName,
  required Iterable<SavedPoolRecord> existing,
  String? excludeId,
}) {
  final key = savedPoolDisplayNameKey(trimmedName);
  for (final row in existing) {
    if (excludeId != null && row.id == excludeId) {
      continue;
    }
    if (savedPoolDisplayNameKey(row.displayName) == key) {
      return true;
    }
  }
  return false;
}
