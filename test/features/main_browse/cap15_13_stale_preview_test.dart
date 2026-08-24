import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_l2_ready_session.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

/// Must match [PhotosAccessGate] resume refresh delay (pending-timer drain).
const _photosAccessGateResumeRefreshDelay = Duration(milliseconds: 300);

Future<void> pumpAsyncWork(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Sync write — `await File.writeAsBytes` never completes under FakeAsync.
String writeTempPngSync(String name) {
  final file = File('${Directory.systemTemp.path}/wt_$name.png');
  file.writeAsBytesSync(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    ),
  );
  return file.path;
}

Future<List<String>> feedOrderedIds(WidgetTester tester) async {
  final element = tester.element(find.byType(VerticalMediaFeed));
  final container = ProviderScope.containerOf(element);
  return (await container.read(browseSessionProvider.future)).orderedAssetIds;
}

Future<void> pumpPhotosFeedAtIndex1(
  WidgetTester tester, {
  required FakeMediaDisplayRepository display,
  required Map<String, String> previewPathsById,
  Map<String, DisplayAsset>? previewReloadHealById,
}) async {
  const ids = ['p0', 'p1', 'p2'];
  if (previewReloadHealById != null) {
    display.previewReloadHealById.addAll(previewReloadHealById);
  }
  for (final id in ids) {
    final path = previewPathsById[id] ?? '/tmp/wt_15_13_missing_$id.jpg';
    display.previewsById[id] = DisplayAsset(
      assetIdentifier: id,
      mediaKind: PlaybackMediaKind.image,
      localFilePath: path,
    );
    display.displaysById[id] = DisplayAsset(
      assetIdentifier: id,
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/wt_15_13_full_$id.jpg',
    );
  }
  await tester.pumpWidget(
    permissionUiHarness(
      repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
      assetSources: FakeAssetSourceRepository(photosIds: ids),
      mediaDisplay: display,
      browseLayer2Dwell: Duration.zero,
    ),
  );
  await pumpAsyncWork(tester);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(VerticalMediaFeed)),
  );
  container
      .read(mainBrowseSelectedSourceProvider.notifier)
      .select(SourceReference.photos);
  await pumpAsyncWork(tester);
  container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
  await pumpAsyncWork(tester);
}

/// Drain [PhotosAccessGate] resume timer exactly (not an ad-hoc "enough" delay).
Future<void> pumpThroughPhotosAccessGateResume(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_photosAccessGateResumeRefreshDelay);
  await tester.pump();
}

