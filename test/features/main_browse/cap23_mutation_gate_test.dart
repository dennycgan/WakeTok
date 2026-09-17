import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/cap19_left_swipe_providers.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_append_controller.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_arbitration.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';

import '../../library_smoke/fake_album_mutation_repository.dart';
import '../../library_smoke/fake_asset_favorite_repository.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_cap19_left_swipe_preferences.dart';
import '../authorization/permission_ui_test_harness.dart';

AssetSource _writableAlbum({
  required String id,
  required String displayName,
}) {
  return AssetSource(
    kind: AssetSourceKind.album,
    id: id,
    displayName: displayName,
    estimatedCount: 3,
    availability: AssetSourceAvailability.available,
    canAddContent: true,
  );
}

FakeAssetSourceRepository _sources({
  required Map<String, AssetAvailability> availabilityById,
  List<AssetSource> extraSources = const [],
}) {
  return FakeAssetSourceRepository(
    allIds: availabilityById.keys.toList(growable: false),
    availabilityById: availabilityById,
    extraSources: extraSources,
  );
}

Future<void> _pumpBrowse({
  required WidgetTester tester,
  required FakeAssetSourceRepository sources,
  FakeAssetFavoriteRepository? favorites,
  FakeAlbumMutationRepository? mutations,
}) async {
  await tester.pumpWidget(
    permissionUiHarness(
      repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
      assetSources: sources,
      assetFavorites: favorites,
      albumMutations: mutations,
    ),
  );
  await tester.pumpAndSettle();
  // Cap 26.4c: Action Column needs cover-visible; FakeAsync / FileImage may
  // not fire frameBuilder — force painted cover when a current page exists.
  await tester.pump();
  final coverFinder = find.byWidgetPredicate(
    (w) => w is MediaFeedPage && w.isCurrent,
  );
  if (coverFinder.evaluate().isNotEmpty) {
    final page = tester.state<MediaFeedPageState>(coverFinder);
    if (!page.debugStillCoverReady || page.debugStillCoverDecodeBroken) {
      page.debugForceStillCoverDecodeBroken(false);
    }
    await tester.pump();
    await tester.pump();
  }
}

