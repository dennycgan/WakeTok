import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/features/main_browse/feed_page_media.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_playback_repository.dart';
import '../authorization/permission_ui_test_harness.dart';
import 'still_cover_test_helpers.dart';

Future<void> pumpAsyncWork(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets(
    'W-28.4-A′ soft settingsResume completed video keeps l2/cover (no loading teardown)',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final playback = FakePlaybackRepository();
      const id = 'v-soft-28';
      final posterPath = File(
        '${Directory.systemTemp.path}/wt_28_soft_$id.png',
      );
      posterPath.writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
        ),
      );
      display.displayErrorById[id] = 'unsupportedMedia';
      display.previewsById[id] = DisplayAsset(
        assetIdentifier: id,
        mediaKind: PlaybackMediaKind.video,
        localFilePath: posterPath.path,
      );

      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const [id],
            availabilityById:
                FakeAssetSourceRepository.deviceLocalForIds(const [id]),
          ),
          mediaDisplay: display,
          playback: playback,
        ),
      );
      await pumpAsyncWork(tester);
      await pumpUntilStillCoverReadyForAsset(tester, id);

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      final page = tester.state<MediaFeedPageState>(
        find.byType(MediaFeedPage),
      );

      expect(page.debugMedia?.kind, FeedPageMediaKind.video);
      expect(page.debugMedia?.display, isNotNull);
      expect(page.debugLoading, isFalse);
      expect(page.debugLayer2InFlight, isFalse);
      expect(
        container.read(mainBrowseCurrentAssetLayer2DisplayReadyProvider),
        isTrue,
      );
      expect(
        container.read(mainBrowseCurrentAssetMediaCoverVisibleProvider),
        isTrue,
      );

      final loadsBefore =
          playback.calls.where((c) => c.startsWith('load:')).length;

      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.settings);
      await tester.pump();
      await pumpAsyncWork(tester);
      expect(
        container.read(mainBrowseCurrentAssetLayer2DisplayReadyProvider),
        isTrue,
        reason: 'completed soft leave keeps l2DisplayReady',
      );

      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.browse);
      await tester.pump();
      await pumpAsyncWork(tester);

      final pageAfter = tester.state<MediaFeedPageState>(
        find.byType(MediaFeedPage),
      );
      expect(pageAfter.debugMedia?.kind, FeedPageMediaKind.video);
      expect(
        pageAfter.debugMedia?.kind,
        isNot(FeedPageMediaKind.pendingVideo),
      );
      expect(pageAfter.debugLoading, isFalse);
      expect(pageAfter.debugLayer2InFlight, isFalse);
      expect(
        container.read(mainBrowseCurrentAssetLayer2DisplayReadyProvider),
        isTrue,
        reason: 'A′ must not clear l2DisplayReady on settingsResume',
      );
      expect(
        container.read(mainBrowseCurrentAssetMediaCoverVisibleProvider),
        isTrue,
        reason: 'A′ must keep coverVisible via poster (no loading dim)',
      );
      expect(
        playback.calls.where((c) => c.startsWith('load:')).length,
        loadsBefore,
        reason: 'soft resume must not re-run Host load teardown',
      );
    },
  );
}
