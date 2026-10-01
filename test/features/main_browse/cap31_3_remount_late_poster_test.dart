import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_playback_repository.dart';
import '../authorization/permission_ui_test_harness.dart';
import 'still_cover_test_helpers.dart';

const _meta = Key('mediaInfoOverlay');
const _ids = ['v1', 'v2', 'v3'];

Future<void> _pumpAsyncWork(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Device-local video feed, then an order Confirm remount. Returns the
/// remounted head and its preview-call count from before the remount.
Future<({String head, int previewsBefore, FakeMediaDisplayRepository display})>
_remountVideoHead(WidgetTester tester) async {
  final display = FakeMediaDisplayRepository();
  seedDecodableStillPaths(display, _ids, mediaKind: PlaybackMediaKind.video);
  for (final id in _ids) {
    display.displayErrorById[id] = 'unsupportedMedia';
  }
  await tester.pumpWidget(
    permissionUiHarness(
      disableBrowseAllPrefetch: true,
      repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
      assetSources: FakeAssetSourceRepository(
        allIds: _ids,
        availabilityById: FakeAssetSourceRepository.deviceLocalForIds(_ids),
      ),
      mediaDisplay: display,
      playback: FakePlaybackRepository(),
    ),
  );
  await _pumpAsyncWork(tester);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(VerticalMediaFeed)),
  );
  final previewsBefore = {
    for (final id in _ids) id: display.previewCalls.where((e) => e == id).length,
  };

  expect(
    await container
        .read(browseSessionProvider.notifier)
        .applyConfirmedOrderPreference(OrderPolicy.newestFirst),
    isTrue,
  );
  container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
  await _pumpAsyncWork(tester);

  final head =
      (await container.read(browseSessionProvider.future)).orderedAssetIds[0];
  return (
    head: head,
    previewsBefore: previewsBefore[head] ?? 0,
    display: display,
  );
}

void main() {
  testWidgets(
    'W-31.3-L1 remount video head gets one late poster under the video',
    (tester) async {
      final r = await _remountVideoHead(tester);
      final page = mediaFeedPageState(tester, r.head);

      expect(page.debugMedia?.display, isNotNull);
      expect(find.byKey(Key('mainBrowseFeedStill_${r.head}')), findsOneWidget);
      expect(
        r.display.previewCalls.where((e) => e == r.head).length,
        r.previewsBefore + 1,
        reason: 'exactly one late poster request after the remount',
      );
      expect(
        tester
            .widget<Opacity>(find.byKey(Key('feedVideoOpacity_${r.head}')))
            .opacity,
        1.0,
        reason: 'late poster must not arm the poster hold',
      );
      expect(find.byKey(_meta), findsOneWidget);
    },
  );

  testWidgets(
    'W-31.3-L2 late poster decode failure still hides Meta',
    (tester) async {
      final r = await _remountVideoHead(tester);
      expect(find.byKey(_meta), findsOneWidget);

      final imageFinder = find.descendant(
        of: find.byKey(Key('mainBrowseFeedStill_${r.head}')),
        matching: find.byType(Image),
      );
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      // Same closure as production; Image decode is unreliable in widget tests.
      image.errorBuilder!(
        tester.element(imageFinder),
        Exception('forced decode failure'),
        StackTrace.current,
      );
      // The broken report is a post-frame callback; make sure a frame runs.
      tester.binding.scheduleFrame();
      await tester.pump();
      await tester.pump();

      expect(
        mediaFeedPageState(tester, r.head).debugStillCoverDecodeBroken,
        isTrue,
      );
      expect(find.byKey(_meta), findsNothing);
    },
  );
}
