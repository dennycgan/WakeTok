import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/build_pool_scaffold_page.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

SourcePoolDefinition _parkedDef() {
  return SourcePoolDefinition(
    id: 'park-21-3',
    persistencePolicy: PersistencePolicy.ephemeral,
    orderedSourceReferences: const [
      SourceReference.photos,
      SourceReference(
        kind: AssetSourceKind.album,
        id: 'album-x',
      ),
    ],
  );
}

void main() {
  group('U-21.3 four-control chrome', () {
    testWidgets('U-21.3-1 parked inject shows chip; clear hides it',
        (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(permissionUiHarness(repo: repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsNothing);

      final container = tester.element(find.byType(MaterialApp));
      final providerScope = ProviderScope.containerOf(container);
      final parked = _parkedDef();
      providerScope
          .read(browseChromeStateProvider.notifier)
          .debugSetParkedEphemeralPool(parked);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsOneWidget);

      final centerBefore = tester.getCenter(
        find.byKey(const Key('mainBrowseChromeCenterPair')),
      );

      providerScope
          .read(browseChromeStateProvider.notifier)
          .debugSetParkedEphemeralPool(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsNothing);

      final centerAfter = tester.getCenter(
        find.byKey(const Key('mainBrowseChromeCenterPair')),
      );
      expect(centerAfter.dx, closeTo(centerBefore.dx, 1));
    });

    testWidgets('U-21.3-2 chip tap from built-in resumes ephemeral Origin',
        (tester) async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a1'],
        photosIds: const ['p1'],
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
      final parked = _parkedDef();
      container
          .read(browseChromeStateProvider.notifier)
          .debugSetParkedEphemeralPool(parked);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mainBrowseTempPoolChip')));
      await tester.pumpAndSettle();

      final chrome = container.read(browseChromeStateProvider);
      expect(
        chrome.activeOrigin,
        BrowseOriginEphemeralPool(parked),
      );
      expect(find.byKey(const Key('mainBrowseCompositionPeek')), findsNothing);
    });

    testWidgets('U-21.3-3 active chip opens peek; no Origin change',
        (tester) async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a1'],
        photosIds: const ['p1'],
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
      final parked = _parkedDef();
      container
          .read(browseChromeStateProvider.notifier)
          .debugActivateEphemeralPool(parked);
      await tester.pumpAndSettle();

      final before = container.read(browseChromeStateProvider);
      await tester.tap(find.byKey(const Key('mainBrowseTempPoolChip')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mainBrowseCompositionPeek')), findsOneWidget);
      expect(container.read(browseChromeStateProvider), before);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.libraryRowPhotos), findsWidgets);
      expect(find.text(l10n.mainBrowseCompositionPeekTitle), findsOneWidget);
    });

    testWidgets('U-21.3-5 Built-in menu selects Photos', (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(permissionUiHarness(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mainBrowseBuiltInMenu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseBuiltInOverlay')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mainBrowseBuiltInOptionPhotos')));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(
        container.read(browseChromeStateProvider).activeOrigin,
        const BrowseOriginBuiltIn(SourceReference.photos),
      );
      expect(
        container.read(mainBrowseSelectedSourceProvider),
        SourceReference.photos,
      );
    });

    testWidgets('U-21.3-6 ephemeral Origin does not accent-select All',
        (tester) async {
      final dark = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(permissionUiHarness(repo: repo));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container
          .read(browseChromeStateProvider.notifier)
          .debugActivateEphemeralPool(_parkedDef());
      await tester.pumpAndSettle();

      final builtInText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('mainBrowseBuiltInMenu')),
          matching: find.byType(Text),
        ),
      );
      expect(builtInText.style?.color, isNot(dark.accent));
      expect(builtInText.style?.color, dark.onMediaMuted);
    });

    testWidgets('U-21.3-7 empty Saved menu is non-navigating',
        (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(permissionUiHarness(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mainBrowseSavedPoolsMenu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseSavedOverlay')), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseSavedPlaceholderEmpty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mainBrowseSavedPlaceholderSave')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('mainBrowseSavedPlaceholderEmpty')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseFeed')), findsOneWidget);
      expect(find.byType(BuildPoolScaffoldPage), findsNothing);
    });

    testWidgets('U-21.3-8 Create opens scaffold; pop preserves chrome',
        (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(permissionUiHarness(repo: repo));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final before = container.read(browseChromeStateProvider);

      await tester.tap(find.byKey(const Key('mainBrowseCreatePool')));
      await tester.pumpAndSettle();
      expect(find.byKey(BuildPoolScaffoldPage.pageKey), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseFeed')), findsOneWidget);
      expect(container.read(browseChromeStateProvider), before);
    });

    testWidgets('U-21.3-9 chip show/hide keeps center pair dx', (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(permissionUiHarness(repo: repo));
      await tester.pumpAndSettle();

      final centerEmpty = tester.getCenter(
        find.byKey(const Key('mainBrowseChromeCenterPair')),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container
          .read(browseChromeStateProvider.notifier)
          .debugSetParkedEphemeralPool(_parkedDef());
      await tester.pumpAndSettle();
      final centerParked = tester.getCenter(
        find.byKey(const Key('mainBrowseChromeCenterPair')),
      );
      expect(centerParked.dx, closeTo(centerEmpty.dx, 1));
    });

    test('U-21.3-resumeParkedEphemeral is no-op when already active', () {
      final container = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(
            FakeAssetSourceRepository(),
          ),
          browseShuffleRandomFactoryProvider.overrideWith(
            (ref) => () => Random(0),
          ),
          browseEmptyRetryDelaysProvider.overrideWithValue(const []),
        ],
      );
      addTearDown(container.dispose);
      final parked = _parkedDef();
      final notifier = container.read(browseChromeStateProvider.notifier);
      notifier.debugActivateEphemeralPool(parked);
      final before = container.read(browseChromeStateProvider);
      notifier.resumeParkedEphemeral();
      expect(container.read(browseChromeStateProvider), before);
      expect(notifier.isParkedEphemeralActive, isTrue);
    });
  });
}
