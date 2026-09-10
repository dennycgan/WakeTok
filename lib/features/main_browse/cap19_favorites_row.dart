import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/features/main_browse/cap19_favorites_album_thumbnail.dart';
import 'package:waketok/features/main_browse/cap19_favorites_controller.dart';
import 'package:waketok/features/main_browse/cap19_favorites_platform_icon.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap19_panel_host_context.dart';
import 'package:waketok/features/main_browse/still_in_library_gate.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 19.5b — synthetic Quick action row (Full Access only).
class Cap19FavoritesRow extends ConsumerStatefulWidget {
  const Cap19FavoritesRow({super.key});

  @override
  ConsumerState<Cap19FavoritesRow> createState() => _Cap19FavoritesRowState();
}

class _Cap19FavoritesRowState extends ConsumerState<Cap19FavoritesRow> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(cap19FavoritesProvider.notifier).loadStatus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final sectionStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: tokens.onMediaMuted,
        );
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.onMedia,
        );
    final favorites = ref.watch(cap19FavoritesProvider);

    return Column(
      key: const Key('cap19FavoritesSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
          child: Text(
            l10n.cap19PanelFavoritesSectionTitle,
            key: const Key('cap19PanelFavoritesSectionTitle'),
            style: sectionStyle,
          ),
        ),
        switch (favorites.phase) {
          Cap19FavoritesPhase.loading => SizedBox(
              height: kCap19PanelRowThumbnailSize,
              child: const Center(
                child: SizedBox(
                  key: Key('cap19FavoritesLoading'),
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          Cap19FavoritesPhase.mediaNotReady => Text(
              l10n.cap19CurrentMediaNotReady,
              key: const Key('cap19FavoritesMediaNotReady'),
              style: titleStyle,
            ),
          Cap19FavoritesPhase.loadError => Text(
              l10n.cap19PanelFavoritesError,
              key: const Key('cap19FavoritesLoadError'),
              style: titleStyle,
            ),
          Cap19FavoritesPhase.loaded ||
          Cap19FavoritesPhase.toggling =>
            _FavoritesToggleRow(
              isFavorite: favorites.isFavorite,
              busy: favorites.phase == Cap19FavoritesPhase.toggling,
            ),
        },
      ],
    );
  }
}

class _FavoritesToggleRow extends ConsumerWidget {
  const _FavoritesToggleRow({
    required this.isFavorite,
    required this.busy,
  });

  final bool isFavorite;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.onMedia,
        );
    final label = isFavorite
        ? l10n.cap19PanelRemoveFromFavorites
        : l10n.cap19PanelAddToFavorites;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('cap19FavoritesRow'),
        onTap: busy ? null : () => _onTap(context, ref),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: kCap19PanelRowThumbnailSize),
          child: Row(
            children: [
              Cap19FavoritesAlbumThumbnail(size: kCap19PanelRowThumbnailSize),
              const SizedBox(width: 12),
              if (busy)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Cap19FavoritesPlatformIcon(
                  isFavorite: isFavorite,
                  color: tokens.onMedia,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  key: Key(
                    isFavorite
                        ? 'cap19FavoritesRemoveLabel'
                        : 'cap19FavoritesAddLabel',
                  ),
                  style: titleStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final hostContext = Cap19PanelHostContext.of(context);
    final allowed = await ensureCurrentAssetStillInLibraryForMutation(
      ref: ref,
      context: context,
    );
    if (!context.mounted || !allowed) {
      return;
    }
    final wasFavorite = isFavorite;
    final success =
        await ref.read(cap19FavoritesProvider.notifier).toggleFavorite();
    if (!context.mounted) {
      return;
    }
    if (success) {
      if (wasFavorite) {
        showCap19FavoritesRemovedToast(hostContext, l10n);
      } else {
        showCap19FavoritesAddedToast(hostContext, l10n);
      }
      return;
    }
    showCap19FavoritesErrorToast(hostContext, l10n);
  }
}
