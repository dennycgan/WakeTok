import 'dart:async';
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
import 'package:waketok/features/main_browse/wait_chrome_policy.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_playback_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

Future<void> _pumpAsyncWork(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<List<String>> _feedOrderedIds(WidgetTester tester) async {
  final element = tester.element(find.byType(VerticalMediaFeed));
  final container = ProviderScope.containerOf(element);
  return (await container.read(browseSessionProvider.future)).orderedAssetIds;
}

Finder _pageFor(String id) {
  return find.byWidgetPredicate(
    (w) => w is MediaFeedPage && w.assetIdentifier == id,
    skipOffstage: false,
  );
}

const _tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  testWidgets(
    'W-17.5b-dual coverless L2 ≥3s shows center Layer2Waiting and corner reassure',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      display.displayGates['a1'] = Completer<void>();
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
          mediaDisplay: display,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await _pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final page = tester.state<MediaFeedPageState>(_pageFor(ids[0]));

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: kLayer2CornerReassureAfter,
        mediaKind: FeedPageMediaKind.pendingVideo,
      );
      await tester.pump();

      expect(find.byKey(const Key('mainBrowseFeedCoverlessWaitLabel')), findsOneWidget);
      expect(find.text(l10n.mainBrowseFeedLayer2Waiting), findsWidgets);
      expect(find.byKey(const Key('mainBrowseFeedLayer2Reassure')), findsOneWidget);
      expect(find.text(l10n.mainBrowseFeedLayer2Reassure), findsOneWidget);
    },
  );

  testWidgets(
    'W-17.5b-covered L1/poster shows corner reassure without center Layer2Waiting',
    (tester) async {
      final path = File('${Directory.systemTemp.path}/wt_175b_covered.png');
      path.writeAsBytesSync(base64Decode(_tinyPng));
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      display.displaysById['a1'] = DisplayAsset(
        assetIdentifier: 'a1',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: path.path,
      );
      display.previewsById['a1'] = display.displaysById['a1']!;
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
          mediaDisplay: display,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await _pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final page = tester.state<MediaFeedPageState>(_pageFor(ids[0]));

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: kLayer2CornerReassureAfter,
        mediaKind: FeedPageMediaKind.still,
      );
      await tester.pump();

      expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
      expect(find.byKey(const Key('mainBrowseFeedLayer2Reassure')), findsOneWidget);
      expect(find.text(l10n.mainBrowseFeedLayer2Reassure), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseFeedCoverlessWaitLabel')),
        findsNothing,
        reason: 'center Layer2Waiting stays coverless-only; must not cover L1',
      );
    },
  );

  testWidgets(
    'W-17.5b-below-3s coverless wait has center copy but no corner reassure',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      display.displayGates['a1'] = Completer<void>();
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
          mediaDisplay: display,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await _pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final page = tester.state<MediaFeedPageState>(_pageFor(ids[0]));

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: const Duration(seconds: 2),
        mediaKind: FeedPageMediaKind.pendingVideo,
      );
      await tester.pump();

      expect(find.byKey(const Key('mainBrowseFeedCoverlessWaitLabel')), findsOneWidget);
      expect(find.byKey(const Key('mainBrowseFeedLayer2Reassure')), findsNothing);
    },
  );

  testWidgets(
    'W-17.5b-g1 leave current clears page-failed Retry on peek',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      display.displayGates['a1'] = Completer<void>();
      display.displayGates['a2'] = Completer<void>();
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
          mediaDisplay: display,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await _pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final page = tester.state<MediaFeedPageState>(_pageFor(ids[0]));

      page.debugForcePageFailed();
      await tester.pump();
      expect(find.byKey(const Key('mainBrowseFeedPageFailed')), findsOneWidget);
      expect(find.byKey(const Key('mainBrowseFeedPageRetry')), findsOneWidget);

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byKey(const Key('mainBrowseFeedPageRetry'), skipOffstage: false),
        findsNothing,
        reason: 'G1: peek must not keep PageFailed Retry after leave',
      );
    },
  );

  testWidgets(
    'W-17.5b-gen stale 3s timer after re-arm does not paint reassure',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      display.displayGates['a1'] = Completer<void>();
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
          mediaDisplay: display,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await _pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final page = tester.state<MediaFeedPageState>(_pageFor(ids[0]));

      // Arm gen=1 at t=0 so a 3s Timer is scheduled.
      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: Duration.zero,
        generation: 1,
        mediaKind: FeedPageMediaKind.pendingVideo,
      );
      await tester.pump();

      // Re-arm gen=2 before the old timer fires.
      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: Duration.zero,
        generation: 2,
        mediaKind: FeedPageMediaKind.pendingVideo,
      );
      await tester.pump();

      // Old gen=1 timer would have fired here; must not show reassure
      // (elapsed still 0 under gen=2).
      await tester.pump(kLayer2CornerReassureAfter);
      expect(find.byKey(const Key('mainBrowseFeedLayer2Reassure')), findsNothing);

      // Fresh gen=2 past 3s still shows when elapsed override says so.
      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: kLayer2CornerReassureAfter,
        generation: 2,
        mediaKind: FeedPageMediaKind.pendingVideo,
      );
      await tester.pump();
      expect(find.byKey(const Key('mainBrowseFeedLayer2Reassure')), findsOneWidget);
    },
  );

  testWidgets(
    'W-17.5b-a4 path never shows corner reassure',
    (tester) async {
      final path = File('${Directory.systemTemp.path}/wt_175b_a4.png');
      path.writeAsBytesSync(base64Decode(_tinyPng));
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      display.displaysById['a1'] = DisplayAsset(
        assetIdentifier: 'a1',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: path.path,
      );
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
          mediaDisplay: display,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await _pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final page = tester.state<MediaFeedPageState>(_pageFor(ids[0]));

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a4L2ReadyEvict,
        elapsed: kLayer2CornerReassureAfter,
        mediaKind: FeedPageMediaKind.pendingVideo,
      );
      await tester.pump();
      expect(find.byKey(const Key('mainBrowseFeedLayer2Reassure')), findsNothing);
    },
  );

  testWidgets(
    'W-17.5b-live LIVE badge stacks above spinner/reassure and pins trailing',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      display.displayGates['a1'] = Completer<void>();
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
          mediaDisplay: display,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await _pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final page = tester.state<MediaFeedPageState>(_pageFor(ids[0]));

      page.debugForceLiveBadgeVisible = true;
      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: kLayer2CornerReassureAfter,
        mediaKind: FeedPageMediaKind.pendingVideo,
      );
      await tester.pump();

      expect(find.byKey(const Key('mainBrowseLiveBadge')), findsOneWidget);
      expect(find.byKey(const Key('mainBrowseFeedLayer2Reassure')), findsOneWidget);
      expect(find.byKey(const Key('mainBrowseFeedLayer3Spinner')), findsOneWidget);
      expect(find.byKey(const Key('mainBrowseFeedCoverlessWaitLabel')), findsOneWidget);

      // Corner collision lock: LIVE above spinner/reassure (not a side-by-side
      // row that recreates the horizontal LIVE|reassure|spinner clash).
      final live = tester.getRect(find.byKey(const Key('mainBrowseLiveBadge')));
      final spinner = tester.getRect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
      );
      final reassure = tester.getRect(
        find.byKey(const Key('mainBrowseFeedLayer2Reassure')),
      );
      expect(
        live.bottom,
        lessThanOrEqualTo(spinner.top),
        reason: 'LIVE must stack above the gold spinner',
      );
      expect(
        live.bottom,
        lessThanOrEqualTo(reassure.top),
        reason: 'LIVE must stack above corner reassure copy',
      );
      // Independent trailing pin (not sized against the spinner row).
      expect(
        live.right,
        closeTo(spinner.right, 0.5),
        reason: 'LIVE and spinner share the same trailing edge (inset)',
      );
      expect(find.text(l10n.mainBrowseLiveBadge), findsWidgets);
    },
  );

  testWidgets(
    'W-17.5b-cancel-order page Retry awaits cancel before load',
    (tester) async {
      final playback = FakePlaybackRepository();
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      display.displayGates['v1'] = Completer<void>();
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['v1'],
            videosIds: const ['v1'],
          ),
          mediaDisplay: display,
          playback: playback,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await _pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final page = tester.state<MediaFeedPageState>(_pageFor(ids[0]));

      page.debugForcePageFailed();
      await tester.pump();
      expect(find.byKey(const Key('mainBrowseFeedPageRetry')), findsOneWidget);

      playback.calls.clear();
      await tester.tap(find.byKey(const Key('mainBrowseFeedPageRetry')));
      await _pumpAsyncWork(tester);

      final cancelIdx = playback.calls.indexWhere(
        (c) => c.startsWith('cancelInFlightPrepare:'),
      );
      expect(
        cancelIdx,
        isNonNegative,
        reason: 'fail Retry must cancel stale prepare first',
      );
      final loadIdx = playback.calls.indexWhere((c) => c.startsWith('load:'));
      if (loadIdx >= 0) {
        expect(
          cancelIdx,
          lessThan(loadIdx),
          reason: 'Cap16 serial: cancel before same-id load',
        );
      }
    },
  );

  testWidgets(
    'W-17.5b-cancel-order resume-fail awaits cancel before reload',
    (tester) async {
      final playback = FakePlaybackRepository();
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      display.displayGates['v1'] = Completer<void>();
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['v1'],
            videosIds: const ['v1'],
          ),
          mediaDisplay: display,
          playback: playback,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await _pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final page = tester.state<MediaFeedPageState>(_pageFor(ids[0]));

      page.debugForcePageFailed();
      await tester.pump();

      playback.calls.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _pumpAsyncWork(tester);

      final cancelIdx = playback.calls.indexWhere(
        (c) => c.startsWith('cancelInFlightPrepare:'),
      );
      expect(
        cancelIdx,
        isNonNegative,
        reason: 'resume-fail must cancel stale prepare first',
      );
      final loadIdx = playback.calls.indexWhere((c) => c.startsWith('load:'));
      if (loadIdx >= 0) {
        expect(cancelIdx, lessThan(loadIdx));
      }
    },
  );
}
