import 'package:waketok/l10n/app_localizations.dart';

/// Cap 8.5 / 17.7 relative / exact date strings via ARB only (ADR-012 / D3=B).
///
/// Relative (Cap 17.7 short bands): coarse local-calendar buckets for
/// `diffDays` 0–2 and 3–7 to absorb ±1-day TZ edge error; 8–30 → `N days ago`;
/// beyond → `Y years M months ago` (omit days; omit zero units).
///
/// Exact (Cap 17.7): day-precision approximate local calendar date from
/// [createdAt] Instant → device TZ (`~` day prefix). Not Photos minute wall;
/// may differ from Photos by ±1 calendar day at timezone edges. Rows 1 and 2
/// share the same honest-degradation stance but are not guaranteed numerically
/// consistent with each other.
String formatOverlayRelativeDate({
  required AppLocalizations l10n,
  required DateTime? createdAt,
  required DateTime now,
}) {
  if (createdAt == null) {
    return '';
  }
  final local = createdAt.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diffDays = today.difference(day).inDays;
  if (diffDays <= 2) {
    // 0–2: today / yesterday / day-before; future-dated metadata included.
    return l10n.mediaInfoRelativeWithin3Days;
  }
  if (diffDays <= 7) {
    return l10n.mediaInfoRelativeWithinWeek;
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
    return l10n.mediaInfoRelativeYearsMonthsAgo(years, months);
  }
  if (years > 0) {
    return l10n.mediaInfoRelativeYearsAgo(years);
  }
  if (months > 0) {
    return l10n.mediaInfoRelativeMonthsAgo(months);
  }
  // Calendar edge (e.g. ~31 days) — fall back to days.
  return l10n.mediaInfoRelativeDaysAgo(diffDays.toString());
}

/// Overlay row 2: approximate local **date** only (Cap 17.7).
String formatOverlayExactDateTime({
  required AppLocalizations l10n,
  required DateTime? createdAt,
}) {
  if (createdAt == null) {
    return '';
  }
  final local = createdAt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return l10n.mediaInfoExactDateApprox(y, m, d);
}
