import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// First-launch Photos permission explanation (system prompt follows CTA).
class PermissionRequestPage extends ConsumerWidget {
  const PermissionRequestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final async = ref.watch(photosAuthorizationProvider);
    final busy = async.isLoading;

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
              l10n.permissionRequestTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: tokens.onSurface,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.permissionRequestBody,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: tokens.onSurface,
                  ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: busy
                  ? null
                  : () => ref
                      .read(photosAuthorizationProvider.notifier)
                      .requestAccess(),
              child: Text(l10n.permissionRequestContinue),
            ),
          ],
        ),
      ),
    );
  }
}
