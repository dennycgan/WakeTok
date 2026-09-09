import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/features/main_browse/feed_page_media.dart';
import 'package:waketok/features/main_browse/magnification_surface.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

/// Cap 15.5 / debt 450: still cover Image Element must survive L1↔L2.
///
/// Required on every Coding Task that touches still cover /
/// `magnification_surface` / feed still tree (see `00-workflow-gates.mdc`).
void main() {
  setUpAll(() {
    // Minimal JPEG so Image stays in tree (errorBuilder → ColoredBox).
    final jpeg = File('/tmp/waketok_continuity_seed.jpg');
    if (!jpeg.existsSync()) {
      jpeg.writeAsBytesSync(const <int>[
        0xFF, 0xD8, 0xFF, 0xD9,
      ]);
    }
  });

  Future<void> pumpAsync(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets(
    'W-15.5a L1→L2 reuses Image State (enter / promote continuity)',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      display.previewsById['a1'] = const DisplayAsset(
        assetIdentifier: 'a1',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: '/tmp/waketok_continuity_l1.jpg',
      );
      display.displaysById['a1'] = const DisplayAsset(
        assetIdentifier: 'a1',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: '/tmp/waketok_continuity_l2.jpg',
      );
      File('/tmp/waketok_continuity_l1.jpg').writeAsBytesSync(
        File('/tmp/waketok_continuity_seed.jpg').readAsBytesSync(),
      );
      File('/tmp/waketok_continuity_l2.jpg').writeAsBytesSync(
        File('/tmp/waketok_continuity_seed.jpg').readAsBytesSync(),
      );
      display.displayGates['a1'] = Completer<void>();

      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
          mediaDisplay: display,
        ),
      );
      await pumpAsync(tester);

      final still = find.byKey(const Key('mainBrowseFeedStill_a1'));
      final imageFinder = find.descendant(
        of: still,
        matching: find.byType(Image),
      );
      expect(imageFinder, findsOneWidget);
      final binderL1 = tester.widget<MagnificationHostModeBinder>(
        find.descendant(
          of: still,
          matching: find.byType(MagnificationHostModeBinder),
        ),
      );
      expect(binderL1.persistent, isFalse);
      final stateL1 = (tester.element(imageFinder) as StatefulElement).state;

      display.displayGates['a1']!.complete();
      await pumpAsync(tester);

      expect(imageFinder, findsOneWidget);
      final binderL2 = tester.widget<MagnificationHostModeBinder>(
        find.descendant(
          of: still,
          matching: find.byType(MagnificationHostModeBinder),
        ),
      );
      expect(binderL2.persistent, isTrue);
      final stateL2 = (tester.element(imageFinder) as StatefulElement).state;
      expect(
        identical(stateL1, stateL2),
        isTrue,
        reason: 'enter L1→L2 must reuse Image State (gapless / Cap 15.5)',
      );
    },
  );

  testWidgets(
    'W-15.5c leave L2→L1 demote reuses Image State (leave continuity)',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      // Cap 22.5: leave 0→1 must not mount the endless-round bridge page
      // (prepare at n-2), or a reused head id duplicates still keys.
      const pool = ['a1', 'a2', 'a3', 'a4', 'a5'];
      for (final id in pool) {
        final l1 = '/tmp/waketok_continuity_${id}_l1.jpg';
        final l2 = '/tmp/waketok_continuity_${id}_l2.jpg';
        File(l1).writeAsBytesSync(
          File('/tmp/waketok_continuity_seed.jpg').readAsBytesSync(),
        );
        File(l2).writeAsBytesSync(
          File('/tmp/waketok_continuity_seed.jpg').readAsBytesSync(),
        );
        display.previewsById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.image,
          localFilePath: l1,
        );
        display.displaysById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.image,
          localFilePath: l2,
        );
      }

      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: pool),
          mediaDisplay: display,
          browseShuffleSeed: 0,
        ),
      );
      await pumpAsync(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VerticalMediaFeed)),
      );
      final headId = container
          .read(browseSessionProvider)
          .requireValue
          .orderedAssetIds
          .first;

      final stillHead = find.byKey(
        Key('mainBrowseFeedStill_$headId'),
        skipOffstage: false,
      );
      final imageFinder = find.descendant(
        of: stillHead,
        matching: find.byType(Image, skipOffstage: false),
        skipOffstage: false,
      );
      expect(imageFinder, findsOneWidget);
      expect(
        tester
            .widget<MagnificationHostModeBinder>(
              find.descendant(
                of: stillHead,
                matching: find.byType(
                  MagnificationHostModeBinder,
                  skipOffstage: false,
                ),
                skipOffstage: false,
              ),
            )
            .persistent,
        isTrue,
      );
      final stateBefore =
          (tester.element(imageFinder) as StatefulElement).state;

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await pumpAsync(tester);

      expect(imageFinder, findsOneWidget);
      final binderAfter = tester.widget<MagnificationHostModeBinder>(
        find.descendant(
          of: stillHead,
          matching: find.byType(
            MagnificationHostModeBinder,
            skipOffstage: false,
          ),
          skipOffstage: false,
        ),
      );
      expect(binderAfter.persistent, isFalse);
      expect(
        tester
            .state<MediaFeedPageState>(
              find.byWidgetPredicate(
                (w) =>
                    w is MediaFeedPage &&
                    w.assetIdentifier == headId &&
                    w.feedIndex == 0,
                skipOffstage: false,
              ),
            )
            .debugMedia
            ?.displayLayer,
        FeedDisplayLayer.preview,
      );
      final stateAfter =
          (tester.element(imageFinder) as StatefulElement).state;
      expect(
        identical(stateBefore, stateAfter),
        isTrue,
        reason: 'leave L2→L1 demote must reuse Image State',
      );
    },
  );
}
