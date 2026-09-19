import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/saved_pool_record.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';

import '../../library_smoke/fake_asset_source_repository.dart';

/// Cap 27.2 / ADR-057: Temp peek promote keep-Session + Open same-recipe.
ProviderContainer _container({required FakeAssetSourceRepository fake}) {
  return ProviderContainer(
    overrides: [
      assetSourceRepositoryProvider.overrideWithValue(fake),
      browseShuffleRandomFactoryProvider.overrideWith((ref) => () => Random(0)),
      browseEmptyRetryDelaysProvider.overrideWithValue(const []),
    ],
  );
}

SavedPoolRecord _record({
  required String id,
  required String name,
  required List<SourceReference> refs,
}) {
  final at = DateTime.utc(2026, 9, 19);
  return SavedPoolRecord(
    id: id,
    displayName: name,
    createdAt: at,
    updatedAt: at,
    orderedSourceReferences: refs,
  );
}

void main() {
  group('Cap 27.2 ADR-057 promote keep-Session', () {
    test('P-27-E: promote keeps Session index, epoch, sticky feed id', () async {
      final fake = FakeAssetSourceRepository(
        photosIds: const ['p1', 'p2', 'p3', 'p4'],
        videosIds: const ['v1'],
      );
      final container = _container(fake: fake);
      addTearDown(container.dispose);

      const refs = [SourceReference.photos, SourceReference.videos];
      container.read(browseChromeStateProvider.notifier).startEphemeralPool(
        SourcePoolDefinition(
          id: 'eph-27-2',
          persistencePolicy: PersistencePolicy.ephemeral,
          orderedSourceReferences: refs,
        ),
      );

      final before = await container.read(browseSessionProvider.future);
      expect(before.orderedAssetIds.length, greaterThan(1));
      final epoch = before.roundEpoch;
      final queue = List<String>.from(before.orderedAssetIds);
      final ephemeralFeedId = container.read(
        browseEffectiveFeedDataSourceIdProvider,
      );
      expect(ephemeralFeedId, 'ephemeral:eph-27-2');

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(2);
      expect(container.read(mainBrowseFeedIndexProvider), 2);

      // Seed L2-ready + watchdog so promote must not clear them.
      container.read(browseL2ReadySessionProvider.notifier).record(
        FeedL2ReadyEntry(
          assetIdentifier: queue[2],
          kind: FeedL2ReadyKind.stillFull,
        ),
      );
      container.read(browseLiveMotionWatchdogSkipIdsProvider.notifier).add(
        queue.first,
      );

      final record = _record(id: 'saved-from-temp', name: 'From Temp', refs: refs);
      container
          .read(browseSessionProvider.notifier)
          .promoteCurrentSessionToSavedPool(record);
      await container.read(browseSessionProvider.future);

      final after = container.read(browseSessionProvider).requireValue;
      expect(after.roundEpoch, epoch);
      expect(after.orderedAssetIds, queue);
      expect(container.read(mainBrowseFeedIndexProvider), 2);
      expect(
        container.read(browseChromeStateProvider).activeOrigin,
        isA<BrowseOriginSavedPool>(),
      );
      expect(
        (container.read(browseChromeStateProvider).activeOrigin
                as BrowseOriginSavedPool)
            .poolId,
        'saved-from-temp',
      );
      expect(
        container.read(browseChromeStateProvider).parkedEphemeralPool,
        isNull,
      );
      // Decision 5: sticky holds ephemeral id (not saved:$poolId yet).
      expect(
        container.read(browseEffectiveFeedDataSourceIdProvider),
        'ephemeral:eph-27-2',
      );
      expect(
        container.read(browseStickyFeedDataSourceIdProvider),
        'ephemeral:eph-27-2',
      );
      expect(
        container.read(browseOriginSessionDeltaProvider).isIdentityPreservingPromote,
        isTrue,
      );
      expect(
        container.read(browseL2ReadySessionProvider).containsKey(queue[2]),
        isTrue,
      );
      expect(
        container.read(browseLiveMotionWatchdogSkipIdsProvider).contains(queue.first),
        isTrue,
      );
    });

    test(
      'P-27-E′: Open same-recipe other Saved ⇒ new Session at index 0',
      () async {
        final fake = FakeAssetSourceRepository(
          photosIds: const ['p1', 'p2', 'p3'],
          videosIds: const ['v1'],
        );
        final container = _container(fake: fake);
        addTearDown(container.dispose);

        const refs = [SourceReference.photos, SourceReference.videos];
        final a = _record(id: 'pool-a', name: 'Copy A', refs: refs);
        final b = _record(id: 'pool-b', name: 'Copy B', refs: refs);

        container.read(browseChromeStateProvider.notifier).openSavedPool(a);
        final first = await container.read(browseSessionProvider.future);
        final epoch1 = first.roundEpoch;
        container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
        expect(container.read(mainBrowseFeedIndexProvider), 1);
        expect(
          container.read(browseEffectiveFeedDataSourceIdProvider),
          'saved:pool-a',
        );

        container.read(browseChromeStateProvider.notifier).openSavedPool(b);
        final second = await container.read(browseSessionProvider.future);

        expect(second.roundEpoch, greaterThan(epoch1));
        expect(container.read(mainBrowseFeedIndexProvider), 0);
        expect(
          (container.read(browseChromeStateProvider).activeOrigin
                  as BrowseOriginSavedPool)
              .poolId,
          'pool-b',
        );
        expect(
          container.read(browseEffectiveFeedDataSourceIdProvider),
          'saved:pool-b',
        );
        expect(container.read(browseStickyFeedDataSourceIdProvider), isNull);
        expect(
          container.read(browseOriginSessionDeltaProvider).isRealSessionBoundary,
          isTrue,
        );
      },
    );

    test(
      'Build startSavedPool still new Session (not promote API)',
      () async {
        final fake = FakeAssetSourceRepository(
          photosIds: const ['p1', 'p2'],
          videosIds: const ['v1'],
        );
        final container = _container(fake: fake);
        addTearDown(container.dispose);

        const refs = [SourceReference.photos, SourceReference.videos];
        container.read(browseChromeStateProvider.notifier).startEphemeralPool(
          SourcePoolDefinition(
            id: 'eph-build',
            persistencePolicy: PersistencePolicy.ephemeral,
            orderedSourceReferences: refs,
          ),
        );
        final before = await container.read(browseSessionProvider.future);
        container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);

        container.read(browseChromeStateProvider.notifier).startSavedPool(
          _record(id: 'from-build', name: 'Build Save', refs: refs),
        );
        final after = await container.read(browseSessionProvider.future);

        expect(after.roundEpoch, greaterThan(before.roundEpoch));
        expect(container.read(mainBrowseFeedIndexProvider), 0);
        expect(
          container.read(browseEffectiveFeedDataSourceIdProvider),
          'saved:from-build',
        );
      },
    );

    test('promote requires active ephemeral', () {
      final container = _container(
        fake: FakeAssetSourceRepository(allIds: const ['a']),
      );
      addTearDown(container.dispose);

      expect(
        () => container
            .read(browseSessionProvider.notifier)
            .promoteCurrentSessionToSavedPool(
              _record(
                id: 'x',
                name: 'X',
                refs: const [SourceReference.all],
              ),
            ),
        throwsStateError,
      );
    });
  });
}
