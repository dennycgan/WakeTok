import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
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
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_playback_repository.dart';
import '../../library_smoke/fake_presentation_metadata_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

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
    await tester.pumpAndSettle();

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
