import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:waketok/l10n/app_localizations.dart';
import 'package:waketok/platform/error_code_mapping.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart'
    show ErrorCode;

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_playback_repository.dart';
import '../../library_smoke/fake_presentation_metadata_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

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
        display.previewsById['a1'] = const DisplayAsset(
          assetIdentifier: 'a1',
          mediaKind: PlaybackMediaKind.image,
          localFilePath: '/tmp/a1-preview.jpg',
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

        expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
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
        final display = FakeMediaDisplayRepository();
        display.previewsById['a1'] = const DisplayAsset(
          assetIdentifier: 'a1',
          mediaKind: PlaybackMediaKind.image,
          localFilePath: '/tmp/a1-preview.jpg',
        );
        display.displayErrorById['a1'] = 'iCloudDownloadFailed';
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
  });
}
