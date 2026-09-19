import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/app/cap19_left_swipe_providers.dart';
import 'package:waketok/app/new_round_toast_providers.dart';
import 'package:waketok/app/saved_pool_providers.dart';
import 'package:waketok/app/waketok_album_providers.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/authorization/photos_authorization_repository.dart';
import 'package:waketok/features/authorization/open_app_settings.dart';
import 'package:waketok/features/authorization/photos_access_gate.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/domain/live_photo/live_photo_repository.dart';
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
import 'package:waketok/features/library_smoke/shared_mute_provider.dart';
import 'package:waketok/features/main_browse/browse_magnification.dart';
import 'package:waketok/features/main_browse/cap24_minute_landmark.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../domain/library/fake_waketok_album_store.dart';
import '../../domain/source/fake_saved_pool_repository.dart';
import '../../library_smoke/fake_album_cover_repository.dart';
import '../../library_smoke/fake_album_mutation_repository.dart';
import '../../library_smoke/fake_asset_favorite_repository.dart';
import '../../library_smoke/fake_asset_soft_delete_repository.dart';
import '../../library_smoke/fake_asset_share_repository.dart';
import '../../library_smoke/fake_cap19_left_swipe_preferences.dart';
import '../../library_smoke/fake_new_round_toast_preferences.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_library_catalog_repository.dart';
import '../../library_smoke/fake_live_photo_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_playback_repository.dart';
import '../../library_smoke/fake_presentation_metadata_repository.dart';

class ControllablePhotosAuthorizationRepository
    implements PhotosAuthorizationRepository {
  ControllablePhotosAuthorizationRepository(this.status);

  PhotosAccess status;
  int requestCalls = 0;
  int presentCalls = 0;

  /// When set, [requestAccess] waits here before applying [grantedAccess].
  Completer<void>? requestAccessHold;

  /// Status written when [requestAccess] completes (default Full, matching W2).
  PhotosAccess grantedAccess = PhotosAccess.full;

  @override
  Future<PhotosAccess> currentStatus() async => status;

  @override
  Future<PhotosAccess> requestAccess() async {
    requestCalls += 1;
    final hold = requestAccessHold;
    if (hold != null) {
      await hold.future;
    }
    status = grantedAccess;
    return status;
  }

  @override
  Future<void> presentLimitedLibraryPicker() async {
    presentCalls += 1;
  }
}

