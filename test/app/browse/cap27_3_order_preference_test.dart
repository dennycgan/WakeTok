import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/domain/source/source_resolve_status.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';

import '../../features/authorization/permission_ui_test_harness.dart';
import '../../library_smoke/fake_asset_source_repository.dart';

ProviderContainer _container({
  required FakeAssetSourceRepository fake,
  PhotosAccess access = PhotosAccess.full,
}) {
  return ProviderContainer(
    overrides: [
      assetSourceRepositoryProvider.overrideWithValue(fake),
      browseShuffleRandomFactoryProvider.overrideWith((ref) => () => Random(0)),
      browseEmptyRetryDelaysProvider.overrideWithValue(const []),
      photosAuthorizationRepositoryProvider.overrideWithValue(
        ControllablePhotosAuthorizationRepository(access),
      ),
    ],
  );
}

ResolvedPoolSnapshot _allSnap(List<String> ids) {
  return ResolvedPoolSnapshot(
    id: 'all',
    coalescedAssetIds: ids,
    sourceStatuses: [
      SourceResolveStatus(
        reference: SourceReference.all,
        availability: ids.isEmpty
            ? AssetSourceAvailability.empty
            : AssetSourceAvailability.available,
        rawCount: ids.length,
        contributedCount: ids.length,
      ),
    ],
  );
}

