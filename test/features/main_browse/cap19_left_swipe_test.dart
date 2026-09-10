import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/library/waketok_album_constants.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_arbitration.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_drag.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_guide.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_session.dart';
import 'package:waketok/features/main_browse/main_browse_shell_page.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../domain/library/fake_waketok_album_store.dart';
import '../../library_smoke/fake_album_mutation_repository.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_cap19_left_swipe_preferences.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_playback_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

const _wakeTokAlbumId = 'waketok-album-1';

FakeAssetSourceRepository _assetSourcesForLeftSwipe({
  List<String> allIds = const [],
}) {
  return FakeAssetSourceRepository(
    allIds: allIds,
    availabilityById: FakeAssetSourceRepository.deviceLocalForIds(allIds),
    extraSources: [
      _waketokAlbum(albumId: _wakeTokAlbumId),
    ],
  );
}

AssetSource _waketokAlbum({required String albumId}) {
  return AssetSource(
    kind: AssetSourceKind.album,
    id: albumId,
    displayName: waketokAlbumTitle,
    estimatedCount: 1,
    availability: AssetSourceAvailability.available,
    canAddContent: true,
  );
}

Future<void> _pumpAsyncWork(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> _simulateLeftSwipeOnPageView(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(PageView)),
  );
  await gesture.moveBy(const Offset(-100, 4));
  await gesture.up();
}

Future<void> _settleCap19Toasts(WidgetTester tester) async {
  await tester.pump(kCap19BrowseToastDuration);
  resetCap19BrowseToastForTest();
}

