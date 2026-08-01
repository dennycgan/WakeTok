import 'package:flutter/material.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/limited_access_banner.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Post-authorization landing shell (Cap 5.3).
///
/// Per-type totals use [countsPending] until 5.4 wires enumeration (T-A).
/// Not the vertical media feed (next capability).
class LibraryTotalsShellPage extends StatelessWidget {
  const LibraryTotalsShellPage({super.key, required this.access});

  final PhotosAccess access;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(title: Text(l10n.libraryShellTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (access == PhotosAccess.limited) const LimitedAccessBanner(),
          Expanded(
            child: ListView(
              children: [
                _TotalsRow(label: l10n.libraryRowAll, value: l10n.countsPending),
                _TotalsRow(
                  label: l10n.libraryRowPhotos,
                  value: l10n.countsPending,
                ),
                _TotalsRow(
                  label: l10n.libraryRowVideos,
                  value: l10n.countsPending,
                ),
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
