import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'still_cover_test_helpers.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/feed_media_request_gate.dart';
import 'package:waketok/features/main_browse/feed_page_media.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/presentation_date_format.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';
import 'package:waketok/l10n/app_localizations.dart';
import 'package:waketok/platform/error_code_mapping.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart'
    show ErrorCode;

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_playback_repository.dart';
import '../../library_smoke/fake_presentation_metadata_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

const _tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

String _writeTempPngSync(String name) {
  final file = File('${Directory.systemTemp.path}/wt_$name.png');
  file.writeAsBytesSync(base64Decode(_tinyPng));
  return file.path;
}

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

void main() {
  group('U-21.6 debt 444 honest feed failure', () {
    test('U-21.6-1 feedFailureReasonFromPlatformCode matrix', () {
      expect(
        feedFailureReasonFromPlatformCode('assetUnavailable'),
        FeedFailureReason.assetUnavailable,
      );
      expect(
        feedFailureReasonFromPlatformCode('iCloudDownloadFailed'),
        FeedFailureReason.download,
      );
      expect(
        feedFailureReasonFromPlatformCode('iCloudDownloadRequired'),
        FeedFailureReason.generic,
      );
      expect(
        feedFailureReasonFromPlatformCode('unknown'),
        FeedFailureReason.generic,
      );
    });

    test(
      'U-21.6-2 loadFeedPageLayer2 still+video map assetUnavailable',
      () async {
        final display = FakeMediaDisplayRepository();
        display.displayErrorById['still-1'] = 'assetUnavailable';
        final stillGate = FeedMediaRequestGate();
        final still = await loadFeedPageLayer2(
          gate: stillGate,
          generation: stillGate.begin(),
          sourceKind: AssetSourceKind.entireLibrary,
          assetIdentifier: 'still-1',
          feedIndex: 0,
          isCurrent: true,
          layer1: null,
          displayRepository: display,
          playbackRepository: FakePlaybackRepository(),
        );
        expect(still?.kind, FeedPageMediaKind.failed);
        expect(still?.failureReason, FeedFailureReason.assetUnavailable);

        final playback = FakePlaybackRepository();
        playback.loadErrorById['vid-1'] = 'assetUnavailable';
        final videoGate = FeedMediaRequestGate();
        final video = await loadFeedPageLayer2(
          gate: videoGate,
          generation: videoGate.begin(),
          sourceKind: AssetSourceKind.mediaTypeVideos,
          assetIdentifier: 'vid-1',
          feedIndex: 0,
          isCurrent: true,
          layer1: null,
          displayRepository: FakeMediaDisplayRepository(),
          playbackRepository: playback,
        );
        expect(video?.kind, FeedPageMediaKind.failed);
        expect(video?.failureReason, FeedFailureReason.assetUnavailable);
      },
    );

    testWidgets(
      'U-21.6-3 coverless L2 assetUnavailable: copy + no Retry',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final display = FakeMediaDisplayRepository();
        // No L1 cover surface → page/coverless fail presents Case B.
        display.previewErrorById['a1'] = 'iCloudDownloadRequired';
        display.displayErrorById['a1'] = 'assetUnavailable';
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(
          permissionUiHarness(
            repo: repo,
            assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
            mediaDisplay: display,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.mainBrowseFeedUnavailable), findsOneWidget);
        expect(find.text(l10n.mainBrowseFeedNetworkFailed), findsNothing);
        expect(
          find.byKey(const Key('mainBrowseFeedLayer2Retry')),
          findsNothing,
        );
        expect(find.byKey(const Key('mainBrowseFeedPageRetry')), findsNothing);
      },
    );

    testWidgets(
      'U-21.6-3b residual cover + assetUnavailable drops cover to page B',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final ok = _writeTempPngSync('21_6_residual_ok');
        final display = FakeMediaDisplayRepository();
        display.previewsById['a1'] = DisplayAsset(
          assetIdentifier: 'a1',
          mediaKind: PlaybackMediaKind.image,
          localFilePath: ok,
        );
        display.displaysById['a1'] = DisplayAsset(
          assetIdentifier: 'a1',
          mediaKind: PlaybackMediaKind.image,
          localFilePath: ok,
        );
        display.displayErrorById['a1'] = 'assetUnavailable';
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(
          permissionUiHarness(
            repo: repo,
            assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
            mediaDisplay: display,
          ),
        );
        await tester.pumpAndSettle();

        // Case B: unload residual cover — page-failed chrome only.
        expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsNothing);
        expect(
          find.byKey(const Key('mainBrowseFeedPageFailed')),
          findsOneWidget,
        );
        expect(find.text(l10n.mainBrowseFeedUnavailable), findsOneWidget);
        expect(
          find.byKey(const Key('mainBrowseFeedLayer2Retry')),
          findsNothing,
        );
        expect(find.byKey(const Key('mainBrowseFeedPageRetry')), findsNothing);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        expect(
          container.read(mainBrowseCurrentAssetHostUnavailableProvider),
          isTrue,
        );
        expect(
          container.read(mainBrowseCurrentAssetActionableProvider),
          isFalse,
        );
      },
    );

    testWidgets(
      'U-21.6-3c coverless generic L2 remaps to B unavailable chrome',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final display = FakeMediaDisplayRepository();
        display.previewErrorById['a1'] = 'unknown';
        display.displayErrorById['a1'] = 'unknown';
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(
          permissionUiHarness(
            repo: repo,
            assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
            mediaDisplay: display,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.mainBrowseFeedUnavailable), findsOneWidget);
        expect(find.text(l10n.mainBrowseFeedMediaFailed), findsNothing);
        expect(find.byKey(const Key('mainBrowseFeedPageRetry')), findsNothing);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        expect(
          container.read(mainBrowseCurrentAssetHostUnavailableProvider),
          isTrue,
        );
        expect(
          container.read(mainBrowseCurrentAssetActionableProvider),
          isFalse,
        );
      },
    );

    testWidgets(
      'U-21.6-3d in-library generic L2 keeps Case A + Retry',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final display = FakeMediaDisplayRepository();
        display.previewErrorById['a1'] = 'unknown';
        display.displayErrorById['a1'] = 'unknown';
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(
          permissionUiHarness(
            repo: repo,
            assetSources: FakeAssetSourceRepository(
              allIds: const ['a1'],
              availabilityById:
                  FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
            ),
            mediaDisplay: display,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.mainBrowseFeedMediaFailed), findsOneWidget);
        expect(find.text(l10n.mainBrowseFeedUnavailable), findsNothing);
        expect(find.byKey(const Key('mainBrowseFeedPageRetry')), findsOneWidget);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        expect(
          container.read(mainBrowseCurrentAssetHostUnavailableProvider),
          isFalse,
        );
        expect(
          container.read(mainBrowseCurrentAssetActionableProvider),
          isTrue,
        );
      },
    );

    testWidgets(
      'U-21.6-4 page-failed assetUnavailable: copy + no Retry',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final display = FakeMediaDisplayRepository();
        display.previewErrorById['a1'] = 'iCloudDownloadRequired';
        display.displayErrorById['a1'] = 'assetUnavailable';
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(
          permissionUiHarness(
            repo: repo,
            assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
            mediaDisplay: display,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('mainBrowseFeedPageFailed')), findsOneWidget);
        expect(find.text(l10n.mainBrowseFeedUnavailable), findsOneWidget);
        expect(find.text(l10n.mainBrowseFeedNetworkFailed), findsNothing);
        expect(find.byKey(const Key('mainBrowseFeedPageRetry')), findsNothing);
      },
    );

    testWidgets(
      'U-21.6-7 assetUnavailable hides Media Info Overlay',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final created = DateTime(2024, 7, 7, 12);
        final exact = formatOverlayExactDateTime(l10n: l10n, createdAt: created);
        final presentation = FakePresentationMetadataRepository(
          basicsById: {
            'a1': PresentationMetadata(
              assetIdentifier: 'a1',
              mediaKind: PresentationMediaKind.image,
              createdAt: created,
            ),
          },
        );
        final display = FakeMediaDisplayRepository();
        display.previewErrorById['a1'] = 'iCloudDownloadRequired';
        display.displayErrorById['a1'] = 'assetUnavailable';
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(
          permissionUiHarness(
            repo: repo,
            assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
            mediaDisplay: display,
            presentationMetadata: presentation,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('mainBrowseFeedPageFailed')), findsOneWidget);
        expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
        expect(find.text(exact), findsNothing);
      },
    );

    testWidgets(
      'U-21.6-9 loading miss does not flash Overlay from prior meta cache',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final created = DateTime(2024, 7, 7, 12);
        final exact = formatOverlayExactDateTime(l10n: l10n, createdAt: created);
        final presentation = FakePresentationMetadataRepository(
          basicsById: {
            'a1': PresentationMetadata(
              assetIdentifier: 'a1',
              mediaKind: PresentationMediaKind.image,
              createdAt: created,
            ),
          },
        );
        final display = FakeMediaDisplayRepository();
        display.previewErrorById['a1'] = 'iCloudDownloadRequired';
        display.displayGates['a1'] = Completer<void>();
        display.displayErrorById['a1'] = 'assetUnavailable';
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(
          permissionUiHarness(
            repo: repo,
            assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
            mediaDisplay: display,
            presentationMetadata: presentation,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byKey(const Key('mainBrowseFeedPageLoading')), findsOneWidget);
        expect(find.text(l10n.mainBrowseFeedLayer1Loading), findsOneWidget);
        expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
        expect(find.text(exact), findsNothing);

        display.displayGates['a1']!.complete();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('mainBrowseFeedPageFailed')), findsOneWidget);
        expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
      },
    );

    testWidgets(
      'U-21.6-8 assetUnavailable dims Cap 19 entry (Decision 7)',
      (tester) async {
        final display = FakeMediaDisplayRepository();
        display.previewErrorById['a1'] = 'iCloudDownloadRequired';
        display.displayErrorById['a1'] = 'assetUnavailable';
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(
          permissionUiHarness(
            repo: repo,
            assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
            mediaDisplay: display,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('mainBrowseFeedPageFailed')), findsOneWidget);
        expect(find.byKey(const Key('cap19EntryIcon')), findsOneWidget);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        expect(
          container.read(mainBrowseCurrentAssetActionableProvider),
          isFalse,
        );
        expect(
          container.read(mainBrowseCurrentAssetHostUnavailableProvider),
          isTrue,
        );

        final opacity = tester.widget<Opacity>(
          find.ancestor(
            of: find.byKey(const Key('cap19EntryIcon')),
            matching: find.byType(Opacity),
          ),
        );
        expect(opacity.opacity, kCap19EntryIconDisabledOpacity);

        await ensureShellMediaCoverVisible(tester);
      await tester.tap(find.byKey(const Key('cap19EntryIcon')));
        await tester.pumpAndSettle();
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.cap19PanelAddToAlbumTitle), findsNothing);
      },
    );

    testWidgets(
      'U-21.6-5 iCloudDownloadFailed keeps download copy + Retry',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final ok = _writeTempPngSync('21_6_download_retry_ok');
        final display = FakeMediaDisplayRepository();
        display.previewsById['a1'] = DisplayAsset(
          assetIdentifier: 'a1',
          mediaKind: PlaybackMediaKind.image,
          localFilePath: ok,
        );
        display.displayErrorById['a1'] = 'iCloudDownloadFailed';
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(
          permissionUiHarness(
            repo: repo,
            assetSources: FakeAssetSourceRepository(
              allIds: const ['a1'],
              // In-library: do not coerce download fail → Case B.
              availabilityById:
                  FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
            ),
            mediaDisplay: display,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
        expect(find.text(l10n.mainBrowseFeedDownloadFailed), findsOneWidget);
        expect(find.text(l10n.mainBrowseFeedUnavailable), findsNothing);
        expect(
          find.byKey(const Key('mainBrowseFeedLayer2Retry')),
          findsOneWidget,
        );
      },
    );

    test('U-21.6-6 feed remap does not change AppError.assetUnavailable', () {
      expect(
        appErrorFromErrorCode(ErrorCode.assetUnavailable),
        AppError.assetUnavailable,
      );
      expect(
        appErrorFromPlatformException(
          PlatformException(code: ErrorCode.assetUnavailable.name),
        ),
        AppError.assetUnavailable,
      );
      expect(
        feedFailureReasonFromPlatformCode(ErrorCode.assetUnavailable.name),
        FeedFailureReason.assetUnavailable,
      );
      // Parallel chains: wire code still means AppError for Cap 19 /
      // gateway; only feed display reason changed off network.
      expect(
        identical(
          appErrorFromErrorCode(ErrorCode.assetUnavailable),
          AppError.assetUnavailable,
        ),
        isTrue,
      );
    });

    testWidgets(
      'U-21.6-3e Case B leave→neighbour→restore→revisit reaches L2 full',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final previewPath = _writeTempPngSync('21_6_3e_preview');
        final displayPath = _writeTempPngSync('21_6_3e_display');
        final ok2 = _writeTempPngSync('21_6_3e_a2');
        final display = FakeMediaDisplayRepository();
        display.previewsById['a1'] = DisplayAsset(
          assetIdentifier: 'a1',
          mediaKind: PlaybackMediaKind.image,
          localFilePath: previewPath,
        );
        display.displaysById['a1'] = DisplayAsset(
          assetIdentifier: 'a1',
          mediaKind: PlaybackMediaKind.image,
          localFilePath: displayPath,
        );
        display.displayErrorById['a1'] = 'assetUnavailable';
        display.previewsById['a2'] = DisplayAsset(
          assetIdentifier: 'a2',
          mediaKind: PlaybackMediaKind.image,
          localFilePath: ok2,
        );
        display.displaysById['a2'] = DisplayAsset(
          assetIdentifier: 'a2',
          mediaKind: PlaybackMediaKind.image,
          localFilePath: ok2,
        );
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(
          permissionUiHarness(
            repo: repo,
            assetSources: FakeAssetSourceRepository(
              allIds: const ['a1', 'a2'],
              availabilityById:
                  FakeAssetSourceRepository.deviceLocalForIds(const [
                    'a1',
                    'a2',
                  ]),
            ),
            mediaDisplay: display,
            browseLayer2Dwell: Duration.zero,
          ),
        );
        await _pumpAsyncWork(tester);

        final ids = await _feedOrderedIds(tester);
        expect(ids.first, 'a1');
        expect(find.text(l10n.mainBrowseFeedUnavailable), findsOneWidget);
        final pageA1 = tester.state<MediaFeedPageState>(_pageFor('a1'));
        expect(pageA1.debugNeedsFullReloadAfterHostUnavailable, isTrue);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
        await _pumpAsyncWork(tester);

        // Simulate Photos restore while parked on neighbour (±1 keep-alive).
        display.displayErrorById.remove('a1');
        container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
        await _pumpAsyncWork(tester);

        final pageBack = tester.state<MediaFeedPageState>(_pageFor('a1'));
        expect(find.text(l10n.mainBrowseFeedUnavailable), findsNothing);
        expect(pageBack.debugMedia?.kind, FeedPageMediaKind.still);
        expect(pageBack.debugMedia?.displayLayer, FeedDisplayLayer.full);
        expect(
          pageBack.debugMedia?.display?.localFilePath,
          displayPath,
        );
        expect(pageBack.debugNeedsFullReloadAfterHostUnavailable, isFalse);
      },
    );
  });
}
