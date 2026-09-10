import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/main_browse_shell_page.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_favorite_repository.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
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

FakeAssetSourceRepository _feedSources() => FakeAssetSourceRepository(
      allIds: const ['a1'],
      availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
    );

Future<void> _openFullSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('cap19EntryIcon')));
  await tester.pumpAndSettle();
}

Future<void> _openFullSheetAndWaitForFavorites(WidgetTester tester) async {
  await _openFullSheet(tester);
  await tester.pump();
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('cap19FavoritesRow')), findsOneWidget);
}

Future<void> _settleCap19Toasts(WidgetTester tester) async {
  await tester.pump(kCap19BrowseToastDuration);
  resetCap19BrowseToastForTest();
}

void main() {
  tearDown(resetCap19BrowseToastForTest);

  testWidgets('W-19.5b-1 Full sheet: Favorites row above first album row',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a1'],
      availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
      extraSources: [
        _writableAlbum(id: 'album-a', displayName: 'Alpha Album'),
      ],
    );
    final favorites = FakeAssetFavoriteRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: sources,
        assetFavorites: favorites,
      ),
    );
    await tester.pumpAndSettle();

    await _openFullSheetAndWaitForFavorites(tester);

    expect(find.byKey(const Key('cap19FavoritesRow')), findsOneWidget);
    expect(find.byKey(const Key('cap19FavoritesAlbumThumbnail')), findsOneWidget);
    expect(find.byKey(const Key('cap19AlbumPickerRow-album-a')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('cap19FavoritesRow'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('cap19AlbumPickerRow-album-a'))).dy,
      ),
    );
  });

  testWidgets('W-19.5b-2 unfavorited shows Add to Favorites + outline star',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final favorites = FakeAssetFavoriteRepository()..statusValue = false;
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: _feedSources(),
        assetFavorites: favorites,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _openFullSheetAndWaitForFavorites(tester);

    expect(find.byKey(const Key('cap19FavoritesPlatformIconOutline')), findsOneWidget);
    expect(find.text(l10n.cap19PanelAddToFavorites), findsOneWidget);
  });

  testWidgets('W-19.5b-3 favorited shows Remove from Favorites + filled star',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final favorites = FakeAssetFavoriteRepository()..statusValue = true;
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: _feedSources(),
        assetFavorites: favorites,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _openFullSheetAndWaitForFavorites(tester);

    expect(find.byKey(const Key('cap19FavoritesPlatformIconFilled')), findsOneWidget);
    expect(find.text(l10n.cap19PanelRemoveFromFavorites), findsOneWidget);
  });

  testWidgets('W-19.5b-4 tap toggle calls setAssetFavorite with inverted bool',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final favorites = FakeAssetFavoriteRepository()..statusValue = false;
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: _feedSources(),
        assetFavorites: favorites,
      ),
    );
    await tester.pumpAndSettle();

    await _openFullSheetAndWaitForFavorites(tester);
    await tester.tap(find.byKey(const Key('cap19FavoritesRow')));
    await tester.pumpAndSettle();

    expect(favorites.setCalls, 1);
    expect(favorites.lastAssetId, 'a1');
    expect(favorites.lastFavorite, isTrue);
    await _settleCap19Toasts(tester);
  });

  testWidgets('W-19.5b-5 success keeps sheet open and updates row', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final favorites = FakeAssetFavoriteRepository()..statusValue = false;
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: _feedSources(),
        assetFavorites: favorites,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _openFullSheetAndWaitForFavorites(tester);
    await tester.tap(find.byKey(const Key('cap19FavoritesRow')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsOneWidget);
    expect(find.byKey(const Key('cap19FavoritesAddedToast')), findsOneWidget);
    expect(find.text(l10n.cap19PanelFavoritesAddedSuccess), findsOneWidget);
    expect(find.byKey(const Key('cap19FavoritesPlatformIconFilled')), findsOneWidget);
    expect(find.text(l10n.cap19PanelRemoveFromFavorites), findsOneWidget);
    await _settleCap19Toasts(tester);
  });

  testWidgets('W-19.5b-6 failure keeps sheet open and shows error SnackBar',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final favorites = FakeAssetFavoriteRepository()
      ..statusValue = false
      ..setException = PlatformException(code: 'unauthorized');
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: _feedSources(),
        assetFavorites: favorites,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _openFullSheetAndWaitForFavorites(tester);
    await tester.tap(find.byKey(const Key('cap19FavoritesRow')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsOneWidget);
    expect(find.byKey(const Key('cap19FavoritesErrorToast')), findsOneWidget);
    expect(find.text(l10n.cap19PanelFavoritesError), findsOneWidget);
    expect(find.byKey(const Key('cap19FavoritesPlatformIconOutline')), findsOneWidget);
    await _settleCap19Toasts(tester);
  });

  testWidgets('W-19.5b-7 Limited does not render Favorites row', (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
    final favorites = FakeAssetFavoriteRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: _feedSources(),
        assetFavorites: favorites,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _openFullSheet(tester);

    expect(find.byKey(const Key('cap19FavoritesRow')), findsNothing);
    expect(find.byKey(const Key('cap19PanelFavoritesSectionTitle')), findsNothing);
    expect(find.byKey(const Key('cap19PanelAlbumsSectionTitle')), findsNothing);
    expect(find.byKey(const Key('cap19AlbumPickerList')), findsNothing);
    expect(find.byKey(const Key('cap19PanelAddToAlbumLimitedRow')), findsOneWidget);
    expect(find.text(l10n.cap19PanelAddToAlbumLimitedMessage), findsOneWidget);
    expect(favorites.statusCalls, 0);
    expect(favorites.setCalls, 0);
  });

  testWidgets('W-19.5b-8 favorite toggle does not restart browse session',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final favorites = FakeAssetFavoriteRepository()..statusValue = false;
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: _feedSources(),
        assetFavorites: favorites,
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MainBrowseShellPage)),
    );
    final epochBefore =
        container.read(browseSessionProvider).asData!.value.roundEpoch;
    final feedIndexBefore = container.read(mainBrowseFeedIndexProvider);

    await _openFullSheetAndWaitForFavorites(tester);
    await tester.tap(find.byKey(const Key('cap19FavoritesRow')));
    await tester.pumpAndSettle();

    final epochAfter =
        container.read(browseSessionProvider).asData!.value.roundEpoch;
    final feedIndexAfter = container.read(mainBrowseFeedIndexProvider);

    expect(epochAfter, epochBefore);
    expect(feedIndexAfter, feedIndexBefore);
    await _settleCap19Toasts(tester);
  });

  testWidgets('W-19.5b-9 divider and section labels present on Full',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: _feedSources(),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _openFullSheetAndWaitForFavorites(tester);

    expect(find.text(l10n.cap19PanelFavoritesSectionTitle), findsOneWidget);
    expect(find.text(l10n.cap19PanelAlbumsSectionTitle), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });
}
