import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/pool_capacity.dart';
import 'package:waketok/domain/source/saved_pool_record.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/build_pool_scaffold_page.dart';
import 'package:waketok/features/main_browse/build_pool_smart_catalog.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/features/main_browse/composition_peek_dismiss.dart';
import 'package:waketok/features/main_browse/composition_source_labels.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/saved_pool_dialogs.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Shared chrome control metrics (Temp / Saved chip / Built-in / Create / Saved menu).
const double _kChromeControlHeight = 32;
const double _kChromeControlHPad = 10;
const double _kSavedChipMaxWidth = 112;
const double _kChromeDropdownIconSize = 16;

/// Drop font leading so glyphs sit in the geometric middle of the fixed hit.
const TextHeightBehavior _kChromeTextHeightBehavior = TextHeightBehavior(
  applyHeightToFirstAscent: false,
  applyHeightToLastDescent: false,
);

TextStyle _chromeOnMediaLabelStyle(WakeTokTokens tokens, Color color) {
  return tokens.labelOnMedia.copyWith(
    color: color,
    inherit: false,
    height: 1.0,
    shadows: tokens.onMediaLabelShadows,
  );
}

Widget _chromeLabelText(
  String text,
  TextStyle style, {
  int maxLines = 1,
}) {
  return Text(
    text,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    textHeightBehavior: _kChromeTextHeightBehavior,
    style: style,
  );
}

/// Fixed-height chrome hit; [child] is centered on both axes inside the pad.
Widget _chromeControlShell({
  required Widget child,
  double? maxWidth,
}) {
  final body = SizedBox(
    height: _kChromeControlHeight,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kChromeControlHPad),
      child: Center(child: child),
    ),
  );
  if (maxWidth == null) {
    return body;
  }
  return ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: body,
  );
}

Widget _chromeDropdownRow({
  required String label,
  required TextStyle style,
  required Color iconColor,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      _chromeLabelText(label, style),
      Icon(
        Icons.arrow_drop_down,
        size: _kChromeDropdownIconSize,
        color: iconColor,
      ),
    ],
  );
}

/// Cap 21.3 four-control top chrome (ADR-044 D6.4 / D7).
///
/// Layout: Temp chip (left, if parked) · Built-in+Saved (screen-center) ·
/// Create (right). Chip show/hide must not translate the center pair.
class BrowseTopChrome extends ConsumerWidget {
  const BrowseTopChrome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chrome = ref.watch(browseChromeStateProvider);
    final parked = chrome.parkedEphemeralPool;
    final origin = chrome.activeOrigin;
    final builtInSelected = builtInControlSelected(origin);
    final remembered = chrome.lastRememberedBuiltIn;
    final chipKind = leftChipKindFor(origin: origin, parked: parked);
    final savedChipName = _savedChipDisplayName(
      origin: origin,
      records: ref.watch(savedPoolRecordsProvider).asData?.value,
    );

    final createEnabled =
        ref.watch(photosAuthorizationProvider).value != PhotosAccess.limited;
    final chromeHeight = createEnabled ? 52.0 : 70.0;

