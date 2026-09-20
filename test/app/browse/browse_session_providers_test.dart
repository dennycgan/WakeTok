import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/domain/session/default_session_profile.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';

import '../../library_smoke/fake_asset_source_repository.dart';

ProviderContainer _sessionContainer({
  required FakeAssetSourceRepository fake,
  BrowseShuffleRandomFactory? shuffle,
  List<Duration> emptyRetryDelays = const [],
}) {
  return ProviderContainer(
    overrides: [
      assetSourceRepositoryProvider.overrideWithValue(fake),
      browseShuffleRandomFactoryProvider.overrideWith(
        (ref) => shuffle ?? () => Random(0),
      ),
      browseEmptyRetryDelaysProvider.overrideWithValue(emptyRetryDelays),
    ],
  );
}

const _zeroEmptyRetries = [Duration.zero, Duration.zero, Duration.zero];

Future<void> _yieldUntil(bool Function() test) async {
  for (var i = 0; i < 200; i++) {
    if (test()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('timed out waiting for condition');
}

void main() {
  test(
    'APP-1 single-source All: coalesce + generalMixed Shuffle config',
    () async {
      final fake = FakeAssetSourceRepository(allIds: const ['x', 'y', 'z']);
      final container = _sessionContainer(fake: fake);
      addTearDown(container.dispose);

      final view = await container.read(browseSessionProvider.future);
      expect(view.session.snapshot.coalescedAssetIds, ['x', 'y', 'z']);
      expect(
        view.session.queue.configuration,
        DefaultSessionProfile.generalMixed,
      );
      expect(view.session.queue.configuration.orderPolicy, OrderPolicy.shuffle);
      expect(fake.resolveCalls, 1);
    },
  );

  test('APP-2 Random(0) All ids match SHUF-1 golden', () async {
    final fake = FakeAssetSourceRepository(allIds: const ['x', 'y', 'z']);
    final container = _sessionContainer(fake: fake);
    addTearDown(container.dispose);

    final view = await container.read(browseSessionProvider.future);
    expect(view.orderedAssetIds, ['z', 'y', 'x']);
  });

  test(
    'APP-3 cache-hit revisit: no re-resolve; Random(1) vs Random(2) orders differ',
    () async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a', 'b', 'c', 'd', 'e'],
      );
      var seed = 1;
      final container = _sessionContainer(
        fake: fake,
        shuffle: () => Random(seed),
      );
      addTearDown(container.dispose);

      final first = await container.read(browseSessionProvider.future);
      expect(fake.resolveCalls, 1);
      // Pre-verified: Random(1) vs Random(2) on n=5 yield different orders.
      expect(first.orderedAssetIds, ['a', 'b', 'c', 'd', 'e']);

      seed = 2;
      container.invalidate(browseSessionProvider);
      final second = await container.read(browseSessionProvider.future);
      expect(fake.resolveCalls, 1);
      expect(second.orderedAssetIds, ['c', 'a', 'e', 'b', 'd']);
      expect(second.orderedAssetIds, isNot(first.orderedAssetIds));
    },
  );

  test('APP-4 All→Photos starts independent session', () async {
    final fake = FakeAssetSourceRepository(
      allIds: const ['all-only'],
      photosIds: const ['ph-only'],
    );
    final container = _sessionContainer(fake: fake);
    addTearDown(container.dispose);

    final allView = await container.read(browseSessionProvider.future);
    expect(allView.orderedAssetIds, ['all-only']);

    container
        .read(mainBrowseSelectedSourceProvider.notifier)
        .select(SourceReference.photos);
    final photosView = await container.read(browseSessionProvider.future);
    expect(photosView.orderedAssetIds, ['ph-only']);
    expect(fake.resolveCalls, 2);
  });

  test('APP-5 advanceToNextRound: first ≠ previous last (n>1)', () async {
    final fake = FakeAssetSourceRepository(
      allIds: const ['a', 'b', 'c', 'd', 'e'],
    );
    final container = _sessionContainer(fake: fake);
    addTearDown(container.dispose);

    final first = await container.read(browseSessionProvider.future);
    expect(first.orderedAssetIds, ['e', 'c', 'd', 'b', 'a']);
    final lastId = first.orderedAssetIds.last;

    // Next read uses a fresh Random(0); with previousRoundLastId 'a' the
    // domain retries off the same instance — provider supplies a new Random(0)
    // per read, matching production injection shape. Assert via notifier.
    container.read(browseSessionProvider.notifier).advanceToNextRound();
    final second = container.read(browseSessionProvider).requireValue;
    expect(second.session.currentIndex, 0);
    expect(second.roundEpoch, greaterThan(first.roundEpoch));
    expect(second.orderedAssetIds.first, isNot(lastId));
    expect(fake.resolveCalls, 1);
  });

  test(
    'APP-6 empty success is not cached; later resolve can populate',
    () async {
      final fake = FakeAssetSourceRepository(allIds: const []);
      final container = _sessionContainer(fake: fake);
      addTearDown(container.dispose);

      final empty = await container.read(browseSessionProvider.future);
      expect(empty.orderedAssetIds, isEmpty);
      expect(fake.resolveCalls, 1);

      fake.allIds = const ['later'];
      container.invalidate(browseSessionProvider);
      final filled = await container.read(browseSessionProvider.future);
      expect(fake.resolveCalls, 2);
      expect(filled.orderedAssetIds, ['later']);
    },
  );

  test('APP-7 unauthorized maps to empty ids, is not cached', () async {
    final fake = FakeAssetSourceRepository(
      resolveException: PlatformException(code: AppError.unauthorized.name),
    );
    final container = _sessionContainer(fake: fake);
    addTearDown(container.dispose);

    final view = await container.read(browseSessionProvider.future);
    expect(view.orderedAssetIds, isEmpty);
    expect(
      view.session.snapshot.sourceStatuses.single.availability,
      AssetSourceAvailability.unauthorized,
    );
    expect(fake.resolveCalls, 1);

    container.invalidate(browseSessionProvider);
    await container.read(browseSessionProvider.future);
    expect(fake.resolveCalls, 2);
  });

  test(
    'APP-8 leave Browse→Settings resets session+index without returning to Browse',
    () async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a', 'b', 'c', 'd', 'e'],
      );
      var seed = 1;
      final container = _sessionContainer(
        fake: fake,
        shuffle: () => Random(seed),
      );
      addTearDown(container.dispose);

      final before = await container.read(browseSessionProvider.future);
      expect(before.orderedAssetIds, ['a', 'b', 'c', 'd', 'e']);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(2);
      expect(container.read(mainBrowseFeedIndexProvider), 2);

      // Cap 14.4e: reset runs on leave, not on resume. Do not select(browse).
      seed = 2;
      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.settings);

      expect(
        container.read(mainBrowseDestinationProvider),
        MainBrowseDestination.settings,
      );
      expect(container.read(mainBrowseFeedIndexProvider), 0);
      final after = await container.read(browseSessionProvider.future);
      expect(after.roundEpoch, greaterThan(before.roundEpoch));
      expect(after.orderedAssetIds, ['c', 'a', 'e', 'b', 'd']);
      expect(fake.resolveCalls, 1);
    },
  );

  test(
    'APP-8b leave Browse→Settings resets; re-select Settings does not reshuffle',
    () async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a', 'b', 'c', 'd', 'e'],
      );
      var seed = 1;
      final container = _sessionContainer(
        fake: fake,
        shuffle: () => Random(seed),
      );
      addTearDown(container.dispose);

      final first = await container.read(browseSessionProvider.future);
      seed = 2;
      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.settings);
      final afterLeave = await container.read(browseSessionProvider.future);
      expect(afterLeave.roundEpoch, greaterThan(first.roundEpoch));
      expect(container.read(mainBrowseFeedIndexProvider), 0);

      final epochAfterLeave = afterLeave.roundEpoch;
      final orderAfterLeave = afterLeave.orderedAssetIds;
      seed = 3;
      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.settings);
      final afterAgain = await container.read(browseSessionProvider.future);
      expect(afterAgain.roundEpoch, epochAfterLeave);
      expect(afterAgain.orderedAssetIds, orderAfterLeave);
      expect(fake.resolveCalls, 1);
    },
  );

  test(
    'APP-8c leave Browse restart maps unmapped throw to AsyncError not stuck Loading',
    () async {
      final fake = FakeAssetSourceRepository(allIds: const ['a', 'b']);
      final container = _sessionContainer(fake: fake);
      addTearDown(container.dispose);

      await container.read(browseSessionProvider.future);
      expect(fake.resolveCalls, 1);

      // Force cache miss so restart re-resolves; plain Exception is not
      // mapped by resolveOneFromRepository (only selected PlatformException).
      container.read(browseSnapshotCacheProvider.notifier).clear();
      fake.resolveException = Exception('unmapped resolve boom');

      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.settings);

      await expectLater(
        container.read(browseSessionProvider.future),
        throwsA(isA<Exception>()),
      );
      final async = container.read(browseSessionProvider);
      expect(async, isA<AsyncError<BrowseSessionView>>());
      expect(async.isLoading, isFalse);
      expect(fake.resolveCalls, 2);
    },
  );

  test('APP-14.6a empty then ids on third attempt; caches non-empty', () async {
    final fake = FakeAssetSourceRepository(
      allIdsForCall: (i) => i < 2 ? const <String>[] : const ['later'],
    );
    final container = _sessionContainer(
      fake: fake,
      emptyRetryDelays: _zeroEmptyRetries,
    );
    addTearDown(container.dispose);

    final view = await container.read(browseSessionProvider.future);
    expect(view.orderedAssetIds, ['later']);
    expect(fake.resolveCalls, 3);
    expect(
      container
          .read(browseSnapshotCacheProvider.notifier)
          .get(SourceReference.all),
      isNotNull,
    );
  });

  test('APP-14.6b four empties stay uncached', () async {
    final fake = FakeAssetSourceRepository(allIds: const []);
    final container = _sessionContainer(
      fake: fake,
      emptyRetryDelays: _zeroEmptyRetries,
    );
    addTearDown(container.dispose);

    final view = await container.read(browseSessionProvider.future);
    expect(view.orderedAssetIds, isEmpty);
    expect(fake.resolveCalls, 4);
    expect(
      container
          .read(browseSnapshotCacheProvider.notifier)
          .get(SourceReference.all),
      isNull,
    );
  });

  test('APP-14.6c first unauthorized does not retry', () async {
    final fake = FakeAssetSourceRepository(
      resolveException: PlatformException(code: AppError.unauthorized.name),
    );
    final container = _sessionContainer(
      fake: fake,
      emptyRetryDelays: _zeroEmptyRetries,
    );
    addTearDown(container.dispose);

    final view = await container.read(browseSessionProvider.future);
    expect(view.orderedAssetIds, isEmpty);
    expect(
      view.session.snapshot.sourceStatuses.single.availability,
      AssetSourceAvailability.unauthorized,
    );
    expect(fake.resolveCalls, 1);
  });

  test('APP-14.6d empty then unauthorized stops retry', () async {
    final fake = FakeAssetSourceRepository(allIds: const []);
    fake.beforeEachResolve = (i) async {
      if (i == 1) {
        fake.resolveException = PlatformException(
          code: AppError.unauthorized.name,
        );
      }
    };
    final container = _sessionContainer(
      fake: fake,
      emptyRetryDelays: _zeroEmptyRetries,
    );
    addTearDown(container.dispose);

    final view = await container.read(browseSessionProvider.future);
    expect(view.orderedAssetIds, isEmpty);
    expect(
      view.session.snapshot.sourceStatuses.single.availability,
      AssetSourceAvailability.unauthorized,
    );
    expect(fake.resolveCalls, 2);
    expect(
      container
          .read(browseSnapshotCacheProvider.notifier)
          .get(SourceReference.all),
      isNull,
    );
  });

  test(
    'APP-14.6e older restartSession does not overwrite a newer restart',
    () async {
      final firstRestartHold = Completer<void>();
      final fake = FakeAssetSourceRepository(
        allIdsForCall: (i) {
          if (i == 0) {
            return const ['init'];
          }
          if (i == 1) {
            return const [];
          }
          return const ['from-second'];
        },
        beforeEachResolve: (i) async {
          if (i == 1) {
            await firstRestartHold.future;
          }
        },
      );
      final container = _sessionContainer(
        fake: fake,
        emptyRetryDelays: _zeroEmptyRetries,
      );
      addTearDown(container.dispose);

      await container.read(browseSessionProvider.future);
      container.read(browseSnapshotCacheProvider.notifier).clear();

      final firstRestart = container
          .read(browseSessionProvider.notifier)
          .restartSession();
      await _yieldUntil(() => fake.resolveCalls >= 2);

      await container.read(browseSessionProvider.notifier).restartSession();
      final afterSecond = container.read(browseSessionProvider).requireValue;
      expect(afterSecond.orderedAssetIds, ['from-second']);

      firstRestartHold.complete();
      await firstRestart;
      await Future<void>.delayed(Duration.zero);

      final afterStale = container.read(browseSessionProvider).requireValue;
      expect(afterStale.orderedAssetIds, ['from-second']);
      expect(afterStale.roundEpoch, afterSecond.roundEpoch);
    },
  );

  test(
    'APP-14.6f in-flight build empty retry does not overwrite restartSession',
    () async {
      final firstBuildHold = Completer<void>();
      final emptyDataIds = <List<String>>[];
      final fake = FakeAssetSourceRepository(
        allIdsForCall: (i) =>
            i == 0 ? const <String>[] : const ['from-restart'],
        beforeEachResolve: (i) async {
          if (i == 0) {
            await firstBuildHold.future;
          }
        },
      );
      final container = _sessionContainer(
        fake: fake,
        emptyRetryDelays: _zeroEmptyRetries,
      );
      addTearDown(container.dispose);

      container.listen<AsyncValue<BrowseSessionView>>(browseSessionProvider, (
        previous,
        next,
      ) {
        final ids = next.asData?.value.orderedAssetIds;
        if (ids != null && ids.isEmpty) {
          emptyDataIds.add(ids);
        }
      }, fireImmediately: true);
      await _yieldUntil(() => fake.resolveCalls >= 1);
      expect(container.read(browseSessionProvider).isLoading, isTrue);

      await container.read(browseSessionProvider.notifier).restartSession();
      final afterRestart = container.read(browseSessionProvider).requireValue;
      expect(afterRestart.orderedAssetIds, ['from-restart']);

      firstBuildHold.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final afterStale = container.read(browseSessionProvider).requireValue;
      expect(afterStale.orderedAssetIds, ['from-restart']);
      expect(emptyDataIds, isEmpty);
    },
  );

  test(
    'U-21.5-1 partial hard-fail with ids caches; empty+hard still not cached',
    () async {
      final fake = FakeAssetSourceRepository(
        photosIds: const ['p1'],
        albumResolveUnauthorized: true,
      );
      final container = _sessionContainer(fake: fake);
      addTearDown(container.dispose);

      final parked = SourcePoolDefinition(
        id: 'partial-cache',
        persistencePolicy: PersistencePolicy.ephemeral,
        orderedSourceReferences: const [
          SourceReference.photos,
          SourceReference(kind: AssetSourceKind.album, id: 'album-x'),
        ],
      );
      container
          .read(browseChromeStateProvider.notifier)
          .debugActivateEphemeralPool(parked);

      final first = await container.read(browseSessionProvider.future);
      expect(first.orderedAssetIds, ['p1']);
      expect(
        first.session.snapshot.sourceStatuses.any(
          (s) => s.availability == AssetSourceAvailability.unauthorized,
        ),
        isTrue,
      );
      expect(fake.resolveCalls, 2);

      container.invalidate(browseSessionProvider);
      final second = await container.read(browseSessionProvider.future);
      expect(fake.resolveCalls, 2, reason: 'non-empty partial must cache');
      expect(second.orderedAssetIds, ['p1']);

      // Empty + hard failure: still never cache (ADR-024).
      fake.photosIds = const [];
      container.read(browseSnapshotCacheProvider.notifier).clear();
      container.invalidate(browseSessionProvider);
      final emptyHard = await container.read(browseSessionProvider.future);
      expect(emptyHard.orderedAssetIds, isEmpty);
      final callsAfterEmpty = fake.resolveCalls;
      container.invalidate(browseSessionProvider);
      await container.read(browseSessionProvider.future);
      expect(fake.resolveCalls, greaterThan(callsAfterEmpty));
    },
  );

  test(
    'U-21.5-2 empty success still retries; hard empty does not (ADR-025 D8)',
    () async {
      final fake = FakeAssetSourceRepository(allIds: const []);
      final container = _sessionContainer(
        fake: fake,
        emptyRetryDelays: _zeroEmptyRetries,
      );
      addTearDown(container.dispose);

      await container.read(browseSessionProvider.future);
      // 1 initial + 3 retries with _zeroEmptyRetries
      expect(fake.resolveCalls, 4);

      final hardFake = FakeAssetSourceRepository(
        resolveException: PlatformException(code: AppError.unauthorized.name),
      );
      final hardContainer = _sessionContainer(
        fake: hardFake,
        emptyRetryDelays: _zeroEmptyRetries,
      );
      addTearDown(hardContainer.dispose);
      await hardContainer.read(browseSessionProvider.future);
      expect(hardFake.resolveCalls, 1);
    },
  );
}
