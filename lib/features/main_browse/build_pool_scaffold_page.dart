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
import 'package:waketok/features/main_browse/build_pool_smart_catalog.dart';
import 'package:waketok/features/main_browse/cap19_album_cover_thumbnail.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/composition_source_labels.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/saved_pool_dialogs.dart';
import 'package:waketok/features/main_browse/smart_album_labels.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 21.4 Build a Pool screen (keeps Cap 21.3 class/route key — D5=A).
///
/// Multi-select catalog + ordered selected list. ADR-047: **Save & browse**
/// persists then `startSavedPool` + pop; **Browse without saving** always
/// starts ephemeral + pop. Cancel / system back does not mutate
/// [browseChromeStateProvider] (ADR-044 D6.1 cancel).
class BuildPoolScaffoldPage extends ConsumerStatefulWidget {
  const BuildPoolScaffoldPage({super.key});

  static const Key pageKey = Key('mainBrowseBuildPoolScaffold');
  static const Key startKey = Key('mainBrowseBuildPoolStart');
  static const Key saveKey = Key('mainBrowseBuildPoolSave');
  static const Key catalogKey = Key('mainBrowseBuildPoolCatalog');
  static const Key selectedListKey = Key('mainBrowseBuildPoolSelected');
  static const Key catalogLoadingKey = Key('mainBrowseBuildPoolCatalogLoading');
  static const Key catalogFailedKey = Key('mainBrowseBuildPoolCatalogFailed');
  static const Key catalogEmptyKey = Key('mainBrowseBuildPoolCatalogEmpty');
  static const Key smartLoadingKey = Key(
    'mainBrowseBuildPoolSmartCatalogLoading',
  );
  static const Key smartFailedKey = Key(
    'mainBrowseBuildPoolSmartCatalogFailed',
  );
  static const Key smartSectionKey = Key('mainBrowseBuildPoolSmartSection');

  @override
  ConsumerState<BuildPoolScaffoldPage> createState() =>
      _BuildPoolScaffoldPageState();
}

class _BuildPoolScaffoldPageState extends ConsumerState<BuildPoolScaffoldPage> {
  final List<SourceReference> _selected = <SourceReference>[];

