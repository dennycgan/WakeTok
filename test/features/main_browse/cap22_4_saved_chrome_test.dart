import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
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

SourcePoolDefinition _eph() {
  return SourcePoolDefinition(
    id: 'eph-22-4',
    persistencePolicy: PersistencePolicy.ephemeral,
    orderedSourceReferences: const [SourceReference.photos],
  );
}

Future<void> _pump({
  required WidgetTester tester,
  FakeSavedPoolRepository? savedPools,
  FakeAssetSourceRepository? assetSources,
  PhotosAccess access = PhotosAccess.full,
  ThemeMode themeMode = ThemeMode.system,
}) async {
  await tester.pumpWidget(
    permissionUiHarness(
      repo: ControllablePhotosAuthorizationRepository(access),
      savedPools: savedPools,
      themeMode: themeMode,
      assetSources:
          assetSources ??
          FakeAssetSourceRepository(
            photosIds: const ['p1'],
            extraSources: [_album('alb-1', 'Travel')],
            albumResolveIds: const {
              'alb-1': ['t1'],
            },
          ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('U-22.4 Saved chrome', () {
    testWidgets('menu lists presets; row Open sets savedPool origin', (
      tester,
    ) async {
      final pools = FakeSavedPoolRepository(createId: () => 'p1');
      await pools.save(
        displayName: 'Trip',
        orderedSourceReferences: const [SourceReference.photos],
      );
      await _pump(tester: tester, savedPools: pools);
      await tester.tap(find.byKey(const Key('mainBrowseSavedPoolsMenu')));
      await tester.pumpAndSettle();
      expect(find.text('Trip'), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseSavedPlaceholderSave')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('mainBrowseSavedRow_p1')));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final chrome = container.read(browseChromeStateProvider);
      expect(chrome.activeOrigin, isA<BrowseOriginSavedPool>());
      expect((chrome.activeOrigin as BrowseOriginSavedPool).poolId, 'p1');
      expect(chrome.feedDataSourceId, 'saved:p1');
      expect(find.byKey(const Key('mainBrowseSavedPoolChip')), findsOneWidget);
      expect(find.text('Trip'), findsWidgets);
      expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsNothing);
    });

    testWidgets('menu Open preserves park; Built-in restore shows Temp chip', (
      tester,
    ) async {
      final pools = FakeSavedPoolRepository(createId: () => 'p1');
      await pools.save(
        displayName: 'Trip',
        orderedSourceReferences: const [SourceReference.photos],
      );
      await _pump(tester: tester, savedPools: pools);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container
          .read(browseChromeStateProvider.notifier)
          .startEphemeralPool(_eph(), compositionLabels: const ['Photos']);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mainBrowseSavedPoolsMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mainBrowseSavedRow_p1')));
      await tester.pumpAndSettle();
      final chrome = container.read(browseChromeStateProvider);
      expect(chrome.parkedEphemeralPool, isNotNull);
      expect(find.byKey(const Key('mainBrowseSavedPoolChip')), findsOneWidget);
      expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsNothing);

      await tester.tap(find.byKey(const Key('mainBrowseBuiltInMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mainBrowseBuiltInOptionAll')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsOneWidget);
      expect(find.byKey(const Key('mainBrowseSavedPoolChip')), findsNothing);
    });

    testWidgets('Saved chip tap opens composition peek (not center Info)', (
      tester,
    ) async {
      final pools = FakeSavedPoolRepository(createId: () => 'p1');
      await pools.save(
        displayName: 'Trip',
        orderedSourceReferences: const [SourceReference.photos],
      );
      await _pump(tester: tester, savedPools: pools);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container
          .read(browseChromeStateProvider.notifier)
          .openSavedPool((await pools.loadAll()).single);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mainBrowseSavedPoolChip')));
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byKey(const Key('mainBrowseCompositionPeek')), findsOneWidget);
      expect(
        find.text(l10n.mainBrowseSavedPoolSourcesTitle('Trip')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mainBrowseSavedPoolInfoDialog')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('mainBrowseCompositionPeekSave')),
        findsNothing,
      );
    });

    testWidgets('455 peek shows removed suffix after catalog drop', (
      tester,
    ) async {
      final fake = FakeAssetSourceRepository(
        photosIds: const ['p1'],
        extraSources: [_album('alb-1', 'Travel')],
        albumResolveIds: const {
          'alb-1': ['t1'],
        },
      );
      final pools = FakeSavedPoolRepository(createId: () => 'p1');
      await pools.save(
        displayName: 'Trip',
        orderedSourceReferences: [
          SourceReference(kind: AssetSourceKind.album, id: 'alb-1'),
        ],
      );
      await _pump(tester: tester, savedPools: pools, assetSources: fake);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container
          .read(browseChromeStateProvider.notifier)
          .openSavedPool((await pools.loadAll()).single);
      await tester.pumpAndSettle();
      fake.extraSources = [];
      await tester.tap(find.byKey(const Key('mainBrowseSavedPoolChip')));
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byKey(const Key('mainBrowseCompositionPeek')), findsOneWidget);
      expect(
        find.textContaining(l10n.mainBrowseCompositionPeekRemovedFromPhotos),
        findsOneWidget,
      );
    });

    testWidgets('menu Info closes overlay and opens centered dialog', (
      tester,
    ) async {
      final pools = FakeSavedPoolRepository(createId: () => 'p1');
      await pools.save(
        displayName: 'Trip',
        orderedSourceReferences: const [SourceReference.photos],
      );
      await _pump(tester: tester, savedPools: pools);
      await tester.tap(find.byKey(const Key('mainBrowseSavedPoolsMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mainBrowseSavedRowInfo_p1')));
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byKey(const Key('mainBrowseSavedOverlay')), findsNothing);
      expect(
        find.byKey(const Key('mainBrowseSavedPoolInfoDialog')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mainBrowseCompositionPeek')), findsNothing);
      expect(
        find.text(l10n.mainBrowseSavedPoolSourcesTitle('Trip')),
        findsOneWidget,
      );
    });

    testWidgets('already-active Saved row Open shows toast (not Info)', (
      tester,
    ) async {
      final pools = FakeSavedPoolRepository(createId: () => 'p1');
      await pools.save(
        displayName: 'Trip',
        orderedSourceReferences: const [SourceReference.photos],
      );
      await _pump(tester: tester, savedPools: pools);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container
          .read(browseChromeStateProvider.notifier)
          .openSavedPool((await pools.loadAll()).single);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mainBrowseSavedPoolsMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mainBrowseSavedRow_p1')));
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        find.byKey(const Key('mainBrowseSavedPoolAlreadyBrowsingToast')),
        findsOneWidget,
      );
      expect(
        find.text(l10n.mainBrowseSavedPoolAlreadyBrowsing('Trip')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mainBrowseSavedPoolInfoDialog')),
        findsNothing,
      );
      expect(find.byKey(const Key('mainBrowseCompositionPeek')), findsNothing);
      await tester.pump(kCap19BrowseToastDuration);
    });

    testWidgets('Rename self-name ok; duplicate blocked; chip updates', (
      tester,
    ) async {
      var n = 0;
      final pools = FakeSavedPoolRepository(createId: () => 'p${n++}');
      await pools.save(
        displayName: 'Trip',
        orderedSourceReferences: const [SourceReference.photos],
      );
      await pools.save(
        displayName: 'Work',
        orderedSourceReferences: const [SourceReference.videos],
      );
      await _pump(tester: tester, savedPools: pools);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container
          .read(browseChromeStateProvider.notifier)
          .openSavedPool(
            (await pools.loadAll()).firstWhere((r) => r.id == 'p0'),
          );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mainBrowseSavedPoolsMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mainBrowseSavedRowRename_p0')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('mainBrowseSavedPoolNamingField')),
            )
            .controller
            ?.text,
        'Trip',
      );
      await tester.tap(
        find.byKey(const Key('mainBrowseSavedPoolNamingConfirm')),
      );
      await tester.pumpAndSettle();
      expect(
        (container.read(browseChromeStateProvider).activeOrigin
                as BrowseOriginSavedPool)
            .poolId,
        'p0',
      );

      await tester.tap(find.byKey(const Key('mainBrowseSavedPoolsMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mainBrowseSavedRowRename_p0')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('mainBrowseSavedPoolNamingField')),
        'Work',
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

      await tester.tap(find.byKey(const Key('mainBrowseSavedPoolsMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mainBrowseSavedRowRename_p0')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('mainBrowseSavedPoolNamingField')),
        'Weekend',
      );
      await tester.tap(
        find.byKey(const Key('mainBrowseSavedPoolNamingConfirm')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseSavedPoolChip')), findsOneWidget);
      expect(find.text('Weekend'), findsWidgets);
    });

    testWidgets('Delete active falls back to lastRemembered; park kept', (
      tester,
    ) async {
      final pools = FakeSavedPoolRepository(createId: () => 'p1');
      await pools.save(
        displayName: 'Trip',
        orderedSourceReferences: const [SourceReference.photos],
      );
      await _pump(tester: tester, savedPools: pools);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container
          .read(browseChromeStateProvider.notifier)
          .startEphemeralPool(_eph(), compositionLabels: const ['Photos']);
      container
          .read(browseChromeStateProvider.notifier)
          .openSavedPool((await pools.loadAll()).single);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mainBrowseSavedPoolsMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mainBrowseSavedRowDelete_p1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('mainBrowseSavedPoolDeleteConfirm')),
      );
      await tester.pumpAndSettle();

      final chrome = container.read(browseChromeStateProvider);
      expect(
        chrome.activeOrigin,
        const BrowseOriginBuiltIn(SourceReference.all),
      );
      expect(chrome.parkedEphemeralPool, isNotNull);
      expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsOneWidget);
      expect((await pools.loadAll()), isEmpty);
    });

    testWidgets('savedPool Built-in a11y does not say Temp Pool', (
      tester,
    ) async {
      final pools = FakeSavedPoolRepository(createId: () => 'p1');
      await pools.save(
        displayName: 'Trip',
        orderedSourceReferences: const [SourceReference.photos],
      );
      await _pump(tester: tester, savedPools: pools);
      final dark = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container
          .read(browseChromeStateProvider.notifier)
          .openSavedPool((await pools.loadAll()).single);
      await tester.pumpAndSettle();

      final builtInText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('mainBrowseBuiltInMenu')),
          matching: find.byType(Text),
        ),
      );
      expect(builtInText.style?.color, isNot(dark.accent));
      expect(builtInText.style?.color, dark.onMediaMuted);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final semantics = tester.getSemantics(
        find.byKey(const Key('mainBrowseBuiltInMenuSemantics')),
      );
      expect(
        semantics.label,
        l10n.mainBrowseBuiltInWhileSavedPoolSemantics(
          l10n.libraryRowAll,
          'Trip',
        ),
      );
      expect(semantics.label, isNot(contains('Temp Pool')));
      expect(semantics.hasFlag(SemanticsFlag.isSelected), isFalse);
    });

    testWidgets('chip show/hide keeps center pair dx', (tester) async {
      final pools = FakeSavedPoolRepository(createId: () => 'p1');
      await pools.save(
        displayName: 'Trip',
        orderedSourceReferences: const [SourceReference.photos],
      );
      await _pump(tester: tester, savedPools: pools);
      final centerEmpty = tester.getCenter(
        find.byKey(const Key('mainBrowseChromeCenterPair')),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container
          .read(browseChromeStateProvider.notifier)
          .openSavedPool((await pools.loadAll()).single);
      await tester.pumpAndSettle();
      final centerSaved = tester.getCenter(
        find.byKey(const Key('mainBrowseChromeCenterPair')),
      );
      expect(centerSaved.dx, closeTo(centerEmpty.dx, 1));
    });

    testWidgets(
      'ThemeMode.light: Saved overlay + naming dialog use immersive dark surface',
      (tester) async {
        final dark = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;
        final light = waketokTheme(Brightness.light).extension<WakeTokTokens>()!;
        expect(light.surface, isNot(dark.surface));

        final pools = FakeSavedPoolRepository(createId: () => 'p1');
        await pools.save(
          displayName: 'Trip',
          orderedSourceReferences: const [SourceReference.photos],
        );
        await _pump(
          tester: tester,
          savedPools: pools,
          themeMode: ThemeMode.light,
        );

        await tester.tap(find.byKey(const Key('mainBrowseSavedPoolsMenu')));
        await tester.pumpAndSettle();
        final overlay = tester.widget<Material>(
          find.byKey(const Key('mainBrowseSavedOverlay')),
        );
        expect(overlay.color, dark.surface.withValues(alpha: 0.96));
        expect(overlay.color, isNot(light.surface.withValues(alpha: 0.96)));

        await tester.tap(find.byKey(const Key('mainBrowseSavedRowRename_p1')));
        await tester.pumpAndSettle();
        final dialog = tester.widget<AlertDialog>(
          find.byKey(const Key('mainBrowseSavedPoolNamingDialog')),
        );
        expect(dialog.backgroundColor, dark.surface);
        expect(dialog.backgroundColor, isNot(light.surface));
        final title = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('mainBrowseSavedPoolNamingDialog')),
            matching: find.text('Name this pool'),
          ),
        );
        expect(title.style?.color, dark.onMedia);
      },
    );
  });
}
