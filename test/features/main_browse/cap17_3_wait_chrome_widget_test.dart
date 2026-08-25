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
    'W-17.3a current a4 suppresses spinner below T then shows after T',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final path = File('${Directory.systemTemp.path}/wt_17_3a.png');
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
      final head = ids[0];
      final page = tester.state<MediaFeedPageState>(_pageFor(head));

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a4L2ReadyEvict,
        elapsed: Duration.zero,
      );
      await tester.pump();
      expect(find.byKey(const Key('mainBrowseFeedLayer3Spinner')), findsNothing);

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a4L2ReadyEvict,
        elapsed: const Duration(milliseconds: 150),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'W-17.3b a1 miss chrome is immediate and ignores a4 T',
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
      expect(
        find.bySemanticsLabel(l10n.mainBrowseFeedLayer1Loading),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mainBrowseFeedLayer3Spinner')), findsNothing);

      display.previewGates['a1']!.complete();
      await _pumpAsyncWork(tester);
    },
  );

  testWidgets(
    'W-17.3c L2-ready still hit has no wait chrome',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      for (final id in const ['a1', 'a2', 'a3']) {
        final path = File('${Directory.systemTemp.path}/wt_17_3c_$id.png');
        path.writeAsBytesSync(base64Decode(_tinyPng));
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
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1', 'a2', 'a3'],
          ),
          mediaDisplay: display,
        ),
      );
      await _pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      expect(container.read(browseL2ReadySessionProvider)[head], isNotNull);

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await _pumpAsyncWork(tester);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
      await _pumpAsyncWork(tester);

      expect(find.byKey(const Key('mainBrowseFeedLayer3Spinner')), findsNothing);
      expect(find.byKey(const Key('mainBrowseFeedPageLoading')), findsNothing);
    },
  );

  testWidgets(
    'W-17.3d peek a4 never shows Layer3 spinner (before or after T)',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      for (final id in const ['a1', 'a2', 'a3']) {
        final path = File('${Directory.systemTemp.path}/wt_17_3d_$id.png');
        path.writeAsBytesSync(base64Decode(_tinyPng));
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
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1', 'a2', 'a3'],
          ),
          mediaDisplay: display,
        ),
      );
      await _pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await _pumpAsyncWork(tester);

      final peekPage = tester.state<MediaFeedPageState>(_pageFor(head));
      expect(peekPage.widget.isCurrent, isFalse);

      peekPage.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a4L2ReadyEvict,
        elapsed: Duration.zero,
      );
      await tester.pump();
      expect(find.byKey(const Key('mainBrowseFeedLayer3Spinner')), findsNothing);

      peekPage.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a4L2ReadyEvict,
        elapsed: const Duration(seconds: 5),
      );
      await tester.pump();
      expect(find.byKey(const Key('mainBrowseFeedLayer3Spinner')), findsNothing);
    },
  );

  testWidgets(
    'W-17.3h a4 loading gate suppresses miss spinner (B)',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final path = File('${Directory.systemTemp.path}/wt_17_3h.png');
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
      final head = ids[0];
      final page = tester.state<MediaFeedPageState>(_pageFor(head));

      page.debugForceA4LoadingGate();
      await tester.pump();
      expect(find.byKey(const Key('mainBrowseFeedPageLoading')), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseFeedPageLoadingSpinner')),
        findsNothing,
        reason: 'a4 eviction loading must not use a1 miss gold',
      );
      expect(find.byKey(const Key('mainBrowseFeedLayer3Spinner')), findsNothing);
    },
  );

  testWidgets(
    'W-17.3j still a2 suppresses below T then shows after T (G)',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final path = File('${Directory.systemTemp.path}/wt_17_3j.png');
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
      final head = ids[0];
      final page = tester.state<MediaFeedPageState>(_pageFor(head));

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: Duration.zero,
        mediaKind: FeedPageMediaKind.still,
      );
      await tester.pump();
      expect(find.byKey(const Key('mainBrowseFeedLayer3Spinner')), findsNothing);

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: const Duration(milliseconds: 150),
        mediaKind: FeedPageMediaKind.still,
      );
      await tester.pump();
      expect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'W-17.3k video a2 remains immediate regardless of elapsed (G still-only)',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final path = File('${Directory.systemTemp.path}/wt_17_3k.png');
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
      final head = ids[0];
      final page = tester.state<MediaFeedPageState>(_pageFor(head));

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: Duration.zero,
        mediaKind: FeedPageMediaKind.video,
      );
      await tester.pump();
      expect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
        findsOneWidget,
        reason: 'G must not suppress video a2 below T',
      );
    },
  );

  testWidgets(
    'W-17.3l L2 success clears inFlight without min-show hold',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final path = File('${Directory.systemTemp.path}/wt_17_3l.png');
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
      final head = ids[0];
      final page = tester.state<MediaFeedPageState>(_pageFor(head));

      page.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a4L2ReadyEvict,
        elapsed: const Duration(milliseconds: 150),
      );
      await tester.pump();
      expect(find.byKey(const Key('mainBrowseFeedLayer3Spinner')), findsOneWidget);

      page.debugCompleteLayer2InFlightForSuccess();
      await tester.pump();
      expect(page.debugLayer2InFlight, isFalse);
      expect(find.byKey(const Key('mainBrowseFeedLayer3Spinner')), findsNothing);
    },
  );
}
