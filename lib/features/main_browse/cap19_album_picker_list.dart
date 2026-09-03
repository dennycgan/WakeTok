import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/features/main_browse/cap19_add_to_album_controller.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/features/main_browse/cap19_album_cover_thumbnail.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap19_panel_host_context.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Full Access Add-to-Album picker (Cap 19.5).
class Cap19AlbumPickerList extends ConsumerStatefulWidget {
  const Cap19AlbumPickerList({super.key});

  @override
  ConsumerState<Cap19AlbumPickerList> createState() =>
      _Cap19AlbumPickerListState();
}

class _Cap19AlbumPickerListState extends ConsumerState<Cap19AlbumPickerList> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(cap19AlbumPickerProvider.notifier).loadAlbums(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final picker = ref.watch(cap19AlbumPickerProvider);
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.onMedia,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.cap19PanelAlbumsSectionTitle,
            key: const Key('cap19PanelAlbumsSectionTitle'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.onMediaMuted,
                ),
          ),
        ),
        switch (picker.phase) {
      Cap19AlbumPickerPhase.loading => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(
              key: Key('cap19AlbumPickerLoading'),
            ),
          ),
        ),
      Cap19AlbumPickerPhase.listError => Column(
          key: const Key('cap19AlbumPickerListError'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.cap19PanelAddToAlbumListError, style: bodyStyle),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: const Key('cap19AlbumPickerRetry'),
                onPressed: () =>
                    ref.read(cap19AlbumPickerProvider.notifier).loadAlbums(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.onMedia,
                  side: BorderSide(
                    color: tokens.onMedia.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(l10n.cap19PanelAddToAlbumRetry),
              ),
            ),
          ],
        ),
      Cap19AlbumPickerPhase.empty => Text(
          key: const Key('cap19AlbumPickerEmpty'),
          l10n.cap19PanelAddToAlbumEmpty,
          style: bodyStyle,
        ),
      Cap19AlbumPickerPhase.loaded => _AlbumList(
          albums: picker.albums,
          appendingAlbumId: picker.appendingAlbumId,
        ),
        },
      ],
    );
  }
}

class _AlbumList extends ConsumerWidget {
  const _AlbumList({
    required this.albums,
    required this.appendingAlbumId,
  });

  final List<AssetSource> albums;
  final String? appendingAlbumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.onMedia,
        );
    const coverSize = kCap19PanelRowThumbnailSize;

    return ListView.separated(
      key: const Key('cap19AlbumPickerList'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: albums.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: tokens.onMedia.withValues(alpha: 0.12),
        ),
        itemBuilder: (context, index) {
          final album = albums[index];
          final busy = appendingAlbumId == album.id;
          return ListTile(
            key: Key('cap19AlbumPickerRow-${album.id}'),
            contentPadding: EdgeInsets.zero,
            leading: Cap19AlbumCoverThumbnail(
              albumId: album.id,
              size: coverSize,
            ),
            title: Text(album.displayName, style: bodyStyle),
            trailing: busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            enabled: appendingAlbumId == null,
            onTap: appendingAlbumId == null
                ? () => _onAlbumTap(context, ref, album)
                : null,
          );
        },
      );
  }

  Future<void> _onAlbumTap(
    BuildContext context,
    WidgetRef ref,
    AssetSource album,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final hostContext = Cap19PanelHostContext.of(context);
    final outcome = await ref
        .read(cap19AlbumPickerProvider.notifier)
        .appendToAlbum(album.id);
    if (!context.mounted) {
      return;
    }
    switch (outcome) {
      case Cap19AlbumAppendOutcome.success:
        Navigator.of(context).pop();
        showCap19AddToAlbumSuccessToast(hostContext, l10n, album.displayName);
      case Cap19AlbumAppendOutcome.mediaNotReady:
        showCap19CurrentMediaNotReadyToast(hostContext, l10n);
      case Cap19AlbumAppendOutcome.failed:
        showCap19AddToAlbumErrorToast(hostContext, l10n);
    }
  }
}
