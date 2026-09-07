import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_chrome_state.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/build_pool_scaffold_page.dart';
import 'package:waketok/features/main_browse/build_pool_smart_catalog.dart';
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

AssetSource _smart(String id, int subtype, {String displayName = ''}) {
  return AssetSource(
    kind: AssetSourceKind.smartAlbum,
    id: id,
    displayName: displayName,
    estimatedCount: null,
    availability: AssetSourceAvailability.available,
    canAddContent: false,
    collectionSubtype: subtype,
  );
}

Key _catalogKey(SourceReference ref) =>
    Key('mainBrowseBuildPoolCatalog_${ref.kind.name}_${ref.id}');

Future<void> _openBuild(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('mainBrowseCreatePool')));
  await tester.pumpAndSettle();
  expect(find.byKey(BuildPoolScaffoldPage.pageKey), findsOneWidget);
}

void main() {
  group('U-21.4b Smart Albums in Build catalog', () {
    testWidgets(
      'U-21.4b-1 whitelist smart rows show ARB labels; Recents excluded',
      (tester) async {
        final fake = FakeAssetSourceRepository(
          allIds: const ['a1'],
          extraSources: [
            _album('alb-1', 'Travel'),
            _smart('smart-fav', 203, displayName: 'Favorites'),
            _smart('smart-slomo', 208, displayName: 'Slo-mo'),
            _smart('smart-recents', 209, displayName: 'Recents'),
          ],
          smartAlbumsWithContentIds: {'smart-fav', 'smart-slomo', 'smart-recents'},
        );
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(
          permissionUiHarness(repo: repo, assetSources: fake),
        );
        await tester.pumpAndSettle();
        await _openBuild(tester);

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(
          find.text(l10n.mainBrowseBuildPoolSectionSmartAlbums),
          findsOneWidget,
        );
        expect(find.text(l10n.smartAlbumFavorites), findsOneWidget);
        expect(find.text(l10n.smartAlbumSlomo), findsOneWidget);
        expect(find.text('Recents'), findsNothing);
        expect(
          find.byKey(
            _catalogKey(
              const SourceReference(
                kind: AssetSourceKind.smartAlbum,
                id: 'smart-recents',
              ),
            ),
          ),
          findsNothing,
        );
        expect(fake.smartAlbumsWithContentCalls, greaterThanOrEqualTo(1));
        // Presence probe only asked for whitelist candidates.
        final asked = fake.smartAlbumsWithContentHistory.first.toSet();
        expect(asked, {'smart-fav', 'smart-slomo'});
      },
    );

    testWidgets('U-21.4b-2 zero-count smart albums are hidden', (tester) async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a1'],
        extraSources: [
          _smart('smart-fav', 203),
          _smart('smart-raw', 217),
        ],
        smartAlbumsWithContentIds: {'smart-fav'},
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: fake),
      );
      await tester.pumpAndSettle();
      await _openBuild(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.smartAlbumFavorites), findsOneWidget);
      expect(find.text(l10n.smartAlbumRaw), findsNothing);
    });

    testWidgets(
      'U-21.4b-3 albums paint while smart presence is still loading',
      (tester) async {
        final hang = Completer<List<String>>();
        final delayed = _DelayedPresenceFake(
          hang.future,
          allIds: const ['a1'],
          extraSources: [
            _album('alb-1', 'Travel'),
            _smart('smart-fav', 203),
          ],
        );

        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(
          permissionUiHarness(repo: repo, assetSources: delayed),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mainBrowseCreatePool')));
        await tester.pump(); // frame with albums + smart loading
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Travel'), findsOneWidget);
        expect(
          find.byKey(BuildPoolScaffoldPage.smartLoadingKey),
          findsOneWidget,
        );

        hang.complete(const ['smart-fav']);
        await tester.pumpAndSettle();
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.smartAlbumFavorites), findsOneWidget);
        expect(
          find.byKey(BuildPoolScaffoldPage.smartLoadingKey),
          findsNothing,
        );
      },
    );

    testWidgets('U-21.4b-4 product sort: Favorites then Live then Slo-mo',
        (tester) async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a1'],
        extraSources: [
          _smart('s-slomo', 208),
          _smart('s-live', 213),
          _smart('s-fav', 203),
        ],
        smartAlbumsWithContentIds: {'s-slomo', 's-live', 's-fav'},
      );
      final container = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);

      final sorted = await container.read(buildPoolSmartCatalogProvider.future);
      expect(
        sorted.map((s) => s.collectionSubtype).toList(),
        [203, 213, 208],
      );
    });

    test('U-21.4b-5 smart-only ephemeral pool still feeds entireLibrary', () {
      final state = BrowseChromeState(
        activeOrigin: BrowseOriginEphemeralPool(
          SourcePoolDefinition(
            id: 'ephemeral-smart',
            persistencePolicy: PersistencePolicy.ephemeral,
            orderedSourceReferences: const [
              SourceReference(kind: AssetSourceKind.smartAlbum, id: 's-fav'),
            ],
          ),
        ),
        parkedEphemeralPool: null,
        lastRememberedBuiltIn: SourceReference.all,
      );
      expect(state.feedSourceKind, AssetSourceKind.entireLibrary);
    });

    testWidgets('U-21.4b-6 zh-Hans section + smart labels', (tester) async {
      final l10n =
          await AppLocalizations.delegate.load(const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ));
      expect(l10n.mainBrowseBuildPoolSectionAlbums, '我的相册');
      expect(l10n.mainBrowseBuildPoolSectionSmartAlbums, '系统相册');
      expect(l10n.smartAlbumFavorites, '个人收藏');
      expect(l10n.smartAlbumLivePhotos, '实况照片');
      expect(l10n.smartAlbumVideos, '视频');
      expect(l10n.smartAlbumSlomo, '慢动作');
      expect(l10n.smartAlbumDualCapture, '同步双拍');
    });
  });
}

/// Awaits [presenceFuture] before returning [smartAlbumsWithContent].
class _DelayedPresenceFake extends FakeAssetSourceRepository {
  _DelayedPresenceFake(
    this._presenceFuture, {
    super.allIds,
    super.extraSources,
  });

  final Future<List<String>> _presenceFuture;

  @override
  Future<List<String>> smartAlbumsWithContent(
    List<String> albumIdentifiers,
  ) async {
    smartAlbumsWithContentCalls += 1;
    smartAlbumsWithContentHistory.add(
      List<String>.unmodifiable(albumIdentifiers),
    );
    return _presenceFuture;
  }
}
