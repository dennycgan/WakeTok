import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/source/pool_capacity.dart';
import 'package:waketok/domain/source/saved_pool_display_name.dart';
import 'package:waketok/domain/source/saved_pool_failure.dart';
import 'package:waketok/domain/source/saved_pool_record.dart';
import 'package:waketok/domain/source/saved_pool_recipe.dart';
import 'package:waketok/domain/source/saved_pool_repository.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/composition_peek_dismiss.dart';
import 'package:waketok/features/main_browse/composition_source_labels.dart';
import 'package:waketok/l10n/app_localizations.dart';

sealed class SavedPoolNamingOutcome {
  const SavedPoolNamingOutcome();
}

final class SavedPoolNamingCancelled extends SavedPoolNamingOutcome {
  const SavedPoolNamingCancelled();
}

final class SavedPoolNamingSaved extends SavedPoolNamingOutcome {
  const SavedPoolNamingSaved(this.record);
  final SavedPoolRecord record;
}

final class SavedPoolNamingAtCapacity extends SavedPoolNamingOutcome {
  const SavedPoolNamingAtCapacity();
}

/// Browse-serving Saved dialogs always use immersive dark tokens (Cap 21
/// Build / Cap 19 half-sheet pattern). Light Appearance must not pair white
/// [WakeTokTokens.surface] with white [WakeTokTokens.onMedia].
ThemeData _browseImmersiveDarkTheme() => waketokTheme(Brightness.dark);

/// Title metrics matching composition peek (`labelOnMedia`, inherit false).
///
/// [AlertDialog] applies Theme [titleLarge] as a DefaultTextStyle around the
/// title; with `inherit: true` (TextStyle default) that inflates size/weight
/// vs peek. All browse Saved dialogs must use this helper — not a raw
/// `labelOnMedia.copyWith(color: …)`.
@visibleForTesting
TextStyle browseSavedPoolDialogTitleStyle(WakeTokTokens tokens) {
  return tokens.labelOnMedia.copyWith(
    color: tokens.onMedia,
    inherit: false,
  );
}

@visibleForTesting
TextStyle browseSavedPoolDialogBodyStyle(WakeTokTokens tokens) {
  return tokens.bodyOnMedia.copyWith(
    color: tokens.onMediaMuted,
    inherit: false,
  );
}

@visibleForTesting
TextStyle browseSavedPoolDialogAccentLabelStyle(WakeTokTokens tokens) {
  return tokens.labelOnMedia.copyWith(
    color: tokens.accent,
    inherit: false,
  );
}

@visibleForTesting
TextStyle browseSavedPoolDialogMutedLabelStyle(WakeTokTokens tokens) {
  return tokens.labelOnMedia.copyWith(
    color: tokens.onMediaMuted,
    inherit: false,
  );
}

/// Balanced vs Material Dialog defaults (too airy) and over-tight 8px insets
/// (hard to tap). Shared by Info / Capacity / Delete / Naming.
@visibleForTesting
const EdgeInsets browseSavedPoolDialogTitlePadding =
    EdgeInsets.fromLTRB(20, 18, 20, 10);

@visibleForTesting
const EdgeInsets browseSavedPoolDialogContentPadding =
    EdgeInsets.fromLTRB(20, 0, 20, 12);

@visibleForTesting
const EdgeInsets browseSavedPoolDialogActionsPadding =
    EdgeInsets.fromLTRB(12, 4, 12, 14);

ButtonStyle _browseSavedPoolDialogActionStyle({required Color foreground}) {
  return TextButton.styleFrom(
    foregroundColor: foreground,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    minimumSize: const Size(48, 40),
    tapTargetSize: MaterialTapTargetSize.padded,
  );
}

