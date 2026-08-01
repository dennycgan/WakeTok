import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/open_app_settings.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Denied / restricted gate — does not enter normal browse (ADR-K §5).
class PermissionBlockedPage extends ConsumerWidget {
  const PermissionBlockedPage({super.key, required this.access});

  final PhotosAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final title = access == PhotosAccess.restricted
        ? l10n.permissionBlockedTitleRestricted
        : l10n.permissionBlockedTitleDenied;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: tokens.onSurface,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.permissionBlockedBody,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: tokens.onSurface,
                  ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => ref.read(openAppSettingsProvider)(),
              child: Text(l10n.permissionOpenSettings),
            ),
          ],
        ),
      ),
    );
  }
}
