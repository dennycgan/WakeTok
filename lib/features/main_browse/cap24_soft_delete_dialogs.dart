import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/library_smoke/asset_soft_delete_providers.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/saved_pool_dialogs.dart';
import 'package:waketok/features/main_browse/still_in_library_gate.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Outcome of the Cap 24 soft-delete App confirm (Q6=A: dialog stays during Host).
enum Cap24SoftDeleteConfirmOutcome {
  /// User tapped Cancel (or system back) before / without Host success.
  dismissed,

  /// Host soft-delete succeeded.
  success,

  /// Host returned `operationCancelled` (system confirm cancel) — no failure toast.
  operationCancelled,

  /// Host / probe failure that should show failure toast (Cap 23 may already
  /// have shown its unavailable dialog).
  failed,
}

ThemeData _browseImmersiveDarkTheme() => waketokTheme(Brightness.dark);

ButtonStyle _actionStyle({required Color foreground}) {
  return TextButton.styleFrom(
    foregroundColor: foreground,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    minimumSize: const Size(48, 40),
    tapTargetSize: MaterialTapTargetSize.padded,
  );
}

/// App confirm stacked on the more half-sheet; stays open (busy) during Host.
Future<Cap24SoftDeleteConfirmOutcome> showCap24SoftDeleteConfirmDialog({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final darkTheme = _browseImmersiveDarkTheme();
  final outcome = await showDialog<Cap24SoftDeleteConfirmOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return Theme(
        data: darkTheme,
        child: _Cap24SoftDeleteConfirmDialog(ref: ref),
      );
    },
  );
  return outcome ?? Cap24SoftDeleteConfirmOutcome.dismissed;
}

class _Cap24SoftDeleteConfirmDialog extends StatefulWidget {
  const _Cap24SoftDeleteConfirmDialog({required this.ref});

  final WidgetRef ref;

  @override
  State<_Cap24SoftDeleteConfirmDialog> createState() =>
      _Cap24SoftDeleteConfirmDialogState();
}

class _Cap24SoftDeleteConfirmDialogState
    extends State<_Cap24SoftDeleteConfirmDialog> {
  bool _inFlight = false;
  bool _hostBusy = false;

  Future<void> _onConfirm() async {
    if (_inFlight) {
      return;
    }
    _inFlight = true;

    final allowed = await ensureCurrentAssetStillInLibraryForMutation(
      ref: widget.ref,
      context: context,
    );
    if (!mounted) {
      _inFlight = false;
      return;
    }
    if (!allowed) {
      // Cap 23 already showed unavailable when missing; silent deny otherwise.
      Navigator.of(context).pop(Cap24SoftDeleteConfirmOutcome.dismissed);
      return;
    }

    final assetId = widget.ref.read(mainBrowseCurrentAssetIdProvider);
    if (assetId == null || assetId.isEmpty) {
      Navigator.of(context).pop(Cap24SoftDeleteConfirmOutcome.dismissed);
      return;
    }

    setState(() => _hostBusy = true);

    try {
      await widget.ref
          .read(assetSoftDeleteRepositoryProvider)
          .softDeleteAsset(assetId);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(Cap24SoftDeleteConfirmOutcome.success);
    } on PlatformException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.code == AppError.operationCancelled.name) {
        Navigator.of(context)
            .pop(Cap24SoftDeleteConfirmOutcome.operationCancelled);
        return;
      }
      Navigator.of(context).pop(Cap24SoftDeleteConfirmOutcome.failed);
    } on Object {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(Cap24SoftDeleteConfirmOutcome.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final l10n = AppLocalizations.of(context)!;
    final busy = _hostBusy;

    return PopScope(
      canPop: !busy && !_inFlight,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || busy || _inFlight) {
          return;
        }
        Navigator.of(context).pop(Cap24SoftDeleteConfirmOutcome.dismissed);
      },
      child: browseSavedPoolAlertDialog(
        key: const Key('cap24SoftDeleteConfirmDialog'),
        tokens: tokens,
        title: Text(l10n.cap24SoftDeleteConfirmTitle),
        content: Text(l10n.cap24SoftDeleteConfirmBody),
        actions: [
          TextButton(
            key: const Key('cap24SoftDeleteConfirmCancel'),
            onPressed: (busy || _inFlight)
                ? null
                : () => Navigator.of(context)
                    .pop(Cap24SoftDeleteConfirmOutcome.dismissed),
            style: _actionStyle(foreground: tokens.onMediaMuted),
            child: Text(
              l10n.cap24SoftDeleteConfirmCancel,
              style: tokens.labelOnMedia.copyWith(
                color: tokens.onMediaMuted,
                inherit: false,
              ),
            ),
          ),
          TextButton(
            key: const Key('cap24SoftDeleteConfirm'),
            onPressed: (busy || _inFlight) ? null : _onConfirm,
            style: _actionStyle(foreground: tokens.accent),
            child: busy
                ? SizedBox(
                    key: const Key('cap24SoftDeleteConfirmBusy'),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.accent,
                    ),
                  )
                : Text(
                    l10n.cap24SoftDeleteConfirm,
                    style: tokens.labelOnMedia.copyWith(
                      color: tokens.accent,
                      inherit: false,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
