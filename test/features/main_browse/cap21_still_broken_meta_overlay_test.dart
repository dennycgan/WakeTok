import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/main_browse/feed_page_media.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';
import 'package:waketok/features/main_browse/wait_chrome_policy.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

/// Cap 21.6 residual (narrowed Cap 26.4b): hide MediaInfoOverlay while
/// still/poster has no decoded frame yet **or** decode is broken — without
/// coupling hide to [_layer2InFlight] alone (normal L2 wait with a painted
/// cover keeps Meta + spinner).
///
/// Cap 26.4b: corner wait spinner (and LIVE badge) stay visible while the
/// cover is only **unresolved**; decode-**broken** still hides Meta +
/// spinner + LIVE. Unresolved-only spinner hide was the LIVE-alone flash.
///
/// Policy seams call [MediaFeedPageState.debugForceStillCoverDecodeBroken]
/// / [MediaFeedPageState.debugForceStillCoverUnresolved].
/// Integration seams drive real [Image.errorBuilder] via a missing file path
/// (Cap 15.13 pattern) and A-class clear via production [_reloadPreviewFile].

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

String _writeTempPngSync(String name) {
  final file = File('${Directory.systemTemp.path}/wt_$name.png');
  file.writeAsBytesSync(base64Decode(_tinyPng));
  return file.path;
}

Future<void> _pumpUntilStillCoverReady(
  WidgetTester tester,
  MediaFeedPageState page,
) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    if (page.debugStillCoverReady && !page.debugStillCoverDecodeBroken) {
      // Extra pump so Overlay rebuilds after ready setState.
      await tester.pump();
      return;
    }
  }
  fail(
    'still cover never became ready '
    '(ready=${page.debugStillCoverReady} broken=${page.debugStillCoverDecodeBroken})',
  );
}

/// FileImage resolve/error runs on the real event loop (Cap 15.13 pattern).
Future<void> _pumpUntilFileImageErrors(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<MediaFeedPageState> _pumpPhotosHeadPage(
  WidgetTester tester, {
  required FakeMediaDisplayRepository display,
  required String headPath,
  String? neighborPath,
}) async {
  final other = neighborPath ?? _writeTempPngSync('21_6_meta_neighbor');
  for (final id in const ['a1', 'a2']) {
    final path = id == 'a1' ? headPath : other;
    display.previewsById[id] = DisplayAsset(
      assetIdentifier: id,
      mediaKind: PlaybackMediaKind.image,
      localFilePath: path,
    );
    display.displaysById[id] = DisplayAsset(
      assetIdentifier: id,
      mediaKind: PlaybackMediaKind.image,
      localFilePath: path,
    );
  }
  await tester.pumpWidget(
    permissionUiHarness(
      repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
      assetSources: FakeAssetSourceRepository(photosIds: const ['a1', 'a2']),
      mediaDisplay: display,
      browseLayer2Dwell: Duration.zero,
    ),
  );
  await _pumpAsyncWork(tester);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(VerticalMediaFeed)),
  );
  container
      .read(mainBrowseSelectedSourceProvider.notifier)
      .select(SourceReference.photos);
  await _pumpAsyncWork(tester);
  final ids = await _feedOrderedIds(tester);
  final head = ids[0];
  return tester.state<MediaFeedPageState>(_pageFor(head));
}

