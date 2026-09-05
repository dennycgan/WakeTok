import 'package:flutter/material.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 21.3 Build a Pool scaffold (full multi-select / Start = Cap 21.4).
///
/// Title + back + one ARB body line. Does not mutate BrowseChromeState.
class BuildPoolScaffoldPage extends StatelessWidget {
  const BuildPoolScaffoldPage({super.key});

  static const Key pageKey = Key('mainBrowseBuildPoolScaffold');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return Scaffold(
      key: pageKey,
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          l10n.mainBrowseBuildPoolScaffoldBody,
          style: tokens.bodyOnMedia.copyWith(color: tokens.onMediaMuted),
        ),
      ),
    );
  }
}
