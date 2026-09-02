import 'dart:async';

import 'package:flutter/material.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/l10n/app_localizations.dart';

OverlayEntry? _cap19BrowseToastEntry;
Timer? _cap19BrowseToastTimer;

double cap19BrowseToastTopInset(BuildContext context) {
  return MediaQuery.paddingOf(context).top +
      kCap19BrowseTopChromeBodyHeight +
      kCap19BrowseToastBelowTopChromeGap;
}

/// Cap 19 action feedback — root overlay below top source chrome (not SnackBar).
void showCap19BrowseToast(
  BuildContext context, {
  required String message,
  required Key toastKey,
}) {
  hideCap19BrowseToast();
  final overlay = Overlay.of(context, rootOverlay: true);
  final tokens = Theme.of(context).extension<WakeTokTokens>()!;
  final top = cap19BrowseToastTopInset(context);

  _cap19BrowseToastEntry = OverlayEntry(
    builder: (overlayContext) => Positioned(
      top: top,
      left: 24,
      right: 24,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            key: toastKey,
            decoration: BoxDecoration(
              color: tokens.feedBackground.withValues(
                alpha: kCap19ActionsHalfSheetTintOpacity,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                message,
                key: const Key('cap19BrowseToastMessage'),
                textAlign: TextAlign.center,
                style: Theme.of(overlayContext).textTheme.bodyMedium?.copyWith(
                      color: tokens.onMedia,
                    ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(_cap19BrowseToastEntry!);
  _cap19BrowseToastTimer = Timer(kCap19BrowseToastDuration, hideCap19BrowseToast);
}

void hideCap19BrowseToast() {
  _cap19BrowseToastTimer?.cancel();
  _cap19BrowseToastTimer = null;
  _cap19BrowseToastEntry?.remove();
  _cap19BrowseToastEntry = null;
}

void showCap19AddToAlbumSuccessToast(
  BuildContext context,
  AppLocalizations l10n,
  String albumName,
) {
  showCap19BrowseToast(
    context,
    message: l10n.cap19PanelAddToAlbumSuccess(albumName),
    toastKey: const Key('cap19AddToAlbumSuccessToast'),
  );
}

void showCap19AddToAlbumErrorToast(
  BuildContext context,
  AppLocalizations l10n,
) {
  showCap19BrowseToast(
    context,
    message: l10n.cap19PanelAddToAlbumError,
    toastKey: const Key('cap19AddToAlbumErrorToast'),
  );
}

void showCap19FavoritesAddedToast(
  BuildContext context,
  AppLocalizations l10n,
) {
  showCap19BrowseToast(
    context,
    message: l10n.cap19PanelFavoritesAddedSuccess,
    toastKey: const Key('cap19FavoritesAddedToast'),
  );
}

void showCap19FavoritesRemovedToast(
  BuildContext context,
  AppLocalizations l10n,
) {
  showCap19BrowseToast(
    context,
    message: l10n.cap19PanelFavoritesRemovedSuccess,
    toastKey: const Key('cap19FavoritesRemovedToast'),
  );
}

void showCap19FavoritesErrorToast(
  BuildContext context,
  AppLocalizations l10n,
) {
  showCap19BrowseToast(
    context,
    message: l10n.cap19PanelFavoritesError,
    toastKey: const Key('cap19FavoritesErrorToast'),
  );
}

void showCap19LeftSwipeAppendSuccessToast(
  BuildContext context,
  AppLocalizations l10n,
) {
  showCap19BrowseToast(
    context,
    message: l10n.cap19LeftSwipeAppendSuccess,
    toastKey: const Key('cap19LeftSwipeAppendSuccessToast'),
  );
}

void showCap19LeftSwipeAppendErrorToast(
  BuildContext context,
  AppLocalizations l10n,
) {
  showCap19BrowseToast(
    context,
    message: l10n.cap19LeftSwipeAppendError,
    toastKey: const Key('cap19LeftSwipeAppendErrorToast'),
  );
}

/// Test-only reset between widget tests.
@visibleForTesting
void resetCap19BrowseToastForTest() => hideCap19BrowseToast();
