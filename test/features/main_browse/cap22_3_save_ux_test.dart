import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/pool_capacity.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/main_browse/build_pool_scaffold_page.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../domain/source/fake_saved_pool_repository.dart';
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

Key _catalogKey(SourceReference ref) =>
    Key('mainBrowseBuildPoolCatalog_${ref.kind.name}_${ref.id}');

Future<void> _openBuild(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('mainBrowseCreatePool')));
  await tester.pumpAndSettle();
  expect(find.byKey(BuildPoolScaffoldPage.pageKey), findsOneWidget);
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  FakeAssetSourceRepository? assetSources,
  FakeSavedPoolRepository? savedPools,
}) async {
  final fake =
      assetSources ??
      FakeAssetSourceRepository(
        allIds: const ['a1'],
        extraSources: [_album('alb-1', 'Travel'), _album('alb-2', 'Family')],
        albumResolveIds: const {
          'alb-1': ['t1', 't2'],
          'alb-2': ['f1'],
        },
      );
  final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
  await tester.pumpWidget(
    permissionUiHarness(repo: repo, assetSources: fake, savedPools: savedPools),
  );
  await tester.pumpAndSettle();
}

Future<void> _hideBuildSnackBar(WidgetTester tester) async {
  final messenger = ScaffoldMessenger.maybeOf(
    tester.element(find.byKey(BuildPoolScaffoldPage.pageKey)),
  );
  messenger?.hideCurrentSnackBar();
  await tester.pump();
}

