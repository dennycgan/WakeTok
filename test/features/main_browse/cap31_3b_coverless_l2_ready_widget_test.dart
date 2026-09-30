import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_playback_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

const _tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Future<void> _pumpAsyncWork(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Finder _pageFor(String id) {
  return find.byWidgetPredicate(
    (w) => w is MediaFeedPage && w.assetIdentifier == id,
    skipOffstage: false,
  );
}

void main() {
  testWidgets(
    'W-31.3b-1 head coverless L2-ready entry: revisit skips fast path and '
    'keeps a poster',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final playback = FakePlaybackRepository();
      for (final id in const ['v1', 'v2']) {
        final file = File('${Directory.systemTemp.path}/wt_31_3b_$id.png');
        file.writeAsBytesSync(base64Decode(_tinyPng));
        display.displayErrorById[id] = 'unsupportedMedia';
        display.previewsById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.video,
          localFilePath: file.path,
        );
      }
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            videosIds: const ['v1', 'v2'],
            availabilityById: const {
              'v1': AssetAvailability.deviceLocal,
              'v2': AssetAvailability.deviceLocal,
            },
          ),
          mediaDisplay: display,
          playback: playback,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(VerticalMediaFeed)),
      );
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.videos);
      await _pumpAsyncWork(tester);
      final ids =
          (await container.read(browseSessionProvider.future)).orderedAssetIds;
      final head = ids[0];

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await _pumpAsyncWork(tester);

      final session = container.read(browseL2ReadySessionProvider.notifier);
      session.record(
        FeedL2ReadyEntry(assetIdentifier: head, kind: FeedL2ReadyKind.video),
      );
      final loadGate = Completer<void>();
      playback.loadGates[head] = loadGate;

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
      await _pumpAsyncWork(tester);

      final page = tester.state<MediaFeedPageState>(_pageFor(head));
      expect(page.widget.isCurrent, isTrue);
      expect(
        page.debugMedia?.display,
        isNotNull,
        reason: 'coverless entry must not mount the video with a null poster',
      );
      expect(
        find.byKey(Key('mainBrowseFeedStill_$head'), skipOffstage: false),
        findsOneWidget,
      );
      expect(session.lookup(head), isNotNull);

      loadGate.complete();
      await _pumpAsyncWork(tester);
    },
  );
}
