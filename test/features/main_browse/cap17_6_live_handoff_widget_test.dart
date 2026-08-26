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
import '../../library_smoke/fake_live_photo_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

Future<void> _pumpFrames(WidgetTester tester, {int n = 8}) async {
  await tester.pump();
  for (var i = 0; i < n; i++) {
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

Finder _livePreparing(String id) =>
    find.byKey(Key('mainBrowseFeedLivePreparing_$id'));

const _tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  late File coverFile;

  setUp(() {
    coverFile = File('${Directory.systemTemp.path}/wt_176_live_cover.png');
    coverFile.writeAsBytesSync(base64Decode(_tinyPng));
  });

  testWidgets(
    'W-17.6-handoff-latched long L2 chrome continues into motion without F1 dip',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final live = FakeLivePhotoRepository();
      final display = FakeMediaDisplayRepository();
      const id = 'live-1';
      final liveAsset = DisplayAsset(
        assetIdentifier: id,
        mediaKind: PlaybackMediaKind.livePhoto,
        localFilePath: coverFile.path,
      );
      display.previewsById[id] = liveAsset;
      display.displaysById[id] = liveAsset;

      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(allIds: const [id]),
          mediaDisplay: display,
          livePhoto: live,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await _pumpFrames(tester);
      final page = tester.state<MediaFeedPageState>(_pageFor(id));

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: kDefaultA4SuppressBelow,
        mediaKind: FeedPageMediaKind.still,
        stillPlaybackKind: PlaybackMediaKind.livePhoto,
      );
      await tester.pump();
      expect(_livePreparing(id), findsOneWidget);
      expect(page.debugLayer2WaitChromeLatched, isTrue);
      expect(
        find.byKey(const Key('mainBrowseFeedLayer2Reassure')),
        findsNothing,
        reason: 'reassure only after 3s; this case is past T but under 3s',
      );

      page.debugCompleteL2HandoffToLivePrepare();
      await tester.pump();

      expect(
        page.debugLivePreparingSkipSuppressBelowT,
        isTrue,
        reason: 'latched L2 wait chrome must skip F1 on motion handoff',
      );
      expect(
        _livePreparing(id),
        findsOneWidget,
        reason: 'ADR-037: no spinner dip between L2 and motion prepare',
      );
      expect(
        find.byKey(const Key('mainBrowseFeedLayer2Reassure')),
        findsNothing,
        reason: 'A1: reassure must not continue into motion',
      );
      expect(find.text(l10n.mainBrowseFeedLayer2Reassure), findsNothing);
    },
  );

  testWidgets(
    'W-17.6-handoff-unlatched short L2 keeps independent F1 suppress on motion',
    (tester) async {
      final live = FakeLivePhotoRepository();
      final display = FakeMediaDisplayRepository();
      const id = 'live-1';
      final liveAsset = DisplayAsset(
        assetIdentifier: id,
        mediaKind: PlaybackMediaKind.livePhoto,
        localFilePath: coverFile.path,
      );
      display.previewsById[id] = liveAsset;
      display.displaysById[id] = liveAsset;
      final gate = Completer<void>();
      display.displayGates[id] = gate;

      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(allIds: const [id]),
          mediaDisplay: display,
          livePhoto: live,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await _pumpFrames(tester);

      // Complete L2 while still <T so wait chrome never paints (no latch).
      await tester.pump(const Duration(milliseconds: 40));
      final page = tester.state<MediaFeedPageState>(_pageFor(id));
      expect(page.debugLayer2WaitChromeLatched, isFalse);
      expect(_livePreparing(id), findsNothing);

      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(page.debugLivePreparing, isTrue);
      expect(page.debugLivePreparingSkipSuppressBelowT, isFalse);
      expect(
        _livePreparing(id),
        findsNothing,
        reason: 'F1: unlatched motion prepare suppresses below T',
      );

      await tester.pump(kDefaultA4SuppressBelow - const Duration(milliseconds: 1));
      expect(_livePreparing(id), findsNothing);

      await tester.pump(const Duration(milliseconds: 1));
      expect(
        _livePreparing(id),
        findsOneWidget,
        reason: 'F1: spinner appears once prepare wall ≥ T',
      );
    },
  );

  testWidgets(
    'W-17.6-f1-short-prepare without L2 latch keeps F1 suppress-below-T',
    (tester) async {
      final live = FakeLivePhotoRepository();
      final display = FakeMediaDisplayRepository();
      const id = 'live-1';
      final liveAsset = DisplayAsset(
        assetIdentifier: id,
        mediaKind: PlaybackMediaKind.livePhoto,
        localFilePath: coverFile.path,
      );
      display.previewsById[id] = liveAsset;
      display.displaysById[id] = liveAsset;
      final gate = Completer<void>();
      display.displayGates[id] = gate;

      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(allIds: const [id]),
          mediaDisplay: display,
          livePhoto: live,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      // Independent short prepare: complete L2 under T (no latch), same as
      // a4/revisit arms that never painted L2 wait chrome.
      gate.complete();
      await tester.pump();
      await tester.pump();

      final page = tester.state<MediaFeedPageState>(_pageFor(id));
      expect(live.calls, contains('requestLivePhoto:$id'));
      expect(page.debugLivePreparingSkipSuppressBelowT, isFalse);
      expect(_livePreparing(id), findsNothing);

      await tester.pump(kDefaultA4SuppressBelow);
      expect(
        _livePreparing(id),
        findsOneWidget,
        reason: 'F1 reveal Timer must paint after T when unlatched',
      );
    },
  );

  testWidgets(
    'W-17.6-play-only never arms preparing or prepare spinner',
    (tester) async {
      final live = FakeLivePhotoRepository();
      final display = FakeMediaDisplayRepository();
      const id = 'live-1';
      final liveAsset = DisplayAsset(
        assetIdentifier: id,
        mediaKind: PlaybackMediaKind.livePhoto,
        localFilePath: coverFile.path,
      );
      display.previewsById[id] = liveAsset;
      display.displaysById[id] = liveAsset;
      // Hold ready so prepare stays up; play-only must still not need it.
      display.displayGates[id] = Completer<void>();

      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(allIds: const [id]),
          mediaDisplay: display,
          livePhoto: live,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await _pumpFrames(tester);
      final page = tester.state<MediaFeedPageState>(_pageFor(id));

      final gen = page.debugBeginLiveMotionGate();
      expect(page.debugLivePreparing, isFalse);
      page.debugArmPreparedLiveForPlay(generation: gen);
      await page.debugPlayLiveMotionOnce(gen);
      await tester.pump();

      expect(page.debugLivePreparing, isFalse);
      expect(_livePreparing(id), findsNothing);
      expect(live.calls, contains('startPlayback'));
      expect(
        live.calls.where((c) => c.startsWith('requestLivePhoto')),
        isEmpty,
        reason: 'play-only must not request / prepare',
      );
    },
  );
}
