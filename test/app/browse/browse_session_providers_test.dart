import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/session/default_session_profile.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';

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
}
