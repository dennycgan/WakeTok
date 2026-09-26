import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/features/main_browse/browse_meta_overlay_shown.dart';
import 'package:waketok/features/main_browse/settings_layout.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 28.6 — Browse display: process-only meta three-row hide.
/// Cap 31.1 — explanatory subtitle in info bubble (list = title+i).
class BrowseDisplaySettingsSection extends ConsumerWidget {
  const BrowseDisplaySettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shown = ref.watch(browseMetaOverlayShownProvider);

    return Column(
      key: const Key('browseDisplaySettingsSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeader(title: l10n.browseDisplaySettingsSectionTitle),
        const SizedBox(height: kSettingsSectionTitleToRowGap),
        SettingsToggleRow(
          key: const Key('browseDisplayShowMetaOverlayToggle'),
          title: l10n.browseDisplayMetaOverlayTitle,
          value: shown,
          onChanged: (value) {
            ref.read(browseMetaOverlayShownProvider.notifier).setShown(value);
          },
          infoMessage: l10n.browseDisplayMetaOverlaySubtitle,
          infoSemanticsLabel: l10n.settingsInfoBubbleSemantics,
          infoButtonKey: const Key('browseDisplayMetaOverlayInfo'),
          infoBubbleKey: const Key('browseDisplayMetaOverlayInfoBubble'),
          infoBarrierKey: const Key('browseDisplayMetaOverlayInfoBarrier'),
        ),
      ],
    );
  }
}
