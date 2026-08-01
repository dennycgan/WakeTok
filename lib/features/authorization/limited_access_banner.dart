import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/authorization/open_app_settings.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Limited Photos Access banner (ADR-K §2–3). Product UI — not the 5.2 debug strip.
class LimitedAccessBanner extends ConsumerWidget {
  const LimitedAccessBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final busy = ref.watch(photosAuthorizationProvider).isLoading;

    return Material(
      color: tokens.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.limitedAccessBannerMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.onSurface,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => ref
                          .read(photosAuthorizationProvider.notifier)
                          .presentLimitedLibraryPicker(),
                  child: Text(l10n.limitedAccessManageSelection),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => ref.read(openAppSettingsProvider)(),
                  child: Text(l10n.permissionOpenSettings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
