import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/pool_capacity.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/cap19_album_cover_thumbnail.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 21.4 Build a Pool screen (keeps Cap 21.3 class/route key — D5=A).
///
/// Multi-select catalog + ordered selected list + Start. Cancel / system
/// back does not mutate [browseChromeStateProvider] (ADR-044 D6.1 cancel).
class BuildPoolScaffoldPage extends ConsumerStatefulWidget {
  const BuildPoolScaffoldPage({super.key});

  static const Key pageKey = Key('mainBrowseBuildPoolScaffold');
  static const Key startKey = Key('mainBrowseBuildPoolStart');
  static const Key catalogKey = Key('mainBrowseBuildPoolCatalog');
  static const Key selectedListKey = Key('mainBrowseBuildPoolSelected');
  static const Key catalogLoadingKey = Key('mainBrowseBuildPoolCatalogLoading');
  static const Key catalogFailedKey = Key('mainBrowseBuildPoolCatalogFailed');
  static const Key catalogEmptyKey = Key('mainBrowseBuildPoolCatalogEmpty');

  @override
  ConsumerState<BuildPoolScaffoldPage> createState() =>
      _BuildPoolScaffoldPageState();
}

class _BuildPoolScaffoldPageState extends ConsumerState<BuildPoolScaffoldPage> {
  final List<SourceReference> _selected = <SourceReference>[];

  bool _contains(SourceReference ref) {
    for (final item in _selected) {
      if (item == ref) {
        return true;
      }
    }
    return false;
  }

  void _toggle(SourceReference ref) {
    setState(() {
      if (_contains(ref)) {
        _selected.removeWhere((item) => item == ref);
        return;
      }
      if (_selected.length >= PoolCapacity.maxSourcesPerPool) {
        return;
      }
      _selected.add(ref);
    });
  }

  void _removeAt(int index) {
    setState(() {
      _selected.removeAt(index);
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _selected.removeAt(oldIndex);
      _selected.insert(newIndex, item);
    });
  }