/// Shared AlertDialog shell for browse Saved surfaces (Info / Capacity /
/// Delete / Naming) — same title token as composition peek.
AlertDialog browseSavedPoolAlertDialog({
  Key? key,
  required WakeTokTokens tokens,
  required Widget title,
  Widget? content,
  required List<Widget> actions,
}) {
  return AlertDialog(
    key: key,
    backgroundColor: tokens.surface,
    titleTextStyle: browseSavedPoolDialogTitleStyle(tokens),
    contentTextStyle: browseSavedPoolDialogBodyStyle(tokens),
    titlePadding: browseSavedPoolDialogTitlePadding,
    contentPadding: browseSavedPoolDialogContentPadding,
    actionsPadding: browseSavedPoolDialogActionsPadding,
    buttonPadding: const EdgeInsets.symmetric(horizontal: 4),
    title: title,
    content: content,
    actions: actions,
  );
}

/// Shared naming dialog (Build Save, peek Save; Rename uses [renamePoolId]).
Future<SavedPoolNamingOutcome> showSavedPoolNamingDialog({
  required BuildContext context,
  required SavedPoolRepository repository,
  List<SourceReference> orderedSourceReferences = const [],
  String? excludePoolId,
  String? initialDisplayName,
  String? renamePoolId,
}) async {
  // Double-insurance for ephemeral composition peek → Save (not Saved Info).
  dismissCompositionPeekIfOpen();
  final darkTheme = _browseImmersiveDarkTheme();
  final outcome = await showDialog<SavedPoolNamingOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return Theme(
        data: darkTheme,
        child: _SavedPoolNamingDialog(
          repository: repository,
          orderedSourceReferences: orderedSourceReferences,
          excludePoolId: excludePoolId ?? renamePoolId,
          initialDisplayName: initialDisplayName,
          renamePoolId: renamePoolId,
        ),
      );
    },
  );
  return outcome ?? const SavedPoolNamingCancelled();
}

Future<bool> showSavedPoolDeleteConfirmDialog({
  required BuildContext context,
  required String displayName,
}) async {
  final darkTheme = _browseImmersiveDarkTheme();
  final tokens = darkTheme.extension<WakeTokTokens>()!;
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return Theme(
        data: darkTheme,
        child: browseSavedPoolAlertDialog(
          key: const Key('mainBrowseSavedPoolDeleteDialog'),
          tokens: tokens,
          title: Text(l10n.mainBrowseSavedPoolDeleteTitle),
          content: Text(l10n.mainBrowseSavedPoolDeleteBody(displayName)),
          actions: [
            TextButton(
              key: const Key('mainBrowseSavedPoolDeleteCancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: _browseSavedPoolDialogActionStyle(
                foreground: tokens.onMediaMuted,
              ),
              child: Text(
                l10n.mainBrowseSavedPoolDeleteCancel,
                style: browseSavedPoolDialogMutedLabelStyle(tokens),
              ),
            ),
            TextButton(
              key: const Key('mainBrowseSavedPoolDeleteConfirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: _browseSavedPoolDialogActionStyle(
                foreground: tokens.accent,
              ),
              child: Text(
                l10n.mainBrowseSavedPoolDeleteConfirm,
                style: browseSavedPoolDialogAccentLabelStyle(tokens),
              ),
            ),
          ],
        ),
      );
    },
  );
  return confirmed ?? false;
}