/// FileImage resolve/error runs on the real event loop; FakeAsync alone never
/// delivers [Image.errorBuilder] (same class of issue as await writeAsBytes).
Future<void> pumpUntilFileImageErrors(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets(
    'W-15.13a current N resume evict does not off-current reload neighbor',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final validP0 = writeTempPngSync('15_13a_p0');
      await pumpPhotosFeedAtIndex1(
        tester,
        display: display,
        previewPathsById: {
          'p0': validP0,
          'p1': '/tmp/wt_15_13_missing_p1.jpg',
          'p2': '/tmp/wt_15_13_missing_p2.jpg',
        },
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(VerticalMediaFeed)),
      );
      final ordered = await feedOrderedIds(tester);
      final nId = ordered[1];
      final nMinus1 = ordered[0];
      final previewsBefore =
          display.previewCalls.where((id) => id == nMinus1).length;

      container.read(browseL2ReadySessionProvider.notifier).record(
        FeedL2ReadyEntry(
          assetIdentifier: nId,
          kind: FeedL2ReadyKind.stillFull,
          cover: DisplayAsset(
            assetIdentifier: nId,
            mediaKind: PlaybackMediaKind.image,
            localFilePath: '/tmp/wt_15_13_stale_current_token.jpg',
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpThroughPhotosAccessGateResume(tester);
      // Cap 15.13 F1 post-frame batch + yields.
      await tester.pump();
      await tester.pump();

      expect(
        container.read(browseL2ReadySessionProvider).containsKey(nId),
        isFalse,
        reason: 'resume batch must evict stale current token',
      );
      expect(
        display.previewCalls.where((id) => id == nMinus1).length,
        previewsBefore,
        reason: 'N resume must not off-current F2-reload N-1',
      );
    },
  );

  testWidgets(
    'W-15.13b N-1 valid poster does not trigger off-current F2 reload',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final validP0 = writeTempPngSync('15_13b_p0');
      final validP1 = writeTempPngSync('15_13b_p1');
      final validP2 = writeTempPngSync('15_13b_p2');
      await pumpPhotosFeedAtIndex1(
        tester,
        display: display,
        previewPathsById: {
          'p0': validP0,
          'p1': validP1,
          'p2': validP2,
        },
      );
      final ordered = await feedOrderedIds(tester);
      final nMinus1 = ordered[0];
      final countAfterPreheat =
          display.previewCalls.where((id) => id == nMinus1).length;
      expect(countAfterPreheat, greaterThanOrEqualTo(1));

      await tester.pump(const Duration(milliseconds: 100));

      expect(
        display.previewCalls.where((id) => id == nMinus1).length,
        countAfterPreheat,
        reason: 'valid N-1 poster must not F2-reload',
      );
    },
  );

  testWidgets(
    'W-15.13c N-2+ stale poster triggers off-current F2 preview reload',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final validP1 = writeTempPngSync('15_13c_p1');
      final healP2 = writeTempPngSync('15_13c_p2_heal');
      await pumpPhotosFeedAtIndex1(
        tester,
        display: display,
        previewPathsById: {
          'p0': '/tmp/wt_15_13_missing_p0.jpg',
          'p1': validP1,
          'p2': '/tmp/wt_15_13_missing_p2.jpg',
        },
        previewReloadHealById: {
          'p2': DisplayAsset(
            assetIdentifier: 'p2',
            mediaKind: PlaybackMediaKind.image,
            localFilePath: healP2,
          ),
          'p0': DisplayAsset(
            assetIdentifier: 'p0',
            mediaKind: PlaybackMediaKind.image,
            localFilePath: writeTempPngSync('15_13c_p0_heal'),
          ),
        },
      );
      final ordered = await feedOrderedIds(tester);
      // Current is index 1; both ±1 neighbors start with missing paths.
      final staleNeighbor = ordered[2];

      await pumpUntilFileImageErrors(tester);
      await pumpUntilFileImageErrors(tester);

      expect(
        display.previewCalls.where((id) => id == staleNeighbor).length,
        greaterThanOrEqualTo(2),
        reason: 'stale ±1 neighbour should self-heal via F2 requestPreview',
      );
      expect(
        display.releasePreviewCalls.where((id) => id == staleNeighbor),
        isEmpty,
      );
    },
  );

  testWidgets(
    'W-15.13d resume batch evicts only missing-path tokens',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final livePath = writeTempPngSync('15_13d_live');
      await pumpPhotosFeedAtIndex1(
        tester,
        display: display,
        previewPathsById: {
          'p0': livePath,
          'p1': livePath,
          'p2': livePath,
        },
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(VerticalMediaFeed)),
      );
      final notifier = container.read(browseL2ReadySessionProvider.notifier);
      notifier.record(
        FeedL2ReadyEntry(
          assetIdentifier: 'live',
          kind: FeedL2ReadyKind.stillFull,
          cover: DisplayAsset(
            assetIdentifier: 'live',
            mediaKind: PlaybackMediaKind.image,
            localFilePath: livePath,
          ),
        ),
      );
      notifier.record(
        const FeedL2ReadyEntry(
          assetIdentifier: 'stale_a',
          kind: FeedL2ReadyKind.video,
          cover: DisplayAsset(
            assetIdentifier: 'stale_a',
            mediaKind: PlaybackMediaKind.video,
            localFilePath: '/tmp/wt_15_13_evict_a.jpg',
          ),
        ),
      );
      notifier.record(
        const FeedL2ReadyEntry(
          assetIdentifier: 'stale_b',
          kind: FeedL2ReadyKind.stillFull,
          cover: DisplayAsset(
            assetIdentifier: 'stale_b',
            mediaKind: PlaybackMediaKind.image,
            localFilePath: '/tmp/wt_15_13_evict_b.jpg',
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpThroughPhotosAccessGateResume(tester);
      await tester.pump();
      await tester.pump();

      final map = container.read(browseL2ReadySessionProvider);
      expect(map.containsKey('live'), isTrue);
      expect(map.containsKey('stale_a'), isFalse);
      expect(map.containsKey('stale_b'), isFalse);
    },
  );

  testWidgets(
    'W-15.13e F2 reload under cap=3 LRU does not evict current or valid neighbour',
    (tester) async {
      final display = FakeMediaDisplayRepository()..enforcePreviewCapLru = true;
      final validP0 = writeTempPngSync('15_13e_p0');
      final validP1 = writeTempPngSync('15_13e_p1');
      final healP2 = writeTempPngSync('15_13e_p2_heal');
      await pumpPhotosFeedAtIndex1(
        tester,
        display: display,
        previewPathsById: {
          'p0': validP0,
          'p1': validP1,
          'p2': '/tmp/wt_15_13_missing_p2.jpg',
        },
        previewReloadHealById: {
          'p2': DisplayAsset(
            assetIdentifier: 'p2',
            mediaKind: PlaybackMediaKind.image,
            localFilePath: healP2,
          ),
        },
      );
      final ordered = await feedOrderedIds(tester);
      final currentId = ordered[1];
      final nMinus1 = ordered[0];
      // Only p2 starts missing; after Random(0) shuffle [p0,p1,p2]→[p2,p1,p0]
      // it sits at index 0 (±1 of current).
      final staleNeighbor = 'p2';
      expect(ordered.contains(staleNeighbor), isTrue);
      expect(
        (ordered.indexOf(staleNeighbor) - 1).abs(),
        1,
        reason: 'p2 must be a math ±1 neighbour of current for F2',
      );

      display.lruEvictedPreviewIds.clear();
      await pumpUntilFileImageErrors(tester);
      await pumpUntilFileImageErrors(tester);

      expect(display.lruEvictedPreviewIds, isNot(contains(currentId)));
      expect(display.lruEvictedPreviewIds, isNot(contains(nMinus1)));
      expect(
        display.releasePreviewCalls.where((id) => id == currentId),
        isEmpty,
      );
      expect(
        display.releasePreviewCalls.where((id) => id == nMinus1),
        isEmpty,
      );
      expect(
        display.previewCalls.where((id) => id == staleNeighbor).length,
        greaterThanOrEqualTo(2),
      );
    },
  );
}