  @override
  void initState() {
    super.initState();
    // Cap 21.5 P4: always re-list when Build mounts (tests / deep links).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.invalidate(assetSourcesProvider);
      ref.invalidate(buildPoolSmartCatalogProvider);
    });
  }

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

  List<String> _compositionLabels() {
    final l10n = AppLocalizations.of(context)!;
    final sources = ref.read(assetSourcesProvider).asData?.value ?? const [];
    final smart =
        ref.read(buildPoolSmartCatalogProvider).asData?.value ?? const [];
    final catalog = <AssetSource>[...sources, ...smart];
    return [
      for (final reference in _selected)
        compositionDisplayLabel(l10n, reference, catalog),
    ];
  }

  Future<void> _saveAndBrowse() async {
    if (_selected.isEmpty) {
      return;
    }
    final repo = ref.read(savedPoolRepositoryProvider);
    final existing = await repo.loadAll();
    if (!mounted) {
      return;
    }
    if (existing.length >= PoolCapacity.maxSavedPoolPresets) {
      await showSavedPoolCapacityDialog(context);
      return;
    }
    final outcome = await showSavedPoolNamingDialog(
      context: context,
      repository: repo,
      orderedSourceReferences: List<SourceReference>.from(_selected),
    );
    if (!mounted) {
      return;
    }
    switch (outcome) {
      case SavedPoolNamingCancelled():
        return;
      case SavedPoolNamingAtCapacity():
        await showSavedPoolCapacityDialog(context);
        return;
      case SavedPoolNamingSaved(:final record):
        // ADR-047 / D3: persist then start Saved Session (same family as D4).
        ref.read(browseChromeStateProvider.notifier).startSavedPool(record);
        Navigator.of(context).pop();
    }
  }

  Future<void> _browseWithoutSaving() async {
    if (_selected.isEmpty) {
      return;
    }
    final labels = _compositionLabels();
    final definition = SourcePoolDefinition(
      id: 'ephemeral-${DateTime.now().microsecondsSinceEpoch}',
      persistencePolicy: PersistencePolicy.ephemeral,
      orderedSourceReferences: List<SourceReference>.from(_selected),
    );
    ref
        .read(browseChromeStateProvider.notifier)
        .startEphemeralPool(definition, compositionLabels: labels);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Cap 21.4b polish: Build is Browse chrome — force dark tokens (same
    // pattern as Cap 19 half-sheet / Main Browse immersive). System Light
    // must not reach onMedia labels (white-on-white).
    final darkTheme = waketokTheme(Brightness.dark);
    return Theme(
      data: darkTheme,
      child: Builder(builder: _buildImmersive),
    );
  }

  Widget _buildImmersive(BuildContext context) {
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
          // Match bottom Filled/Outlined button label (Theme labelLarge /
          // labelChrome) — not the smaller on-media badge role.
          style: tokens.labelChrome.copyWith(color: tokens.onMedia),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            // Cap 21.4b polish: catalog ~9, selected ~4 (selected ≈ 2/3 of
            // prior 3:2 selected pane).
            flex: 9,
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
            flex: 4,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    key: BuildPoolScaffoldPage.saveKey,
                    onPressed: canStart ? _saveAndBrowse : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.accent,
                      foregroundColor: tokens.onAccent,
                      disabledBackgroundColor: tokens.onMediaMuted.withValues(
                        alpha: 0.25,
                      ),
                    ),
                    child: Text(l10n.mainBrowseBuildPoolSaveAndBrowse),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: BuildPoolScaffoldPage.startKey,
                    onPressed: canStart ? _browseWithoutSaving : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.onMedia,
                      side: BorderSide(
                        color: canStart
                            ? tokens.accent
                            : tokens.onMediaMuted.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(l10n.mainBrowseBuildPoolBrowseWithoutSaving),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogPane extends ConsumerWidget {
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

  /// User albums render immediately; smart section loads independently.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = <AssetSource>[
      for (final source in sources)
        if (source.kind == AssetSourceKind.album) source,
    ];
    final smartAsync = ref.watch(buildPoolSmartCatalogProvider);
    final albumsEmpty = albums.isEmpty;
    final smartSettledEmpty = smartAsync.asData?.value.isEmpty ?? false;
    final smartStillLoading = smartAsync.isLoading;
    if (albumsEmpty && smartSettledEmpty && !smartStillLoading) {
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
        if (albums.isNotEmpty) ...[
          _sectionHeader(l10n.mainBrowseBuildPoolSectionAlbums),
          for (final source in albums) _catalogTile(source),
          Divider(
            key: const Key('mainBrowseBuildPoolSectionSmartDivider'),
            height: 24,
            thickness: 1,
            color: tokens.onMediaMuted.withValues(alpha: 0.3),
          ),
        ],
        _sectionHeader(l10n.mainBrowseBuildPoolSectionSmartAlbums),
        ...smartAsync.when(
          data: (smart) {
            if (smart.isEmpty) {
              return const <Widget>[];
            }
            return <Widget>[for (final source in smart) _catalogTile(source)];
          },
          loading: () => <Widget>[
            Padding(
              key: BuildPoolScaffoldPage.smartLoadingKey,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.mainBrowseBuildPoolSmartCatalogLoading,
                      style: tokens.bodyOnMedia.copyWith(
                        color: tokens.onMediaMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          error: (_, _) => <Widget>[
            Padding(
              key: BuildPoolScaffoldPage.smartFailedKey,
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.mainBrowseBuildPoolSmartCatalogFailed,
                textAlign: TextAlign.center,
                style: tokens.bodyOnMedia.copyWith(color: tokens.onMediaMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Text(
        title,
        // Same type role as AppBar "Build a Pool" (labelChrome).
        style: tokens.labelChrome.copyWith(color: tokens.onMedia),
      ),
    );
  }

  String _label(AssetSource source) {
    final subtype = source.collectionSubtype;
    if (source.kind == AssetSourceKind.smartAlbum && subtype != null) {
      return smartAlbumDisplayLabel(l10n, subtype);
    }
    return source.displayName.isEmpty ? source.id : source.displayName;
  }

  /// Cover + title row (Cap 19.5 Add-to-Album shape), check mark trailing.
  Widget _catalogTile(AssetSource source) {
    final reference = SourceReference.fromAssetSource(source);
    final checked = _isSelected(reference);
    final enabled = checked || !atCap;
    final label = _label(source);
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
        final subtype = source.collectionSubtype;
        if (source.kind == AssetSourceKind.smartAlbum && subtype != null) {
          return smartAlbumDisplayLabel(l10n, subtype);
        }
        return source.displayName.isEmpty ? reference.id : source.displayName;
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
                    // Compact rows so ~5 selected sources fit between the
                    // heading and Save & browse (default ListTile ≈ 3).
                    return ListTile(
                      key: Key(
                        'mainBrowseBuildPoolSelected_${reference.kind.name}_${reference.id}_$index',
                      ),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      minVerticalPadding: 0,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
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
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(36, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
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
