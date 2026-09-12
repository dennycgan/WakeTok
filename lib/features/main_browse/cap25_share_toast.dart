import 'package:flutter/material.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 25 Share Host failure — same toast style family as Cap 19 / Cap 24.
void showCap25ShareFailedToast(
  BuildContext context,
  AppLocalizations l10n,
) {
  showCap19BrowseToast(
    context,
    message: l10n.cap25ShareFailed,
    toastKey: const Key('cap25ShareFailedToast'),
  );
}
