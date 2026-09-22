import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/browse_meta_overlay_shown.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 28.6 — Browse display: process-only meta three-row hide.
class BrowseDisplaySettingsSection extends ConsumerWidget {
  const BrowseDisplaySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: tokens.onSurface,
          fontWeight: FontWeight.w600,
        );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.onSurface,
        );
    final mutedStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: tokens.onSurface.withValues(alpha: 0.65),
        );

    final shown = ref.watch(browseMetaOverlayShownProvider);

    return Column(
      key: const Key('browseDisplaySettingsSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.browseDisplaySettingsSectionTitle, style: titleStyle),
        const SizedBox(height: 8),
        Row(
          key: const Key('browseDisplayShowMetaOverlayToggle'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.browseDisplayMetaOverlayTitle,
                    style: bodyStyle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.browseDisplayMetaOverlaySubtitle,
                    style: mutedStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CupertinoSwitch(
              value: shown,
              onChanged: (value) {
                ref
                    .read(browseMetaOverlayShownProvider.notifier)
                    .setShown(value);
              },
            ),
          ],
        ),
      ],
    );
  }
}
