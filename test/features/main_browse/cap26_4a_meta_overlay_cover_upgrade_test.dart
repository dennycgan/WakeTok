import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/presentation_date_format.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_presentation_metadata_repository.dart';
import '../authorization/permission_ui_test_harness.dart';
import 'still_cover_test_helpers.dart';

/// Cap 26.4a: still (incl. Live static) L1→L2 cover path upgrade must not
/// tear down Meta Overlay via `_suppressStillCoverMeta`.
///
/// L1→L2 trigger mirrors production: hung `requestDisplayAsset` via
/// [FakeMediaDisplayRepository.displayGates], distinct preview vs display
/// PNG paths, and `iCloudNotDownloaded` so All-tab does not skip L1
/// (same pattern as W-15.5a / W-L2). Completing the gate runs
/// `_applyLayer2Result` → `_trackStillCoverPath` — not a debug shortcut.

Future<void> _pumpAsyncWork(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets(
    'W-26.4a-keep: same-page still L1→L2 path upgrade keeps Meta Overlay',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final created = DateTime(2024, 3, 10, 14, 0);
      final exact = formatOverlayExactDateTime(l10n: l10n, createdAt: created);

      final pathL1 = writeStillCoverTestPng('26_4a_keep_l1');
      final pathL2 = writeStillCoverTestPng('26_4a_keep_l2');
      expect(pathL1, isNot(equals(pathL2)));

      final display = FakeMediaDisplayRepository();
      display.previewsById['a1'] = DisplayAsset(
        assetIdentifier: 'a1',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: pathL1,
      );
      display.displaysById['a1'] = DisplayAsset(
        assetIdentifier: 'a1',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: pathL2,
      );
      display.displayGates['a1'] = Completer<void>();

      final presentation = FakePresentationMetadataRepository(
        basicsById: {
          'a1': PresentationMetadata(
            assetIdentifier: 'a1',
            mediaKind: PresentationMediaKind.image,
            createdAt: created,
          ),
        },
      );

      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById: const {
              'a1': AssetAvailability.iCloudNotDownloaded,
            },
          ),
          mediaDisplay: display,
          presentationMetadata: presentation,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await _pumpAsyncWork(tester);

      expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
      expect(display.displayCalls, contains('a1'));
      expect(display.displayGates['a1']!.isCompleted, isFalse);

      final page = mediaFeedPageState(tester, 'a1');
      await pumpUntilStillCoverReady(tester, page);
      expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);
      expect(find.text(exact), findsOneWidget);
      expect(page.debugStillCoverReady, isTrue);
      expect(page.debugMedia?.display?.localFilePath, pathL1);

      // Production L2 success: completes Host display → `_applyLayer2Result`.
      display.displayGates['a1']!.complete();
      await _pumpAsyncWork(tester);

      expect(
        page.debugMedia?.display?.localFilePath,
        pathL2,
        reason: 'L2 must have applied the distinct display path',
      );
      expect(
        page.debugStillCoverReady,
        isTrue,
        reason: 'keep-ready must survive still cover path upgrade',
      );
      expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);
      expect(find.text(exact), findsOneWidget);
      // Do not call pumpUntilStillCoverReady / debugForce here — that would
      // remask a regression that cleared ready on path change.
    },
  );

  testWidgets(
    'W-26.4a-switch: leaving asset still replaces Overlay with next page',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final a1Created = DateTime(2024, 1, 15, 10, 30);
      final a2Created = DateTime(2023, 5, 20, 8, 0);
      final a1Exact = formatOverlayExactDateTime(
        l10n: l10n,
        createdAt: a1Created,
      );
      final a2Exact = formatOverlayExactDateTime(
        l10n: l10n,
        createdAt: a2Created,
      );

      final presentation = FakePresentationMetadataRepository(
        basicsById: {
          'a1': PresentationMetadata(
            assetIdentifier: 'a1',
            mediaKind: PresentationMediaKind.image,
            createdAt: a1Created,
          ),
          'a2': PresentationMetadata(
            assetIdentifier: 'a2',
            mediaKind: PresentationMediaKind.image,
            createdAt: a2Created,
          ),
        },
      );

      final display = FakeMediaDisplayRepository();
      seedDecodableStillPaths(display, const ['a1', 'a2']);

      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1', 'a2'],
            availabilityById: FakeAssetSourceRepository.deviceLocalForIds(
              const ['a1', 'a2'],
            ),
          ),
          mediaDisplay: display,
          presentationMetadata: presentation,
        ),
      );
      await _pumpAsyncWork(tester);
      await pumpUntilStillCoverReadyForAsset(tester, 'a1');
      expect(find.text(a1Exact), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VerticalMediaFeed)),
      );
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await _pumpAsyncWork(tester);
      await pumpUntilStillCoverReadyForAsset(tester, 'a2');

      expect(find.text(a2Exact), findsOneWidget);
      expect(find.text(a1Exact), findsNothing);
      expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);
    },
  );

  testWidgets(
    'W-26.4a-broken: decode-broken still hides Meta Overlay',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      seedDecodableStillPaths(display, const ['a1']);
      final presentation = FakePresentationMetadataRepository(
        basicsById: {
          'a1': PresentationMetadata(
            assetIdentifier: 'a1',
            mediaKind: PresentationMediaKind.image,
            createdAt: DateTime(2024, 3, 10, 14, 0),
          ),
        },
      );

      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById: FakeAssetSourceRepository.deviceLocalForIds(
              const ['a1'],
            ),
          ),
          mediaDisplay: display,
          presentationMetadata: presentation,
        ),
      );
      await _pumpAsyncWork(tester);
      final page = mediaFeedPageState(tester, 'a1');
      await pumpUntilStillCoverReady(tester, page);
      expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);

      page.debugForceStillCoverDecodeBroken(true);
      await tester.pump();
      expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
      expect(page.debugStillCoverDecodeBroken, isTrue);
      expect(page.debugStillCoverReady, isFalse);
    },
  );
}
