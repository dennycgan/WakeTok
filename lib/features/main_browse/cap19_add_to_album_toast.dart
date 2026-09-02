import 'package:flutter/material.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/l10n/app_localizations.dart';

void showCap19AddToAlbumSuccessToast(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  String albumName,
) {
  final context = messenger.context;
  final tokens = Theme.of(context).extension<WakeTokTokens>()!;

  messenger.showSnackBar(
    SnackBar(
      key: const Key('cap19AddToAlbumSuccessSnackBar'),
      content: Text(
        l10n.cap19PanelAddToAlbumSuccess(albumName),
        style: TextStyle(color: tokens.onMedia),
      ),
      backgroundColor: tokens.feedBackground.withValues(
        alpha: kCap19ActionsHalfSheetTintOpacity,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showCap19AddToAlbumErrorToast(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
) {
  final context = messenger.context;
  final tokens = Theme.of(context).extension<WakeTokTokens>()!;

  messenger.showSnackBar(
    SnackBar(
      key: const Key('cap19AddToAlbumErrorSnackBar'),
      content: Text(
        l10n.cap19PanelAddToAlbumError,
        style: TextStyle(color: tokens.onMedia),
      ),
      backgroundColor: tokens.feedBackground.withValues(
        alpha: kCap19ActionsHalfSheetTintOpacity,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
