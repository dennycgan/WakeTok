import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/build_pool_scaffold_page.dart';
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

    return Material(
      key: const Key('mainBrowseTopSourceChrome'),
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
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
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BuildPoolScaffoldPage(),
                      ),
                    );
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
      );
      return;
    }
    ref.read(browseChromeStateProvider.notifier).resumeParkedEphemeral();
  }
}

String builtInDisplayLabel(AppLocalizations l10n, SourceReference source) {
  if (source == SourceReference.all) {
    return l10n.libraryRowAll;
  }
  if (source == SourceReference.photos) {
    return l10n.libraryRowPhotos;
  }
  if (source == SourceReference.videos) {
    return l10n.libraryRowVideos;
  }
  return source.id;
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
  const _CreateControl({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return InkWell(
      key: const Key('mainBrowseCreatePool'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          l10n.mainBrowseCreatePool,
          style: tokens.labelOnMedia.copyWith(
            color: tokens.onMediaMuted,
            shadows: tokens.onMediaLabelShadows,
          ),
        ),
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
    return InkWell(
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

/// Lightweight composition peek anchored under the temp chip (D2: lighter
/// than Built-in/Saved overlay). Uses [assetSourcesProvider] for names.
Future<void> showCompositionPeekPopover({
  required BuildContext context,
  required SourcePoolDefinition parked,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: AppLocalizations.of(context)!.mainBrowseCompositionPeekTitle,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return SafeArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 56, 48, 0),
            child: _CompositionPeekCard(parked: parked),
          ),
        ),
      );
    },
  );
}

class _CompositionPeekCard extends ConsumerWidget {
  const _CompositionPeekCard({required this.parked});

  final SourcePoolDefinition parked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final asyncSources = ref.watch(assetSourcesProvider);

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
                      for (final ref in parked.orderedSourceReferences)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            _peekLineLabel(l10n, ref, sources),
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
                    l10n.mainBrowseCompositionPeekUnavailable,
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

  String _peekLineLabel(
    AppLocalizations l10n,
    SourceReference reference,
    List<AssetSource> sources,
  ) {
    final builtIn = builtInDisplayLabel(l10n, reference);
    if (reference == SourceReference.all ||
        reference == SourceReference.photos ||
        reference == SourceReference.videos) {
      return builtIn;
    }
    AssetSource? match;
    for (final source in sources) {
      if (source.kind == reference.kind && source.id == reference.id) {
        match = source;
        break;
      }
    }
    if (match == null) {
      return '$builtIn (${l10n.mainBrowseCompositionPeekUnavailable})';
    }
    final name =
        match.displayName.isEmpty ? builtIn : match.displayName;
    final unavailable =
        match.availability != AssetSourceAvailability.available &&
            match.availability != AssetSourceAvailability.empty;
    if (unavailable || match.availability == AssetSourceAvailability.empty) {
      return '$name (${l10n.mainBrowseCompositionPeekUnavailable})';
    }
    return name;
  }
}
