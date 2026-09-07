import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/build_pool_scaffold_page.dart';
import 'package:waketok/features/main_browse/build_pool_smart_catalog.dart';
import 'package:waketok/features/main_browse/composition_source_labels.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/l10n/app_localizations.dart';

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
    final builtInActive = origin is BrowseOriginBuiltIn;
    final remembered = chrome.lastRememberedBuiltIn;
    final ephemeralActive = parked != null &&
        origin is BrowseOriginEphemeralPool &&
        origin.definition == parked;

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
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    key: const Key('mainBrowseChromeCenterPair'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BuiltInControl(
                        remembered: remembered,
                        highlightAsSelected: builtInActive,
                        onPick: (next) => ref
                            .read(mainBrowseSelectedSourceProvider.notifier)
                            .select(next),
                      ),
                      const SizedBox(width: 12),
                      const _SavedControl(),
                    ],
                  ),
                ),
              ),
              if (parked != null)
                Positioned(
                  left: 8,
                  top: 4,
                  child: _TempPoolChip(
                    onTap: () => _onChipTap(
                      context,
                      ref,
                      parked: parked,
                      alreadyActive: ephemeralActive,
                    ),
                  ),
                ),
              Positioned(
                right: 8,
                top: 4,
                child: _CreateControl(
                  enabled: createEnabled,
                  onTap: () {
                    // Cap 21.5 P4: refresh catalog when opening Build so
                    // deleted albums do not linger from a stale FutureProvider.
                    ref.invalidate(assetSourcesProvider);
                    ref.invalidate(buildPoolSmartCatalogProvider);
                    final cover =
                        ref.read(browseCoveringRouteOpenProvider.notifier);
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onChipTap(
    BuildContext context,
    WidgetRef ref, {
    required SourcePoolDefinition parked,
    required bool alreadyActive,
  }) async {
    if (alreadyActive) {
      await showCompositionPeekPopover(
        context: context,
        parked: parked,
        frozenLabels: ref.read(browseChromeStateProvider).parkedCompositionLabels,
      );
      return;
    }
    ref.read(browseChromeStateProvider.notifier).resumeParkedEphemeral();
  }
}

class _TempPoolChip extends StatelessWidget {
  const _TempPoolChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return Material(
      key: const Key('mainBrowseTempPoolChip'),
      color: tokens.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            l10n.mainBrowseTempPoolChip,
            style: tokens.labelOnMedia.copyWith(
              color: tokens.accent,
              shadows: tokens.onMediaLabelShadows,
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateControl extends StatelessWidget {
  const _CreateControl({
    required this.onTap,
    required this.enabled,
  });

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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                l10n.mainBrowseCreatePool,
                style: tokens.labelOnMedia.copyWith(
                  color: color,
                  shadows: tokens.onMediaLabelShadows,
                ),
              ),
            ),
          ),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.only(right: 10, bottom: 2),
              child: Text(
                key: const Key('mainBrowseCreatePoolRequiresFullAccess'),
                l10n.mainBrowseCreatePoolRequiresFullAccess,
                textAlign: TextAlign.end,
                style: tokens.labelOnMedia.copyWith(
                  fontSize: 9,
                  height: 1.1,
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
    required this.highlightAsSelected,
    required this.onPick,
  });

  final SourceReference remembered;
  final bool highlightAsSelected;
  final ValueChanged<SourceReference> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final label = builtInDisplayLabel(l10n, remembered);
    final color =
        highlightAsSelected ? tokens.accent : tokens.onMediaMuted;
    // Cap 21.5 D7: when Origin is ephemeral, visual chrome is muted and
    // VoiceOver must not announce Built-in as selected for the remembered
    // tab — announce that browsing is the Temp Pool instead.
    final semanticsLabel = highlightAsSelected
        ? label
        : l10n.mainBrowseBuiltInWhileEphemeralSemantics(label);
    return Semantics(
      key: const Key('mainBrowseBuiltInMenuSemantics'),
      button: true,
      selected: highlightAsSelected,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: InkWell(
          key: const Key('mainBrowseBuiltInMenu'),
          onTap: () => _openBuiltInOverlay(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: tokens.labelOnMedia.copyWith(
                    color: color,
                    shadows: tokens.onMediaLabelShadows,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openBuiltInOverlay(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
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
      tokens: tokens,
    );
    if (choice != null) {
      onPick(choice);
    }
  }
}

class _SavedControl extends StatelessWidget {
  const _SavedControl();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return InkWell(
      key: const Key('mainBrowseSavedPoolsMenu'),
      onTap: () => _openSavedOverlay(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.mainBrowseSavedPoolsMenu,
              style: tokens.labelOnMedia.copyWith(
                color: tokens.onMediaMuted,
                shadows: tokens.onMediaLabelShadows,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: tokens.onMediaMuted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSavedOverlay(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final muted = tokens.onMediaMuted.withValues(alpha: 0.55);
    await _showChromeMenuOverlay<void>(
      context: context,
      menuKey: const Key('mainBrowseSavedOverlay'),
      barrierLabel: l10n.mainBrowseSavedPoolsMenu,
      items: [
        _ChromeMenuItem(
          key: const Key('mainBrowseSavedPlaceholderSave'),
          label: l10n.mainBrowseSavedPlaceholderSave,
          value: null,
          enabled: false,
          labelColor: muted,
        ),
        _ChromeMenuItem(
          key: const Key('mainBrowseSavedPlaceholderManage'),
          label: l10n.mainBrowseSavedPlaceholderManage,
          value: null,
          enabled: false,
          labelColor: muted,
        ),
        _ChromeMenuItem(
          key: const Key('mainBrowseSavedPlaceholderEmpty'),
          label: l10n.mainBrowseSavedPlaceholderEmpty,
          value: null,
          enabled: false,
          labelColor: muted,
        ),
      ],
      tokens: tokens,
    );
  }
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
  required WakeTokTokens tokens,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return SafeArea(
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
                            color: item.labelColor ??
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
}) {
  final overlay = Overlay.of(context);
  final completer = Completer<void>();
  late OverlayEntry entry;

  void dismiss() {
    if (completer.isCompleted) {
      return;
    }
    entry.remove();
    completer.complete();
  }

  final darkTheme = waketokTheme(Brightness.dark);
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
    this.frozenLabels,
  });

  final SourcePoolDefinition parked;
  final List<String>? frozenLabels;

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
        constraints: const BoxConstraints(maxWidth: 280, maxHeight: 320),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.mainBrowseCompositionPeekTitle,
                style: tokens.labelOnMedia.copyWith(color: tokens.onMedia),
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
            ],
          ),
        ),
      ),
    );
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