  void _start() {
    if (_selected.isEmpty) {
      return;
    }
    final definition = SourcePoolDefinition(
      id: 'ephemeral-${DateTime.now().microsecondsSinceEpoch}',
      persistencePolicy: PersistencePolicy.ephemeral,
      orderedSourceReferences: List<SourceReference>.from(_selected),
    );
    ref.read(browseChromeStateProvider.notifier).startEphemeralPool(definition);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final asyncSources = ref.watch(assetSourcesProvider);
    final canStart = _selected.isNotEmpty;
    final atCap = _selected.length >= PoolCapacity.maxSourcesPerPool;

    return Scaffold(
      key: BuildPoolScaffoldPage.pageKey,
      backgroundColor: tokens.background,
      appBar: AppBar(
        backgroundColor: tokens.background,
        foregroundColor: tokens.onMedia,
        elevation: 0,
        title: Text(
          l10n.mainBrowseBuildPoolScaffoldTitle,
          style: tokens.labelOnMedia.copyWith(color: tokens.onMedia),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: asyncSources.when(
              data: (sources) => _CatalogPane(
                sources: sources,
                selected: _selected,
                atCap: atCap,
                onToggle: _toggle,
                tokens: tokens,
                l10n: l10n,
              ),
              loading: () => Center(
                key: BuildPoolScaffoldPage.catalogLoadingKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: tokens.accent),
                    const SizedBox(height: 12),
                    Text(
                      l10n.mainBrowseBuildPoolCatalogLoading,
                      style: tokens.bodyOnMedia.copyWith(
                        color: tokens.onMediaMuted,
                      ),
                    ),
                  ],
                ),
              ),
              error: (_, _) => Center(
                key: BuildPoolScaffoldPage.catalogFailedKey,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.mainBrowseBuildPoolCatalogFailed,
                    textAlign: TextAlign.center,
                    style: tokens.bodyOnMedia.copyWith(
                      color: tokens.onMediaMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: tokens.onMediaMuted.withValues(alpha: 0.3)),
          Expanded(
            flex: 2,
            child: _SelectedPane(
              selected: _selected,
              sources: asyncSources.asData?.value ?? const [],
              onReorder: _reorder,
              onRemove: _removeAt,
              tokens: tokens,
              l10n: l10n,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: BuildPoolScaffoldPage.startKey,
                  onPressed: canStart ? _start : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: tokens.onMedia,
                    disabledBackgroundColor:
                        tokens.onMediaMuted.withValues(alpha: 0.25),
                  ),
                  child: Text(l10n.mainBrowseBuildPoolStart),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogPane extends StatelessWidget {
  const _CatalogPane({
    required this.sources,
    required this.selected,
    required this.atCap,
    required this.onToggle,
    required this.tokens,
    required this.l10n,
  });

  final List<AssetSource> sources;
  final List<SourceReference> selected;
  final bool atCap;
  final ValueChanged<SourceReference> onToggle;
  final WakeTokTokens tokens;
  final AppLocalizations l10n;

  bool _isSelected(SourceReference ref) {
    for (final item in selected) {
      if (item == ref) {
        return true;
      }
    }
    return false;
  }

  /// User albums only. All / Photos / Videos stay top-tab controls, and smart
  /// albums wait for curation + non-empty counts (Cap 21.4 device round).
  @override
  Widget build(BuildContext context) {
    final albums = <AssetSource>[
      for (final source in sources)
        if (source.kind == AssetSourceKind.album) source,
    ];

    if (albums.isEmpty) {
      return Center(
        key: BuildPoolScaffoldPage.catalogEmptyKey,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.mainBrowseBuildPoolCatalogEmpty,
            textAlign: TextAlign.center,
            style: tokens.bodyOnMedia.copyWith(color: tokens.onMediaMuted),
          ),
        ),
      );
    }

    return ListView(
      key: BuildPoolScaffoldPage.catalogKey,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      children: [
        _sectionHeader(l10n.mainBrowseBuildPoolSectionAlbums),
        for (final source in albums) _catalogTile(source),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Text(
        title,
        style: tokens.labelOnMedia.copyWith(color: tokens.onMediaMuted),
      ),
    );
  }

  /// Cover + title row (Cap 19.5 Add-to-Album shape), check mark trailing.
  Widget _catalogTile(AssetSource source) {
    final reference = SourceReference.fromAssetSource(source);
    final checked = _isSelected(reference);
    final enabled = checked || !atCap;
    final label = source.displayName.isEmpty ? reference.id : source.displayName;
    return ListTile(
      key: Key(
        'mainBrowseBuildPoolCatalog_${reference.kind.name}_${reference.id}',
      ),
      onTap: enabled ? () => onToggle(reference) : null,
      leading: Cap19AlbumCoverThumbnail(
        albumId: reference.id,
        size: kCap19PanelRowThumbnailSize,
      ),
      title: Text(
        label,
        style: tokens.bodyOnMedia.copyWith(
          color: enabled ? tokens.onMedia : tokens.onMediaMuted,
        ),
      ),
      trailing: checked
          ? Icon(Icons.check, color: tokens.accent)
          : const SizedBox(width: 24),
    );
  }
}

class _SelectedPane extends StatelessWidget {
  const _SelectedPane({
    required this.selected,
    required this.sources,
    required this.onReorder,
    required this.onRemove,
    required this.tokens,
    required this.l10n,
  });

  final List<SourceReference> selected;
  final List<AssetSource> sources;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onRemove;
  final WakeTokTokens tokens;
  final AppLocalizations l10n;

  String _label(SourceReference reference) {
    for (final source in sources) {
      if (source.kind == reference.kind && source.id == reference.id) {
        return source.displayName.isEmpty
            ? reference.id
            : source.displayName;
      }
    }
    return reference.id;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(
            l10n.mainBrowseBuildPoolSelectedHeading(selected.length),
            style: tokens.labelOnMedia.copyWith(color: tokens.onMedia),
          ),
        ),
        Expanded(
          child: selected.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.mainBrowseBuildPoolEmptySelected,
                    style: tokens.bodyOnMedia.copyWith(
                      color: tokens.onMediaMuted,
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  key: BuildPoolScaffoldPage.selectedListKey,
                  buildDefaultDragHandles: true,
                  itemCount: selected.length,
                  onReorder: onReorder,
                  itemBuilder: (context, index) {
                    final reference = selected[index];
                    final label = _label(reference);
                    return ListTile(
                      key: Key(
                        'mainBrowseBuildPoolSelected_${reference.kind.name}_${reference.id}_$index',
                      ),
                      title: Text(
                        label,
                        style: tokens.bodyOnMedia.copyWith(
                          color: tokens.onMedia,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: tokens.onMediaMuted,
                        ),
                        onPressed: () => onRemove(index),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