Future<void> showSavedPoolCapacityDialog(BuildContext context) {
  // Double-insurance for ephemeral composition peek → Save (not Saved Info).
  dismissCompositionPeekIfOpen();
  final darkTheme = _browseImmersiveDarkTheme();
  final tokens = darkTheme.extension<WakeTokTokens>()!;
  final l10n = AppLocalizations.of(context)!;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Theme(
        data: darkTheme,
        child: browseSavedPoolAlertDialog(
          key: const Key('mainBrowseSavedPoolCapacityDialog'),
          tokens: tokens,
          title: Text(l10n.mainBrowseSavedPoolCapacityTitle),
          content: Text(l10n.mainBrowseSavedPoolCapacityBody),
          actions: [
            TextButton(
              key: const Key('mainBrowseSavedPoolCapacityConfirm'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: _browseSavedPoolDialogActionStyle(
                foreground: tokens.accent,
              ),
              child: Text(
                l10n.mainBrowseSavedPoolCapacityConfirm,
                style: browseSavedPoolDialogAccentLabelStyle(tokens),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Centered Saved recipe Info (AlertDialog shell — same family as capacity /
/// naming). Opened from Saved-menu row Info (i), not from the top-leading chip.
Future<void> showSavedPoolInfoDialog({
  required BuildContext context,
  required String displayName,
  required SourcePoolDefinition definition,
}) {
  final darkTheme = _browseImmersiveDarkTheme();
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Theme(
        data: darkTheme,
        child: _SavedPoolInfoDialog(
          displayName: displayName,
          definition: definition,
        ),
      );
    },
  );
}

class _SavedPoolInfoDialog extends ConsumerWidget {
  const _SavedPoolInfoDialog({
    required this.displayName,
    required this.definition,
  });

  final String displayName;
  final SourcePoolDefinition definition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final asyncSources = ref.watch(assetSourcesProvider);
    final access = ref.watch(photosAuthorizationProvider).value;
    final refs = definition.orderedSourceReferences;

    return browseSavedPoolAlertDialog(
      key: const Key('mainBrowseSavedPoolInfoDialog'),
      tokens: tokens,
      title: Text(l10n.mainBrowseSavedPoolSourcesTitle(displayName)),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: asyncSources.when(
            data: (sources) => ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final reference in refs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      compositionPeekLine(
                        l10n: l10n,
                        access: access,
                        reference: reference,
                        catalog: sources,
                      ),
                    ),
                  ),
              ],
            ),
            loading: () => Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.accent,
                ),
              ),
            ),
            error: (_, _) => Text(l10n.mainBrowseCompositionPeekUnknownSource),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('mainBrowseSavedPoolInfoClose'),
          onPressed: () => Navigator.of(context).pop(),
          style: _browseSavedPoolDialogActionStyle(foreground: tokens.accent),
          child: Text(
            l10n.mainBrowseSavedPoolInfoClose,
            style: browseSavedPoolDialogAccentLabelStyle(tokens),
          ),
        ),
      ],
    );
  }
}

class _SavedPoolNamingDialog extends StatefulWidget {
  const _SavedPoolNamingDialog({
    required this.repository,
    required this.orderedSourceReferences,
    this.excludePoolId,
    this.initialDisplayName,
    this.renamePoolId,
  });

  final SavedPoolRepository repository;
  final List<SourceReference> orderedSourceReferences;
  final String? excludePoolId;
  final String? initialDisplayName;
  final String? renamePoolId;

  @override
  State<_SavedPoolNamingDialog> createState() => _SavedPoolNamingDialogState();
}

