import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_l2_ready_session.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';

import '../../library_smoke/fake_asset_soft_delete_repository.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

FakeAssetSourceRepository _threeLocal() {
  return FakeAssetSourceRepository(
    allIds: const ['a', 'b', 'c'],
    availabilityById:
        FakeAssetSourceRepository.deviceLocalForIds(const ['a', 'b', 'c']),
  );
}

ProviderContainer _containerOf(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
}

Future<void> _openMoreSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('cap24MoreEntryIcon')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
}

Future<void> _confirmSoftDelete(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('cap24SoftDeleteSheetDelete')));
  await tester.pumpAndSettle();
}

List<String> _queueIds(ProviderContainer container) {
  return container
      .read(browseSessionProvider)
      .requireValue
      .session
      .queue
      .orderedAssetIds;
}

void main() {
  tearDown(hideCap19BrowseToast);

  testWidgets(
    'W-24.4-1 success mid-list: queue drops id; same feedIndex; next rises',
    (tester) async {
      final softDelete = FakeAssetSoftDeleteRepository();
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _threeLocal(),
          assetSoftDelete: softDelete,
        ),
      );
      await tester.pumpAndSettle();

      final container = _containerOf(tester);
      final before = List<String>.from(_queueIds(container));
      expect(before, hasLength(3));
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await tester.pumpAndSettle();

      final deleted = container.read(mainBrowseCurrentAssetIdProvider)!;
      final formerNext = before[2];
      expect(deleted, before[1]);

      final epochBefore =
          container.read(browseSessionProvider).requireValue.roundEpoch;

      await _openMoreSheet(tester);
      await _confirmSoftDelete(tester);

      expect(softDelete.callCount, 1);
      expect(softDelete.lastAssetId, deleted);
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsNothing);

      final after = _queueIds(container);
      expect(after, isNot(contains(deleted)));
      expect(after, hasLength(2));
      expect(container.read(mainBrowseFeedIndexProvider), 1);
      expect(container.read(mainBrowseCurrentAssetIdProvider), formerNext);
      expect(
        container.read(browseSessionProvider).requireValue.roundEpoch,
        epochBefore,
      );
    },
  );

  testWidgets(
    'W-24.4-2 fail / cancel: queue and feedIndex unchanged',
    (tester) async {
      final softDelete = FakeAssetSoftDeleteRepository()
        ..exception = PlatformException(
          code: AppError.operationCancelled.name,
        );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _threeLocal(),
          assetSoftDelete: softDelete,
        ),
      );
      await tester.pumpAndSettle();

      final container = _containerOf(tester);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await tester.pumpAndSettle();
      final beforeIds = List<String>.from(_queueIds(container));
      final beforeIndex = container.read(mainBrowseFeedIndexProvider);
      final beforeCurrent =
          container.read(mainBrowseCurrentAssetIdProvider);

      await _openMoreSheet(tester);
      await _confirmSoftDelete(tester);

      expect(_queueIds(container), beforeIds);
      expect(container.read(mainBrowseFeedIndexProvider), beforeIndex);
      expect(container.read(mainBrowseCurrentAssetIdProvider), beforeCurrent);
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);

      // Host unknown failure path — still no Queue mutate.
      softDelete.exception =
          PlatformException(code: AppError.unknown.name);
      await tester.tap(find.byKey(const Key('cap24SoftDeleteSheetDelete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cap24SoftDeleteSheetDelete')));
      await tester.pumpAndSettle();

      expect(_queueIds(container), beforeIds);
      expect(container.read(mainBrowseFeedIndexProvider), beforeIndex);
      expect(find.byKey(const Key('cap24SoftDeleteFailedToast')), findsOneWidget);
      hideCap19BrowseToast();
    },
  );

  testWidgets(
    'W-24.4-3 delete last item lands on newLength-1 (not head)',
    (tester) async {
      final softDelete = FakeAssetSoftDeleteRepository();
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _threeLocal(),
          assetSoftDelete: softDelete,
        ),
      );
      await tester.pumpAndSettle();

      final container = _containerOf(tester);
      final before = List<String>.from(_queueIds(container));
      final lastIndex = before.length - 1;
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(lastIndex);
      await tester.pumpAndSettle();

      final deleted = container.read(mainBrowseCurrentAssetIdProvider)!;
      final expectedLand = before[lastIndex - 1];

      await _openMoreSheet(tester);
      await _confirmSoftDelete(tester);

      final after = _queueIds(container);
      expect(after, isNot(contains(deleted)));
      expect(container.read(mainBrowseFeedIndexProvider), after.length - 1);
      expect(container.read(mainBrowseCurrentAssetIdProvider), expectedLand);
      expect(container.read(mainBrowseFeedIndexProvider), isNot(0));
    },
  );

  testWidgets(
    'W-24.4-4 success does not invalidate Snapshot cache',
    (tester) async {
      final softDelete = FakeAssetSoftDeleteRepository();
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _threeLocal(),
          assetSoftDelete: softDelete,
        ),
      );
      await tester.pumpAndSettle();

      final container = _containerOf(tester);
      final cacheBefore = Map<String, ResolvedPoolSnapshot>.from(
        container.read(browseSnapshotCacheProvider),
      );
      expect(cacheBefore, isNotEmpty);
      final coalescedBefore = {
        for (final e in cacheBefore.entries)
          e.key: List<String>.from(e.value.coalescedAssetIds),
      };

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);
      await _confirmSoftDelete(tester);

      final cacheAfter = container.read(browseSnapshotCacheProvider);
      expect(cacheAfter.keys.toSet(), cacheBefore.keys.toSet());
      for (final key in coalescedBefore.keys) {
        expect(
          cacheAfter[key]!.coalescedAssetIds,
          coalescedBefore[key],
        );
      }
    },
  );

  testWidgets(
    'W-24.4-5 after land, … opens half-sheet again (Cap 23 latch clear)',
    (tester) async {
      final softDelete = FakeAssetSoftDeleteRepository();
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _threeLocal(),
          assetSoftDelete: softDelete,
        ),
      );
      await tester.pumpAndSettle();

      final container = _containerOf(tester);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await tester.pumpAndSettle();

      await _openMoreSheet(tester);
      await _confirmSoftDelete(tester);
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsNothing);

      await _openMoreSheet(tester);
      expect(find.byKey(const Key('stillInLibraryUnavailableDialog')), findsNothing);
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
    },
  );

  testWidgets(
    'W-24.4-6 after land, vertical feed settled + trailing chrome restored',
    (tester) async {
      final softDelete = FakeAssetSoftDeleteRepository();
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _threeLocal(),
          assetSoftDelete: softDelete,
        ),
      );
      await tester.pumpAndSettle();

      final container = _containerOf(tester);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await tester.pumpAndSettle();

      await _openMoreSheet(tester);
      // Force unsettled while sheet is open — success path must restore
      // explicitly (ADR-042 D8); do not rely on gesture ScrollEnd.
      container
          .read(mainBrowseVerticalFeedSettledProvider.notifier)
          .setSettled(false);
      expect(container.read(mainBrowseVerticalFeedSettledProvider), isFalse);

      await _confirmSoftDelete(tester);

      expect(container.read(mainBrowseVerticalFeedSettledProvider), isTrue);
      expect(find.byKey(const Key('cap24MoreEntryIcon')), findsOneWidget);
      expect(
        tester
            .widget<InkWell>(find.byKey(const Key('cap24MoreEntryIcon')))
            .onTap,
        isNotNull,
      );
    },
  );

  testWidgets(
    'W-24.4-7 L2-ready token for deleted id is evicted',
    (tester) async {
      final softDelete = FakeAssetSoftDeleteRepository();
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _threeLocal(),
          assetSoftDelete: softDelete,
        ),
      );
      await tester.pumpAndSettle();

      final container = _containerOf(tester);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await tester.pumpAndSettle();
      final deleted = container.read(mainBrowseCurrentAssetIdProvider)!;

      container.read(browseL2ReadySessionProvider.notifier).record(
            FeedL2ReadyEntry(
              assetIdentifier: deleted,
              kind: FeedL2ReadyKind.stillFull,
              cover: DisplayAsset(
                assetIdentifier: deleted,
                mediaKind: PlaybackMediaKind.image,
                localFilePath: '/tmp/cap24-l2-evict.jpg',
              ),
            ),
          );
      expect(
        container.read(browseL2ReadySessionProvider.notifier).lookup(deleted),
        isNotNull,
      );

      await _openMoreSheet(tester);
      await _confirmSoftDelete(tester);

      expect(
        container.read(browseL2ReadySessionProvider.notifier).lookup(deleted),
        isNull,
      );
    },
  );
}
