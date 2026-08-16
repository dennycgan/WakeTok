import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/domain/session/default_session_profile.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';

import '../../library_smoke/fake_asset_source_repository.dart';

void main() {
  test('APP-1 single-source All: coalesce + generalMixed Shuffle config',
      () async {
    final fake = FakeAssetSourceRepository(
      allIds: const ['x', 'y', 'z'],
    );
    final container = ProviderContainer(
      overrides: [
        assetSourceRepositoryProvider.overrideWithValue(fake),
        browseShuffleRandomFactoryProvider.overrideWith((ref) => () => Random(0)),
      ],
    );
    addTearDown(container.dispose);

    final view = await container.read(browseSessionProvider.future);
    expect(view.session.snapshot.coalescedAssetIds, ['x', 'y', 'z']);
    expect(
      view.session.queue.configuration,
      DefaultSessionProfile.generalMixed,
    );
    expect(view.session.queue.configuration.orderPolicy, OrderPolicy.shuffle);
    expect(fake.resolveCalls, 1);
  });

  test('APP-2 Random(0) All ids match SHUF-1 golden', () async {
    final fake = FakeAssetSourceRepository(
      allIds: const ['x', 'y', 'z'],
    );
    final container = ProviderContainer(
      overrides: [
        assetSourceRepositoryProvider.overrideWithValue(fake),
        browseShuffleRandomFactoryProvider.overrideWith((ref) => () => Random(0)),
      ],
    );
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
    final container = ProviderContainer(
      overrides: [
        assetSourceRepositoryProvider.overrideWithValue(fake),
        browseShuffleRandomFactoryProvider.overrideWith(
          (ref) => () => Random(seed),
        ),
      ],
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
  });

  test('APP-4 All→Photos starts independent session', () async {
    final fake = FakeAssetSourceRepository(
      allIds: const ['all-only'],
      photosIds: const ['ph-only'],
    );
    final container = ProviderContainer(
      overrides: [
        assetSourceRepositoryProvider.overrideWithValue(fake),
        browseShuffleRandomFactoryProvider.overrideWith((ref) => () => Random(0)),
      ],
    );
    addTearDown(container.dispose);

    final allView = await container.read(browseSessionProvider.future);
    expect(allView.orderedAssetIds, ['all-only']);

    container.read(mainBrowseSelectedSourceProvider.notifier).select(
          SourceReference.photos,
        );
    final photosView = await container.read(browseSessionProvider.future);
    expect(photosView.orderedAssetIds, ['ph-only']);
    expect(fake.resolveCalls, 2);
  });

  test('APP-5 advanceToNextRound: first ≠ previous last (n>1)', () async {
    final fake = FakeAssetSourceRepository(
      allIds: const ['a', 'b', 'c', 'd', 'e'],
    );
    final container = ProviderContainer(
      overrides: [
        assetSourceRepositoryProvider.overrideWithValue(fake),
        browseShuffleRandomFactoryProvider.overrideWith((ref) => () => Random(0)),
      ],
    );
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

  test('APP-6 empty success is not cached; later resolve can populate',
      () async {
    final fake = FakeAssetSourceRepository(allIds: const []);
    final container = ProviderContainer(
      overrides: [
        assetSourceRepositoryProvider.overrideWithValue(fake),
        browseShuffleRandomFactoryProvider.overrideWith((ref) => () => Random(0)),
      ],
    );
    addTearDown(container.dispose);

    final empty = await container.read(browseSessionProvider.future);
    expect(empty.orderedAssetIds, isEmpty);
    expect(fake.resolveCalls, 1);

    fake.allIds = const ['later'];
    container.invalidate(browseSessionProvider);
    final filled = await container.read(browseSessionProvider.future);
    expect(fake.resolveCalls, 2);
    expect(filled.orderedAssetIds, ['later']);
  });

  test('APP-7 unauthorized maps to empty ids, is not cached', () async {
    final fake = FakeAssetSourceRepository(
      resolveException: PlatformException(code: AppError.unauthorized.name),
    );
    final container = ProviderContainer(
      overrides: [
        assetSourceRepositoryProvider.overrideWithValue(fake),
        browseShuffleRandomFactoryProvider.overrideWith((ref) => () => Random(0)),
      ],
    );
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
      final container = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(fake),
          browseShuffleRandomFactoryProvider.overrideWith(
            (ref) => () => Random(seed),
          ),
        ],
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

      expect(container.read(mainBrowseDestinationProvider),
          MainBrowseDestination.settings);
      expect(container.read(mainBrowseFeedIndexProvider), 0);
      final after = await container.read(browseSessionProvider.future);
      expect(after.roundEpoch, greaterThan(before.roundEpoch));
      expect(after.orderedAssetIds, ['c', 'a', 'e', 'b', 'd']);
      expect(fake.resolveCalls, 1);
    },
  );

  test(
    'APP-8b leave Browse→Clips also resets; Settings→Clips does not reshuffle again',
    () async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a', 'b', 'c', 'd', 'e'],
      );
      var seed = 1;
      final container = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(fake),
          browseShuffleRandomFactoryProvider.overrideWith(
            (ref) => () => Random(seed),
          ),
        ],
      );
      addTearDown(container.dispose);

      final first = await container.read(browseSessionProvider.future);
      seed = 2;
      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.clips);
      final afterClips = await container.read(browseSessionProvider.future);
      expect(afterClips.roundEpoch, greaterThan(first.roundEpoch));
      expect(container.read(mainBrowseFeedIndexProvider), 0);

      final epochAfterLeave = afterClips.roundEpoch;
      final orderAfterLeave = afterClips.orderedAssetIds;
      seed = 3;
      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.settings);
      final afterSettings =
          await container.read(browseSessionProvider.future);
      expect(afterSettings.roundEpoch, epochAfterLeave);
      expect(afterSettings.orderedAssetIds, orderAfterLeave);
      expect(fake.resolveCalls, 1);
    },
  );

  test(
    'APP-8c leave Browse restart maps unmapped throw to AsyncError not stuck Loading',
    () async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a', 'b'],
      );
      final container = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(fake),
          browseShuffleRandomFactoryProvider.overrideWith(
            (ref) => () => Random(0),
          ),
        ],
      );
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
}