ProviderContainer _containerOf(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cap 23.3 mutation gate wiring', () {
    testWidgets('W-23-1 unavailable entry → dialog, no half-sheet', (
      tester,
    ) async {
      final sources = _sources(
        availabilityById: {
          'a1': AssetAvailability.unavailable,
        },
      );
      await _pumpBrowse(tester: tester, sources: sources);
      final before = sources.getAssetAvailabilitiesCalls;

      await tester.tap(find.byKey(const Key('cap19EntryIcon')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('stillInLibraryUnavailableDialog')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsNothing);
      expect(sources.getAssetAvailabilitiesCalls, greaterThan(before));
    });

    testWidgets('W-23-2 deviceLocal entry → half-sheet, no dialog', (
      tester,
    ) async {
      final sources = _sources(
        availabilityById: {
          'a1': AssetAvailability.deviceLocal,
        },
      );
      await _pumpBrowse(tester: tester, sources: sources);

      await tester.tap(find.byKey(const Key('cap19EntryIcon')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsOneWidget);
      expect(
        find.byKey(const Key('stillInLibraryUnavailableDialog')),
        findsNothing,
      );
    });

    testWidgets('W-23-3 iCloudNotDownloaded entry → half-sheet', (
      tester,
    ) async {
      final sources = _sources(
        availabilityById: {
          'a1': AssetAvailability.iCloudNotDownloaded,
        },
      );
      await _pumpBrowse(tester: tester, sources: sources);

      await tester.tap(find.byKey(const Key('cap19EntryIcon')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsOneWidget);
      expect(
        find.byKey(const Key('stillInLibraryUnavailableDialog')),
        findsNothing,
      );
    });

    testWidgets('W-23-4 probing latch: second entry tap does not dual Host', (
      tester,
    ) async {
      final gate = Completer<void>();
      final sources = _sources(
        availabilityById: {
          'a1': AssetAvailability.deviceLocal,
        },
      )..beforeEachGetAssetAvailabilities = (_) => gate.future;
      await _pumpBrowse(tester: tester, sources: sources);
      final before = sources.getAssetAvailabilitiesCalls;

      await tester.tap(find.byKey(const Key('cap19EntryIcon')));
      await tester.pump();
      expect(
        _containerOf(tester)
            .read(mainBrowseCurrentAssetStillInLibraryProvider)
            .status,
        StillInLibraryStatus.probing,
      );

      await tester.tap(find.byKey(const Key('cap19EntryIcon')));
      await tester.pump();
      expect(sources.getAssetAvailabilitiesCalls, before + 1);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsOneWidget);
    });

    testWidgets('W-23-5 dialog latch: busy while dialog visible; clear on OK', (
      tester,
    ) async {
      final sources = _sources(
        availabilityById: {
          'a1': AssetAvailability.unavailable,
        },
      );
      await _pumpBrowse(tester: tester, sources: sources);

      await tester.tap(find.byKey(const Key('cap19EntryIcon')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('stillInLibraryUnavailableDialog')),
        findsOneWidget,
      );

      final container = _containerOf(tester);
      expect(
        container.read(mainBrowseCurrentAssetStillInLibraryProvider).isBusy,
        isTrue,
      );
      final before = sources.getAssetAvailabilitiesCalls;
      final second = await container
          .read(mainBrowseCurrentAssetStillInLibraryProvider.notifier)
          .probeCurrentAssetStillInLibrary();
      expect(second, isFalse);
      expect(sources.getAssetAvailabilitiesCalls, before);

      await tester.tap(
        find.byKey(const Key('stillInLibraryUnavailableDialogDismiss')),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(mainBrowseCurrentAssetStillInLibraryProvider).isBusy,
        isFalse,
      );
    });

    testWidgets(
      'W-23-11 Favorites re-probe after sheet open when asset goes missing',
      (tester) async {
        final favorites = FakeAssetFavoriteRepository();
        final sources = _sources(
          availabilityById: {
            'a1': AssetAvailability.deviceLocal,
          },
        );
        await _pumpBrowse(
          tester: tester,
          sources: sources,
          favorites: favorites,
        );

        await tester.tap(find.byKey(const Key('cap19EntryIcon')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsOneWidget);

        sources.availabilityById['a1'] = AssetAvailability.unavailable;
        final before = sources.getAssetAvailabilitiesCalls;

        await tester.tap(find.byKey(const Key('cap19FavoritesRow')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('stillInLibraryUnavailableDialog')),
          findsOneWidget,
        );
        expect(favorites.setCalls, 0);
        expect(sources.getAssetAvailabilitiesCalls, before + 1);
      },
    );

    testWidgets(
      'W-23-11b Add-to-Album re-probe after sheet open when asset goes missing',
      (tester) async {
        final mutations = FakeAlbumMutationRepository();
        final sources = _sources(
          availabilityById: {
            'a1': AssetAvailability.deviceLocal,
          },
          extraSources: [
            _writableAlbum(id: 'alb-1', displayName: 'Alpha'),
          ],
        );
        await _pumpBrowse(
          tester: tester,
          sources: sources,
          mutations: mutations,
        );

        await tester.tap(find.byKey(const Key('cap19EntryIcon')));
        await tester.pumpAndSettle();
        sources.availabilityById['a1'] = AssetAvailability.unavailable;
        final before = sources.getAssetAvailabilitiesCalls;

        await tester.tap(find.byKey(const Key('cap19AlbumPickerRow-alb-1')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('stillInLibraryUnavailableDialog')),
          findsOneWidget,
        );
        expect(mutations.addCalls, 0);
        expect(sources.getAssetAvailabilitiesCalls, before + 1);
      },
    );

    test('W-23-8 left-swipe arm predicate does not require Host probe', () {
      // Arming is pure ([leftSwipeArmingAllowed]); Host probe lives only on
      // append (W-23-9). Guarantees ADR-049 "not on arm".
      expect(
        leftSwipeArmingAllowed(
          leftSwipeAddEnabled: true,
          isCurrentStillMagnified: false,
          cap19PanelOpen: false,
          currentAssetMediaCoverVisible: true,
          currentAssetActionable: true,
        ),
        isTrue,
      );
    });

    test('W-23-9 append missing → notInLibrary + dialogVisible armed',
        () async {
      final sources = FakeAssetSourceRepository(
        allIds: const ['a1'],
        availabilityById: const {
          'a1': AssetAvailability.unavailable,
        },
      );
      final container = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(sources),
          mainBrowseCurrentAssetIdProvider.overrideWith((ref) => 'a1'),
          cap19LeftSwipePreferencesProvider.overrideWithValue(
            FakeCap19LeftSwipePreferences(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final outcome = await container
          .read(cap19LeftSwipeAppendProvider.notifier)
          .appendCurrentAssetToWakeTokAlbum();

      expect(outcome, Cap19LeftSwipeAppendOutcome.notInLibrary);
      expect(
        container.read(mainBrowseCurrentAssetStillInLibraryProvider).dialogVisible,
        isTrue,
      );
      expect(sources.getAssetAvailabilitiesCalls, 1);
    });

    testWidgets('W-23-10 barrier dismiss clears dialogVisible latch', (
      tester,
    ) async {
      final sources = _sources(
        availabilityById: {
          'a1': AssetAvailability.unavailable,
        },
      );
      await _pumpBrowse(tester: tester, sources: sources);

      await tester.tap(find.byKey(const Key('cap19EntryIcon')));
      await tester.pumpAndSettle();
      final container = _containerOf(tester);
      expect(
        container.read(mainBrowseCurrentAssetStillInLibraryProvider).dialogVisible,
        isTrue,
      );

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('stillInLibraryUnavailableDialog')),
        findsNothing,
      );
      expect(
        container.read(mainBrowseCurrentAssetStillInLibraryProvider).dialogVisible,
        isFalse,
      );

      final beforeReprobe = sources.getAssetAvailabilitiesCalls;
      await tester.tap(find.byKey(const Key('cap19EntryIcon')));
      await tester.pumpAndSettle();
      expect(
        sources.getAssetAvailabilitiesCalls,
        beforeReprobe + 1,
        reason: 'barrier-cleared latch must allow a fresh Host probe',
      );
      expect(
        find.byKey(const Key('stillInLibraryUnavailableDialog')),
        findsOneWidget,
      );
    });
  });
}