Widget permissionUiHarness({
  required PhotosAuthorizationRepository repo,
  OpenAppSettings? openSettings,
  Locale? locale,
  ThemeMode themeMode = ThemeMode.system,
  FakeLibraryCatalogRepository? catalog,
  FakeAssetSourceRepository? assetSources,
  FakeAlbumMutationRepository? albumMutations,
  FakeAlbumCoverRepository? albumCovers,
  FakeAssetFavoriteRepository? assetFavorites,
  FakeAssetSoftDeleteRepository? assetSoftDelete,
  FakeAssetShareRepository? assetShare,
  FakeCap19LeftSwipePreferences? cap19LeftSwipePreferences,
  FakeNewRoundToastPreferences? newRoundToastPreferences,
  FakeWakeTokAlbumStore? wakeTokAlbumStore,
  FakeMediaDisplayRepository? mediaDisplay,
  FakePlaybackRepository? playback,
  FakePresentationMetadataRepository? presentationMetadata,
  LivePhotoRepository? livePhoto,
  FakeSavedPoolRepository? savedPools,
  bool sharedMuteInitiallyMuted = false,

  /// Cap 13.4: default seeded Shuffle so feed widget tests are deterministic.
  /// Each read constructs a fresh [Random] so session rebuilds do not share
  /// a consumed PRNG stream.
  int browseShuffleSeed = 0,

  /// Cap 14.6: default no extra empty retries so existing empty-path tests
  /// keep a single resolve. Pass production or zero-duration lists to
  /// exercise the retry loop.
  List<Duration> browseEmptyRetryDelays = const [],

  /// Cap 16.4: default zero so existing feed tests do not wait production N.
  Duration browseLayer2Dwell = Duration.zero,

  /// Cap 15.12: default zero so existing feed tests do not wait N_local.
  Duration browseLocalFirstVisitDwell = Duration.zero,

  /// Cap 20.2: force still-magnified signal true for widget tests.
  bool forceStillMagnified = false,

  /// Cap 24.3: override minute-landmark loader (flash / mounted tests).
  Cap24MinuteLandmarkLoader? minuteLandmarkLoader,
}) {
  final libraryCatalog = catalog ?? FakeLibraryCatalogRepository();
  final sources = assetSources ?? FakeAssetSourceRepository();
  final mutations = albumMutations ?? FakeAlbumMutationRepository();
  final covers = albumCovers ?? FakeAlbumCoverRepository();
  final favorites = assetFavorites ?? FakeAssetFavoriteRepository();
  final softDelete = assetSoftDelete ?? FakeAssetSoftDeleteRepository();
  final share = assetShare ?? FakeAssetShareRepository();
  final leftSwipePrefs =
      cap19LeftSwipePreferences ?? FakeCap19LeftSwipePreferences();
  final newRoundPrefs =
      newRoundToastPreferences ?? FakeNewRoundToastPreferences();
  final albumStore = wakeTokAlbumStore ?? FakeWakeTokAlbumStore();
  final pools = savedPools ?? FakeSavedPoolRepository();
  return ProviderScope(
    overrides: [
      photosAuthorizationRepositoryProvider.overrideWithValue(repo),
      libraryCatalogRepositoryProvider.overrideWithValue(libraryCatalog),
      assetSourceRepositoryProvider.overrideWithValue(sources),
      albumMutationRepositoryProvider.overrideWithValue(mutations),
      albumCoverRepositoryProvider.overrideWithValue(covers),
      assetFavoriteRepositoryProvider.overrideWithValue(favorites),
      assetSoftDeleteRepositoryProvider.overrideWithValue(softDelete),
      assetShareRepositoryProvider.overrideWithValue(share),
      cap19LeftSwipePreferencesProvider.overrideWithValue(leftSwipePrefs),
      newRoundToastPreferencesProvider.overrideWithValue(newRoundPrefs),
      wakeTokAlbumStoreProvider.overrideWithValue(albumStore),
      savedPoolRepositoryProvider.overrideWithValue(pools),
      mediaDisplayRepositoryProvider.overrideWithValue(
        mediaDisplay ?? FakeMediaDisplayRepository(),
      ),
      playbackRepositoryProvider.overrideWithValue(
        playback ?? FakePlaybackRepository(),
      ),
      presentationMetadataRepositoryProvider.overrideWithValue(
        presentationMetadata ?? FakePresentationMetadataRepository(),
      ),
      livePhotoRepositoryProvider.overrideWithValue(
        livePhoto ?? FakeLivePhotoRepository(),
      ),
      browseShuffleRandomFactoryProvider.overrideWith(
        (ref) =>
            () => Random(browseShuffleSeed),
      ),
      browseEmptyRetryDelaysProvider.overrideWithValue(browseEmptyRetryDelays),
      browseLayer2DwellProvider.overrideWithValue(browseLayer2Dwell),
      browseLocalFirstVisitDwellProvider.overrideWithValue(
        browseLocalFirstVisitDwell,
      ),
      // Cap 27.3: widget harnesses assert resolve-call counts; disable
      // post-auth All prefetch so those contracts stay stable. Production
      // shell still watches [browseAllPrefetchBinderProvider].
      browseAllPrefetchBinderProvider.overrideWith((ref) {}),
      if (openSettings != null)
        openAppSettingsProvider.overrideWithValue(openSettings),
      if (sharedMuteInitiallyMuted)
        sharedMuteProvider.overrideWith(_HarnessMutedTrueSharedMute.new),
      if (forceStillMagnified)
        browseStillMagnifiedProvider.overrideWith((ref) => true),
      if (minuteLandmarkLoader != null)
        cap24MinuteLandmarkLoaderProvider.overrideWithValue(
          minuteLandmarkLoader,
        ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: waketokTheme(Brightness.light),
      darkTheme: waketokTheme(Brightness.dark),
      themeMode: themeMode,
      home: const PhotosAccessGate(),
    ),
  );
}

class _HarnessMutedTrueSharedMute extends SharedMuteNotifier {
  @override
  bool build() => true;
}
