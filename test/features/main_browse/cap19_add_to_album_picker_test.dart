import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'still_cover_test_helpers.dart';
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

import '../../library_smoke/fake_album_mutation_repository.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

AssetSource _writableAlbum({
  required String id,
  required String displayName,
  bool canAddContent = true,
}) {
  return AssetSource(
    kind: AssetSourceKind.album,
    id: id,
    displayName: displayName,
    estimatedCount: 3,
    availability: AssetSourceAvailability.available,
    canAddContent: canAddContent,
  );
}

Future<void> _openFullSheet(WidgetTester tester) async {
  await ensureShellMediaCoverVisible(tester);
      await tester.tap(find.byKey(const Key('cap19EntryIcon')));
  await tester.pumpAndSettle();
}

Future<void> _settleCap19Toasts(WidgetTester tester) async {
  await tester.pump(kCap19BrowseToastDuration);
  resetCap19BrowseToastForTest();
}

void main() {
  tearDown(resetCap19BrowseToastForTest);

  testWidgets('W-19.5-1 Full sheet lists writable user albums', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a1'],
      availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
      extraSources: [
        _writableAlbum(id: 'album-b', displayName: 'Beta Album'),
        _writableAlbum(id: 'album-a', displayName: 'Alpha Album'),
      ],
    );
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, assetSources: sources),
    );
    await tester.pumpAndSettle();

    await _openFullSheet(tester);

    expect(find.byKey(const Key('cap19AlbumPickerList')), findsOneWidget);
    expect(find.byKey(const Key('cap19AlbumPickerRow-album-a')), findsOneWidget);
    expect(find.byKey(const Key('cap19AlbumCover-album-a')), findsOneWidget);
    expect(find.byKey(const Key('cap19AlbumPickerRow-album-b')), findsOneWidget);
    expect(sources.listCalls, 1);

    expect(find.text('Alpha Album'), findsOneWidget);
    expect(find.text('Beta Album'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Alpha Album')).dy,
      lessThan(tester.getTopLeft(find.text('Beta Album')).dy),
    );
  });

  testWidgets('W-19.5-2 non-writable albums are omitted', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a1'],
      availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
      extraSources: [
        _writableAlbum(id: 'writable', displayName: 'Writable'),
        _writableAlbum(
          id: 'readonly',
          displayName: 'Read Only',
          canAddContent: false,
        ),
      ],
    );
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, assetSources: sources),
    );
    await tester.pumpAndSettle();

    await _openFullSheet(tester);

    expect(find.byKey(const Key('cap19AlbumPickerRow-writable')), findsOneWidget);
    expect(find.byKey(const Key('cap19AlbumPickerRow-readonly')), findsNothing);
  });

  testWidgets('W-19.5-3 Limited keeps D4 row without list', (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
    final sources = FakeAssetSourceRepository(allIds: const ['a1'], availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const ['a1']));
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, assetSources: sources),
    );
    await tester.pumpAndSettle();

    await _openFullSheet(tester);

    expect(find.byKey(const Key('cap19PanelAddToAlbumLimitedRow')), findsOneWidget);
    expect(find.byKey(const Key('cap19AlbumPickerList')), findsNothing);
    expect(sources.listCalls, 0);
  });

  testWidgets('W-19.5-4 append calls addAssetToAlbum with current asset',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['asset-current'],
      availabilityById: FakeAssetSourceRepository.deviceLocalForIds(
        const ['asset-current'],
      ),
      extraSources: [
        _writableAlbum(id: 'target-album', displayName: 'Target'),
      ],
    );
    final mutations = FakeAlbumMutationRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: sources,
        albumMutations: mutations,
      ),
    );
    await tester.pumpAndSettle();

    await _openFullSheet(tester);
    await tester.tap(find.byKey(const Key('cap19AlbumPickerRow-target-album')));
    await tester.pumpAndSettle();

    expect(mutations.addCalls, 1);
    expect(mutations.lastAssetId, 'asset-current');
    expect(mutations.lastAlbumId, 'target-album');
    await _settleCap19Toasts(tester);
  });

  testWidgets('W-19.5-5 append success closes sheet and shows SnackBar',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a1'],
      availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
      extraSources: [
        _writableAlbum(id: 'album-1', displayName: 'Vacation'),
      ],
    );
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, assetSources: sources),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _openFullSheet(tester);
    await tester.tap(find.byKey(const Key('cap19AlbumPickerRow-album-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsNothing);
    expect(find.byKey(const Key('cap19AddToAlbumSuccessToast')), findsOneWidget);
    expect(
      find.text(l10n.cap19PanelAddToAlbumSuccess('Vacation')),
      findsOneWidget,
    );
    await _settleCap19Toasts(tester);
  });

  testWidgets('W-19.5-6 append failure keeps sheet and shows error SnackBar',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a1'],
      availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
      extraSources: [
        _writableAlbum(id: 'album-1', displayName: 'Vacation'),
      ],
    );
    final mutations = FakeAlbumMutationRepository()
      ..addException = PlatformException(code: 'albumNotWritable');
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: sources,
        albumMutations: mutations,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _openFullSheet(tester);
    await tester.tap(find.byKey(const Key('cap19AlbumPickerRow-album-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsOneWidget);
    expect(find.byKey(const Key('cap19AddToAlbumErrorToast')), findsOneWidget);
    expect(find.text(l10n.cap19PanelAddToAlbumError), findsOneWidget);
    await _settleCap19Toasts(tester);
  });

  testWidgets('W-19.5-7 append does not restart browse session', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a1', 'a2'],
      availabilityById: FakeAssetSourceRepository.deviceLocalForIds(
        const ['a1', 'a2'],
      ),
      extraSources: [
        _writableAlbum(id: 'album-1', displayName: 'Vacation'),
      ],
    );
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, assetSources: sources),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MainBrowseShellPage)),
    );
    final epochBefore =
        container.read(browseSessionProvider).asData!.value.roundEpoch;
    final feedIndexBefore = container.read(mainBrowseFeedIndexProvider);

    await _openFullSheet(tester);
    await tester.tap(find.byKey(const Key('cap19AlbumPickerRow-album-1')));
    await tester.pumpAndSettle();

    final epochAfter =
        container.read(browseSessionProvider).asData!.value.roundEpoch;
    final feedIndexAfter = container.read(mainBrowseFeedIndexProvider);

    expect(epochAfter, epochBefore);
    expect(feedIndexAfter, feedIndexBefore);
    await _settleCap19Toasts(tester);
  });

  testWidgets('W-19.5-8 empty writable list shows empty state', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a1'],
      availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
      extraSources: [
        _writableAlbum(
          id: 'readonly',
          displayName: 'Read Only',
          canAddContent: false,
        ),
      ],
    );
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, assetSources: sources),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _openFullSheet(tester);

    expect(find.byKey(const Key('cap19AlbumPickerEmpty')), findsOneWidget);
    expect(find.text(l10n.cap19PanelAddToAlbumEmpty), findsOneWidget);
    expect(find.byKey(const Key('cap19AlbumPickerRow-readonly')), findsNothing);
  });

  testWidgets(
      'W-31.4-S1 append finishing during sheet exit keeps the Browse page',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a1'],
      availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
      extraSources: [
        _writableAlbum(id: 'album-1', displayName: 'Vacation'),
      ],
    );
    final mutations = _StallingAlbumMutationRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: sources,
        albumMutations: mutations,
      ),
    );
    await tester.pumpAndSettle();

    await _openFullSheet(tester);
    await tester.tap(find.byKey(const Key('cap19AlbumPickerRow-album-1')));
    await tester.pump();
    expect(mutations.addCalls, 1);

    // Barrier tap while the append is in flight.
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    mutations.gate.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsNothing);
    expect(find.byType(MainBrowseShellPage), findsOneWidget);
    await _settleCap19Toasts(tester);
  });
}

class _StallingAlbumMutationRepository extends FakeAlbumMutationRepository {
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> addAssetToAlbum(
    String assetIdentifier,
    String albumIdentifier,
  ) async {
    await super.addAssetToAlbum(assetIdentifier, albumIdentifier);
    await gate.future;
  }
}
