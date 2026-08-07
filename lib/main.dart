import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/authorization/photos_access_gate.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/library_smoke/library_catalog_providers.dart';
import 'package:waketok/features/library_smoke/playback_providers.dart';
import 'package:waketok/features/library_smoke/presentation_providers.dart';
import 'package:waketok/l10n/app_localizations.dart';
import 'package:waketok/l10n/locale_resolution.dart';
import 'package:waketok/platform/photo_library_gateway.dart';
import 'package:waketok/platform/playback_gateway.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final gateway = PhotoLibraryGateway();
  final playback = PlaybackGateway();
  runApp(
    ProviderScope(
      overrides: [
        photosAuthorizationRepositoryProvider.overrideWithValue(gateway),
        libraryCatalogRepositoryProvider.overrideWithValue(gateway),
        assetSourceRepositoryProvider.overrideWithValue(gateway),
        mediaDisplayRepositoryProvider.overrideWithValue(gateway),
        presentationMetadataRepositoryProvider.overrideWithValue(gateway),
        playbackRepositoryProvider.overrideWithValue(playback),
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
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (locales, supportedLocales) {
        return resolveAppLocale(locales);
      },
      theme: waketokTheme(Brightness.light),
      darkTheme: waketokTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const PhotosAccessGate(),
    );
  }
}
