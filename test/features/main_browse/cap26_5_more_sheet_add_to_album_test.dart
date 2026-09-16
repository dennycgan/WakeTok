import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';

import '../../library_smoke/fake_asset_soft_delete_repository.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

/// Cap 26.5: "…" sheet Add-to-Album second entry → Cap 19 half-sheet.

FakeAssetSourceRepository _localSources([String id = 'a1']) {
  return FakeAssetSourceRepository(
    allIds: [id],
    availabilityById: FakeAssetSourceRepository.deviceLocalForIds([id]),
  );
}

Future<void> _openMoreSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('cap24MoreEntryIcon')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
}

void main() {
  tearDown(hideCap19BrowseToast);

  testWidgets(
    'W-26.5-1 Add sits above Delete with matching outlined size',
    (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: _localSources()),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);

      final add = tester.getRect(find.byKey(const Key('cap24MoreSheetAddToAlbum')));
      final del =
          tester.getRect(find.byKey(const Key('cap24SoftDeleteSheetDelete')));
      expect(add.bottom, lessThan(del.top));
      expect(add.width, closeTo(del.width, 0.5));
      expect(add.height, closeTo(del.height, 0.5));
      expect(add.left, closeTo(del.left, 0.5));
    },
  );

  testWidgets(
    'W-26.5-2 Full: Add closes "…" then opens Cap 19 sheet',
    (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: _localSources()),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);

      await tester.tap(find.byKey(const Key('cap24MoreSheetAddToAlbum')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsNothing);
      expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsOneWidget);
      expect(find.byKey(const Key('cap19PanelAddToAlbumLimitedRow')), findsNothing);
    },
  );

  testWidgets(
    'W-26.5-3 Limited: chain opens Cap 19 Limited row',
    (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: _localSources()),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);

      await tester.tap(find.byKey(const Key('cap24MoreSheetAddToAlbum')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsNothing);
      expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsOneWidget);
      expect(
        find.byKey(const Key('cap19PanelAddToAlbumLimitedRow')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'W-26.5-4 Cap 23 fail: stay on "…"; no Cap 19',
    (tester) async {
      final sources = FakeAssetSourceRepository(
        allIds: const ['a1'],
        availabilityById:
            FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: sources),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);

      sources.availabilityById['a1'] = AssetAvailability.unavailable;

      await tester.tap(find.byKey(const Key('cap24MoreSheetAddToAlbum')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('stillInLibraryUnavailableDialog')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
      expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsNothing);

      await tester.tap(
        find.byKey(const Key('stillInLibraryUnavailableDialogDismiss')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('cap24MoreSheetAddToAlbum')),
            )
            .onPressed,
        isNotNull,
        reason: 'latch must clear after Cap 23 fail',
      );
    },
  );

  testWidgets(
    'W-26.5-5 rapid Add while Cap 23 in flight → one Cap 19 only',
    (tester) async {
      final gate = Completer<void>();
      var hangAvailabilities = false;
      final sources = FakeAssetSourceRepository(
        allIds: const ['a1'],
        availabilityById:
            FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
      )..beforeEachGetAssetAvailabilities = (_) async {
          if (hangAvailabilities) {
            await gate.future;
          }
        };
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: sources),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);

      hangAvailabilities = true;
      final probesBefore = sources.getAssetAvailabilitiesCalls;

      await tester.tap(find.byKey(const Key('cap24MoreSheetAddToAlbum')));
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('cap24MoreSheetAddToAlbum')),
            )
            .onPressed,
        isNull,
        reason: 'latch disables Add while Cap 23 / handoff in flight',
      );

      // Second gesture must not start another Cap 23 / Cap 19 chain.
      await tester.tap(find.byKey(const Key('cap24MoreSheetAddToAlbum')));
      await tester.pump();

      expect(
        sources.getAssetAvailabilitiesCalls,
        probesBefore + 1,
        reason: 'only one Cap 23 probe from the first Add',
      );

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsNothing);
      expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsOneWidget);
    },
  );

  testWidgets(
    'W-26.5-6 Delete Host hold: Add onPressed is null (mutual latch)',
    (tester) async {
      final hold = Completer<void>();
      final softDelete = FakeAssetSoftDeleteRepository()..hold = hold;
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          assetSoftDelete: softDelete,
        ),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);

      await tester.tap(find.byKey(const Key('cap24SoftDeleteSheetDelete')));
      await tester.pump();
      expect(
        find.byKey(const Key('cap24SoftDeleteSheetDeleteBusy')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('cap24MoreSheetAddToAlbum')),
            )
            .onPressed,
        isNull,
        reason: '_deleteLatch must disable Add',
      );

      hold.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'W-26.5-7 Add Cap23 hang: Delete onPressed is null (mutual latch)',
    (tester) async {
      final gate = Completer<void>();
      var hangAvailabilities = false;
      final sources = FakeAssetSourceRepository(
        allIds: const ['a1'],
        availabilityById:
            FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
      )..beforeEachGetAssetAvailabilities = (_) async {
          if (hangAvailabilities) {
            await gate.future;
          }
        };
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: sources),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);

      hangAvailabilities = true;
      await tester.tap(find.byKey(const Key('cap24MoreSheetAddToAlbum')));
      await tester.pump();

      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('cap24MoreSheetAddToAlbum')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('cap24SoftDeleteSheetDelete')),
            )
            .onPressed,
        isNull,
        reason: '_addToAlbumLatch must disable Delete',
      );
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);

      // Unblock Cap23 so the test does not leak; expect Cap19 after handoff.
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsOneWidget);
    },
  );
}
