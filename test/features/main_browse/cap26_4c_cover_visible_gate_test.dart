import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';

import '../../domain/library/fake_waketok_album_store.dart';
import '../../library_smoke/fake_album_mutation_repository.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
import '../authorization/permission_ui_test_harness.dart';
import 'still_cover_test_helpers.dart';

/// Cap 26.4c / ADR-054 — the five hard gate combinations that must not be
/// covered only by predicate unit tests or empty-source chrome.
///
/// Empty source (`actionable == false`, no current id) is a **different**
/// axis from cover-visible miss (`actionable == true` ∧ `¬coverVisible`).
/// These cases assert the latter; do not treat W-26.4b-3 as a substitute.

FakeAssetSourceRepository _local([String id = 'a1']) {
  return FakeAssetSourceRepository(
    allIds: [id],
    availabilityById: FakeAssetSourceRepository.deviceLocalForIds([id]),
  );
}

ProviderContainer _containerOf(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
}

InkWell _ink(WidgetTester tester, Key key) {
  return tester.widget<InkWell>(find.byKey(key));
}

Semantics _semanticsAncestor(WidgetTester tester, Key key) {
  return tester.widget<Semantics>(
    find.ancestor(of: find.byKey(key), matching: find.byType(Semantics)).first,
  );
}

