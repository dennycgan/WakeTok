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
    'W-17.4a still a2 below T: no spinner and no Layer2Waiting label (G door)',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final path = File('${Directory.systemTemp.path}/wt_17_4a.png');
      path.writeAsBytesSync(base64Decode(_tinyPng));
      for (final id in const ['a1', 'a2']) {
        display.displaysById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.image,
          localFilePath: path.path,
        );
        display.previewsById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.image,
          localFilePath: path.path,
        );
      }
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
          mediaDisplay: display,
        ),
      );
      await _pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final page = tester.state<MediaFeedPageState>(_pageFor(ids[0]));

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: Duration.zero,
        mediaKind: FeedPageMediaKind.still,
      );
      await tester.pump();
      expect(find.byKey(const Key('mainBrowseFeedLayer3Spinner')), findsNothing);
      expect(find.text(l10n.mainBrowseFeedLayer2Waiting), findsNothing);
      expect(
        find.byKey(const Key('mainBrowseFeedCoverlessWaitLabel')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'W-17.4b still a2 after T: spinner yes; Layer2Waiting absent (has cover)',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final path = File('${Directory.systemTemp.path}/wt_17_4b.png');
      path.writeAsBytesSync(base64Decode(_tinyPng));
      for (final id in const ['a1', 'a2']) {
        display.displaysById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.image,
          localFilePath: path.path,
        );
        display.previewsById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.image,
          localFilePath: path.path,
        );
      }
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
          mediaDisplay: display,
        ),
      );
      await _pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final page = tester.state<MediaFeedPageState>(_pageFor(ids[0]));

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: const Duration(milliseconds: 150),
        mediaKind: FeedPageMediaKind.still,
      );
      await tester.pump();
      expect(find.byKey(const Key('mainBrowseFeedLayer3Spinner')), findsOneWidget);
      expect(find.text(l10n.mainBrowseFeedLayer2Waiting), findsNothing);
    },
  );

  testWidgets(
    'W-17.4c coverless video a2 immediate: spinner and Layer2Waiting together',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final path = File('${Directory.systemTemp.path}/wt_17_4c.png');
      path.writeAsBytesSync(base64Decode(_tinyPng));
      for (final id in const ['a1', 'a2']) {
        display.displaysById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.video,
          localFilePath: path.path,
        );
        display.previewsById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.video,
          localFilePath: path.path,
        );
      }
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
          mediaDisplay: display,
        ),
      );
      await _pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final page = tester.state<MediaFeedPageState>(_pageFor(ids[0]));

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: Duration.zero,
        mediaKind: FeedPageMediaKind.pendingVideo,
      );
      await tester.pump();
      expect(find.byKey(const Key('mainBrowseFeedLayer3Spinner')), findsOneWidget);
      expect(find.text(l10n.mainBrowseFeedLayer2Waiting), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseFeedCoverlessWaitLabel')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'W-17.4d a1 miss: Layer1Loading visible with spinner (immediate)',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final display = FakeMediaDisplayRepository();
      display.previewGates['a1'] = Completer<void>();
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
          mediaDisplay: display,
        ),
      );
      await _pumpAsyncWork(tester);

      expect(find.byKey(const Key('mainBrowseFeedPageLoading')), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseFeedPageLoadingSpinner')),
        findsOneWidget,
      );
      expect(find.text(l10n.mainBrowseFeedLayer1Loading), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseFeedCoverlessWaitLabel')),
        findsOneWidget,
      );

      display.previewGates['a1']!.complete();
      await _pumpAsyncWork(tester);
    },
  );

  testWidgets(
    'W-17.4e a4 loading gate: no miss gold and no coverless label (B)',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final path = File('${Directory.systemTemp.path}/wt_17_4e.png');
      path.writeAsBytesSync(base64Decode(_tinyPng));
      display.displaysById['a1'] = DisplayAsset(
        assetIdentifier: 'a1',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: path.path,
      );
      display.previewsById['a1'] = DisplayAsset(
        assetIdentifier: 'a1',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: path.path,
      );
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
          mediaDisplay: display,
        ),
      );
      await _pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final page = tester.state<MediaFeedPageState>(_pageFor(ids[0]));

      page.debugForceA4LoadingGate();
      await tester.pump();
      expect(find.byKey(const Key('mainBrowseFeedPageLoading')), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseFeedPageLoadingSpinner')),
        findsNothing,
      );
      expect(find.text(l10n.mainBrowseFeedLayer1Loading), findsNothing);
      expect(find.text(l10n.mainBrowseFeedLayer2Waiting), findsNothing);
      expect(
        find.byKey(const Key('mainBrowseFeedCoverlessWaitLabel')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'W-17.4f coverless wait copy and failed replace; never stacked',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final path = File('${Directory.systemTemp.path}/wt_17_4f.png');
      path.writeAsBytesSync(base64Decode(_tinyPng));
      for (final id in const ['a1', 'a2']) {
        display.displaysById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.video,
          localFilePath: path.path,
        );
        display.previewsById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.video,
          localFilePath: path.path,
        );
      }
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
          mediaDisplay: display,
        ),
      );
      await _pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final page = tester.state<MediaFeedPageState>(_pageFor(ids[0]));

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: Duration.zero,
        mediaKind: FeedPageMediaKind.pendingVideo,
      );
      await tester.pump();
      expect(find.text(l10n.mainBrowseFeedLayer2Waiting), findsOneWidget);
      expect(find.text(l10n.mainBrowseFeedMediaFailed), findsNothing);

      page.debugForceCoverlessLayer2Failed();
      await tester.pump();
      expect(find.text(l10n.mainBrowseFeedLayer2Waiting), findsNothing);
      expect(find.text(l10n.mainBrowseFeedMediaFailed), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseFeedCoverlessFailedSlot')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mainBrowseFeedCoverlessWaitLabel')),
        findsNothing,
      );
    },
  );
}
