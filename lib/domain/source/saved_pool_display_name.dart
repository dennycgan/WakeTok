import 'package:waketok/domain/source/saved_pool_failure.dart';
import 'package:waketok/domain/source/saved_pool_record.dart';

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
