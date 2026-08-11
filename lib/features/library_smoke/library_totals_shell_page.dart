import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/library_totals.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/authorization/limited_access_banner.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/library_smoke/builtin_quantile.dart';
import 'package:waketok/features/library_smoke/library_catalog_providers.dart';
import 'package:waketok/features/library_smoke/playback_pipeline_probe.dart';
import 'package:waketok/features/library_smoke/shared_mute_provider.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Post-authorization landing shell (Cap 5.3 / 5.4 + Cap 6.4 smoke).
///
/// Totals rows plus built-in source resolve / All-only quantile / illegal-pair
/// probe. Not the product All/Photos/Videos top bar (Main Browse).
class LibraryTotalsShellPage extends ConsumerStatefulWidget {
  const LibraryTotalsShellPage({super.key, required this.access});

  final PhotosAccess access;

  @override
  ConsumerState<LibraryTotalsShellPage> createState() =>
      _LibraryTotalsShellPageState();
}

class _LibraryTotalsShellPageState
    extends ConsumerState<LibraryTotalsShellPage> {
  SourceReference _selected = SourceReference.all;
  bool _busy = false;
  int? _resolvedLength;
  String? _pairProbeMessage;
  List<_QuantileRowData>? _quantileRows;
  String? _yearSpanLabel;

  int? _totalsComponent(LibraryTotals? totals, AssetSourceKind kind) {
    if (totals == null) {
      return null;
    }
    return switch (kind) {
      AssetSourceKind.entireLibrary => totals.all,
      AssetSourceKind.mediaTypePhotos => totals.photos,
      AssetSourceKind.mediaTypeVideos => totals.videos,
      // Smoke UI only lists built-ins; album/smartAlbum have no totals row.
      AssetSourceKind.album || AssetSourceKind.smartAlbum => null,
    };
  }

  /// Cap 11.2 E1: list diagnostic for Limited notes (counts + smart names).
  List<Widget> _listDiagnostics(
    AppLocalizations l10n,
    WakeTokTokens tokens,
    List<AssetSource> sources,
  ) {
    var builtIn = 0;
    var userAlbum = 0;
    final smartNames = <String>[];
    for (final s in sources) {
      switch (s.kind) {
        case AssetSourceKind.entireLibrary:
        case AssetSourceKind.mediaTypePhotos:
        case AssetSourceKind.mediaTypeVideos:
          builtIn += 1;
        case AssetSourceKind.album:
          userAlbum += 1;
        case AssetSourceKind.smartAlbum:
          smartNames.add(
            s.displayName.isEmpty ? l10n.sourceListDiagnosticUntitled : s.displayName,
          );
      }
    }
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.onSurface,
        );
    final namesLabel = smartNames.isEmpty
        ? l10n.sourceListDiagnosticSmartNamesNone
        : l10n.sourceListDiagnosticSmartNames(smartNames.join(', '));
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Text(
          l10n.sourceListDiagnosticTitle,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: tokens.onSurface,
              ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Text(
          l10n.sourceListDiagnosticCounts(builtIn, userAlbum, smartNames.length),
          style: bodyStyle,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(namesLabel, style: bodyStyle),
      ),
    ];
  }

  Future<void> _resolveSelected() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _pairProbeMessage = null;
    });
    try {
      final resolved =
          await ref.read(assetSourceRepositoryProvider).resolve(_selected);
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedLength = resolved.assetIdentifiers.length;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedLength = null;
        _pairProbeMessage = l10n.sourceSmokeOperationFailed;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _runQuantile() async {
    if (_selected.kind != AssetSourceKind.entireLibrary) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _quantileRows = null;
      _yearSpanLabel = null;
      _pairProbeMessage = null;
    });
    try {
      final repo = ref.read(assetSourceRepositoryProvider);
      final catalog = ref.read(libraryCatalogRepositoryProvider);
      final resolved = await repo.resolve(SourceReference.all);
      final ids = resolved.assetIdentifiers;
      final indices = builtinAllQuantileIndices(ids.length);
      final rows = <_QuantileRowData>[];
      for (final q in indices) {
        final page = await catalog.fetchPage(cursor: '$q', pageSize: 1);
        final pageId = page.assets.isEmpty ? '' : page.assets.first.id;
        final asset = page.assets.isEmpty ? null : page.assets.first;
        rows.add(
          _QuantileRowData(
            q: q,
            id: ids[q],
            date: asset?.createdAt,
            aligned: pageId == ids[q],
            availability: asset?.availability.name ?? '—',
          ),
        );
      }
      final years = rows
          .map((r) => r.date)
          .whereType<DateTime>()
          .map((d) => d.toUtc().year)
          .toList()
        ..sort();
      final span = years.isEmpty
          ? '—'
          : years.length == 1
              ? '${years.first}'
              : '${years.first}–${years.last} (${years.last - years.first})';
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedLength = ids.length;
        _quantileRows = rows;
        _yearSpanLabel = l10n.sourceQuantileYearSpan(span);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _quantileRows = null;
        _yearSpanLabel = null;
        _pairProbeMessage = l10n.sourceSmokeOperationFailed;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _probeIllegalPair() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _pairProbeMessage = null;
    });
    const illegal = SourceReference(
      kind: AssetSourceKind.entireLibrary,
      id: 'photos',
    );
    try {
      await ref.read(assetSourceRepositoryProvider).resolve(illegal);
      if (!mounted) {
        return;
      }
      setState(() {
        _pairProbeMessage = l10n.sourcePairProbeUnexpected;
      });
    } on PlatformException catch (e) {
      if (!mounted) {
        return;
      }
      // Map by AppError member name — features must not import platform/.
      setState(() {
        _pairProbeMessage = e.code == AppError.assetUnavailable.name
            ? l10n.sourcePairMismatchError
            : l10n.sourcePairProbeUnexpected;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pairProbeMessage = l10n.sourcePairProbeUnexpected;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final asyncTotals = ref.watch(libraryTotalsProvider);
    final asyncSources = ref.watch(assetSourcesProvider);

    final LibraryTotals? totals = asyncTotals.asData?.value;
    final String allValue;
    final String photosValue;
    final String videosValue;
    if (totals == null) {
      allValue = l10n.countsPending;
      photosValue = l10n.countsPending;
      videosValue = l10n.countsPending;
    } else {
      allValue = '${totals.all}';
      photosValue = '${totals.photos}';
      videosValue = '${totals.videos}';
    }

    final sources = asyncSources.asData?.value;
    AssetSource? selectedSource;
    if (sources != null) {
      for (final s in sources) {
        if (s.kind == _selected.kind && s.id == _selected.id) {
          selectedSource = s;
          break;
        }
      }
    }

    final expected = _totalsComponent(totals, _selected.kind);
    final String matchLabel;
    if (_resolvedLength == null || expected == null) {
      matchLabel = l10n.sourceCountPending;
    } else if (_resolvedLength == expected) {
      matchLabel = l10n.sourceCountMatch;
    } else {
      matchLabel = l10n.sourceCountMismatch;
    }

    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.onSurface,
        );

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(title: Text(l10n.libraryShellTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.access == PhotosAccess.limited)
            const LimitedAccessBanner(),
          if (asyncTotals.hasError)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${asyncTotals.error}',
                style: bodyStyle,
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _TotalsRow(label: l10n.libraryRowAll, value: allValue),
                _TotalsRow(label: l10n.libraryRowPhotos, value: photosValue),
                _TotalsRow(label: l10n.libraryRowVideos, value: videosValue),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    l10n.sourceSmokeSectionTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: tokens.onSurface,
                        ),
                  ),
                ),
                if (sources != null) ..._listDiagnostics(l10n, tokens, sources),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<SourceReference>(
                    segments: [
                      ButtonSegment(
                        value: SourceReference.all,
                        label: Text(l10n.libraryRowAll),
                      ),
                      ButtonSegment(
                        value: SourceReference.photos,
                        label: Text(l10n.libraryRowPhotos),
                      ),
                      ButtonSegment(
                        value: SourceReference.videos,
                        label: Text(l10n.libraryRowVideos),
                      ),
                    ],
                    selected: {_selected},
                    onSelectionChanged: _busy
                        ? null
                        : (next) {
                            setState(() {
                              _selected = next.first;
                              _resolvedLength = null;
                              _quantileRows = null;
                              _yearSpanLabel = null;
                              _pairProbeMessage = null;
                            });
                          },
                  ),
                ),
                if (selectedSource != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      selectedSource.estimatedCount == null
                          ? l10n.sourceEstimatedCountUnknown
                          : l10n.sourceEstimatedCount(
                              selectedSource.estimatedCount!,
                            ),
                      style: bodyStyle,
                    ),
                  ),
                if (_resolvedLength != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      l10n.sourceResolvedLength(_resolvedLength!),
                      style: bodyStyle,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(matchLabel, style: bodyStyle),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: FilledButton(
                    onPressed: _busy ? null : _resolveSelected,
                    child: Text(
                      _busy ? l10n.sourceBusy : l10n.sourceResolveButton,
                    ),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    l10n.sourceQuantileSectionTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: tokens.onSurface,
                        ),
                  ),
                ),
                if (_selected.kind != AssetSourceKind.entireLibrary)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l10n.sourceQuantileOnlyAllHint,
                      style: bodyStyle,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: FilledButton(
                    onPressed: _busy ||
                            _selected.kind != AssetSourceKind.entireLibrary
                        ? null
                        : _runQuantile,
                    child: Text(l10n.sourceQuantileRunButton),
                  ),
                ),
                if (_yearSpanLabel != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(_yearSpanLabel!, style: bodyStyle),
                  ),
                if (_quantileRows != null)
                  ..._quantileRows!.map((row) {
                    final dateLabel = row.date == null
                        ? l10n.sourceQuantileDateUnknown
                        : row.date!.toUtc().toIso8601String();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        l10n.sourceQuantileRow(
                          row.q,
                          row.id,
                          dateLabel,
                          row.aligned
                              ? l10n.sourceQuantileAlignOk
                              : l10n.sourceQuantileAlignFail,
                          row.availability,
                        ),
                        style: bodyStyle,
                      ),
                    );
                  }),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    l10n.sourceNegativeSectionTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: tokens.onSurface,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: FilledButton(
                    onPressed: _busy ? null : _probeIllegalPair,
                    child: Text(l10n.sourceProbeIllegalPairButton),
                  ),
                ),
                if (_pairProbeMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      _pairProbeMessage!,
                      key: const Key('sourcePairProbeMessage'),
                      style: bodyStyle,
                    ),
                  ),
                const _SharedMuteDebugSection(),
                const PlaybackPipelineProbeSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cap 9.6 G2=B: toggles [sharedMuteProvider] only — Feed applies Live setMute
/// via LiveHostOpSerial; does not call LivePhotoApi from smoke.
class _SharedMuteDebugSection extends ConsumerWidget {
  const _SharedMuteDebugSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final muted = ref.watch(sharedMuteProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            l10n.sharedMuteDebugSectionTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: tokens.onSurface,
                ),
          ),
        ),
        SwitchListTile(
          key: const Key('sharedMuteDebugSwitch'),
          title: Text(
            l10n.sharedMuteDebugSwitchLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.onSurface,
                ),
          ),
          value: muted,
          onChanged: (value) {
            ref.read(sharedMuteProvider.notifier).setMuted(value);
          },
        ),
      ],
    );
  }
}

class _QuantileRowData {
  const _QuantileRowData({
    required this.q,
    required this.id,
    required this.date,
    required this.aligned,
    required this.availability,
  });

  final int q;
  final String id;
  final DateTime? date;
  final bool aligned;
  final String availability;
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return ListTile(
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: tokens.onSurface,
            ),
      ),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: tokens.onSurface,
            ),
      ),
    );
  }
}
