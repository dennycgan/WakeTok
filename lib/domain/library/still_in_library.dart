import 'package:waketok/domain/library/asset_availability.dart';

/// Cap 23 / ADR-049: Photos existence for mutation chrome.
///
/// Still-in-library iff [availability] is not [AssetAvailability.unavailable].
/// `deviceLocal`, `iCloudNotDownloaded`, and `downloading` all count as
/// in-library (existence ≠ device-local).
bool isAssetStillInLibrary(AssetAvailability availability) {
  return availability != AssetAvailability.unavailable;
}

/// Cap 23 / ADR-049: AND gate for mutation chrome — do not merge axes.
///
/// [actionable] = Cap 19 / ADR-042 has-current (+ Cap 21.6 Host-unavailable).
/// [stillInLibrary] = ADR-049 Photos-existence axis.
bool mutationChromeMayProceed({
  required bool actionable,
  required bool stillInLibrary,
}) {
  return actionable && stillInLibrary;
}