Future<void> _saveNamed(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(BuildPoolScaffoldPage.saveKey));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('mainBrowseSavedPoolNamingField')),
    name,
  );
  await tester.tap(find.byKey(const Key('mainBrowseSavedPoolNamingConfirm')));
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('U-22.3 Build Save / Start fingerprint', () {
    testWidgets('Save and Start disabled when selection is empty', (
      tester,
    ) async {
      await _pumpHarness(tester);
      await _openBuild(tester);

      expect(
        tester
            .widget<OutlinedButton>(find.byKey(BuildPoolScaffoldPage.saveKey))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(BuildPoolScaffoldPage.startKey))
            .onPressed,
        isNull,
      );
    });

    testWidgets('successful Save stays on Build and does not change chrome', (
      tester,
    ) async {
      final pools = FakeSavedPoolRepository(createId: () => 'saved-1');
      await _pumpHarness(tester, savedPools: pools);
      await _openBuild(tester);

      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-1'))));
      await tester.pumpAndSettle();
      await _saveNamed(tester, 'Trip');
      await tester.pump();

      expect(find.byKey(BuildPoolScaffoldPage.pageKey), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseBuildPoolSaveSuccess')),
        findsOneWidget,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.mainBrowseBuildPoolSaveSuccess), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final chrome = container.read(browseChromeStateProvider);
      expect(
        chrome.activeOrigin,
        const BrowseOriginBuiltIn(SourceReference.all),
      );
      expect(chrome.parkedEphemeralPool, isNull);
      expect((await pools.loadAll()).single.id, 'saved-1');
      await _hideBuildSnackBar(tester);
    });

    testWidgets('empty name shows inline error', (tester) async {
      await _pumpHarness(tester);
      await _openBuild(tester);
      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-1'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BuildPoolScaffoldPage.saveKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('mainBrowseSavedPoolNamingConfirm')),
      );
      await tester.pump();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.mainBrowseSavedPoolNamingEmpty), findsOneWidget);
      expect(find.byKey(BuildPoolScaffoldPage.pageKey), findsOneWidget);
    });

    testWidgets('duplicate name shows inline error', (tester) async {
      final pools = FakeSavedPoolRepository();
      await pools.save(
        displayName: 'Trip',
        orderedSourceReferences: const [SourceReference.photos],
      );
      await _pumpHarness(tester, savedPools: pools);
      await _openBuild(tester);
      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-1'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BuildPoolScaffoldPage.saveKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('mainBrowseSavedPoolNamingField')),
        'Trip',
      );
      await tester.tap(
        find.byKey(const Key('mainBrowseSavedPoolNamingConfirm')),
      );
      await tester.pump();
      await tester.pump();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        find.text(l10n.mainBrowseSavedPoolNamingDuplicate),
        findsOneWidget,
      );
      expect(find.byKey(BuildPoolScaffoldPage.pageKey), findsOneWidget);
    });

    testWidgets('capacity at 10 shows capacity dialog', (tester) async {
      final pools = FakeSavedPoolRepository();
      for (var i = 0; i < PoolCapacity.maxSavedPoolPresets; i++) {
        await pools.save(
          displayName: 'Seed $i',
          orderedSourceReferences: const [SourceReference.photos],
        );
      }
      await _pumpHarness(tester, savedPools: pools);
      await _openBuild(tester);
      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-1'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BuildPoolScaffoldPage.saveKey));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('mainBrowseSavedPoolCapacityDialog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mainBrowseSavedPoolNamingDialog')),
        findsNothing,
      );
    });

    testWidgets('Start after Save uses savedPool origin', (tester) async {
      final pools = FakeSavedPoolRepository(createId: () => 'saved-1');
      await _pumpHarness(tester, savedPools: pools);
      await _openBuild(tester);
      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-1'))));
      await tester.pumpAndSettle();
      await _saveNamed(tester, 'Trip');
      await _hideBuildSnackBar(tester);
      await tester.tap(find.byKey(BuildPoolScaffoldPage.startKey));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final chrome = container.read(browseChromeStateProvider);
      expect(chrome.activeOrigin, isA<BrowseOriginSavedPool>());
      expect((chrome.activeOrigin as BrowseOriginSavedPool).poolId, 'saved-1');
      expect(chrome.parkedEphemeralPool, isNull);
    });

    testWidgets('Start without Save uses ephemeral', (tester) async {
      await _pumpHarness(tester);
      await _openBuild(tester);
      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-1'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BuildPoolScaffoldPage.startKey));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final chrome = container.read(browseChromeStateProvider);
      expect(chrome.activeOrigin, isA<BrowseOriginEphemeralPool>());
      expect(chrome.parkedEphemeralPool, isNotNull);
      expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsOneWidget);
    });

    testWidgets('mutate selection after Save then Start uses ephemeral', (
      tester,
    ) async {
      final pools = FakeSavedPoolRepository(createId: () => 'saved-1');
      await _pumpHarness(tester, savedPools: pools);
      await _openBuild(tester);
      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-1'))));
      await tester.pumpAndSettle();
      await _saveNamed(tester, 'Trip');
      await _hideBuildSnackBar(tester);
      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-2'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BuildPoolScaffoldPage.startKey));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(
        container.read(browseChromeStateProvider).activeOrigin,
        isA<BrowseOriginEphemeralPool>(),
      );
    });

    testWidgets('mutate then restore selection Start uses savedPool', (
      tester,
    ) async {
      final pools = FakeSavedPoolRepository(createId: () => 'saved-1');
      await _pumpHarness(tester, savedPools: pools);
      await _openBuild(tester);
      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-1'))));
      await tester.pumpAndSettle();
      await _saveNamed(tester, 'Trip');
      await _hideBuildSnackBar(tester);
      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-2'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_catalogKey(_albumRef('alb-2'))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BuildPoolScaffoldPage.startKey));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final origin = container.read(browseChromeStateProvider).activeOrigin;
      expect(origin, isA<BrowseOriginSavedPool>());
      expect((origin as BrowseOriginSavedPool).poolId, 'saved-1');
    });

    testWidgets(
      'failed Save after success does not replace lastSaved; Start uses first',
      (tester) async {
        var n = 0;
        final pools = FakeSavedPoolRepository(createId: () => 'saved-${n++}');
        await _pumpHarness(tester, savedPools: pools);
        await _openBuild(tester);
        await tester.tap(find.byKey(_catalogKey(_albumRef('alb-1'))));
        await tester.pumpAndSettle();
        await _saveNamed(tester, 'Trip');
        await _hideBuildSnackBar(tester);

        await tester.tap(find.byKey(BuildPoolScaffoldPage.saveKey));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('mainBrowseSavedPoolNamingField')),
          'Trip',
        );
        await tester.tap(
          find.byKey(const Key('mainBrowseSavedPoolNamingConfirm')),
        );
        await tester.pump();
        await tester.pump();
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(
          find.text(l10n.mainBrowseSavedPoolNamingDuplicate),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('mainBrowseSavedPoolNamingCancel')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(BuildPoolScaffoldPage.startKey));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final origin = container.read(browseChromeStateProvider).activeOrigin;
        expect(origin, isA<BrowseOriginSavedPool>());
        expect((origin as BrowseOriginSavedPool).poolId, 'saved-0');
        expect((await pools.loadAll()).length, 1);
      },
    );
  });

  group('U-22.3 peek Save promote', () {
    testWidgets('already-active peek shows Save footer', (tester) async {
      await _pumpHarness(
        tester,
        assetSources: FakeAssetSourceRepository(
          photosIds: const ['p1'],
          videosIds: const ['v1'],
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container
          .read(browseChromeStateProvider.notifier)
          .startEphemeralPool(
            SourcePoolDefinition(
              id: 'eph-peek',
              persistencePolicy: PersistencePolicy.ephemeral,
              orderedSourceReferences: const [
                SourceReference.photos,
                SourceReference.videos,
              ],
            ),
            compositionLabels: const ['Photos', 'Videos'],
          );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mainBrowseTempPoolChip')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('mainBrowseCompositionPeekSave')),
        findsOneWidget,
      );
    });

    testWidgets('peek Save promotes to savedPool and clears park', (
      tester,
    ) async {
      final pools = FakeSavedPoolRepository(createId: () => 'saved-peek');
      await _pumpHarness(
        tester,
        savedPools: pools,
        assetSources: FakeAssetSourceRepository(
          photosIds: const ['p1'],
          videosIds: const ['v1'],
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container
          .read(browseChromeStateProvider.notifier)
          .startEphemeralPool(
            SourcePoolDefinition(
              id: 'eph-peek',
              persistencePolicy: PersistencePolicy.ephemeral,
              orderedSourceReferences: const [
                SourceReference.photos,
                SourceReference.videos,
              ],
            ),
            compositionLabels: const ['Photos', 'Videos'],
          );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mainBrowseTempPoolChip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mainBrowseCompositionPeekSave')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('mainBrowseSavedPoolNamingField')),
        'Weekend',
      );
      await tester.tap(
        find.byKey(const Key('mainBrowseSavedPoolNamingConfirm')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mainBrowseCompositionPeek')), findsNothing);
      expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsNothing);
      final chrome = container.read(browseChromeStateProvider);
      expect(chrome.activeOrigin, isA<BrowseOriginSavedPool>());
      expect(
        (chrome.activeOrigin as BrowseOriginSavedPool).poolId,
        'saved-peek',
      );
      expect(chrome.parkedEphemeralPool, isNull);
    });
  });
}
