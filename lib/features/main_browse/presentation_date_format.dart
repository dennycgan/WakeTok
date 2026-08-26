import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 8.5 relative / exact date strings via ARB only (ADR-012 / D3=B).
///
/// Relative: same calendar day → Today; 1–30 days → `N days ago`;
/// beyond → `Y years M months ago` (omit days; omit zero units).
/// Uses [createdAt] Instant vs [now] (Cap 17.7 / ADR-038 — not Photos wall).
///
/// Cap 17.7 bound reveal: blank while [exactDateResolved] is false so row 1
/// does not paint before row 2 (ADR-038 exception to ADR-015 progressive
/// dates). Computation still ignores [CaptureWallClock].
String formatOverlayRelativeDate({
  required AppLocalizations l10n,
  required bool exactDateResolved,
  required DateTime? createdAt,
  required DateTime now,
}) {
  if (!exactDateResolved || createdAt == null) {
    return '';
  }
  final local = createdAt.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diffDays = today.difference(day).inDays;
  if (diffDays <= 0) {
    // Today, or future-dated metadata treated as today.
    return l10n.mediaInfoRelativeToday;
  }
  if (diffDays <= 30) {
    return l10n.mediaInfoRelativeDaysAgo(diffDays.toString());
  }

  var years = now.year - local.year;
  var months = now.month - local.month;
  if (now.day < local.day) {
    months -= 1;
  }
  if (months < 0) {
    years -= 1;
    months += 12;
  }
  if (years < 0) {
    years = 0;
    months = 0;
  }

  if (years > 0 && months > 0) {
    return l10n.mediaInfoRelativeYearsMonthsAgo(
      years.toString(),
      months.toString(),
    );
  }
  if (years > 0) {
    return l10n.mediaInfoRelativeYearsAgo(years.toString());
  }
  if (months > 0) {
    return l10n.mediaInfoRelativeMonthsAgo(months.toString());
  }
  // Calendar edge (e.g. ~31 days) — fall back to days.
  return l10n.mediaInfoRelativeDaysAgo(diffDays.toString());
}

/// Overlay exact row (Cap 17.7 / ADR-038).
///
/// - While [exactDateResolved] is false → blank (Host wall-clock still in flight).
/// - When [captureWallClock] is set → format those components (no `toLocal`).
/// - Else → ADR-038 fallback: [createdAt] via device-local calendar fields
///   (Host completed with no EXIF/TIFF — video / NO_EXIF / no local bytes).
String formatOverlayExactDateTime({
  required AppLocalizations l10n,
  required bool exactDateResolved,
  CaptureWallClock? captureWallClock,
  DateTime? createdAt,
}) {
  if (!exactDateResolved) {
    return '';
  }
  if (captureWallClock != null) {
    return _formatExactComponents(
      l10n: l10n,
      year: captureWallClock.year,
      month: captureWallClock.month,
      day: captureWallClock.day,
      hour: captureWallClock.hour,
      minute: captureWallClock.minute,
    );
  }
  if (createdAt == null) {
    return '';
  }
  // ADR-038 fallback: epoch Instant → current device timezone wall clock.
  final local = createdAt.toLocal();
  return _formatExactComponents(
    l10n: l10n,
    year: local.year,
    month: local.month,
    day: local.day,
    hour: local.hour,
    minute: local.minute,
  );
}

String _formatExactComponents({
  required AppLocalizations l10n,
  required int year,
  required int month,
  required int day,
  required int hour,
  required int minute,
}) {
  final y = year.toString().padLeft(4, '0');
  final m = month.toString().padLeft(2, '0');
  final d = day.toString().padLeft(2, '0');
  final hh = hour.toString().padLeft(2, '0');
  final mm = minute.toString().padLeft(2, '0');
  return l10n.mediaInfoExactDateTime(y, m, d, hh, mm);
}
