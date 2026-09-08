import 'package:waketok/domain/source/saved_pool_failure.dart';

/// Trim; blank (including whitespace-only) becomes `null`.
String? normalizeSavedPoolDisplayName(String raw) {
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Uniqueness key: trim already applied; case-insensitive, no locale fold.
String savedPoolDisplayNameKey(String trimmedDisplayName) {
  return trimmedDisplayName.toLowerCase();
}

/// Throws [SavedPoolInvalidName] when [raw] is empty after trim.
String requireSavedPoolDisplayName(String raw) {
  final normalized = normalizeSavedPoolDisplayName(raw);
  if (normalized == null) {
    throw const SavedPoolInvalidName();
  }
  return normalized;
}
