import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/l10n/app_localizations.dart';
import 'package:waketok/l10n/locale_resolution.dart';
import 'package:waketok/platform/photo_library_gateway.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        photosAuthorizationRepositoryProvider.overrideWithValue(
          PhotoLibraryGateway(),
        ),
      ],
      child: const WakeTokApp(),
    ),
  );
}

/// Root app: l10n + theme (ADR-U / ADR-009) + Riverpod (ADR-010).
class WakeTokApp extends StatelessWidget {
  const WakeTokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.l10nSmoke,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (locales, supportedLocales) {
        return resolveAppLocale(locales);
      },
      theme: waketokTheme(Brightness.light),
      darkTheme: waketokTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const L10nSmokePage(),
    );
  }
}

/// Minimal home surface for l10n smoke + temporary auth debug harness (5.2).
class L10nSmokePage extends StatelessWidget {
  const L10nSmokePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.l10nSmoke),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                l10n.l10nSmoke,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          const Divider(height: 1),
          ColoredBox(
            color: tokens.surface,
            child: const AuthDebugStrip(),
          ),
        ],
      ),
    );
  }
}

/// TEMPORARY / DEBUG-ONLY authorization harness for Cap 5.2 acceptance.
///
/// Not a product UI and must not become the foundation for 5.3 permission
/// screens. Remove or replace when 5.3 product flows land.
class AuthDebugStrip extends ConsumerWidget {
  const AuthDebugStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final asyncStatus = ref.watch(photosAuthorizationProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DEBUG ONLY — temporary 5.2 auth harness (not 5.3 UI)',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: tokens.accentProvisional,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'PhotosAccess: ${asyncStatus.when(
              data: (s) => s.name,
              loading: () => 'loading…',
              error: (e, _) => 'error: $e',
            )}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: asyncStatus.isLoading
                    ? null
                    : () => ref
                        .read(photosAuthorizationProvider.notifier)
                        .requestAccess(),
                child: const Text('Request access'),
              ),
              OutlinedButton(
                onPressed: asyncStatus.isLoading ||
                        asyncStatus.value != PhotosAccess.limited
                    ? null
                    : () => ref
                        .read(photosAuthorizationProvider.notifier)
                        .presentLimitedLibraryPicker(),
                child: const Text('Limited picker'),
              ),
              OutlinedButton(
                onPressed: asyncStatus.isLoading
                    ? null
                    : () => ref.invalidate(photosAuthorizationProvider),
                child: const Text('Refresh status'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
