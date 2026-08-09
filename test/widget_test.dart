import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/photos_access_gate.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/features/library_smoke/library_catalog_providers.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/library_smoke/playback_providers.dart';
import 'package:waketok/main.dart';

import 'features/authorization/permission_ui_test_harness.dart';
import 'library_smoke/fake_asset_source_repository.dart';
import 'library_smoke/fake_library_catalog_repository.dart';
import 'library_smoke/fake_media_display_repository.dart';
import 'library_smoke/fake_playback_repository.dart';
import 'library_smoke/fake_presentation_metadata_repository.dart';
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
        ],
        child: const WakeTokApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PhotosAccessGate), findsOneWidget);
  });
}
