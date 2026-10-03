import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/open_privacy_policy.dart';
import 'package:waketok/features/main_browse/settings_layout.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 32 — About section: one external Privacy Policy link row.
class AboutSettingsSection extends ConsumerWidget {
  const AboutSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      key: const Key('aboutSettingsSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeader(title: l10n.settingsAboutSectionTitle),
        const SizedBox(height: kSettingsSectionTitleToRowGap),
        _SettingsExternalLinkRow(
          key: const Key('aboutPrivacyPolicyRow'),
          title: l10n.settingsPrivacyPolicyRow,
          onTap: () => unawaited(ref.read(openPrivacyPolicyProvider)()),
        ),
      ],
    );
  }
}

/// Title → external-link glyph gap: twice the info `i` gap, which reads too
/// tight beside this glyph (settings-layout-notes §3). Promote to a shared
/// Settings constant when a second link row appears.
const double _kSettingsTitleLinkGap = kSettingsTitleInfoGap * 2;

/// Title with the external-link glyph inline after its last glyph (same
/// hug rule as the info `i`, settings-layout-notes §3); the whole row is
/// one link node.
class _SettingsExternalLinkRow extends StatelessWidget {
  const _SettingsExternalLinkRow({
    super.key,
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return Semantics(
      link: true,
      label: title,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kSettingsInfoHit),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text.rich(
              TextSpan(
                style: settingsRowTitleStyle(tokens),
                children: [
                  TextSpan(text: title),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: _kSettingsTitleLinkGap,
                      ),
                      child: Icon(
                        Icons.open_in_new,
                        key: const Key('aboutPrivacyPolicyExternalIcon'),
                        size: kSettingsInfoIconSize,
                        color: tokens.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
