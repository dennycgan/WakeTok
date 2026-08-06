import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/resolved_source.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/main_browse/feed_media_request_gate.dart';
import 'package:waketok/features/main_browse/feed_page_media.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/main_browse_shell_page.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_playback_repository.dart';
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
    expect(find.byKey(const Key('mainBrowseFeedRetry')), findsOneWidget);
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
}

class _ThrowingResolveRepository extends FakeAssetSourceRepository {
  @override
  Future<ResolvedSource> resolve(SourceReference reference) async {
    throw StateError('resolve failed');
  }
}
