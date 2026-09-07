import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/main_browse/build_pool_scaffold_page.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_album_cover_repository.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

SourcePoolDefinition _photosPlusEmptyVideosPool() {
  return SourcePoolDefinition(
    id: 'partial-21-5-videos-empty',
    persistencePolicy: PersistencePolicy.ephemeral,
    orderedSourceReferences: const [
      SourceReference.photos,
      SourceReference.videos,
    ],
  );
}

SourcePoolDefinition _emptyAlbumPlusPhotosPool() {
  return SourcePoolDefinition(
    id: 'partial-21-5-empty-album',
    persistencePolicy: PersistencePolicy.ephemeral,
    orderedSourceReferences: const [
      SourceReference(
        kind: AssetSourceKind.album,
        id: 'album-empty',
      ),
      SourceReference.photos,
    ],
  );
}

SourcePoolDefinition _missingAlbumPlusPhotosPool() {
  return SourcePoolDefinition(
    id: 'partial-21-5-missing-album',
    persistencePolicy: PersistencePolicy.ephemeral,
    orderedSourceReferences: const [
      SourceReference.photos,
      SourceReference(kind: AssetSourceKind.album, id: 'album-gone'),
    ],
  );
}

void main() {
  group('U-21.5 pool-path polish', () {
    testWidgets(
      'U-21.5-3 empty Videos: feed plays, no banner, peek name only',
      (tester) async {
        final fake = FakeAssetSourceRepository(
          photosIds: const ['p1'],
          videosIds: const [],
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
        container
            .read(browseChromeStateProvider.notifier)
            .debugActivateEphemeralPool(_photosPlusEmptyVideosPool());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('mainBrowseFeed')), findsOneWidget);
        expect(find.byKey(const Key('mainBrowseFeedEmpty')), findsNothing);
        expect(
          find.byKey(const Key('mainBrowsePartialSourcesHint')),
          findsNothing,
        );

        await tester.tap(find.byKey(const Key('mainBrowseTempPoolChip')));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byKey(const Key('mainBrowseCompositionPeek'))),
        )!;
        expect(find.text(l10n.libraryRowVideos), findsOneWidget);
        expect(
          find.textContaining(l10n.mainBrowseCompositionPeekRemovedFromPhotos),
          findsNothing,
        );
        expect(
          find.textContaining(l10n.mainBrowseCompositionPeekRequiresFullAccess),
          findsNothing,
        );
      },
    );

    testWidgets(
      'U-21.5-3b empty album: peek shows name without suffix',
      (tester) async {
        final fake = FakeAssetSourceRepository(
          photosIds: const ['p1'],
          albumResolveIds: const {'album-empty': <String>[]},
          extraSources: const [
            AssetSource(
              kind: AssetSourceKind.album,
              id: 'album-empty',
              displayName: 'Empty Album',
              estimatedCount: 0,
              availability: AssetSourceAvailability.empty,
              canAddContent: true,
            ),
          ],
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
        container
            .read(browseChromeStateProvider.notifier)
            .debugActivateEphemeralPool(_emptyAlbumPlusPhotosPool());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('mainBrowseTempPoolChip')));
        await tester.pumpAndSettle();
        expect(find.text('Empty Album'), findsOneWidget);
        final l10n = AppLocalizations.of(
          tester.element(find.byKey(const Key('mainBrowseCompositionPeek'))),
        )!;
        expect(
          find.textContaining(l10n.mainBrowseCompositionPeekRemovedFromPhotos),
          findsNothing,
        );
        expect(
          find.textContaining(l10n.mainBrowseCompositionPeekRequiresFullAccess),
          findsNothing,
        );
      },
    );

    testWidgets(
      'U-21.5-3c missing album under Full: Removed from Photos',
      (tester) async {
        final fake = FakeAssetSourceRepository(
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
        container
            .read(browseChromeStateProvider.notifier)
            .debugActivateEphemeralPool(_missingAlbumPlusPhotosPool());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('mainBrowseTempPoolChip')));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byKey(const Key('mainBrowseCompositionPeek'))),
        )!;
        expect(
          find.textContaining(l10n.mainBrowseCompositionPeekRemovedFromPhotos),
          findsOneWidget,
        );
        expect(
          find.textContaining(l10n.mainBrowseCompositionPeekRequiresFullAccess),
          findsNothing,
        );
        expect(find.textContaining('album-gone'), findsNothing);
      },
    );

    testWidgets(
      'U-21.5-3c2 missing album under Limited: Requires Full Access not Removed',
      (tester) async {
        final fake = FakeAssetSourceRepository(
          photosIds: const ['p1'],
        );
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
        await tester.pumpWidget(
          permissionUiHarness(repo: repo, assetSources: fake),
        );
        await tester.pumpAndSettle();

        const frozenName = 'Parked Album';
        final pool = SourcePoolDefinition(
          id: 'limited-missing',
          persistencePolicy: PersistencePolicy.ephemeral,
          orderedSourceReferences: const [
            SourceReference(kind: AssetSourceKind.album, id: 'album-x'),
            SourceReference.photos,
          ],
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        container.read(browseChromeStateProvider.notifier).debugActivateEphemeralPool(
              pool,
              compositionLabels: [frozenName, l10n.libraryRowPhotos],
            );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('mainBrowseTempPoolChip')));
        await tester.pumpAndSettle();
        expect(
          find.text(
            '$frozenName (${l10n.mainBrowseCompositionPeekRequiresFullAccess})',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(l10n.mainBrowseCompositionPeekRemovedFromPhotos),
          findsNothing,
        );
      },
    );

    testWidgets(
      'U-21.5-3d deleted album keeps frozen name + Removed from Photos',
      (tester) async {
        const albumId = 'album-deleted-id-uuid-shaped';
        const frozenName = 'Holiday Trip';
        final fake = FakeAssetSourceRepository(
          photosIds: const ['p1'],
        );
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(
          permissionUiHarness(repo: repo, assetSources: fake),
        );
        await tester.pumpAndSettle();

        final pool = SourcePoolDefinition(
          id: 'frozen-label-pool',
          persistencePolicy: PersistencePolicy.ephemeral,
          orderedSourceReferences: const [
            SourceReference(kind: AssetSourceKind.album, id: albumId),
            SourceReference.photos,
          ],
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        container.read(browseChromeStateProvider.notifier).debugActivateEphemeralPool(
              pool,
              compositionLabels: [frozenName, l10n.libraryRowPhotos],
            );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('mainBrowseTempPoolChip')));
        await tester.pumpAndSettle();

        expect(
          find.text(
            '$frozenName (${l10n.mainBrowseCompositionPeekRemovedFromPhotos})',
          ),
          findsOneWidget,
        );
        expect(find.textContaining(albumId), findsNothing);
      },
    );

    testWidgets(
      'U-21.5-3e peek tap outside dismisses',
      (tester) async {
        final fake = FakeAssetSourceRepository(photosIds: const ['p1']);
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(
          permissionUiHarness(repo: repo, assetSources: fake),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        container
            .read(browseChromeStateProvider.notifier)
            .debugActivateEphemeralPool(_photosPlusEmptyVideosPool());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('mainBrowseTempPoolChip')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('mainBrowseCompositionPeek')), findsOneWidget);

        await tester.tapAt(const Offset(300, 500));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('mainBrowseCompositionPeek')), findsNothing);
      },
    );

    testWidgets(
      'U-21.5-4 Built-in Semantics not selected while ephemeral',
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

        final builtInNode = tester.getSemantics(
          find.byKey(const Key('mainBrowseBuiltInMenuSemantics')),
        );
        expect(builtInNode.hasFlag(SemanticsFlag.isSelected), isTrue);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        container
            .read(browseChromeStateProvider.notifier)
            .debugActivateEphemeralPool(_photosPlusEmptyVideosPool());
        await tester.pumpAndSettle();

        final ephemeralNode = tester.getSemantics(
          find.byKey(const Key('mainBrowseBuiltInMenuSemantics')),
        );
        expect(ephemeralNode.hasFlag(SemanticsFlag.isSelected), isFalse);
        final l10n = AppLocalizations.of(
          tester.element(find.byKey(const Key('mainBrowseBuiltInMenu'))),
        )!;
        expect(
          ephemeralNode.label,
          contains(l10n.mainBrowseTempPoolChip),
        );
      },
    );

    testWidgets(
      'U-21.5-5 Saved gray placeholder stays non-navigating',
      (tester) async {
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(permissionUiHarness(repo: repo));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('mainBrowseSavedPoolsMenu')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('mainBrowseSavedOverlay')), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('mainBrowseSavedPlaceholderManage')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('mainBrowseFeed')), findsOneWidget);
        expect(find.byType(BuildPoolScaffoldPage), findsNothing);
      },
    );

    testWidgets('U-21.5-6 Limited disables Create Pool + Full Access caption',
        (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
      await tester.pumpWidget(permissionUiHarness(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mainBrowseCreatePool')));
      await tester.pumpAndSettle();
      expect(find.byType(BuildPoolScaffoldPage), findsNothing);
      expect(
        find.byKey(const Key('mainBrowseCreatePoolRequiresFullAccess')),
        findsOneWidget,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        find.text(l10n.mainBrowseCreatePoolRequiresFullAccess),
        findsOneWidget,
      );
    });

    testWidgets(
      'U-21.5-7 hung cover stops spinner after timeout',
      (tester) async {
        final covers = FakeAlbumCoverRepository(hangCoverRequests: true);
        final fake = FakeAssetSourceRepository(
          extraSources: const [
            AssetSource(
              kind: AssetSourceKind.album,
              id: 'album-hang',
              displayName: 'Hang',
              estimatedCount: 1,
              availability: AssetSourceAvailability.available,
              canAddContent: true,
            ),
          ],
        );
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(
          permissionUiHarness(
            repo: repo,
            assetSources: fake,
            albumCovers: covers,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mainBrowseCreatePool')));
        // Do not pumpAndSettle while the hung cover spinner is animating.
        final coverFinder = find.byKey(const Key('cap19AlbumCover-album-hang'));
        for (var i = 0; i < 80; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (coverFinder.evaluate().isNotEmpty) {
            break;
          }
        }
        expect(coverFinder, findsOneWidget);
        expect(
          find.descendant(
            of: coverFinder,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );

        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        expect(
          find.descendant(
            of: coverFinder,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
      },
    );
  });
}