class _SavedPoolNamingDialogState extends State<_SavedPoolNamingDialog> {
  late final TextEditingController _controller;
  String? _error;
  /// Display-name key that already failed uniqueness; same key + Save must
  /// not clear/restore [_error] (AlertDialog height jump looks like flicker).
  String? _blockedDuplicateKey;
  /// True after a same-recipe block on create — renaming cannot clear it.
  bool _blockedDuplicateRecipe = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDisplayName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_submitting) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final trimmed = normalizeSavedPoolDisplayName(_controller.text);
    if (trimmed == null) {
      setState(() {
        _error = l10n.mainBrowseSavedPoolNamingEmpty;
        _blockedDuplicateKey = null;
      });
      return;
    }
    final nameKey = savedPoolDisplayNameKey(trimmed);
    final renaming = widget.renamePoolId != null;
    // Same colliding name already surfaced — skip async re-check / setState.
    if (_blockedDuplicateKey == nameKey) {
      return;
    }
    // Same-recipe block on create — any name still refused; avoid flicker.
    if (!renaming && _blockedDuplicateRecipe) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final existing = await widget.repository.loadAll();
      if (!renaming && existing.length >= PoolCapacity.maxSavedPoolPresets) {
        if (mounted) {
          Navigator.of(context).pop(const SavedPoolNamingAtCapacity());
        }
        return;
      }
      if (!renaming) {
        final recipeClash = findSavedPoolWithSameRecipe(
          candidate: widget.orderedSourceReferences,
          existing: existing,
        );
        if (recipeClash != null) {
          if (mounted) {
            setState(() {
              _submitting = false;
              _error = l10n.mainBrowseSavedPoolNamingDuplicateRecipe(
                recipeClash.displayName,
              );
              _blockedDuplicateRecipe = true;
              _blockedDuplicateKey = null;
            });
          }
          return;
        }
      }
      if (savedPoolDisplayNameTaken(
        trimmedName: trimmed,
        existing: existing,
        excludeId: widget.excludePoolId,
      )) {
        if (mounted) {
          setState(() {
            _submitting = false;
            _error = l10n.mainBrowseSavedPoolNamingDuplicate;
            _blockedDuplicateKey = nameKey;
          });
        }
        return;
      }
      final record = renaming
          ? await widget.repository.rename(
              id: widget.renamePoolId!,
              displayName: trimmed,
            )
          : await widget.repository.save(
              displayName: trimmed,
              orderedSourceReferences: widget.orderedSourceReferences,
            );
      if (mounted) {
        Navigator.of(context).pop(SavedPoolNamingSaved(record));
      }
    } on SavedPoolDuplicateRecipe catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = l10n.mainBrowseSavedPoolNamingDuplicateRecipe(
            e.existingDisplayName,
          );
          _blockedDuplicateRecipe = true;
          _blockedDuplicateKey = null;
        });
      }
    } on SavedPoolDuplicateName {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = l10n.mainBrowseSavedPoolNamingDuplicate;
          _blockedDuplicateKey = nameKey;
        });
      }
    } on SavedPoolCapacityExceeded {
      if (mounted) {
        Navigator.of(context).pop(const SavedPoolNamingAtCapacity());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return browseSavedPoolAlertDialog(
      key: const Key('mainBrowseSavedPoolNamingDialog'),
      tokens: tokens,
      title: Text(l10n.mainBrowseSavedPoolNamingTitle),
      content: SizedBox(
        // Wider than Material AlertDialog default so recipe-duplicate copy
        // can wrap to two lines instead of single-line ellipsis.
        width: 320,
        child: TextField(
          key: const Key('mainBrowseSavedPoolNamingField'),
          controller: _controller,
          enabled: !_submitting,
          autofocus: true,
          style: tokens.bodyOnMedia.copyWith(color: tokens.onMedia),
          cursorColor: tokens.accent,
          decoration: InputDecoration(
            hintText: l10n.mainBrowseSavedPoolNamingHint,
            hintStyle: tokens.bodyOnMedia.copyWith(
              color: tokens.onMediaMuted,
            ),
            errorText: _error,
            errorMaxLines: 2,
            errorStyle: tokens.bodyOnMedia.copyWith(color: tokens.accent),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: tokens.onMediaMuted),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: tokens.accent),
            ),
            errorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: tokens.accent),
            ),
            focusedErrorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: tokens.accent),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('mainBrowseSavedPoolNamingCancel'),
          onPressed: _submitting
              ? null
              : () =>
                    Navigator.of(context).pop(const SavedPoolNamingCancelled()),
          style: _browseSavedPoolDialogActionStyle(
            foreground: tokens.onMediaMuted,
          ),
          child: Text(
            l10n.mainBrowseSavedPoolNamingCancel,
            style: browseSavedPoolDialogMutedLabelStyle(tokens),
          ),
        ),
        TextButton(
          key: const Key('mainBrowseSavedPoolNamingConfirm'),
          onPressed: _submitting ? null : _confirm,
          style: _browseSavedPoolDialogActionStyle(foreground: tokens.accent),
          child: Text(
            l10n.mainBrowseSavedPoolNamingConfirm,
            style: browseSavedPoolDialogAccentLabelStyle(tokens),
          ),
        ),
      ],
    );
  }
}