Future<void> _yieldUntil(bool Function() test) async {
  for (var i = 0; i < 200; i++) {
    if (test()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('timed out waiting for condition');
}

/// Capture a [Ref] from [container] for calling [ensureBrowseAllSnapshotCached].
Ref _refOf(ProviderContainer container) {
  late Ref captured;
  final probe = Provider<int>((ref) {
    captured = ref;
    return 0;
  });
  container.read(probe);
  return captured;
}

void main() {
  test('PREF-1 null preference → derive shuffle on new Session', () async {
    final fake = FakeAssetSourceRepository(allIds: const ['x', 'y', 'z']);
    final container = _container(fake: fake);
    addTearDown(container.dispose);

    expect(container.read(browseOrderPreferenceProvider), isNull);
    final view = await container.read(browseSessionProvider.future);
    expect(view.session.queue.configuration.orderPolicy, OrderPolicy.shuffle);
  });

  test(
    'PREF-2 set newestFirst then restartSession keeps newestFirst',
    () async {
      final fake = FakeAssetSourceRepository(allIds: const ['c', 'a', 'b']);
      final container = _container(fake: fake);
      addTearDown(container.dispose);

      await container.read(browseSessionProvider.future);
      container
          .read(browseOrderPreferenceProvider.notifier)
          .setPreference(OrderPolicy.newestFirst);
      await container.read(browseSessionProvider.notifier).restartSession();
      final view = container.read(browseSessionProvider).asData!.value;
      expect(
        view.session.queue.configuration.orderPolicy,
        OrderPolicy.newestFirst,
      );
      expect(view.orderedAssetIds, ['c', 'a', 'b']);
    },
  );

  test(
    'PREF-3 preference survives tab switch (new Session still uses it)',
    () async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a1', 'a2', 'a3'],
        photosIds: const ['p1', 'p2', 'p3'],
      );
      final container = _container(fake: fake);
      addTearDown(container.dispose);

      await container.read(browseSessionProvider.future);
      container
          .read(browseOrderPreferenceProvider.notifier)
          .setPreference(OrderPolicy.oldestFirst);

      container
          .read(browseChromeStateProvider.notifier)
          .selectBuiltIn(SourceReference.photos);
      await _yieldUntil(() {
        final data = container.read(browseSessionProvider).asData;
        if (data == null) {
          return false;
        }
        return data.value.session.queue.configuration.orderPolicy ==
            OrderPolicy.oldestFirst;
      });
      final view = container.read(browseSessionProvider).asData!.value;
      expect(
        view.session.queue.configuration.orderPolicy,
        OrderPolicy.oldestFirst,
      );
      expect(view.orderedAssetIds, ['p3', 'p2', 'p1']);
    },
  );

  test(
    'RANK-1 multi-source Session uses All ranks for newestFirst',
    () async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a', 'b', 'c', 'd'],
        albumResolveIds: {
          'album-1': const ['c', 'a'],
          'album-2': const ['d'],
        },
      );
      final container = _container(fake: fake);
      addTearDown(container.dispose);

      container
          .read(browseOrderPreferenceProvider.notifier)
          .setPreference(OrderPolicy.newestFirst);
      container.read(browseChromeStateProvider.notifier).startEphemeralPool(
            SourcePoolDefinition(
              id: 'ephem-ms',
              persistencePolicy: PersistencePolicy.ephemeral,
              orderedSourceReferences: const [
                SourceReference(kind: AssetSourceKind.album, id: 'album-1'),
                SourceReference(kind: AssetSourceKind.album, id: 'album-2'),
              ],
            ),
          );
      await _yieldUntil(
        () =>
            container.read(browseSessionProvider).hasValue &&
            container
                    .read(browseSessionProvider)
                    .asData!
                    .value
                    .orderedAssetIds
                    .length ==
                3,
      );
      final view = container.read(browseSessionProvider).asData!.value;
      expect(view.orderedAssetIds, ['a', 'c', 'd']);
    },
  );

  test('RANK-2 clearing All cache drops browseAllRankMapProvider', () {
    final fake = FakeAssetSourceRepository(allIds: const ['a', 'b']);
    final container = _container(fake: fake);
    addTearDown(container.dispose);

    container
        .read(browseSnapshotCacheProvider.notifier)
        .put(SourceReference.all, _allSnap(const ['a', 'b']));
    expect(container.read(browseAllRankMapProvider), {'a': 0, 'b': 1});
    container.read(browseSnapshotCacheProvider.notifier).clear();
    expect(container.read(browseAllRankMapProvider), isNull);
  });

  test(
    'PREFETCH-1 success puts All; empty does not; no Session restart',
    () async {
      final fake = FakeAssetSourceRepository(allIds: const ['x', 'y']);
      final container = _container(fake: fake);
      addTearDown(container.dispose);

      final before = await container.read(browseSessionProvider.future);
      final epochBefore = before.roundEpoch;
      // Session build already cached All — clear to force prefetch resolve.
      container.read(browseSnapshotCacheProvider.notifier).clear();
      final resolvesBefore = fake.resolveCalls;

      await ensureBrowseAllSnapshotCached(_refOf(container));
      expect(
        container.read(browseSnapshotCacheProvider)[
            BrowseSnapshotCache.keyFor(SourceReference.all)]?.coalescedAssetIds,
        ['x', 'y'],
      );
      expect(fake.resolveCalls, greaterThan(resolvesBefore));
      expect(
        container.read(browseSessionProvider).asData!.value.roundEpoch,
        epochBefore,
      );

      container.read(browseSnapshotCacheProvider.notifier).clear();
      fake.allIds = const [];
      final put = await ensureBrowseAllSnapshotCached(_refOf(container));
      expect(put?.coalescedAssetIds ?? const <String>[], isEmpty);
      expect(
        container.read(browseSnapshotCacheProvider)[
            BrowseSnapshotCache.keyFor(SourceReference.all)],
        isNull,
      );
    },
  );

  test(
    'PREFETCH-2 binder fires after full auth without restarting Session',
    () async {
      final fake = FakeAssetSourceRepository(allIds: const ['p', 'q']);
      final container = _container(fake: fake);
      addTearDown(container.dispose);

      final view = await container.read(browseSessionProvider.future);
      final epoch = view.roundEpoch;
      // Drop All if session already resolved it, then re-bind prefetch.
      container.read(browseSnapshotCacheProvider.notifier).clear();
      container.read(browseAllPrefetchBinderProvider);
      await _yieldUntil(
        () =>
            container.read(browseSnapshotCacheProvider)[
                BrowseSnapshotCache.keyFor(SourceReference.all)] !=
            null,
      );
      expect(
        container.read(browseSessionProvider).asData!.value.roundEpoch,
        epoch,
      );
    },
  );
}
