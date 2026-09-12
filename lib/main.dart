import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/app/browse/snapshot_invalidating_album_mutation_repository.dart';
import 'package:waketok/app/cap19_left_swipe_providers.dart';
import 'package:waketok/app/new_round_toast_providers.dart';
import 'package:waketok/app/saved_pool_providers.dart';
import 'package:waketok/app/waketok_album_providers.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/data/local/drift_saved_pool_repository.dart';
import 'package:waketok/data/local/waketok_database.dart';
import 'package:waketok/data/preferences/cap19_left_swipe_preferences_store.dart';
import 'package:waketok/data/preferences/new_round_toast_preferences_store.dart';
import 'package:waketok/data/preferences/waketok_album_preferences_store.dart';
import 'package:waketok/features/authorization/photos_access_gate.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/features/library_smoke/album_cover_providers.dart';
import 'package:waketok/features/library_smoke/album_mutation_providers.dart';
import 'package:waketok/features/library_smoke/asset_favorite_providers.dart';
import 'package:waketok/features/library_smoke/asset_share_providers.dart';
import 'package:waketok/features/library_smoke/asset_soft_delete_providers.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/library_smoke/library_catalog_providers.dart';
import 'package:waketok/features/library_smoke/live_photo_providers.dart';
import 'package:waketok/features/library_smoke/playback_providers.dart';
import 'package:waketok/features/library_smoke/presentation_providers.dart';
import 'package:waketok/l10n/app_localizations.dart';
import 'package:waketok/l10n/locale_resolution.dart';
import 'package:waketok/platform/live_photo_gateway.dart';
import 'package:waketok/platform/photo_library_gateway.dart';
import 'package:waketok/platform/playback_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  final gateway = PhotoLibraryGateway();
  final playback = PlaybackGateway();
  final livePhoto = LivePhotoGateway();
  final wakeTokAlbumStore = WakeTokAlbumPreferencesStore();
  final cap19LeftSwipePreferences = Cap19LeftSwipePreferencesStore();
  final newRoundToastPreferences = NewRoundToastPreferencesStore();
  final savedPoolRepository = DriftSavedPoolRepository(
    WaketokDatabase.defaults(),
  );
  runApp(
    ProviderScope(
      overrides: [
        photosAuthorizationRepositoryProvider.overrideWithValue(gateway),
        libraryCatalogRepositoryProvider.overrideWithValue(gateway),
        assetSourceRepositoryProvider.overrideWithValue(gateway),
        albumMutationRepositoryProvider.overrideWith((ref) {
          return SnapshotInvalidatingAlbumMutationRepository(
            inner: gateway,
            onMembershipChanged: (albumId) {
              ref
                  .read(browseSnapshotCacheProvider.notifier)
                  .invalidateEntriesContainingAlbum(albumId);
            },
          );
        }),
        albumCoverRepositoryProvider.overrideWithValue(gateway),
        assetFavoriteRepositoryProvider.overrideWithValue(gateway),
        assetSoftDeleteRepositoryProvider.overrideWithValue(gateway),
        assetShareRepositoryProvider.overrideWithValue(gateway),
        wakeTokAlbumStoreProvider.overrideWithValue(wakeTokAlbumStore),
        cap19LeftSwipePreferencesProvider.overrideWithValue(
          cap19LeftSwipePreferences,
        ),
        newRoundToastPreferencesProvider.overrideWithValue(
          newRoundToastPreferences,
        ),
        savedPoolRepositoryProvider.overrideWithValue(savedPoolRepository),
        mediaDisplayRepositoryProvider.overrideWithValue(gateway),
        presentationMetadataRepositoryProvider.overrideWithValue(gateway),
        playbackRepositoryProvider.overrideWithValue(playback),
        livePhotoRepositoryProvider.overrideWithValue(livePhoto),
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
