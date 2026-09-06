import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/pool_capacity.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/build_pool_scaffold_page.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

AssetSource _album(String id, String name) {
  return AssetSource(
    kind: AssetSourceKind.album,
    id: id,
    displayName: name,
    estimatedCount: 3,
    availability: AssetSourceAvailability.available,
    canAddContent: false,
  );
}

SourceReference _albumRef(String id) =>
    SourceReference(kind: AssetSourceKind.album, id: id);

Future<void> _openBuild(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('mainBrowseCreatePool')));
  await tester.pumpAndSettle();
  expect(find.byKey(BuildPoolScaffoldPage.pageKey), findsOneWidget);
}

Key _catalogKey(SourceReference ref) =>
    Key('mainBrowseBuildPoolCatalog_${ref.kind.name}_${ref.id}');

void main() {
  group('U-21.4 Build a Pool', () {
    testWidgets('U-21.4-1 catalog lists user albums, not built-ins',
        (tester) async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a1'],
        photosIds: const ['p1'],
        videosIds: const ['v1'],
        extraSources: [_album('alb-1', 'Travel')],
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: fake),
      );
      await tester.pumpAndSettle();
      await _openBuild(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.mainBrowseBuildPoolSectionAlbums), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text(l10n.mainBrowseBuildPoolSectionBuiltIn), findsNothing);
      expect(find.byKey(_catalogKey(SourceReference.all)), findsNothing);
      expect(find.byKey(_catalogKey(SourceReference.photos)), findsNothing);
    });

    testWidgets('U-21.4-2 no albums (Limited-style) shows empty catalog',
        (tester) async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a1'],
        photosIds: const ['p1'],
        videosIds: const ['v1'],
        extraSources: const [],
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: fake),
      );
      await tester.pumpAndSettle();
      await _openBuild(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byKey(BuildPoolScaffoldPage.catalogEmptyKey), findsOneWidget);
      expect(find.text(l10n.mainBrowseBuildPoolCatalogEmpty), findsOneWidget);
      final start = tester.widget<FilledButton>(
        find.byKey(BuildPoolScaffoldPage.startKey),
      );
      expect(start.onPressed, isNull);
    });

    testWidgets('U-21.4-3 Start disabled at zero; enabled after select',
        (tester) async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a1'],
        extraSources: [_album('alb-1', 'Travel')],
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: fake),
      );
      await tester.pumpAndSettle();
      await _openBuild(tester);

      final start = tester.widget<FilledButton>(
        find.byKey(BuildPoolScaffoldPage.startKey),
      );
      expect(start.onPressed, isNull);

      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-1'))));
      await tester.pumpAndSettle();
      final enabled = tester.widget<FilledButton>(
        find.byKey(BuildPoolScaffoldPage.startKey),
      );
      expect(enabled.onPressed, isNotNull);
    });

    testWidgets('U-21.4-4 at 30 selected further adds are blocked',
        (tester) async {
      final extras = <AssetSource>[
        for (var i = 0; i < PoolCapacity.maxSourcesPerPool + 1; i++)
          _album('alb-$i', 'Album $i'),
      ];
      final fake = FakeAssetSourceRepository(
        allIds: const ['a1'],
        extraSources: extras,
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: fake),
      );
      await tester.pumpAndSettle();
      await _openBuild(tester);

      final catalogScrollable = find.descendant(
        of: find.byKey(BuildPoolScaffoldPage.catalogKey),
        matching: find.byType(Scrollable),
      );

      for (var i = 0; i < PoolCapacity.maxSourcesPerPool; i++) {
        final key = _catalogKey(_albumRef('alb-$i'));
        await tester.scrollUntilVisible(
          find.byKey(key),
          80,
          scrollable: catalogScrollable,
        );
        await tester.tap(find.byKey(key));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      final overflowKey = _catalogKey(
        _albumRef('alb-${PoolCapacity.maxSourcesPerPool}'),
      );
      await tester.scrollUntilVisible(
        find.byKey(overflowKey),
        80,
        scrollable: catalogScrollable,
      );
      final tile = tester.widget<ListTile>(find.byKey(overflowKey));
      expect(tile.onTap, isNull);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        find.text(l10n.mainBrowseBuildPoolSelectedHeading(30)),
        findsOneWidget,
      );
    });

    testWidgets('U-21.4-5 selection order is Definition order on Start',
        (tester) async {
      // Product reorder uses ReorderableListView; order-of-add is the
      // Definition order contract without relying on flaky drag in CI.
      final fake = FakeAssetSourceRepository(
        allIds: const ['a1'],
        extraSources: [_album('alb-1', 'Travel'), _album('alb-2', 'Family')],
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: fake),
      );
      await tester.pumpAndSettle();
      await _openBuild(tester);

      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-2'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-1'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BuildPoolScaffoldPage.startKey));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final parked =
          container.read(browseChromeStateProvider).parkedEphemeralPool!;
      expect(
        parked.orderedSourceReferences,
        [_albumRef('alb-2'), _albumRef('alb-1')],
      );
    });

    testWidgets('U-21.4-5b ReorderableListView onReorder updates order',
        (tester) async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a1'],
        extraSources: [_album('alb-1', 'Travel'), _album('alb-2', 'Family')],
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: fake),
      );
      await tester.pumpAndSettle();
      await _openBuild(tester);

      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-1'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-2'))));
      await tester.pumpAndSettle();

      final list = tester.widget<ReorderableListView>(
        find.byKey(BuildPoolScaffoldPage.selectedListKey),
      );
      list.onReorder(0, 2);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(BuildPoolScaffoldPage.startKey));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final parked =
          container.read(browseChromeStateProvider).parkedEphemeralPool!;
      expect(
        parked.orderedSourceReferences,
        [_albumRef('alb-2'), _albumRef('alb-1')],
      );
    });

    testWidgets('U-21.4-6 Start parks ephemeral and returns to feed',
        (tester) async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a1'],
        extraSources: [_album('alb-1', 'Travel')],
        albumResolveIds: const {
          'alb-1': ['t1', 't2'],
        },
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: fake),
      );
      await tester.pumpAndSettle();
      await _openBuild(tester);

      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-1'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BuildPoolScaffoldPage.startKey));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mainBrowseFeed')), findsOneWidget);
      expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final chrome = container.read(browseChromeStateProvider);
      expect(chrome.parkedEphemeralPool, isNotNull);
      expect(chrome.activeOrigin, isA<BrowseOriginEphemeralPool>());
      final session = await container.read(browseSessionProvider.future);
      expect(session.orderedAssetIds, ['t1', 't2']);
    });

    testWidgets('U-21.4-7 back without Start preserves chrome (D6.1 cancel)',
        (tester) async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a1'],
        extraSources: [_album('alb-1', 'Travel')],
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: fake),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final before = container.read(browseChromeStateProvider);

      await _openBuild(tester);
      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-1'))));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(container.read(browseChromeStateProvider), before);
      expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsNothing);
    });

    testWidgets('U-21.4-8 Start session uses selected source resolve',
        (tester) async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['all-only'],
        extraSources: [_album('alb-1', 'Travel'), _album('alb-2', 'Family')],
        albumResolveIds: const {
          'alb-1': ['t-a', 't-b'],
          'alb-2': ['f-x'],
        },
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: fake),
      );
      await tester.pumpAndSettle();
      await _openBuild(tester);
      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-1'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BuildPoolScaffoldPage.startKey));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final session = await container.read(browseSessionProvider.future);
      expect(session.orderedAssetIds.toSet(), {'t-a', 't-b'});
      expect(session.orderedAssetIds.length, 2);
    });

    testWidgets('U-21.4-9 second Start replaces parked Definition',
        (tester) async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a1'],
        extraSources: [_album('alb-1', 'Travel'), _album('alb-2', 'Family')],
        albumResolveIds: const {
          'alb-1': ['t1'],
          'alb-2': ['f1'],
        },
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: fake),
      );
      await tester.pumpAndSettle();

      await _openBuild(tester);
      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-1'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BuildPoolScaffoldPage.startKey));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final firstId =
          container.read(browseChromeStateProvider).parkedEphemeralPool!.id;

      await _openBuild(tester);
      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-2'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BuildPoolScaffoldPage.startKey));
      await tester.pumpAndSettle();

      final second =
          container.read(browseChromeStateProvider).parkedEphemeralPool!;
      expect(second.id, isNot(firstId));
      expect(second.orderedSourceReferences, [_albumRef('alb-2')]);
    });

    testWidgets('U-21.4-10a catalog failed shows fallback', (tester) async {
      final fake = FakeAssetSourceRepository(allIds: const ['a1'])
        ..listException = Exception('list boom');
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: fake),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mainBrowseCreatePool')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(BuildPoolScaffoldPage.catalogFailedKey),
        findsOneWidget,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.mainBrowseBuildPoolCatalogFailed), findsOneWidget);
    });

    testWidgets('U-21.4-10b catalog loading shows spinner chrome',
        (tester) async {
      final hang = Completer<List<AssetSource>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assetSourcesProvider.overrideWith((ref) => hang.future),
          ],
          child: MaterialApp(
            theme: waketokTheme(Brightness.dark),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const BuildPoolScaffoldPage(),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(BuildPoolScaffoldPage.catalogLoadingKey),
        findsOneWidget,
      );
      hang.complete(const []);
      await tester.pumpAndSettle();
      expect(
        find.byKey(BuildPoolScaffoldPage.catalogLoadingKey),
        findsNothing,
      );
    });

    test('U-21.4-11 Pool origin feeds entireLibrary kind, never album kind',
        () {
      final state = BrowseChromeState(
        activeOrigin: BrowseOriginEphemeralPool(
          SourcePoolDefinition(
            id: 'ephemeral-1',
            persistencePolicy: PersistencePolicy.ephemeral,
            orderedSourceReferences: [
              SourceReference(kind: AssetSourceKind.album, id: 'alb-1'),
            ],
          ),
        ),
        parkedEphemeralPool: null,
        lastRememberedBuiltIn: SourceReference.all,
      );

      // Album kind in a feed page makes Layer 2 fail for every item.
      expect(state.feedSourceKind, AssetSourceKind.entireLibrary);
    });
  });
}
