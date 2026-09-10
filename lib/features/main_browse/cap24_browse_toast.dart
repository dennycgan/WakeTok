import 'package:flutter/material.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 24 soft-delete failure — same toast style family as Cap 19 errors.
void showCap24SoftDeleteFailedToast(
  BuildContext context,
  AppLocalizations l10n,
) {
  showCap19BrowseToast(
    context,
    message: l10n.cap24SoftDeleteFailed,
    toastKey: const Key('cap24SoftDeleteFailedToast'),
  );
}