void main() {
  setUp(Cap19LeftSwipeGuideSession.resetForTest);
  tearDown(() {
    resetCap19BrowseToastForTest();
    Cap19LeftSwipeGuideSession.resetForTest();
  });

  testWidgets('W-19.6-1 left swipe bootstraps and appends current asset',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final mutations = FakeAlbumMutationRepository();
    final albumStore = FakeWakeTokAlbumStore()..albumId = _wakeTokAlbumId;
    final sources = _assetSourcesForLeftSwipe(allIds: const ['asset-1']);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: sources,
        albumMutations: mutations,
        wakeTokAlbumStore: albumStore,
      ),
    );
    await tester.pumpAndSettle();

    await _simulateLeftSwipeOnPageView(tester);
    await tester.pumpAndSettle();

    expect(mutations.addCalls, 1);
    expect(mutations.lastAssetId, 'asset-1');
    expect(mutations.lastAlbumId, _wakeTokAlbumId);
    await _settleCap19Toasts(tester);
  });

  testWidgets('W-19.6-2 leftSwipeAddEnabled false does not append',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final mutations = FakeAlbumMutationRepository();
    final prefs = FakeCap19LeftSwipePreferences()..leftSwipeAddEnabled = false;
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['asset-1'], availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const ['asset-1'])),
        albumMutations: mutations,
        cap19LeftSwipePreferences: prefs,
      ),
    );
    await tester.pumpAndSettle();

    await _simulateLeftSwipeOnPageView(tester);
    await tester.pumpAndSettle();
    expect(mutations.addCalls, 0);
  });

  testWidgets('W-19.6-3 success shows top toast', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final albumStore = FakeWakeTokAlbumStore()..albumId = _wakeTokAlbumId;
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: _assetSourcesForLeftSwipe(allIds: const ['asset-1']),
        wakeTokAlbumStore: albumStore,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _simulateLeftSwipeOnPageView(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cap19LeftSwipeAppendSuccessToast')), findsOneWidget);
    expect(find.text(l10n.cap19LeftSwipeAppendSuccess), findsOneWidget);
    await _settleCap19Toasts(tester);
  });

  testWidgets('W-19.6-4 append does not restart browse session', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final albumStore = FakeWakeTokAlbumStore()..albumId = _wakeTokAlbumId;
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: _assetSourcesForLeftSwipe(allIds: const ['a1', 'a2']),
        wakeTokAlbumStore: albumStore,
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MainBrowseShellPage)),
    );
    final epochBefore =
        container.read(browseSessionProvider).asData!.value.roundEpoch;

    await _simulateLeftSwipeOnPageView(tester);
    await tester.pumpAndSettle();

    final epochAfter =
        container.read(browseSessionProvider).asData!.value.roundEpoch;
    expect(epochAfter, epochBefore);
    await _settleCap19Toasts(tester);
  });

  testWidgets('W-19.6-5 vertical drag still changes page', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['v1', 'v2'], availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const ['v1', 'v2'])),
      ),
    );
    await _pumpAsyncWork(tester);

    await tester.drag(find.byType(PageView), const Offset(0, -280));
    await _pumpAsyncWork(tester);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('W-19.6-6 scrubber-band horizontal drag does not append',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final mutations = FakeAlbumMutationRepository();
    final display = FakeMediaDisplayRepository();
    final playback = FakePlaybackRepository();
    for (final id in const ['v1']) {
      display.displayErrorById[id] = 'unsupportedMedia';
      display.previewsById[id] = DisplayAsset(
        assetIdentifier: id,
        mediaKind: PlaybackMediaKind.video,
        localFilePath: '/tmp/fake_preview_$id.jpg',
      );
    }
    final albumStore = FakeWakeTokAlbumStore()..albumId = _wakeTokAlbumId;
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: _assetSourcesForLeftSwipe(allIds: const ['v1']),
        albumMutations: mutations,
        mediaDisplay: display,
        playback: playback,
        wakeTokAlbumStore: albumStore,
      ),
    );
    await _pumpAsyncWork(tester);
    for (var i = 0; i < 40; i++) {
      if (find.byKey(const Key('mainBrowseVideoScrubber')).evaluate().isNotEmpty) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 20));
    }

    await tester.drag(
      find.byKey(const Key('mainBrowseVideoScrubber')),
      const Offset(120, 0),
    );
    await _pumpAsyncWork(tester);
    expect(mutations.addCalls, 0);
  });

  testWidgets('W-19.6-7 guide shows once per session on Browse', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final prefs = FakeCap19LeftSwipePreferences()
      ..leftSwipeAddEnabled = true
      ..leftSwipeGuideEnabled = true;
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1'], availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const ['a1'])),
        cap19LeftSwipePreferences: prefs,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsOneWidget);
    await tester.pump(kCap19LeftSwipeGuideDuration);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsNothing);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsNothing);
  });

  testWidgets(
    'W-19.6-8 parent off overrides guide on — no guide, no append',
    (tester) async {
      // Explicit: guide KV is ON — we are testing parent override, not both off.
      final prefs = FakeCap19LeftSwipePreferences()
        ..leftSwipeAddEnabled = false
        ..leftSwipeGuideEnabled = true;
      final mutations = FakeAlbumMutationRepository();
      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(allIds: const ['a1'], availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const ['a1'])),
          albumMutations: mutations,
          cap19LeftSwipePreferences: prefs,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsNothing);
      await _simulateLeftSwipeOnPageView(tester);
      await tester.pumpAndSettle();
      expect(mutations.addCalls, 0);
    },
  );

  testWidgets(
    'W-19.6-10 guide off still allows append when feature on',
    (tester) async {
      final prefs = FakeCap19LeftSwipePreferences()
        ..leftSwipeAddEnabled = true
        ..leftSwipeGuideEnabled = false;
      final mutations = FakeAlbumMutationRepository();
      final albumStore = FakeWakeTokAlbumStore()..albumId = _wakeTokAlbumId;
      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: _assetSourcesForLeftSwipe(allIds: const ['a1']),
          albumMutations: mutations,
          cap19LeftSwipePreferences: prefs,
          wakeTokAlbumStore: albumStore,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsNothing);
      await _simulateLeftSwipeOnPageView(tester);
      await tester.pumpAndSettle();
      expect(mutations.addCalls, 1);
      await _settleCap19Toasts(tester);
    },
  );

  testWidgets('W-19.6-9 magnified stub blocks left swipe append', (tester) async {
    final mutations = FakeAlbumMutationRepository();
    final albumStore = FakeWakeTokAlbumStore()..albumId = _wakeTokAlbumId;
    await tester.pumpWidget(
      permissionUiHarness(
        repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
        assetSources: _assetSourcesForLeftSwipe(allIds: const ['a1']),
        albumMutations: mutations,
        wakeTokAlbumStore: albumStore,
        forceStillMagnified: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cap19LeftSwipeGesture')), findsNothing);
    await _simulateLeftSwipeOnPageView(tester);
    await tester.pumpAndSettle();
    expect(mutations.addCalls, 0);
  });

  testWidgets('W-19.8-drag chip copy switches at 72px threshold', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: waketokTheme(Brightness.dark),
          home: const Scaffold(
            body: Stack(
              children: [
                Cap19LeftSwipeAlbumReveal(isCurrent: true),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    container
        .read(cap19LeftSwipeDragProvider.notifier)
        .updateOffset(-(kCap19LeftSwipeDistanceThreshold - 1));
    await tester.pump();
    expect(find.text(l10n.cap19LeftSwipeDragHintContinue), findsOneWidget);
    expect(find.text(l10n.cap19LeftSwipeDragHintArmed), findsNothing);

    container
        .read(cap19LeftSwipeDragProvider.notifier)
        .updateOffset(-kCap19LeftSwipeDistanceThreshold);
    await tester.pump();
    expect(find.text(l10n.cap19LeftSwipeDragHintArmed), findsOneWidget);
    expect(find.text(l10n.cap19LeftSwipeDragHintContinue), findsNothing);
  });

  testWidgets(
    'W-22.5b advance remount with unfinished left-swipe pointer does not throw',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final albumStore = FakeWakeTokAlbumStore()..albumId = _wakeTokAlbumId;
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _assetSourcesForLeftSwipe(
            allIds: const ['a', 'b', 'c', 'd', 'e'],
          ),
          wakeTokAlbumStore: albumStore,
          browseShuffleSeed: 0,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap19LeftSwipeGesture')), findsOneWidget);

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      final epochBefore =
          container.read(browseSessionProvider).requireValue.roundEpoch;

      // Hold a pointer on the left-swipe Listener, then force scheme A
      // advance remount (clears Cap19 drag before page-tree swap).
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('cap19LeftSwipeGesture'))),
      );
      await gesture.moveBy(const Offset(-40, 2));
      await tester.pump();

      final feedState = tester.state<VerticalMediaFeedState>(
        find.byType(VerticalMediaFeed),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      feedState.debugAdvanceEndlessRound(l10n);
      await tester.pump();
      await tester.pump();

      expect(
        container.read(browseSessionProvider).requireValue.roundEpoch,
        greaterThan(epochBefore),
      );

      // Pointer up after remount disposed the prior Listener — must not throw.
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(container.read(cap19LeftSwipeDragProvider).offsetX, 0);

      await tester.pump(const Duration(milliseconds: 200));
      hideCap19BrowseToast();
      await tester.pump(kCap19BrowseToastDuration);
    },
  );
}