Future<void> _pumpShell(WidgetTester tester) async {
  final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
  await tester.pumpWidget(
    permissionUiHarness(repo: repo, assetSources: _local()),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'W-26.4c-1 Share race: L2 ready ∧ ¬coverVisible → Share onTap null '
    '(ADR-054 A)',
    (tester) async {
      await _pumpShell(tester);
      await ensureShellMediaCoverVisible(tester);

      final container = _containerOf(tester);
      // Production can publish L2 before cover frame is ready; weld that
      // window: keep L2 true, force cover unresolved.
      container
          .read(mainBrowseCurrentAssetLayer2DisplayReadyProvider.notifier)
          .setReady(true);
      final page = tester.state<MediaFeedPageState>(
        find.byWidgetPredicate((w) => w is MediaFeedPage && w.isCurrent),
      );
      page.debugForceStillCoverUnresolved();
      await tester.pump();
      await tester.pump();

      expect(container.read(mainBrowseCurrentAssetActionableProvider), isTrue);
      expect(
        container.read(mainBrowseCurrentAssetLayer2DisplayReadyProvider),
        isTrue,
      );
      expect(
        container.read(mainBrowseCurrentAssetMediaCoverVisibleProvider),
        isFalse,
      );
      expect(_ink(tester, const Key('cap25ShareEntryIcon')).onTap, isNull);
      expect(
        _semanticsAncestor(tester, const Key('cap25ShareEntryIcon')).properties.enabled,
        isFalse,
      );
    },
  );

  testWidgets(
    'W-26.4c-7 debt-473 Loading-item miss: More onTap null while actionable '
    '(not empty-source)',
    (tester) async {
      await _pumpShell(tester);
      await ensureShellMediaCoverVisible(tester);

      final container = _containerOf(tester);
      expect(container.read(mainBrowseCurrentAssetIdProvider), isNotNull);
      expect(container.read(mainBrowseCurrentAssetActionableProvider), isTrue);
      expect(_ink(tester, const Key('cap24MoreEntryIcon')).onTap, isNotNull);

      final page = tester.state<MediaFeedPageState>(
        find.byWidgetPredicate((w) => w is MediaFeedPage && w.isCurrent),
      );
      page.debugForceA4LoadingGate();
      await tester.pump();
      await tester.pump();

      // Distinct from empty-source: id still determined → actionable stays true.
      expect(container.read(mainBrowseCurrentAssetIdProvider), isNotNull);
      expect(container.read(mainBrowseCurrentAssetActionableProvider), isTrue);
      expect(
        container.read(mainBrowseCurrentAssetMediaCoverVisibleProvider),
        isFalse,
      );
      expect(page.debugLoading, isTrue);
      expect(_ink(tester, const Key('cap24MoreEntryIcon')).onTap, isNull);
      expect(
        _semanticsAncestor(tester, const Key('cap24MoreEntryIcon'))
            .properties
            .enabled,
        isFalse,
      );
    },
  );

  testWidgets(
    'W-26.4c-3 cover ready ∧ ¬L2: More/Album onTap set; Share onTap null',
    (tester) async {
      await _pumpShell(tester);
      await ensureShellMediaCoverVisible(tester);

      final container = _containerOf(tester);
      expect(
        container.read(mainBrowseCurrentAssetMediaCoverVisibleProvider),
        isTrue,
      );
      // Weld L2-not-yet without fighting cover publish (L2 is not rebuilt
      // every frame the way cover-visible is).
      container
          .read(mainBrowseCurrentAssetLayer2DisplayReadyProvider.notifier)
          .setReady(false);
      await tester.pump();

      expect(
        container.read(mainBrowseCurrentAssetMediaCoverVisibleProvider),
        isTrue,
      );
      expect(
        container.read(mainBrowseCurrentAssetLayer2DisplayReadyProvider),
        isFalse,
      );
      expect(_ink(tester, const Key('cap24MoreEntryIcon')).onTap, isNotNull);
      expect(_ink(tester, const Key('cap19EntryIcon')).onTap, isNotNull);
      expect(_ink(tester, const Key('cap25ShareEntryIcon')).onTap, isNull);
    },
  );

  testWidgets(
    'W-26.4c-6 coverless video: ¬surfaceReady disables three icons; '
    'surfaceReady → Share follows D14',
    (tester) async {
      await _pumpShell(tester);

      final container = _containerOf(tester);
      final page = tester.state<MediaFeedPageState>(
        find.byWidgetPredicate((w) => w is MediaFeedPage && w.isCurrent),
      );

      page.debugForceCoverlessVideoSurface(surfaceReady: false);
      await tester.pump();
      await tester.pump();

      expect(container.read(mainBrowseCurrentAssetActionableProvider), isTrue);
      expect(page.debugSurfaceReady, isFalse);
      expect(
        container.read(mainBrowseCurrentAssetMediaCoverVisibleProvider),
        isFalse,
      );
      expect(_ink(tester, const Key('cap24MoreEntryIcon')).onTap, isNull);
      expect(_ink(tester, const Key('cap25ShareEntryIcon')).onTap, isNull);
      expect(_ink(tester, const Key('cap19EntryIcon')).onTap, isNull);

      page.debugForceCoverlessVideoSurface(surfaceReady: true);
      await tester.pump();
      await tester.pump();

      expect(page.debugSurfaceReady, isTrue);
      expect(
        container.read(mainBrowseCurrentAssetMediaCoverVisibleProvider),
        isTrue,
      );
      expect(
        container.read(mainBrowseCurrentAssetLayer2DisplayReadyProvider),
        isTrue,
      );
      // Coverless: surfaceReady flips coverVisible and L2 together → D14 ok.
      expect(_ink(tester, const Key('cap25ShareEntryIcon')).onTap, isNotNull);
      expect(_ink(tester, const Key('cap24MoreEntryIcon')).onTap, isNotNull);
      expect(_ink(tester, const Key('cap19EntryIcon')).onTap, isNotNull);
    },
  );

  testWidgets(
    'W-26.4c-9 ¬coverVisible: left-swipe gesture not armed (not icon-only)',
    (tester) async {
      final mutations = FakeAlbumMutationRepository();
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _local(),
          albumMutations: mutations,
          wakeTokAlbumStore: FakeWakeTokAlbumStore()..albumId = 'wt-album',
        ),
      );
      await tester.pumpAndSettle();
      await ensureShellMediaCoverVisible(tester);

      expect(find.byKey(const Key('cap19LeftSwipeGesture')), findsOneWidget);

      final container = _containerOf(tester);
      final page = tester.state<MediaFeedPageState>(
        find.byWidgetPredicate((w) => w is MediaFeedPage && w.isCurrent),
      );
      page.debugForceStillCoverUnresolved();
      await tester.pump();
      await tester.pump();

      expect(container.read(mainBrowseCurrentAssetActionableProvider), isTrue);
      expect(
        container.read(mainBrowseCurrentAssetMediaCoverVisibleProvider),
        isFalse,
      );
      expect(find.byKey(const Key('cap19LeftSwipeGesture')), findsNothing);

      // Gesture gone → PageView swipe must not append.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await gesture.moveBy(const Offset(-100, 4));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(mutations.addCalls, 0);
    },
  );
}
