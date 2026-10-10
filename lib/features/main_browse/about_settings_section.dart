import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/open_privacy_policy.dart';
import 'package:waketok/features/main_browse/settings_layout.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 32 — About section: the external Privacy Policy link row; Cap 35.1
/// adds the in-app Third-party licences row.
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
        _SettingsInlineGlyphRow(
          key: const Key('aboutPrivacyPolicyRow'),
          title: l10n.settingsPrivacyPolicyRow,
          glyph: Icons.open_in_new,
          glyphKey: const Key('aboutPrivacyPolicyExternalIcon'),
          glyphGap: _kSettingsTitleLinkGap,
          isExternalLink: true,
          onTap: () => unawaited(ref.read(openPrivacyPolicyProvider)()),
        ),
        _SettingsInlineGlyphRow(
          key: const Key('aboutThirdPartyLicensesRow'),
          title: l10n.settingsThirdPartyLicensesRow,
          glyph: Icons.arrow_forward_ios,
          glyphKey: const Key('aboutThirdPartyLicensesChevronIcon'),
          glyphGap: kSettingsTitleInfoGap,
          isExternalLink: false,
          onTap: () => _openThirdPartyLicences(context, l10n.appTitle),
        ),
      ],
    );
  }
}

/// Title → external-link glyph gap: twice the info `i` gap, which reads too
/// tight beside this glyph (settings-layout-notes §3). Promote to a shared
/// Settings constant when a second link row appears.
const double _kSettingsTitleLinkGap = kSettingsTitleInfoGap * 2;

void _openThirdPartyLicences(BuildContext context, String appTitle) {
  unawaited(
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          final page = LicensePage(applicationName: appTitle);
          if (Localizations.localeOf(context).languageCode != 'en') {
            return page;
          }
          // English copy is British; Material's en_GB strings spell
          // "Licences". Scoped to this route — the app locale stays `en`.
          return Localizations.override(
            context: context,
            locale: const Locale('en', 'GB'),
            child: page,
          );
        },
      ),
    ),
  );
}

/// Title with a glyph inline after its last glyph (same hug rule as the info
/// `i`, settings-layout-notes §3); the whole row is one semantics node — a
/// link when it leaves the app, otherwise a button.
class _SettingsInlineGlyphRow extends StatelessWidget {
  const _SettingsInlineGlyphRow({
    super.key,
    required this.title,
    required this.glyph,
    required this.glyphKey,
    required this.glyphGap,
    required this.isExternalLink,
    required this.onTap,
  });

  final String title;
  final IconData glyph;
  final Key glyphKey;
  final double glyphGap;
  final bool isExternalLink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return Semantics(
      link: isExternalLink,
      button: !isExternalLink,
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
                      padding: EdgeInsets.only(left: glyphGap),
                      child: Icon(
                        glyph,
                        key: glyphKey,
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