void main() {
  testWidgets(
    'W-21.6-meta-broken: still + decode-broken hides Meta and spinner '
    'even if L2 in flight',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final ok = _writeTempPngSync('21_6_meta_broken_ok');
      final page = await _pumpPhotosHeadPage(
        tester,
        display: display,
        headPath: ok,
      );
      await _pumpUntilStillCoverReady(tester, page);

      // ≥T so still a2 wait chrome would paint (ADR-034 G).
      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: const Duration(milliseconds: 200),
      );
      await tester.pump();
      expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
        findsOneWidget,
      );

      page.debugForceStillCoverDecodeBroken(true);
      await tester.pump();
      expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
      expect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
        findsNothing,
      );
      expect(page.debugStillCoverDecodeBroken, isTrue);
      expect(page.debugLayer2InFlight, isTrue);
    },
  );

  testWidgets(
    'W-21.6-meta-l2wait: L2 in flight without broken keeps Meta + spinner',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final ok = _writeTempPngSync('21_6_meta_l2wait_ok');
      final page = await _pumpPhotosHeadPage(
        tester,
        display: display,
        headPath: ok,
      );
      await _pumpUntilStillCoverReady(tester, page);

      // mediaKind omitted so debugForce does not swap in missing
      // `/tmp/cap173_chrome_still.png` (would false-trigger broken once wired).
      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: const Duration(milliseconds: 200),
      );
      await tester.pump();

      expect(page.debugStillCoverDecodeBroken, isFalse);
      expect(page.debugStillCoverReady, isTrue);
      expect(page.debugLayer2InFlight, isTrue);
      expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'W-21.6-meta-broken-wire: FileImage errorBuilder hides Meta (integration)',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final page = await _pumpPhotosHeadPage(
        tester,
        display: display,
        headPath: '/tmp/wt_21_6_meta_missing_head.jpg',
        neighborPath: _writeTempPngSync('21_6_meta_wire_neighbor'),
      );

      await _pumpUntilFileImageErrors(tester);
      await _pumpUntilFileImageErrors(tester);

      expect(
        page.debugStillCoverDecodeBroken,
        isTrue,
        reason: 'errorBuilder → _onPreviewFileBroken must set the bit',
      );
      expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
      expect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'W-21.6-meta-recover: production reload heal clears bit and restores Meta',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final pathA = _writeTempPngSync('21_6_meta_recover_a');
      final pathB = _writeTempPngSync('21_6_meta_recover_b');
      final page = await _pumpPhotosHeadPage(
        tester,
        display: display,
        headPath: pathA,
      );
      await _pumpUntilStillCoverReady(tester, page);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];

      expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);

      // Policy arm (sets tried path to current cover for A-class clear).
      page.debugForceStillCoverDecodeBroken(true);
      await tester.pump();
      expect(page.debugStillCoverDecodeBroken, isTrue);
      expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);

      // Next requestPreview returns a different path → production clear.
      display.previewReloadHealById.clear();
      display.previewsById[head] = DisplayAsset(
        assetIdentifier: head,
        mediaKind: PlaybackMediaKind.image,
        localFilePath: pathB,
      );

      await tester.runAsync(() async {
        await page.debugRunReloadPreviewFile();
      });
      await _pumpUntilStillCoverReady(tester, page);

      expect(
        page.debugStillCoverDecodeBroken,
        isFalse,
        reason: 'A-class clear must run via production _reloadPreviewFile',
      );
      expect(page.debugStillCoverReady, isTrue);
      expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);
    },
  );

  testWidgets(
    'W-26.4b-unresolved-keeps-spinner: Meta hidden, Layer3 spinner stays',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final ok = _writeTempPngSync('26_4b_unresolved_ok');
      final page = await _pumpPhotosHeadPage(
        tester,
        display: display,
        headPath: ok,
      );
      await _pumpUntilStillCoverReady(tester, page);

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: const Duration(milliseconds: 200),
      );
      await tester.pump();
      expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
        findsOneWidget,
      );

      page.debugForceStillCoverUnresolved();
      await tester.pump();
      expect(page.debugStillCoverReady, isFalse);
      expect(page.debugStillCoverDecodeBroken, isFalse);
      expect(
        find.byKey(const Key('mediaInfoOverlay')),
        findsNothing,
        reason: 'unresolved still suppresses Meta',
      );
      expect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
        findsOneWidget,
        reason: 'Cap 26.4b: unresolved must not hide corner spinner',
      );
    },
  );

  testWidgets(
    'W-26.4b-live-unresolved-keeps-spinner: LIVE + spinner, no Meta',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final ok = _writeTempPngSync('26_4b_live_unresolved_ok');
      final page = await _pumpPhotosHeadPage(
        tester,
        display: display,
        headPath: ok,
      );
      await _pumpUntilStillCoverReady(tester, page);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: const Duration(milliseconds: 200),
        mediaKind: FeedPageMediaKind.still,
        stillPlaybackKind: PlaybackMediaKind.livePhoto,
      );
      await tester.pump();
      page.debugForceStillCoverUnresolved();
      await tester.pump();

      expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
      expect(
        find.byKey(Key('mainBrowseFeedLivePreparing_$head')),
        findsOneWidget,
        reason: 'unresolved Live must keep prepare/wait spinner',
      );
      expect(
        find.byKey(Key('mainBrowseFeedLiveChrome_$head')),
        findsOneWidget,
        reason: 'LIVE badge may stay with spinner while cover unresolved',
      );
    },
  );

  testWidgets(
    'W-26.4b-live-broken-hides-live: Meta + spinner + LIVE all gone',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final ok = _writeTempPngSync('26_4b_live_broken_ok');
      final page = await _pumpPhotosHeadPage(
        tester,
        display: display,
        headPath: ok,
      );
      await _pumpUntilStillCoverReady(tester, page);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: const Duration(milliseconds: 200),
        mediaKind: FeedPageMediaKind.still,
        stillPlaybackKind: PlaybackMediaKind.livePhoto,
      );
      await tester.pump();
      expect(
        find.byKey(Key('mainBrowseFeedLiveChrome_$head')),
        findsOneWidget,
      );

      page.debugForceStillCoverDecodeBroken(true);
      await tester.pump();

      expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
      expect(
        find.byKey(Key('mainBrowseFeedLivePreparing_$head')),
        findsNothing,
      );
      expect(
        find.byKey(Key('mainBrowseFeedLiveChrome_$head')),
        findsNothing,
        reason: 'decode-broken hides LIVE with Meta/spinner',
      );
    },
  );

  testWidgets(
    'W-26.4b-A2a-l2-below-T: unresolved + layer2InFlight forces spinner',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final ok = _writeTempPngSync('26_4b_a2a_l2');
      final page = await _pumpPhotosHeadPage(
        tester,
        display: display,
        headPath: ok,
      );
      await _pumpUntilStillCoverReady(tester, page);

      // Still a2 G: elapsed < T ⇒ evaluateWaitChrome paint path false.
      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: const Duration(milliseconds: 50),
      );
      page.debugForceStillCoverUnresolved();
      await tester.pump();

      expect(page.debugStillCoverReady, isFalse);
      expect(page.debugStillCoverDecodeBroken, isFalse);
      expect(page.debugLayer2InFlight, isTrue);
      expect(page.debugLivePreparing, isFalse);
      expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
      expect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
        findsOneWidget,
        reason: 'A2a: unresolved ∧ _layer2InFlight forces spinner under G <T',
      );
    },
  );

  testWidgets(
    'W-26.4b-A2a-live-F1: unresolved + livePreparing forces spinner',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final ok = _writeTempPngSync('26_4b_a2a_live_f1');
      final page = await _pumpPhotosHeadPage(
        tester,
        display: display,
        headPath: ok,
      );
      await _pumpUntilStillCoverReady(tester, page);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: const Duration(milliseconds: 200),
        mediaKind: FeedPageMediaKind.still,
        stillPlaybackKind: PlaybackMediaKind.livePhoto,
      );
      await tester.pump();
      page.debugCompleteLayer2InFlightForSuccess();
      page.debugForceStillCoverUnresolved();
      final generation = page.debugBeginLiveMotionGate();
      page.debugSetLivePreparing(generation, true);
      // Do not pump past F1 T — raw _showLiveLoadSpinner must stay false.
      await tester.pump();

      expect(page.debugLayer2InFlight, isFalse);
      expect(page.debugLivePreparing, isTrue);
      expect(page.debugStillCoverReady, isFalse);
      expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
      expect(
        find.byKey(Key('mainBrowseFeedLivePreparing_$head')),
        findsOneWidget,
        reason: 'A2a: unresolved ∧ _livePreparing forces spinner under F1',
      );
      expect(
        find.byKey(Key('mainBrowseFeedLiveChrome_$head')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'W-26.4b-A2a-honesty: unresolved without host work does not force spinner',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final ok = _writeTempPngSync('26_4b_a2a_honesty');
      final page = await _pumpPhotosHeadPage(
        tester,
        display: display,
        headPath: ok,
      );
      await _pumpUntilStillCoverReady(tester, page);

      page.debugForceStillCoverUnresolved();
      await tester.pump();

      expect(page.debugStillCoverReady, isFalse);
      expect(page.debugStillCoverDecodeBroken, isFalse);
      expect(page.debugLayer2InFlight, isFalse);
      expect(page.debugLivePreparing, isFalse);
      expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
      expect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
        findsNothing,
        reason: 'honesty: unresolved alone must not fake a spinner',
      );
    },
  );
}