    return Material(
      key: const Key('mainBrowseTopSourceChrome'),
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: chromeHeight,
          child: Stack(
            children: [
              // Vertically center all four controls in the chrome band
              // (Cap 22.5: top:4 left/right sat optically higher than the
              // Built-in+Saved pair which includes the dropdown icon).
              Align(
                alignment: Alignment.center,
                child: Row(
                  key: const Key('mainBrowseChromeCenterPair'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BuiltInControl(
                      remembered: remembered,
                      origin: origin,
                      savedPoolName: savedChipName,
                      highlightAsSelected: builtInSelected,
                      onPick: (next) => ref
                          .read(mainBrowseSelectedSourceProvider.notifier)
                          .select(next),
                    ),
                    const SizedBox(width: 12),
                    const _SavedControl(),
                  ],
                ),
              ),
              switch (chipKind) {
                BrowseLeftChipKind.hidden => const SizedBox.shrink(),
                BrowseLeftChipKind.tempPool => Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _TempPoolChip(
                      isActive: switch (origin) {
                        BrowseOriginEphemeralPool() => true,
                        BrowseOriginBuiltIn() ||
                        BrowseOriginSavedPool() =>
                          false,
                      },
                      onTap: () =>
                          _onTempChipTap(context, ref, parked: parked!),
                    ),
                  ),
                ),
                BrowseLeftChipKind.savedPool => Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _SavedPoolChip(
                      label: savedChipName ?? '',
                      onTap: () => _onSavedChipTap(context, ref),
                    ),
                  ),
                ),
              },
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _CreateControl(
                    enabled: createEnabled,
                    onTap: () {
                      // Cap 21.5 P4: refresh catalog when opening Build so
                      // deleted albums do not linger from a stale
                      // FutureProvider.
                      ref.invalidate(assetSourcesProvider);
                      ref.invalidate(buildPoolSmartCatalogProvider);
                      final cover = ref.read(
                        browseCoveringRouteOpenProvider.notifier,
                      );
                      cover.setOpen(true);
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute<void>(
                              builder: (_) => const BuildPoolScaffoldPage(),
                            ),
                          )
                          .whenComplete(() => cover.setOpen(false));
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onTempChipTap(
    BuildContext context,
    WidgetRef ref, {
    required SourcePoolDefinition parked,
  }) async {
    if (ref.read(browseChromeStateProvider.notifier).isParkedEphemeralActive) {
      await showCompositionPeekPopover(
        context: context,
        parked: parked,
        frozenLabels: ref
            .read(browseChromeStateProvider)
            .parkedCompositionLabels,
        showSaveFooter: true,
      );
      return;
    }
    ref.read(browseChromeStateProvider.notifier).resumeParkedEphemeral();
  }

  Future<void> _onSavedChipTap(BuildContext context, WidgetRef ref) async {
    final origin = ref.read(browseChromeStateProvider).activeOrigin;
    switch (origin) {
      case BrowseOriginSavedPool(:final definition, :final poolId):
        // Entry-point shell: top-leading chip → composition peek (not
        // center Info). Same peek family as Temp; Saved title uses name.
        ref.invalidate(assetSourcesProvider);
        final name = _savedChipDisplayName(
              origin: origin,
              records: ref.read(savedPoolRecordsProvider).asData?.value,
            ) ??
            definition.displayName ??
            poolId;
        await showCompositionPeekPopover(
          context: context,
          parked: definition,
          title: AppLocalizations.of(context)!.mainBrowseSavedPoolSourcesTitle(
            name,
          ),
          showSaveFooter: false,
        );
      case BrowseOriginBuiltIn() || BrowseOriginEphemeralPool():
        return;
    }
  }
}

String? _savedChipDisplayName({
  required BrowseOrigin origin,
  required List<SavedPoolRecord>? records,
}) {
  return switch (origin) {
    BrowseOriginSavedPool(:final poolId, :final definition) => () {
      if (records != null) {
        for (final row in records) {
          if (row.id == poolId) {
            return row.displayName;
          }
        }
      }
      return definition.displayName ?? poolId;
    }(),
    BrowseOriginBuiltIn() || BrowseOriginEphemeralPool() => null,
  };
}

String _builtInSemanticsLabel({
  required AppLocalizations l10n,
  required String builtInLabel,
  required BrowseOrigin origin,
  String? savedPoolName,
}) {
  return switch (origin) {
    BrowseOriginBuiltIn() => builtInLabel,
    BrowseOriginEphemeralPool() =>
      l10n.mainBrowseBuiltInWhileEphemeralSemantics(builtInLabel),
    BrowseOriginSavedPool() => l10n.mainBrowseBuiltInWhileSavedPoolSemantics(
      builtInLabel,
      savedPoolName ?? '',
    ),
  };
}

