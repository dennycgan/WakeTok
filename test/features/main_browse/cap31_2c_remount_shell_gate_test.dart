import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/media_info_overlay.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_live_photo_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../authorization/permission_ui_test_harness.dart';
import 'still_cover_test_helpers.dart';

/// Cap 31.2c / ADR-066 (debt 485): a `roundEpoch` remount disposes the old
/// current [MediaFeedPage] without clearing the shell cover gates, and the
/// new head publishes post-frame. The Feed listener must clear them before
/// the new tree's first frame, or the Action Column paints the previous
/// item's enabled chrome over "Loading item".

ProviderContainer _containerOf(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
}

InkWell _ink(WidgetTester tester, Key key) {
  return tester.widget<InkWell>(find.byKey(key));
}

Future<void> _pumpAsyncWork(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

final _currentPage = find.byWidgetPredicate(
  (w) => w is MediaFeedPage && w.isCurrent,
);

/// Pumps a device-local pool, then one Confirm-order `roundEpoch` remount so
/// the landing head takes the Cap 27.4 prefer-Host hard-reload APPLY path.
Future<ProviderContainer> _pumpAndRemount(
  WidgetTester tester, {
  required PlaybackMediaKind mediaKind,
  FakeLivePhotoRepository? livePhoto,
}) async {
  const ids = ['a1', 'a2', 'a3'];
  final display = FakeMediaDisplayRepository();
  seedDecodableStillPaths(display, ids, mediaKind: mediaKind);
  final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
  await tester.pumpWidget(
    permissionUiHarness(
      disableBrowseAllPrefetch: true,
      repo: repo,
      assetSources: FakeAssetSourceRepository(
        allIds: ids,
        availabilityById: FakeAssetSourceRepository.deviceLocalForIds(ids),
      ),
      mediaDisplay: display,
      livePhoto: livePhoto,
    ),
  );
  await _pumpAsyncWork(tester);
  final container = _containerOf(tester);
  expect(
    await container
        .read(browseSessionProvider.notifier)
        .applyConfirmedOrderPreference(OrderPolicy.newestFirst),
    isTrue,
  );
  container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
  await _pumpAsyncWork(tester);
  return container;
}

void main() {
  testWidgets(
    'W-31.2c-A1 roundEpoch remount: shell gates false and three icons '
    'disabled on the first frame of the new tree',
    (tester) async {
      const ids = ['a1', 'a2', 'a3'];
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: ids,
            availabilityById: FakeAssetSourceRepository.deviceLocalForIds(ids),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await ensureShellMediaCoverVisible(tester);

      final container = _containerOf(tester);
      // Previous current item fully settled (Live motion mounted is the
      // worst case: all three gates true).
      container
          .read(mainBrowseCurrentAssetLayer2DisplayReadyProvider.notifier)
          .setReady(true);
      container
          .read(mainBrowseCurrentLiveMotionMountedProvider.notifier)
          .setMounted(true);
      await tester.pump();
      expect(
        container.read(mainBrowseCurrentAssetMediaCoverVisibleProvider),
        isTrue,
      );
      expect(_ink(tester, const Key('cap19EntryIcon')).onTap, isNotNull);
      expect(_ink(tester, const Key('cap24MoreEntryIcon')).onTap, isNotNull);

      final epochBefore =
          container.read(browseSessionProvider).asData!.value.roundEpoch;
      final pageBefore = tester.state<MediaFeedPageState>(
        find.byWidgetPredicate((w) => w is MediaFeedPage && w.isCurrent),
      );

      expect(
        await container
            .read(browseSessionProvider.notifier)
            .applyConfirmedOrderPreference(OrderPolicy.newestFirst),
        isTrue,
      );
      expect(
        container.read(browseSessionProvider).asData!.value.roundEpoch,
        greaterThan(epochBefore),
      );

      // Cleared synchronously by the listener — before any new frame.
      expect(
        container.read(mainBrowseCurrentAssetMediaCoverVisibleProvider),
        isFalse,
      );
      expect(
        container.read(mainBrowseCurrentAssetLayer2DisplayReadyProvider),
        isFalse,
      );
      expect(
        container.read(mainBrowseCurrentLiveMotionMountedProvider),
        isFalse,
      );

      // First frame of the remounted tree.
      await tester.pump();
      final pageAfter = tester.state<MediaFeedPageState>(
        find.byWidgetPredicate((w) => w is MediaFeedPage && w.isCurrent),
      );
      expect(identical(pageAfter, pageBefore), isFalse);
      expect(_ink(tester, const Key('cap19EntryIcon')).onTap, isNull);
      expect(_ink(tester, const Key('cap24MoreEntryIcon')).onTap, isNull);
      expect(_ink(tester, const Key('cap25ShareEntryIcon')).onTap, isNull);
    },
  );

  testWidgets(
    'W-31.2c-B1 remount Host APPLY: Loading shell holds until the cover '
    'frame, then cover and Meta appear on the same frame',
    (tester) async {
      final container = await _pumpAndRemount(
        tester,
        mediaKind: PlaybackMediaKind.image,
      );
      final page = tester.state<MediaFeedPageState>(_currentPage);

      // APPLY done (L2 media set, page not loading) but no decoded frame.
      expect(page.debugLoading, isFalse);
      expect(page.debugMedia?.display, isNotNull);
      expect(page.debugStillCoverReady, isFalse);
      expect(page.debugRemountRevealHoldActive, isTrue);
      expect(
        find.byKey(const Key('mainBrowseFeedRemountRevealHold')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _currentPage,
          matching: find.byType(MediaInfoOverlay),
        ),
        findsNothing,
      );
      expect(
        container.read(mainBrowseCurrentAssetMediaCoverVisibleProvider),
        isFalse,
      );
      expect(_ink(tester, const Key('cap24MoreEntryIcon')).onTap, isNull);

      // First decoded frame → one setState: hold off, Meta on.
      page.debugForceStillCoverDecodeBroken(false);
      await tester.pump();
      expect(page.debugRemountRevealHoldActive, isFalse);
      expect(
        find.byKey(const Key('mainBrowseFeedRemountRevealHold')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: _currentPage,
          matching: find.byType(MediaInfoOverlay),
        ),
        findsOneWidget,
      );

      // ADR-054: shell cover gate publishes post-frame.
      await tester.pump();
      expect(
        container.read(mainBrowseCurrentAssetMediaCoverVisibleProvider),
        isTrue,
      );
      expect(_ink(tester, const Key('cap24MoreEntryIcon')).onTap, isNotNull);
    },
  );

  testWidgets(
    'W-31.2c-B3 remount head with a Session token: first frame paints no '
    'miss gold or "Loading item" (Cap 17.3 B a4)',
    (tester) async {
      final container = await _pumpAndRemount(
        tester,
        mediaKind: PlaybackMediaKind.image,
      );
      final head =
          tester.state<MediaFeedPageState>(_currentPage).widget.assetIdentifier;
      expect(container.read(browseL2ReadySessionProvider)[head], isNotNull);
      final pageBefore = tester.state<MediaFeedPageState>(_currentPage);

      // newestFirst Endless: same list back to index 0 → same head remounts.
      container.read(browseSessionProvider.notifier).advanceToNextRound();
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
      await tester.pump();

      final pageAfter = tester.state<MediaFeedPageState>(_currentPage);
      expect(identical(pageAfter, pageBefore), isFalse);
      expect(pageAfter.widget.assetIdentifier, head);
      // Element tree = the new page's first build (Loading shell).
      expect(find.byKey(const Key('mainBrowseFeedPageLoading')), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseFeedPageLoadingSpinner')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('mainBrowseFeedCoverlessWaitLabel')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'W-31.2c-B2 remount Host APPLY Live still: motion prepare waits for the '
    'cover reveal',
    (tester) async {
      final live = FakeLivePhotoRepository();
      await _pumpAndRemount(
        tester,
        mediaKind: PlaybackMediaKind.livePhoto,
        livePhoto: live,
      );
      final page = tester.state<MediaFeedPageState>(_currentPage);
      final head = page.widget.assetIdentifier;
      final requestsBefore =
          live.calls.where((c) => c == 'requestLivePhoto:$head').length;

      expect(page.debugRemountRevealHoldActive, isTrue);
      expect(page.debugLivePrepareDeferredForReveal, isTrue);
      expect(page.debugLiveMotionMounted, isFalse);

      page.debugForceStillCoverDecodeBroken(false);
      await _pumpAsyncWork(tester);

      expect(page.debugRemountRevealHoldActive, isFalse);
      expect(page.debugLivePrepareDeferredForReveal, isFalse);
      expect(
        live.calls.where((c) => c == 'requestLivePhoto:$head').length,
        greaterThan(requestsBefore),
        reason: 'deferred Live prepare must run once the cover is revealed',
      );
    },
  );
}
