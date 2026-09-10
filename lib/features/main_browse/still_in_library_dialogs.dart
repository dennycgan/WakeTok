import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/saved_pool_dialogs.dart';
import 'package:waketok/l10n/app_localizations.dart';

ThemeData _stillInLibraryImmersiveDarkTheme() => waketokTheme(Brightness.dark);

ButtonStyle _stillInLibraryDialogActionStyle({required Color foreground}) {
  return TextButton.styleFrom(
    foregroundColor: foreground,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    minimumSize: const Size(48, 40),
    tapTargetSize: MaterialTapTargetSize.padded,
  );
}

/// Shared Cap 23 unavailable dialog (ADR-049 D5) — Cap 22 Saved shell.
///
/// Owns [StillInLibraryGateState.dialogVisible]: sets true before show, clears
/// in a `finally` after [showDialog] returns (OK **or** barrier dismiss).
Future<void> showStillInLibraryUnavailableDialog({
  required WidgetRef ref,
  required BuildContext context,
}) async {
  final gate = ref.read(mainBrowseCurrentAssetStillInLibraryProvider.notifier);
  gate.setDialogVisible(true);
  final darkTheme = _stillInLibraryImmersiveDarkTheme();
  final tokens = darkTheme.extension<WakeTokTokens>()!;
  final l10n = AppLocalizations.of(context)!;
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Theme(
          data: darkTheme,
          child: browseSavedPoolAlertDialog(
            key: const Key('stillInLibraryUnavailableDialog'),
            tokens: tokens,
            title: Text(l10n.stillInLibraryUnavailableTitle),
            content: Text(l10n.stillInLibraryUnavailableBody),
            actions: [
              TextButton(
                key: const Key('stillInLibraryUnavailableDialogDismiss'),
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: _stillInLibraryDialogActionStyle(
                  foreground: tokens.accent,
                ),
                child: Text(
                  l10n.stillInLibraryUnavailableConfirm,
                  style: browseSavedPoolDialogAccentLabelStyle(tokens),
                ),
              ),
            ],
          ),
        );
      },
    );
  } finally {
    gate.setDialogVisible(false);
  }
}
