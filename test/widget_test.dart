import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/photos_access_gate.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/features/library_smoke/library_catalog_providers.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/library_smoke/playback_providers.dart';
import 'package:waketok/app/cap19_left_swipe_providers.dart';
import 'package:waketok/app/cap30_first_launch_guide_providers.dart';
import 'package:waketok/app/new_round_toast_providers.dart';
import 'package:waketok/app/waketok_album_providers.dart';
import 'package:waketok/main.dart';

import 'features/authorization/permission_ui_test_harness.dart';
import 'domain/library/fake_waketok_album_store.dart';
import 'library_smoke/fake_asset_source_repository.dart';
import 'library_smoke/fake_cap19_left_swipe_preferences.dart';
import 'library_smoke/fake_library_catalog_repository.dart';
import 'library_smoke/fake_media_display_repository.dart';
import 'library_smoke/fake_new_round_toast_preferences.dart';
import 'library_smoke/fake_playback_repository.dart';
import 'library_smoke/fake_presentation_metadata_repository.dart';
import 'onboarding/fake_cap30_first_launch_guide_preferences.dart';
import 'package:waketok/features/library_smoke/presentation_providers.dart';

void main() {
  testWidgets('WakeTokApp opens PhotosAccessGate', (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.notDetermined);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photosAuthorizationRepositoryProvider.overrideWithValue(repo),
          libraryCatalogRepositoryProvider.overrideWithValue(
            FakeLibraryCatalogRepository(),
          ),
          assetSourceRepositoryProvider.overrideWithValue(
            FakeAssetSourceRepository(),
          ),
          mediaDisplayRepositoryProvider.overrideWithValue(
            FakeMediaDisplayRepository(),
          ),
          playbackRepositoryProvider.overrideWithValue(FakePlaybackRepository()),
          presentationMetadataRepositoryProvider.overrideWithValue(
            FakePresentationMetadataRepository(),
          ),
          cap19LeftSwipePreferencesProvider.overrideWithValue(
            FakeCap19LeftSwipePreferences(),
          ),
          cap30FirstLaunchGuidePreferencesProvider.overrideWithValue(
            FakeCap30FirstLaunchGuidePreferences()..step = 3,
          ),
          newRoundToastPreferencesProvider.overrideWithValue(
            FakeNewRoundToastPreferences(),
          ),
          wakeTokAlbumStoreProvider.overrideWithValue(FakeWakeTokAlbumStore()),
        ],
        child: const WakeTokApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PhotosAccessGate), findsOneWidget);
  });
}
