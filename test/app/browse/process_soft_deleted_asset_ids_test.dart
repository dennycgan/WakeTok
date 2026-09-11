import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/app/browse/process_soft_deleted_asset_ids.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';

import '../../library_smoke/fake_asset_source_repository.dart';

ProviderContainer _container({
  required FakeAssetSourceRepository fake,
}) {
  return ProviderContainer(
    overrides: [
      assetSourceRepositoryProvider.overrideWithValue(fake),
      browseShuffleRandomFactoryProvider.overrideWith((ref) => () => Random(0)),
      browseEmptyRetryDelaysProvider.overrideWithValue(const []),
    ],
  );
}

void main() {
  test('U-24.4c-5 fresh ProcessSoftDeletedAssetIds defaults empty', () {
    final a = ProviderContainer();
    final b = ProviderContainer();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    expect(a.read(processSoftDeletedAssetIdsProvider), isEmpty);
    expect(b.read(processSoftDeletedAssetIdsProvider), isEmpty);
    a.read(processSoftDeletedAssetIdsProvider.notifier).add('gone');
    expect(a.read(processSoftDeletedAssetIdsProvider), {'gone'});
    // Independent containers = independent process-scoped state (no disk).
    expect(b.read(processSoftDeletedAssetIdsProvider), isEmpty);
  });

  test(
    'U-24.4c-1 soft-delete survives ≥3 Origin leave/return Session starts',
    () async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a', 'b', 'c', 'd'],
        photosIds: const ['a', 'b', 'c', 'd'],
        videosIds: const [],
      );
      final container = _container(fake: fake);
      addTearDown(container.dispose);

      await container.read(browseSessionProvider.future);
      final deleted = container
          .read(browseSessionProvider)
          .requireValue
          .orderedAssetIds
          .first;
      container.read(browseSessionProvider.notifier).removeAssetAndLand(
            assetId: deleted,
            feedIndex: 0,
          );
      expect(
        container.read(processSoftDeletedAssetIdsProvider),
        contains(deleted),
      );

      for (var i = 0; i < 3; i++) {
        container
            .read(browseChromeStateProvider.notifier)
            .selectBuiltIn(SourceReference.photos);
        await container.read(browseSessionProvider.future);
        container
            .read(browseChromeStateProvider.notifier)
            .selectBuiltIn(SourceReference.all);
        final view = await container.read(browseSessionProvider.future);
        expect(
          view.orderedAssetIds,
          isNot(contains(deleted)),
          reason: 'ghost on leave/return cycle #$i',
        );
      }
    },
  );

  test(
    'U-24.4c-2 process exclusion is global across multiple Origins',
    () async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a', 'b', 'c'],
        photosIds: const ['a', 'b', 'c'],
        videosIds: const ['a', 'b'],
      );
      final container = _container(fake: fake);
      addTearDown(container.dispose);

      await container.read(browseSessionProvider.future);
      final deleted = container
          .read(browseSessionProvider)
          .requireValue
          .orderedAssetIds
          .first;
      container.read(browseSessionProvider.notifier).removeAssetAndLand(
            assetId: deleted,
            feedIndex: 0,
          );

      container
          .read(browseChromeStateProvider.notifier)
          .selectBuiltIn(SourceReference.photos);
      var view = await container.read(browseSessionProvider.future);
      expect(view.orderedAssetIds, isNot(contains(deleted)));

      container
          .read(browseChromeStateProvider.notifier)
          .selectBuiltIn(SourceReference.videos);
      view = await container.read(browseSessionProvider.future);
      expect(view.orderedAssetIds, isNot(contains(deleted)));

      container
          .read(browseChromeStateProvider.notifier)
          .selectBuiltIn(SourceReference.all);
      view = await container.read(browseSessionProvider.future);
      expect(view.orderedAssetIds, isNot(contains(deleted)));
    },
  );

  test(
    'U-24.4c-3 Snapshot cache still holds deleted id; Session Queue does not',
    () async {
      final fake = FakeAssetSourceRepository(allIds: const ['a', 'b', 'c']);
      final container = _container(fake: fake);
      addTearDown(container.dispose);

      await container.read(browseSessionProvider.future);
      final deleted = container
          .read(browseSessionProvider)
          .requireValue
          .orderedAssetIds
          .first;
      container.read(browseSessionProvider.notifier).removeAssetAndLand(
            assetId: deleted,
            feedIndex: 0,
          );

      final cached = container
          .read(browseSnapshotCacheProvider.notifier)
          .get(SourceReference.all);
      expect(cached, isNotNull);
      expect(cached!.coalescedAssetIds, contains(deleted));

      container
          .read(browseChromeStateProvider.notifier)
          .selectBuiltIn(SourceReference.photos);
      await container.read(browseSessionProvider.future);
      container
          .read(browseChromeStateProvider.notifier)
          .selectBuiltIn(SourceReference.all);
      final view = await container.read(browseSessionProvider.future);
      expect(view.orderedAssetIds, isNot(contains(deleted)));
      expect(
        container
            .read(browseSnapshotCacheProvider.notifier)
            .get(SourceReference.all)!
            .coalescedAssetIds,
        contains(deleted),
      );
    },
  );

  test('U-24.4c-4 no soft-delete: Session still uses full coalesced list',
      () async {
    final fake = FakeAssetSourceRepository(allIds: const ['a', 'b', 'c']);
    final container = _container(fake: fake);
    addTearDown(container.dispose);

    final view = await container.read(browseSessionProvider.future);
    expect(view.orderedAssetIds.toSet(), {'a', 'b', 'c'});
    expect(container.read(processSoftDeletedAssetIdsProvider), isEmpty);
  });

  test('snapshotExcludingProcessSoftDeletes is pure / cache-safe', () {
    final snap = ResolvedPoolSnapshot(
      id: 's',
      coalescedAssetIds: const ['a', 'b', 'c'],
      sourceStatuses: const [],
    );
    final filtered = snapshotExcludingProcessSoftDeletes(
      snapshot: snap,
      excluded: {'b'},
    );
    expect(filtered.coalescedAssetIds, ['a', 'c']);
    expect(snap.coalescedAssetIds, ['a', 'b', 'c']);
    expect(
      identical(
        snapshotExcludingProcessSoftDeletes(
          snapshot: snap,
          excluded: const {},
        ),
        snap,
      ),
      isTrue,
    );
  });
}
