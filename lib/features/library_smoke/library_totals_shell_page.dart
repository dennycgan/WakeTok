import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/library_totals.dart';
import 'package:waketok/features/authorization/limited_access_banner.dart';
import 'package:waketok/features/library_smoke/library_catalog_providers.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Post-authorization landing shell (Cap 5.3 / 5.4).
///
/// Shows per-type totals from [libraryTotalsProvider]. Loading keeps
/// [countsPending]; empty library may show real zeros.
class LibraryTotalsShellPage extends ConsumerWidget {
  const LibraryTotalsShellPage({super.key, required this.access});

  final PhotosAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final asyncTotals = ref.watch(libraryTotalsProvider);

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

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(title: Text(l10n.libraryShellTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (access == PhotosAccess.limited) const LimitedAccessBanner(),
          if (asyncTotals.hasError)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${asyncTotals.error}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.onSurface,
                    ),
              ),
            ),
          Expanded(
            child: ListView(
              children: [
                _TotalsRow(label: l10n.libraryRowAll, value: allValue),
                _TotalsRow(label: l10n.libraryRowPhotos, value: photosValue),
                _TotalsRow(label: l10n.libraryRowVideos, value: videosValue),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
