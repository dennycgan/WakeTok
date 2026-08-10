import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/live_photo/live_photo_repository.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/presentation/file_size_semantics.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/resolved_source.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/main_browse/feed_media_request_gate.dart';
import 'package:waketok/features/main_browse/feed_page_media.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/main_browse_shell_page.dart';
import 'package:waketok/features/main_browse/presentation_date_format.dart';
import 'package:waketok/features/main_browse/presentation_size_format.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_live_photo_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_playback_repository.dart';
import '../../library_smoke/fake_presentation_metadata_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

/// Advances async work without waiting for indeterminate preparing spinners.
Future<void> pumpAsyncWork(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('W-F1 full lands on VerticalMediaFeed not placeholder',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MainBrowseShellPage), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeed')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedPlaceholder')), findsNothing);
    expect(find.byType(VerticalMediaFeed), findsOneWidget);
  });

  testWidgets('W-F2 PageView builds for resolved ids', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a', 'b', 'c'],
    );
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, assetSources: sources),
    );
    await tester.pumpAndSettle();

    expect(sources.resolveCalls, greaterThan(0));
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedStill_a')), findsOneWidget);
  });

  testWidgets('W-F3 empty resolve shows empty ARB', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.mainBrowseFeedEmpty), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedEmpty')), findsOneWidget);
    expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
  });

  testWidgets('W-F4 resolve failure shows error ARB and retry', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = _ThrowingResolveRepository();
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, assetSources: sources),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.mainBrowseFeedResolveFailed), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedResolveFailed')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedRetry')), findsOneWidget);
    expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
  });

  testWidgets('W-F5 page change updates feed index via PageController',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a', 'b', 'c'],
    );
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, assetSources: sources),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await tester.pumpAndSettle();

    expect(container.read(mainBrowseFeedIndexProvider), 1);
    expect(find.byKey(const Key('mainBrowseFeedStill_b')), findsOneWidget);
  });

  testWidgets('W-F6 switching Photos calls resolve for photos and resets',
      (tester) async {
    // First visit to Photos — always a host resolve (cache miss).
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['all-1', 'all-2'],
      photosIds: const ['ph-1'],
    );
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, assetSources: sources),
    );
    await tester.pumpAndSettle();

    final callsBefore = sources.resolveCalls;
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.libraryRowPhotos));
    await tester.pumpAndSettle();

    expect(sources.resolveCalls, greaterThan(callsBefore));
    expect(sources.lastResolve, SourceReference.photos);
    expect(find.byKey(const Key('mainBrowseFeedStill_ph-1')), findsOneWidget);

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    expect(container.read(mainBrowseFeedIndexProvider), 0);
  });

  testWidgets(
      'W-S1 All→Photos→All resolves each source once (session cache)',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['all-1'],
      photosIds: const ['ph-1'],
    );
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, assetSources: sources),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.libraryRowPhotos));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.libraryRowAll));
    await tester.pumpAndSettle();

    expect(
      sources.resolveHistory.where((r) => r == SourceReference.all).length,
      1,
    );
    expect(
      sources.resolveHistory.where((r) => r == SourceReference.photos).length,
      1,
    );
    expect(sources.resolveCalls, 2);
    expect(find.byKey(const Key('mainBrowseFeedStill_all-1')), findsOneWidget);
  });

  testWidgets('W-S2 cache-hit source switch still resets feed index to 0',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a', 'b', 'c'],
      photosIds: const ['ph-1'],
    );
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, assetSources: sources),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(2);
    await tester.pumpAndSettle();
    expect(container.read(mainBrowseFeedIndexProvider), 2);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.libraryRowPhotos));
    await tester.pumpAndSettle();
    expect(container.read(mainBrowseFeedIndexProvider), 0);

    await tester.tap(find.text(l10n.libraryRowAll));
    await tester.pumpAndSettle();
    expect(container.read(mainBrowseFeedIndexProvider), 0);
    expect(find.byKey(const Key('mainBrowseFeedStill_a')), findsOneWidget);
    expect(
      sources.resolveHistory.where((r) => r == SourceReference.all).length,
      1,
    );
  });

  testWidgets('W-S3 Photos resolve is independent of All (not Dart filter)',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['shared', 'all-only'],
      photosIds: const ['ph-only'],
    );
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, assetSources: sources),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.libraryRowPhotos));
    await tester.pumpAndSettle();

    expect(sources.lastResolve, SourceReference.photos);
    expect(find.byKey(const Key('mainBrowseFeedStill_ph-only')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedStill_all-only')), findsNothing);
    expect(find.byKey(const Key('mainBrowseFeedStill_shared')), findsNothing);
  });

  testWidgets(
      'W-S4 retry after failure resolves again then caches success',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = _FailThenSucceedRepository(
      allIds: const ['a1'],
      failTimes: 1,
    );
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, assetSources: sources),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.mainBrowseFeedResolveFailed), findsOneWidget);
    expect(sources.resolveCalls, 1);

    await tester.tap(find.byKey(const Key('mainBrowseFeedRetry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
    expect(sources.resolveCalls, 2);

    await tester.tap(find.text(l10n.libraryRowPhotos));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.libraryRowAll));
    await tester.pumpAndSettle();

    // All success was cached — no third resolve for All.
    expect(
      sources.resolveHistory.where((r) => r == SourceReference.all).length,
      2,
    );
    expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
  });

  testWidgets(
      'W-F7 stale display for index N discarded after jump toward N+2',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    final gateN = Completer<void>();
    display.displayGates['n'] = gateN;
    display.displaysById['n'] = const DisplayAsset(
      assetIdentifier: 'n',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/n.jpg',
    );
    display.displaysById['mid'] = const DisplayAsset(
      assetIdentifier: 'mid',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/mid.jpg',
    );
    display.displaysById['n2'] = const DisplayAsset(
      assetIdentifier: 'n2',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/n2.jpg',
    );

    final sources = FakeAssetSourceRepository(
      allIds: const ['n', 'mid', 'n2'],
    );

    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: sources,
        mediaDisplay: display,
      ),
    );
    // Resolve + start gated display for current page.
    await tester.pump();
    await tester.pump();
    expect(display.displayCalls, contains('n'));

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(2);
    await tester.pump();
    await tester.pump();

    gateN.complete();
    await pumpAsyncWork(tester);

    expect(find.byKey(const Key('mainBrowseLiveBadge')), findsOneWidget);
    expect(container.read(mainBrowseFeedIndexProvider), 2);
  });

  testWidgets('W-F8 switching source pauses playback (no audio leak)',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final playback = FakePlaybackRepository();
    final sources = FakeAssetSourceRepository(
      allIds: const ['all-1'],
      photosIds: const ['ph-1'],
    );
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: sources,
        playback: playback,
      ),
    );
    await tester.pumpAndSettle();

    playback.calls.clear();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.libraryRowPhotos));
    await tester.pumpAndSettle();

    expect(playback.calls.where((c) => c == 'pause'), isNotEmpty);
  });

  testWidgets(
      'W-F8b leave video for still pauses playback (no audio leak)',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final playback = FakePlaybackRepository();
    final display = FakeMediaDisplayRepository();
    // All: unsupportedMedia → video path for v1; still is a normal image.
    display.displayErrorById['v1'] = 'unsupportedMedia';
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['v1', 'still']),
        mediaDisplay: display,
        playback: playback,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsOneWidget);

    playback.calls.clear();
    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mainBrowseFeedStill_still')), findsOneWidget);
    expect(playback.calls.where((c) => c == 'pause'), isNotEmpty);
  });

  testWidgets(
      'W-F8c leave video for iCloud-only pauses playback (no audio leak)',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final playback = FakePlaybackRepository();
    final display = FakeMediaDisplayRepository();
    display.displayErrorById['v1'] = 'unsupportedMedia';
    display.displayErrorById['cloud'] = 'iCloudDownloadRequired';
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources:
            FakeAssetSourceRepository(allIds: const ['v1', 'cloud']),
        mediaDisplay: display,
        playback: playback,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsOneWidget);

    playback.calls.clear();
    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mainBrowseFeedPageICloud')), findsOneWidget);
    expect(playback.calls.where((c) => c == 'pause'), isNotEmpty);
  });

  test('U-1 Videos source skips display and goes playable', () async {
    final display = FakeMediaDisplayRepository();
    final gate = FeedMediaRequestGate();
    final generation = gate.begin();
    final playback = FakePlaybackRepository();

    final media = await loadFeedPageMedia(
      gate: gate,
      generation: generation,
      sourceKind: AssetSourceKind.mediaTypeVideos,
      assetIdentifier: 'v1',
      feedIndex: 0,
      isCurrent: true,
      displayRepository: display,
      playbackRepository: playback,
    );

    expect(display.displayCalls, isEmpty);
    expect(display.playableCalls, ['v1']);
    expect(media?.kind, FeedPageMediaKind.video);
  });

  test('U-1-pending off-current Videos does not touch playable', () async {
    final display = FakeMediaDisplayRepository();
    final gate = FeedMediaRequestGate();
    final generation = gate.begin();
    final playback = FakePlaybackRepository();

    final media = await loadFeedPageMedia(
      gate: gate,
      generation: generation,
      sourceKind: AssetSourceKind.mediaTypeVideos,
      assetIdentifier: 'v1',
      feedIndex: 1,
      isCurrent: false,
      displayRepository: display,
      playbackRepository: playback,
    );

    expect(display.playableCalls, isEmpty);
    expect(playback.calls, isEmpty);
    expect(media?.kind, FeedPageMediaKind.pendingVideo);
  });

  test('U-1b All unsupportedMedia falls through to video', () async {
    final display = FakeMediaDisplayRepository();
    display.displayErrorById['vid'] = 'unsupportedMedia';
    final gate = FeedMediaRequestGate();
    final generation = gate.begin();
    final playback = FakePlaybackRepository();

    final media = await loadFeedPageMedia(
      gate: gate,
      generation: generation,
      sourceKind: AssetSourceKind.entireLibrary,
      assetIdentifier: 'vid',
      feedIndex: 1,
      isCurrent: true,
      displayRepository: display,
      playbackRepository: playback,
    );

    expect(display.displayCalls, ['vid']);
    expect(display.playableCalls, ['vid']);
    expect(media?.kind, FeedPageMediaKind.video);
  });

  test('W-F7-unit stale generation discards late display', () async {
    final display = FakeMediaDisplayRepository();
    final gateN = Completer<void>();
    display.displayGates['n'] = gateN;
    display.displaysById['n'] = const DisplayAsset(
      assetIdentifier: 'n',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/n.jpg',
    );
    display.displaysById['n2'] = const DisplayAsset(
      assetIdentifier: 'n2',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/n2.jpg',
    );

    final gate = FeedMediaRequestGate();
    final playback = FakePlaybackRepository();

    final genN = gate.begin();
    final futureN = loadFeedPageMedia(
      gate: gate,
      generation: genN,
      sourceKind: AssetSourceKind.mediaTypePhotos,
      assetIdentifier: 'n',
      feedIndex: 0,
      isCurrent: true,
      displayRepository: display,
      playbackRepository: playback,
    );

    final genN2 = gate.begin();
    final mediaN2 = await loadFeedPageMedia(
      gate: gate,
      generation: genN2,
      sourceKind: AssetSourceKind.mediaTypePhotos,
      assetIdentifier: 'n2',
      feedIndex: 2,
      isCurrent: true,
      displayRepository: display,
      playbackRepository: playback,
    );
    gateN.complete();
    final mediaN = await futureN;

    expect(mediaN, isNull);
    expect(mediaN2?.display?.assetIdentifier, 'n2');
  });

  testWidgets(
      'W-O-display metadata delay does not block still display',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final presentation = FakePresentationMetadataRepository(
      basicsGate: Completer<void>(),
      sizeGate: Completer<void>(),
    );
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
        presentationMetadata: presentation,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
    expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);
    expect(presentation.basicsCalls, greaterThan(0));
  });

  testWidgets(
      'W-O-cache returning to seen asset shows cached Overlay without blank',
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
    final a1Size = formatOverlayFileSize(
      l10n: l10n,
      fileSizeBytes: 2_886_627,
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
      sizeById: {
        'a1': const PresentationFileSize(
          assetIdentifier: 'a1',
          fileSizeBytes: 2_886_627,
          fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
        ),
        'a2': const PresentationFileSize(
          assetIdentifier: 'a2',
          fileSizeBytes: 11_260_685,
          fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
        ),
      },
    );

    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        presentationMetadata: presentation,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(a1Exact), findsOneWidget);
    expect(find.text(a1Size), findsOneWidget);

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await tester.pumpAndSettle();
    expect(find.text(a2Exact), findsOneWidget);
    expect(find.text(a1Exact), findsNothing);

    // Hang subsequent metadata refresh so only the session cache can paint.
    presentation.basicsGate = Completer<void>();
    presentation.sizeGate = Completer<void>();
    final callsBeforeReturn = presentation.basicsCalls;

    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
    await tester.pump(); // one frame — do not settle / wait for hung refresh

    expect(find.text(a1Exact), findsOneWidget);
    expect(find.text(a1Size), findsOneWidget);
    expect(find.text(a2Exact), findsNothing);
    expect(presentation.basicsCalls, greaterThan(callsBeforeReturn));

    // Unblock hung refresh so the test does not leak pending futures.
    presentation.basicsGate!.complete();
    presentation.sizeGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('W-L1 resolve loading shows Key and copy; no Overlay',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = _HangingResolveRepository(allIds: const ['a1']);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, assetSources: sources),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('mainBrowseFeedLoading')), findsOneWidget);
    expect(find.text(l10n.mainBrowseFeedLoading), findsOneWidget);
    expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);

    sources.gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
  });

  testWidgets(
      'W-L2 per-page loading Key; Overlay paints when metadata arrives',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final created = DateTime(2024, 7, 1, 9, 0);
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
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    display.displayGates['a1'] = Completer<void>();
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
        mediaDisplay: display,
        presentationMetadata: presentation,
      ),
    );
    var sawPageLoading = false;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find
          .byKey(const Key('mainBrowseFeedPageLoading'))
          .evaluate()
          .isNotEmpty) {
        sawPageLoading = true;
        break;
      }
    }
    expect(sawPageLoading, isTrue);

    // Metadata can finish while display is still hung — Overlay stays up.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text(exact).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.byKey(const Key('mainBrowseFeedPageLoading')), findsOneWidget);
    expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);
    expect(find.text(exact), findsOneWidget);

    display.displayGates['a1']!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
  });

  testWidgets('W-L3 per-page iCloud-only shows panel + retry', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    display.displayErrorById['a1'] = 'iCloudDownloadRequired';
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
        mediaDisplay: display,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeedPageICloud')), findsOneWidget);
    expect(find.text(l10n.mainBrowseFeedICloudOnly), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedPageRetry')), findsOneWidget);
  });

  testWidgets('W-L4 per-page failed shows panel + retry', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    display.displayErrorById['a1'] = 'assetUnavailable';
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
        mediaDisplay: display,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeedPageFailed')), findsOneWidget);
    expect(find.text(l10n.mainBrowseFeedMediaFailed), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedPageRetry')), findsOneWidget);
  });

  testWidgets('W-L5 resolve loading hides Overlay', (tester) async {
    // Empty / resolve-failed Overlay absence covered by W-F3 / W-F4.
    // Separate testWidgets — re-pumping ProviderScope in one test can
    // retain a cached resolve and falsely keep a non-empty feed.
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final hanging = _HangingResolveRepository(allIds: const ['a1']);
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, assetSources: hanging),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('mainBrowseFeedLoading')), findsOneWidget);
    expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
    hanging.gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'W-L6 per-page iCloud/failed keeps Overlay when metadata arrived',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final created = DateTime(2024, 3, 10, 14, 5);
    final exact = formatOverlayExactDateTime(l10n: l10n, createdAt: created);
    final presentation = FakePresentationMetadataRepository(
      basicsById: {
        'cloud': PresentationMetadata(
          assetIdentifier: 'cloud',
          mediaKind: PresentationMediaKind.image,
          createdAt: created,
        ),
        'bad': PresentationMetadata(
          assetIdentifier: 'bad',
          mediaKind: PresentationMediaKind.image,
          createdAt: created,
        ),
      },
    );
    final display = FakeMediaDisplayRepository();
    display.displayErrorById['cloud'] = 'iCloudDownloadRequired';
    display.displayErrorById['bad'] = 'assetUnavailable';

    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['cloud', 'bad'],
        ),
        mediaDisplay: display,
        presentationMetadata: presentation,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeedPageICloud')), findsOneWidget);
    expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);
    expect(find.text(exact), findsOneWidget);

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeedPageFailed')), findsOneWidget);
    expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);
    expect(find.text(exact), findsOneWidget);
  });

  testWidgets(
      'W-Loc2 feed metadata lands Row2+Row3; production path has no Row4',
      (tester) async {
    // Hard gates: exact date (Row2) + formatted size (Row3) from this
    // fixture prove metadata landed — not an empty Overlay shell. Row1
    // relative date is optional (clock-dependent). No Row4 = Location
    // specifically unset on the production feed path.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final created = DateTime(2023, 11, 15, 8, 30);
    const sizeBytes = 2_886_627;
    final exact = formatOverlayExactDateTime(l10n: l10n, createdAt: created);
    final sizeCopy =
        formatOverlayFileSize(l10n: l10n, fileSizeBytes: sizeBytes);
    expect(exact, isNotEmpty);
    expect(sizeCopy, isNotEmpty);

    final presentation = FakePresentationMetadataRepository(
      basicsById: {
        'loc1': PresentationMetadata(
          assetIdentifier: 'loc1',
          mediaKind: PresentationMediaKind.image,
          createdAt: created,
        ),
      },
      sizeById: {
        'loc1': const PresentationFileSize(
          assetIdentifier: 'loc1',
          fileSizeBytes: sizeBytes,
          fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
        ),
      },
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['loc1']),
        presentationMetadata: presentation,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(exact), findsOneWidget);
    expect(find.text(sizeCopy), findsOneWidget);
    expect(find.byKey(const Key('mediaInfoOverlayRow4')), findsNothing);
  });

  testWidgets(
      'L-F1 Live current: clearPlaybackPool before requestLivePhoto',
      (tester) async {
    final live = FakeLivePhotoRepository();
    final playback = FakePlaybackRepository();
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
        mediaDisplay: display,
        playback: playback,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);

    expect(find.byKey(const Key('mainBrowseFeedStill_live-1')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseLiveBadge')), findsOneWidget);
    expect(playback.calls, contains('clearPlaybackPool'));
    expect(live.calls, contains('requestLivePhoto:live-1'));
    final clearAt = playback.calls.indexOf('clearPlaybackPool');
    final requestAt = live.calls.indexOf('requestLivePhoto:live-1');
    expect(clearAt, lessThan(requestAt));
    expect(
      find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
      findsOneWidget,
    );
  });

  testWidgets('L-F2 leave current Live cancels and stops', (tester) async {
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    display.displaysById['still-2'] = const DisplayAsset(
      assetIdentifier: 'still-2',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/still-2.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources:
            FakeAssetSourceRepository(allIds: const ['live-1', 'still-2']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    expect(live.calls, contains('requestLivePhoto:live-1'));
    live.calls.clear();

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await pumpAsyncWork(tester);

    expect(live.calls, contains('cancel:live-1'));
    expect(live.calls, contains('stopPlayback'));
    expect(
      find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
      findsNothing,
    );
  });

  testWidgets('L-F3 playbackEnded unloads Live motion surface (Q7)',
      (tester) async {
    final live = FakeLivePhotoRepository(autoReady: true);
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    expect(
      find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
      findsOneWidget,
    );
    expect(live.calls, contains('startPlayback'));

    live.endedController.add(
      const LivePhotoPlaybackEndedEvent(assetIdentifier: 'live-1'),
    );
    await pumpAsyncWork(tester);

    expect(
      find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
      findsNothing,
    );
    expect(find.byKey(const Key('mainBrowseFeedStill_live-1')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseLiveBadge')), findsOneWidget);
  });

  testWidgets('L-F4 sync request failure keeps still + badge (no skip)',
      (tester) async {
    final live = FakeLivePhotoRepository(throwOnRequestCode: 'unsupportedMedia');
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);

    expect(find.byKey(const Key('mainBrowseFeedStill_live-1')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseLiveBadge')), findsOneWidget);
    expect(
      find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
      findsNothing,
    );
  });

  testWidgets('L-F5 failedEvents unloads motion; still remains', (tester) async {
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    expect(
      find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
      findsOneWidget,
    );

    live.failedController.add(
      const LivePhotoFailedEvent(
        assetIdentifier: 'live-1',
        error: AppError.iCloudDownloadFailed,
      ),
    );
    await pumpAsyncWork(tester);

    expect(
      find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
      findsNothing,
    );
    expect(find.byKey(const Key('mainBrowseFeedStill_live-1')), findsOneWidget);
  });

  testWidgets(
      'L-F6 stale ready after leave does not startPlayback on re-enter race',
      (tester) async {
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    display.displaysById['still-2'] = const DisplayAsset(
      assetIdentifier: 'still-2',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/still-2.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources:
            FakeAssetSourceRepository(allIds: const ['live-1', 'still-2']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await pumpAsyncWork(tester);

    // Stale ready from first activation — must be ignored (F4 token).
    live.readyController.add(
      const LivePhotoReadyEvent(assetIdentifier: 'live-1'),
    );
    await pumpAsyncWork(tester);
    expect(live.calls.where((c) => c == 'startPlayback'), isEmpty);

    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
    await pumpAsyncWork(tester);
    final startsBefore = live.calls.where((c) => c == 'startPlayback').length;

    live.readyController.add(
      const LivePhotoReadyEvent(assetIdentifier: 'live-1'),
    );
    await pumpAsyncWork(tester);
    expect(
      live.calls.where((c) => c == 'startPlayback').length,
      greaterThan(startsBefore),
    );
  });

  testWidgets('L-F7 re-enter Live requests again (Q6 play-once)', (tester) async {
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    display.displaysById['still-2'] = const DisplayAsset(
      assetIdentifier: 'still-2',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/still-2.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources:
            FakeAssetSourceRepository(allIds: const ['live-1', 'still-2']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    expect(
      live.calls.where((c) => c == 'requestLivePhoto:live-1').length,
      1,
    );

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await pumpAsyncWork(tester);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
    await pumpAsyncWork(tester);

    expect(
      live.calls.where((c) => c == 'requestLivePhoto:live-1').length,
      2,
    );
  });

  testWidgets(
      'L-F8 leave→return while cancel held: second request after cancel/stop',
      (tester) async {
    // F4 lock: if feed-scoped `LiveHostOpSerial.enqueue` is bypassed and
    // cancel/request race freely, the mid-hold assertion (no request while
    // cancel held) fails.
    // Note: still-2 may cancel/stop interleaved in the shared call log;
    // assertions use a mid-hold snapshot so that noise is excluded.
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    display.displaysById['still-2'] = const DisplayAsset(
      assetIdentifier: 'still-2',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/still-2.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources:
            FakeAssetSourceRepository(allIds: const ['live-1', 'still-2']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    expect(
      live.calls.where((c) => c == 'requestLivePhoto:live-1').length,
      1,
    );

    live.calls.clear();
    final cancelHold = Completer<void>();
    live.cancelHold = cancelHold;
    live.cancelHoldAssetId = 'live-1';

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);

    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await tester.pump();
    await tester.idle();
    await tester.pump();
    expect(
      live.calls,
      contains('cancel:live-1'),
      reason: 'leave must invoke cancel(live-1); calls=${live.calls}',
    );

    // Return while cancel still held — live-1 chain must not request yet.
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
    await tester.pump();
    await tester.idle();
    await tester.pump();
    final midHoldCalls = List<String>.from(live.calls);
    expect(
      midHoldCalls.where((c) => c == 'requestLivePhoto:live-1'),
      isEmpty,
      reason: 're-enter request must wait for leave cancel/stop '
          '(LiveHostOpSerial); mid=$midHoldCalls',
    );

    cancelHold.complete();
    await pumpAsyncWork(tester);

    final afterHold = live.calls.skip(midHoldCalls.length).toList();
    expect(
      afterHold,
      contains('stopPlayback'),
      reason: 'leave stop must run after cancelHold; after=$afterHold '
          'full=${live.calls}',
    );
    expect(
      afterHold,
      contains('requestLivePhoto:live-1'),
      reason: 're-enter request must run after cancelHold; after=$afterHold '
          'full=${live.calls}',
    );
    expect(
      afterHold.indexOf('stopPlayback'),
      lessThan(afterHold.indexOf('requestLivePhoto:live-1')),
      reason: 'stop before request in post-hold suffix; after=$afterHold',
    );
  });

  testWidgets('L-S1 preparing Key while waiting for ready', (tester) async {
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);

    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mainBrowseFeedStill_live-1')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseLiveBadge')), findsOneWidget);
  });

  testWidgets('L-S2 ready clears preparing Key', (tester) async {
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsOneWidget,
    );

    live.readyController.add(
      const LivePhotoReadyEvent(assetIdentifier: 'live-1'),
    );
    await pumpAsyncWork(tester);

    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsNothing,
    );
    expect(live.calls, contains('startPlayback'));
  });

  testWidgets('L-S3 sync request failure clears preparing; still remains',
      (tester) async {
    final live = FakeLivePhotoRepository(throwOnRequestCode: 'unsupportedMedia');
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);

    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsNothing,
    );
    expect(find.byKey(const Key('mainBrowseFeedStill_live-1')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseLiveBadge')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedPageICloud')), findsNothing);
  });

  testWidgets('L-S4 failedEvents clears preparing; still remains',
      (tester) async {
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsOneWidget,
    );

    live.failedController.add(
      const LivePhotoFailedEvent(
        assetIdentifier: 'live-1',
        error: AppError.iCloudDownloadFailed,
      ),
    );
    await pumpAsyncWork(tester);

    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsNothing,
    );
    expect(find.byKey(const Key('mainBrowseFeedStill_live-1')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedPageICloud')), findsNothing);
  });

  testWidgets('L-S5 leave while preparing clears preparing Key', (tester) async {
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    display.displaysById['still-2'] = const DisplayAsset(
      assetIdentifier: 'still-2',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/still-2.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources:
            FakeAssetSourceRepository(allIds: const ['live-1', 'still-2']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsOneWidget,
    );

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await pumpAsyncWork(tester);

    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsNothing,
    );
  });

  testWidgets(
      'L-S6 leave→return: stale ready does not clear new preparing',
      (tester) async {
    // Cap 9.5: (1) off-page stream ready after leave → no startPlayback
    // (subscriptions torn down). (2) After re-enter preparing is lit,
    // debugSetLivePreparing(stale) must not clear it — defensive gate litmus
    // (not a stream-reproducible dual-listener race; see hook doc).
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    display.displaysById['still-2'] = const DisplayAsset(
      assetIdentifier: 'still-2',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/still-2.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources:
            FakeAssetSourceRepository(allIds: const ['live-1', 'still-2']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsOneWidget,
    );

    live.calls.clear();
    final cancelHold = Completer<void>();
    live.cancelHold = cancelHold;
    live.cancelHoldAssetId = 'live-1';

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);

    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await tester.pump();
    await tester.idle();
    await tester.pump();
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsNothing,
    );

    // Stale ready while off Live — must not startPlayback.
    live.readyController.add(
      const LivePhotoReadyEvent(assetIdentifier: 'live-1'),
    );
    await tester.pump();
    expect(live.calls.where((c) => c == 'startPlayback'), isEmpty);

    // Return while cancel held — no new preparing until chain advances.
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
    await tester.pump();
    await tester.idle();
    await tester.pump();
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsNothing,
      reason: 'new activation waits on LiveHostOpSerial behind cancelHold',
    );
    expect(
      live.calls.where((c) => c == 'requestLivePhoto:live-1'),
      isEmpty,
    );

    cancelHold.complete();
    await pumpAsyncWork(tester);
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsOneWidget,
      reason: 'current activation preparing after re-enter request',
    );

    // Defensive stale write (not a stream-reproducible race today — leave
    // cancels listeners before return re-subscribes). generation 0 is never
    // current after any begin(); locks gatedFlagUpdate via the sole write path.
    final startPlaybackBeforeStale =
        live.calls.where((c) => c == 'startPlayback').length;
    final livePage = tester.state<MediaFeedPageState>(
      find.byWidgetPredicate(
        (w) => w is MediaFeedPage && w.assetIdentifier == 'live-1',
      ),
    );
    livePage.debugSetLivePreparing(0, false);
    await tester.pump();
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsOneWidget,
      reason: 'stale generation must not clear current preparing',
    );
    expect(
      live.calls.where((c) => c == 'startPlayback').length,
      startPlaybackBeforeStale,
    );

    // Current ready ends preparing and may startPlayback.
    live.readyController.add(
      const LivePhotoReadyEvent(assetIdentifier: 'live-1'),
    );
    await pumpAsyncWork(tester);
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsNothing,
    );
    expect(live.calls, contains('startPlayback'));
  });

  testWidgets('L-M1 default unmuted: setMute:false before startPlayback',
      (tester) async {
    final live = FakeLivePhotoRepository(autoReady: true);
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);

    final muteAt = live.calls.indexOf('setMute:false');
    final startAt = live.calls.indexOf('startPlayback');
    expect(muteAt, isNonNegative, reason: 'explicit setMute(false) required');
    expect(startAt, isNonNegative);
    expect(muteAt, lessThan(startAt));
  });

  testWidgets('L-M2 muted pref: setMute:true before startPlayback',
      (tester) async {
    final live = FakeLivePhotoRepository(autoReady: true);
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
        mediaDisplay: display,
        livePhoto: live,
        sharedMuteInitiallyMuted: true,
      ),
    );
    await pumpAsyncWork(tester);

    final muteAt = live.calls.indexOf('setMute:true');
    final startAt = live.calls.indexOf('startPlayback');
    expect(muteAt, isNonNegative);
    expect(startAt, isNonNegative);
    expect(muteAt, lessThan(startAt));
    expect(live.calls.contains('setMute:false'), isFalse);
  });

  testWidgets(
      'L-M3 after Live clear → video: setMute before play (index order)',
      (tester) async {
    final live = FakeLivePhotoRepository(autoReady: true);
    final playback = FakePlaybackRepository();
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    // All: unsupportedMedia → video path for v1.
    display.displayErrorById['v1'] = 'unsupportedMedia';
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources:
            FakeAssetSourceRepository(allIds: const ['live-1', 'v1']),
        mediaDisplay: display,
        playback: playback,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    expect(playback.calls, contains('clearPlaybackPool'));

    playback.calls.clear();
    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await pumpAsyncWork(tester);

    expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsOneWidget);
    final muteAt = playback.calls.indexOf('setMute:false');
    final playAt = playback.calls.indexOf('play');
    expect(muteAt, isNonNegative);
    expect(playAt, isNonNegative);
    expect(muteAt, lessThan(playAt));
  });

  testWidgets(
      'L-M4 video→Live→video: second video setMute before play',
      (tester) async {
    final live = FakeLivePhotoRepository(autoReady: true);
    final playback = FakePlaybackRepository();
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    display.displayErrorById['v1'] = 'unsupportedMedia';
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources:
            FakeAssetSourceRepository(allIds: const ['v1', 'live-1']),
        mediaDisplay: display,
        playback: playback,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsOneWidget);
    expect(playback.calls.indexOf('setMute:false'),
        lessThan(playback.calls.indexOf('play')));

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await pumpAsyncWork(tester);
    expect(playback.calls, contains('clearPlaybackPool'));

    playback.calls.clear();
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
    await pumpAsyncWork(tester);

    expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsOneWidget);
    final muteAt = playback.calls.indexOf('setMute:false');
    final playAt = playback.calls.indexOf('play');
    expect(muteAt, isNonNegative);
    expect(playAt, isNonNegative);
    expect(muteAt, lessThan(playAt));
  });
}

class _HangingResolveRepository extends FakeAssetSourceRepository {
  _HangingResolveRepository({super.allIds});

  final Completer<void> gate = Completer<void>();

  @override
  Future<ResolvedSource> resolve(SourceReference reference) async {
    await gate.future;
    return super.resolve(reference);
  }
}

class _ThrowingResolveRepository extends FakeAssetSourceRepository {
  @override
  Future<ResolvedSource> resolve(SourceReference reference) async {
    resolveCalls += 1;
    lastResolve = reference;
    resolveHistory.add(reference);
    throw StateError('resolve failed');
  }
}

/// Fails the first [failTimes] resolve calls, then delegates to the fake.
class _FailThenSucceedRepository extends FakeAssetSourceRepository {
  _FailThenSucceedRepository({
    super.allIds,
    super.photosIds,
    super.videosIds,
    this.failTimes = 1,
  });

  final int failTimes;
  int _failuresEmitted = 0;

  @override
  Future<ResolvedSource> resolve(SourceReference reference) async {
    if (_failuresEmitted < failTimes) {
      _failuresEmitted += 1;
      resolveCalls += 1;
      lastResolve = reference;
      resolveHistory.add(reference);
      throw StateError('resolve failed');
    }
    return super.resolve(reference);
  }
}