class _TempPoolChip extends StatelessWidget {
  const _TempPoolChip({required this.isActive, required this.onTap});

  /// True while browsing the parked ephemeral (accent + surface pill).
  /// False while parked but [BrowseOriginBuiltIn] (muted, no pill).
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final color = isActive ? tokens.accent : tokens.onMediaMuted;
    return Semantics(
      button: true,
      selected: isActive,
      label: l10n.mainBrowseTempPoolChip,
      child: Material(
        key: const Key('mainBrowseTempPoolChip'),
        color: isActive
            ? tokens.surface.withValues(alpha: 0.92)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: _chromeControlShell(
            child: _chromeLabelText(
              l10n.mainBrowseTempPoolChip,
              _chromeOnMediaLabelStyle(tokens, color),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedPoolChip extends StatelessWidget {
  const _SavedPoolChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return Material(
      key: const Key('mainBrowseSavedPoolChip'),
      color: tokens.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: _chromeControlShell(
          maxWidth: _kSavedChipMaxWidth,
          child: _chromeLabelText(
            label,
            _chromeOnMediaLabelStyle(tokens, tokens.accent),
          ),
        ),
      ),
    );
  }
}

class _CreateControl extends StatelessWidget {
  const _CreateControl({required this.onTap, required this.enabled});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    // Cap 21.5 P5: Limited — Create is disabled (Build catalog has no
    // albums after Cap 21.4 Q3; STATE Accepted deviation).
    final color = enabled
        ? tokens.onMediaMuted
        : tokens.onMediaMuted.withValues(alpha: 0.35);
    final labelStyle = _chromeOnMediaLabelStyle(tokens, color);
    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled
          ? l10n.mainBrowseCreatePool
          : '${l10n.mainBrowseCreatePool}. ${l10n.mainBrowseCreatePoolRequiresFullAccess}',
      child: Column(
        key: const Key('mainBrowseCreatePoolColumn'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          InkWell(
            key: const Key('mainBrowseCreatePool'),
            onTap: enabled ? onTap : null,
            child: _chromeControlShell(
              child: _chromeLabelText(
                l10n.mainBrowseCreatePool,
                labelStyle,
              ),
            ),
          ),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.only(right: _kChromeControlHPad, bottom: 2),
              child: Text(
                key: const Key('mainBrowseCreatePoolRequiresFullAccess'),
                l10n.mainBrowseCreatePoolRequiresFullAccess,
                textAlign: TextAlign.end,
                textHeightBehavior: _kChromeTextHeightBehavior,
                style: tokens.labelOnMedia.copyWith(
                  fontSize: 9,
                  height: 1.0,
                  inherit: false,
                  color: color,
                  shadows: tokens.onMediaLabelShadows,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BuiltInControl extends StatelessWidget {
  const _BuiltInControl({
    required this.remembered,
    required this.origin,
    required this.highlightAsSelected,
    required this.onPick,
    this.savedPoolName,
  });

  final SourceReference remembered;
  final BrowseOrigin origin;
  final String? savedPoolName;
  final bool highlightAsSelected;
  final ValueChanged<SourceReference> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final label = builtInDisplayLabel(l10n, remembered);
    final color = highlightAsSelected ? tokens.accent : tokens.onMediaMuted;
    final semanticsLabel = _builtInSemanticsLabel(
      l10n: l10n,
      builtInLabel: label,
      origin: origin,
      savedPoolName: savedPoolName,
    );
    return Semantics(
      key: const Key('mainBrowseBuiltInMenuSemantics'),
      button: true,
      selected: highlightAsSelected,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Material(
          key: const Key('mainBrowseBuiltInMenu'),
          color: highlightAsSelected
              ? tokens.surface.withValues(alpha: 0.92)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _openBuiltInOverlay(context),
            borderRadius: BorderRadius.circular(16),
            child: _chromeControlShell(
              child: _chromeDropdownRow(
                label: label,
                style: _chromeOnMediaLabelStyle(tokens, color),
                iconColor: color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openBuiltInOverlay(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final choice = await _showChromeMenuOverlay<SourceReference>(
      context: context,
      menuKey: const Key('mainBrowseBuiltInOverlay'),
      barrierLabel: l10n.mainBrowseBuiltInMenu,
      items: [
        _ChromeMenuItem(
          key: const Key('mainBrowseBuiltInOptionAll'),
          label: l10n.libraryRowAll,
          value: SourceReference.all,
        ),
        _ChromeMenuItem(
          key: const Key('mainBrowseBuiltInOptionPhotos'),
          label: l10n.libraryRowPhotos,
          value: SourceReference.photos,
        ),
        _ChromeMenuItem(
          key: const Key('mainBrowseBuiltInOptionVideos'),
          label: l10n.libraryRowVideos,
          value: SourceReference.videos,
        ),
      ],
    );
    if (choice != null) {
      onPick(choice);
    }
  }
}

class _SavedControl extends ConsumerWidget {
  const _SavedControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return InkWell(
      key: const Key('mainBrowseSavedPoolsMenu'),
      onTap: () => _openSavedOverlay(context, ref),
      child: _chromeControlShell(
        child: _chromeDropdownRow(
          label: l10n.mainBrowseSavedPoolsMenu,
          style: _chromeOnMediaLabelStyle(tokens, tokens.onMediaMuted),
          iconColor: tokens.onMediaMuted,
        ),
      ),
    );
  }

  Future<void> _openSavedOverlay(BuildContext context, WidgetRef ref) async {
    ref.invalidate(assetSourcesProvider);
    await ref.read(savedPoolRecordsProvider.notifier).refresh();
    if (!context.mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final pick = await _showSavedPoolsOverlay(
      context: context,
      barrierLabel: l10n.mainBrowseSavedPoolsMenu,
    );
    if (!context.mounted || pick == null) {
      return;
    }
    await _handleSavedOverlayPick(context, ref, pick);
  }

  Future<void> _handleSavedOverlayPick(
    BuildContext context,
    WidgetRef ref,
    _SavedOverlayPick pick,
  ) async {
    final notifier = ref.read(browseChromeStateProvider.notifier);
    final repo = ref.read(savedPoolRepositoryProvider);
    switch (pick) {
      case _SavedOverlayOpen(:final record):
        final current = ref.read(browseChromeStateProvider).activeOrigin;
        final already = switch (current) {
          BrowseOriginSavedPool(:final poolId) => poolId == record.id,
          BrowseOriginBuiltIn() || BrowseOriginEphemeralPool() => false,
        };
        if (already) {
          final l10n = AppLocalizations.of(context)!;
          showCap19BrowseToast(
            context,
            message: l10n.mainBrowseSavedPoolAlreadyBrowsing(
              record.displayName,
            ),
            toastKey: const Key('mainBrowseSavedPoolAlreadyBrowsingToast'),
          );
          return;
        }
        notifier.openSavedPool(record);
      case _SavedOverlayInfo(:final record):
        // Menu already popped via Navigator.pop(pick); center Info (not peek).
        ref.invalidate(assetSourcesProvider);
        await showSavedPoolInfoDialog(
          context: context,
          displayName: record.displayName,
          definition: record.toDefinition(),
        );
      case _SavedOverlayRename(:final record):
        final outcome = await showSavedPoolNamingDialog(
          context: context,
          repository: repo,
          initialDisplayName: record.displayName,
          renamePoolId: record.id,
        );
        if (!context.mounted) {
          return;
        }
        switch (outcome) {
          case SavedPoolNamingSaved(:final record):
            notifier.replaceActiveSavedPool(record);
            await ref.read(savedPoolRecordsProvider.notifier).refresh();
          case SavedPoolNamingCancelled() || SavedPoolNamingAtCapacity():
            return;
        }
      case _SavedOverlayDelete(:final record):
        final confirmed = await showSavedPoolDeleteConfirmDialog(
          context: context,
          displayName: record.displayName,
        );
        if (!context.mounted || !confirmed) {
          return;
        }
        final current = ref.read(browseChromeStateProvider).activeOrigin;
        final deletingActive = switch (current) {
          BrowseOriginSavedPool(:final poolId) => poolId == record.id,
          BrowseOriginBuiltIn() || BrowseOriginEphemeralPool() => false,
        };
        if (deletingActive) {
          notifier.selectBuiltIn(
            ref.read(browseChromeStateProvider).lastRememberedBuiltIn,
          );
        }
        await repo.delete(record.id);
        await ref.read(savedPoolRecordsProvider.notifier).refresh();
    }
  }
}

sealed class _SavedOverlayPick {
  const _SavedOverlayPick();
}

final class _SavedOverlayOpen extends _SavedOverlayPick {
  const _SavedOverlayOpen(this.record);
  final SavedPoolRecord record;
}

final class _SavedOverlayInfo extends _SavedOverlayPick {
  const _SavedOverlayInfo(this.record);
  final SavedPoolRecord record;
}

final class _SavedOverlayRename extends _SavedOverlayPick {
  const _SavedOverlayRename(this.record);
  final SavedPoolRecord record;
}

final class _SavedOverlayDelete extends _SavedOverlayPick {
  const _SavedOverlayDelete(this.record);
  final SavedPoolRecord record;
}

Future<_SavedOverlayPick?> _showSavedPoolsOverlay({
  required BuildContext context,
  required String barrierLabel,
}) {
  // showGeneralDialog does not capture InheritedThemes — force immersive
  // dark like Cap 19 half-sheet / Cap 21 Build (avoid light surface + onMedia).
  final darkTheme = waketokTheme(Brightness.dark);
  final tokens = darkTheme.extension<WakeTokTokens>()!;
  return showGeneralDialog<_SavedOverlayPick>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Theme(
        data: darkTheme,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 56),
              child: Material(
                key: const Key('mainBrowseSavedOverlay'),
                color: tokens.surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 220,
                    maxWidth: 320,
                    maxHeight: 400,
                  ),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final l10n = AppLocalizations.of(context)!;
                      final async = ref.watch(savedPoolRecordsProvider);
                      return async.when(
                        data: (rows) {
                          if (rows.isEmpty) {
                            return ListTile(
                              key: const Key('mainBrowseSavedPlaceholderEmpty'),
                              enabled: false,
                              title: Text(
                                l10n.mainBrowseSavedPlaceholderEmpty,
                                style: tokens.labelOnMedia.copyWith(
                                  color: tokens.onMediaMuted.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            );
                          }
                          return ListView(
                            shrinkWrap: true,
                            children: [
                              for (final record in rows)
                                ListTile(
                                  key: Key('mainBrowseSavedRow_${record.id}'),
                                  title: Text(
                                    record.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tokens.labelOnMedia.copyWith(
                                      color: tokens.onMedia,
                                    ),
                                  ),
                                  onTap: () => Navigator.of(
                                    dialogContext,
                                  ).pop(_SavedOverlayOpen(record)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        key: Key(
                                          'mainBrowseSavedRowInfo_${record.id}',
                                        ),
                                        tooltip: l10n.mainBrowseSavedPoolRowInfo,
                                        visualDensity: VisualDensity.compact,
                                        style: IconButton.styleFrom(
                                          minimumSize: const Size(36, 36),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          padding: EdgeInsets.zero,
                                        ),
                                        icon: Icon(
                                          Icons.info_outline,
                                          size: 20,
                                          color: tokens.onMediaMuted,
                                        ),
                                        onPressed: () => Navigator.of(
                                          dialogContext,
                                        ).pop(_SavedOverlayInfo(record)),
                                      ),
                                      IconButton(
                                        key: Key(
                                          'mainBrowseSavedRowRename_${record.id}',
                                        ),
                                        tooltip:
                                            l10n.mainBrowseSavedPoolRowRename,
                                        visualDensity: VisualDensity.compact,
                                        style: IconButton.styleFrom(
                                          minimumSize: const Size(36, 36),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          padding: EdgeInsets.zero,
                                        ),
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          size: 20,
                                          color: tokens.onMediaMuted,
                                        ),
                                        onPressed: () => Navigator.of(
                                          dialogContext,
                                        ).pop(_SavedOverlayRename(record)),
                                      ),
                                      IconButton(
                                        key: Key(
                                          'mainBrowseSavedRowDelete_${record.id}',
                                        ),
                                        tooltip:
                                            l10n.mainBrowseSavedPoolRowDelete,
                                        visualDensity: VisualDensity.compact,
                                        style: IconButton.styleFrom(
                                          minimumSize: const Size(36, 36),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          padding: EdgeInsets.zero,
                                        ),
                                        icon: Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                          color: tokens.onMediaMuted,
                                        ),
                                        onPressed: () => Navigator.of(
                                          dialogContext,
                                        ).pop(_SavedOverlayDelete(record)),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                        loading: () => Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: tokens.accent,
                              ),
                            ),
                          ),
                        ),
                        error: (_, _) => ListTile(
                          enabled: false,
                          title: Text(
                            l10n.mainBrowseSavedPlaceholderEmpty,
                            style: tokens.labelOnMedia.copyWith(
                              color: tokens.onMediaMuted,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ChromeMenuItem<T> {
  const _ChromeMenuItem({
    required this.key,
    required this.label,
    required this.value,
    this.enabled = true,
    this.labelColor,
  });

  final Key key;
  final String label;
  final T? value;
  final bool enabled;
  final Color? labelColor;
}

/// Dark immersive menu overlay (Built-in / Saved). Barrier absorbs taps
/// and blocks feed drag while open (ADR-040 — manual soak verifies gesture).
Future<T?> _showChromeMenuOverlay<T>({
  required BuildContext context,
  required Key menuKey,
  required String barrierLabel,
  required List<_ChromeMenuItem<T>> items,
}) {
  // showGeneralDialog does not capture InheritedThemes — force immersive dark.
  final darkTheme = waketokTheme(Brightness.dark);
  final tokens = darkTheme.extension<WakeTokTokens>()!;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Theme(
        data: darkTheme,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 56),
              child: Material(
                key: menuKey,
                color: tokens.surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final item in items)
                        ListTile(
                          key: item.key,
                          enabled: item.enabled,
                          title: Text(
                            item.label,
                            style: tokens.labelOnMedia.copyWith(
                              color:
                                  item.labelColor ??
                                  (item.enabled
                                      ? tokens.onMedia
                                      : tokens.onMediaMuted),
                            ),
                          ),
                          onTap: item.enabled && item.value != null
                              ? () => Navigator.of(dialogContext).pop(item.value)
                              : null,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Cap 21.5: non-modal composition peek (lighter than Built-in/Saved overlay).
///
/// Vertical drag / tap outside dismisses so Browse feed can keep scrolling.
/// Manual device check for gesture pass-through; automated tests cover
/// tap-outside and chip re-open dismiss paths where practical.
Future<void> showCompositionPeekPopover({
  required BuildContext context,
  required SourcePoolDefinition parked,
  List<String>? frozenLabels,
  bool showSaveFooter = false,
  String? title,
}) {
  final overlay = Overlay.of(context);
  final completer = Completer<void>();
  late OverlayEntry entry;

  void dismiss() {
    if (completer.isCompleted) {
      return;
    }
    entry.remove();
    registerCompositionPeekDismiss(null);
    completer.complete();
  }

  final darkTheme = waketokTheme(Brightness.dark);
  registerCompositionPeekDismiss(dismiss);
  entry = OverlayEntry(
    builder: (overlayContext) {
      return Theme(
        data: darkTheme,
        child: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => dismiss(),
                onPointerMove: (event) {
                  if (event.delta.dy.abs() >= 4) {
                    dismiss();
                  }
                },
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 56, 48, 0),
                  child: GestureDetector(
                    // Absorb taps on the card so they do not hit the
                    // translucent dismiss layer underneath.
                    onTap: () {},
                    child: _CompositionPeekCard(
                      parked: parked,
                      frozenLabels: frozenLabels,
                      showSaveFooter: showSaveFooter,
                      title: title,
                      hostContext: context,
                      onDismiss: dismiss,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  overlay.insert(entry);
  return completer.future;
}

class _CompositionPeekCard extends ConsumerWidget {
  const _CompositionPeekCard({
    required this.parked,
    required this.hostContext,
    required this.onDismiss,
    this.frozenLabels,
    this.showSaveFooter = false,
    this.title,
  });

  final SourcePoolDefinition parked;
  final List<String>? frozenLabels;
  final bool showSaveFooter;
  final String? title;
  final BuildContext hostContext;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final asyncSources = ref.watch(assetSourcesProvider);
    final access = ref.watch(photosAuthorizationProvider).value;
    final refs = parked.orderedSourceReferences;

    return Material(
      key: const Key('mainBrowseCompositionPeek'),
      color: tokens.surface.withValues(alpha: 0.96),
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280, maxHeight: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title ?? l10n.mainBrowseCompositionPeekTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: browseSavedPoolDialogTitleStyle(tokens),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: asyncSources.when(
                  data: (sources) => ListView(
                    shrinkWrap: true,
                    children: [
                      for (var i = 0; i < refs.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            compositionPeekLine(
                              l10n: l10n,
                              access: access,
                              reference: refs[i],
                              catalog: sources,
                              frozenLabel: _frozenAt(i),
                            ),
                            style: tokens.bodyOnMedia.copyWith(
                              color: tokens.onMediaMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                  loading: () => SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.accent,
                    ),
                  ),
                  error: (_, _) => Text(
                    l10n.mainBrowseCompositionPeekUnknownSource,
                    style: tokens.bodyOnMedia.copyWith(
                      color: tokens.onMediaMuted,
                    ),
                  ),
                ),
              ),
              if (showSaveFooter) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const Key('mainBrowseCompositionPeekSave'),
                    onPressed: _saveFromPeek,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.onMedia,
                      side: BorderSide(color: tokens.accent),
                    ),
                    child: Text(l10n.mainBrowseCompositionPeekSave),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveFromPeek() async {
    final host = hostContext;
    if (!host.mounted) {
      return;
    }
    // Capture before dismiss — OverlayEntry.remove unmounts this card's Ref.
    final container = ProviderScope.containerOf(host);
    final repo = container.read(savedPoolRepositoryProvider);
    final sourceRefs = parked.orderedSourceReferences;
    // Dismiss composition peek before capacity / naming dialogs so the two
    // surfaces never overlap (Temp chip → Save this pool).
    onDismiss();
    final existing = await repo.loadAll();
    if (!host.mounted) {
      return;
    }
    if (existing.length >= PoolCapacity.maxSavedPoolPresets) {
      await showSavedPoolCapacityDialog(host);
      return;
    }
    final outcome = await showSavedPoolNamingDialog(
      context: host,
      repository: repo,
      orderedSourceReferences: sourceRefs,
    );
    if (!host.mounted) {
      return;
    }
    switch (outcome) {
      case SavedPoolNamingCancelled():
        return;
      case SavedPoolNamingAtCapacity():
        await showSavedPoolCapacityDialog(host);
        return;
      case SavedPoolNamingSaved(:final record):
        container.read(browseChromeStateProvider.notifier).startSavedPool(record);
    }
  }

  String? _frozenAt(int index) {
    final frozen = frozenLabels;
    if (frozen == null || index < 0 || index >= frozen.length) {
      return null;
    }
    final value = frozen[index];
    return value.isEmpty ? null : value;
  }
}
