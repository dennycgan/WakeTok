import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';
import 'package:waketok/features/main_browse/wait_chrome_policy.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_live_photo_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../authorization/permission_ui_test_harness.dart';
import 'still_cover_test_helpers.dart';

Future<void> pumpAsyncWork(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> pumpPastLivePreparingSuppress(WidgetTester tester) async {
  await tester.pump(kDefaultA4SuppressBelow);
  await tester.pump();
}

Future<FakeLivePhotoRepository> pumpLiveFeedAtMotion({
  required WidgetTester tester,
  required List<String> liveIds,
}) async {
  final live = FakeLivePhotoRepository(autoReady: true);
  final display = FakeMediaDisplayRepository();
  seedDecodableStillPaths(
    display,
    liveIds,
    mediaKind: PlaybackMediaKind.livePhoto,
  );
  final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
  await tester.pumpWidget(
    permissionUiHarness(
      disableBrowseAllPrefetch: true,
      repo: repo,
      assetSources: FakeAssetSourceRepository(
        allIds: liveIds,
        availabilityById: FakeAssetSourceRepository.deviceLocalForIds(liveIds),
      ),
      mediaDisplay: display,
      livePhoto: live,
    ),
  );
  await pumpAsyncWork(tester);
  await pumpUntilStillCoverReadyForAsset(tester, liveIds.first);
  await pumpPastLivePreparingSuppress(tester);
  expect(
    find.byKey(Key('mainBrowseFeedLiveMotion_${liveIds.first}')),
    findsOneWidget,
  );
  expect(live.calls, contains('startPlayback'));
  return live;
}

void main() {
  testWidgets(
    'W-28.4-L1 settingsResume: mid-motion Settings return is static (no new Live host play)',
    (tester) async {
      const liveId = 'live-cap28-a';
      final live = await pumpLiveFeedAtMotion(
        tester: tester,
        liveIds: const [liveId],
      );

      final requestBefore = live.calls
          .where((c) => c.startsWith('requestLivePhoto:'))
          .length;
      final startBefore =
          live.calls.where((c) => c == 'startPlayback').length;
      expect(startBefore, greaterThanOrEqualTo(1));

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.settings);
      await tester.pump();
      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.browse);
      await pumpAsyncWork(tester);
      await pumpPastLivePreparingSuppress(tester);

      expect(
        live.calls.where((c) => c.startsWith('requestLivePhoto:')).length,
        requestBefore,
        reason: 'settingsResume must not re-request Live Photo',
      );
      expect(
        live.calls.where((c) => c == 'startPlayback').length,
        startBefore,
        reason: 'settingsResume must not auto-replay motion',
      );
      expect(
        find.byKey(Key('mainBrowseFeedLiveMotion_$liveId')),
        findsNothing,
      );
      expect(
        find.byKey(Key('mainBrowseFeedStill_$liveId')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'W-28.4-L2 swipe away and back: Live auto-plays once (ADR-019 guard)',
    (tester) async {
      const liveA = 'live-cap28-b0';
      const liveB = 'live-cap28-b1';
      final live = await pumpLiveFeedAtMotion(
        tester: tester,
        liveIds: const [liveA, liveB],
      );

      final startOnA =
          live.calls.where((c) => c == 'startPlayback').length;

      await tester.drag(find.byType(PageView), const Offset(0, -280));
      await pumpAsyncWork(tester);
      expect(
        find.byKey(Key('mainBrowseFeedLiveMotion_$liveB')),
        findsOneWidget,
      );
      final startOnB =
          live.calls.where((c) => c == 'startPlayback').length;
      expect(startOnB, greaterThan(startOnA));

      await tester.drag(find.byType(PageView), const Offset(0, 280));
      await pumpAsyncWork(tester);
      await pumpPastLivePreparingSuppress(tester);

      expect(
        find.byKey(Key('mainBrowseFeedLiveMotion_$liveA')),
        findsOneWidget,
      );
      expect(
        live.calls.where((c) => c == 'startPlayback').length,
        startOnB + 1,
        reason:
            'swipe back to A must trigger exactly one ADR-019 play-once',
      );
    },
  );
}
