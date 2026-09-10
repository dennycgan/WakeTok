import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/still_in_library_dialogs.dart';

/// Cap 23 mutation gate: actionable AND still-in-library (ADR-049).
///
/// Returns `true` only when the current asset may proceed to mutation chrome
/// or Host mutation. Shows the shared unavailable dialog iff the probe ends
/// in [StillInLibraryStatus.missing]. Silent `false` for busy / stale / not
/// actionable.
Future<bool> ensureCurrentAssetStillInLibraryForMutation({
  required WidgetRef ref,
  required BuildContext context,
}) async {
  final gate = ref.read(mainBrowseCurrentAssetStillInLibraryProvider.notifier);
  if (gate.isBusy) {
    return false;
  }
  if (!ref.read(mainBrowseCurrentAssetActionableProvider)) {
    return false;
  }

  final ok = await gate.probeCurrentAssetStillInLibrary();
  if (ok) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  if (ref.read(mainBrowseCurrentAssetStillInLibraryProvider).status ==
      StillInLibraryStatus.missing) {
    await showStillInLibraryUnavailableDialog(ref: ref, context: context);
  }
  return false;
}
