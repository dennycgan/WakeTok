import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/resolve_pool.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/domain/source/source_resolve_attempt.dart';
import 'package:waketok/domain/source/source_resolve_status.dart';

void main() {
  const photos = SourceReference.photos;
  const all = SourceReference.all;
  const albumA = SourceReference(kind: AssetSourceKind.album, id: 'album-a');
  const albumB = SourceReference(kind: AssetSourceKind.album, id: 'album-b');

  SourcePoolDefinition pool(List<SourceReference> refs, {String id = 'p1'}) {
    return SourcePoolDefinition(
      id: id,
      persistencePolicy: PersistencePolicy.ephemeral,
      orderedSourceReferences: refs,
    );
  }

  test('SNAP-1 single available source keeps order and counts', () async {
    final snapshot = await resolvePool(
      definition: pool([photos]),
      resolveOne: (ref) async {
        expect(ref, photos);
        return SourceResolveSuccess(['a', 'b', 'c']);
      },
    );
    expect(snapshot.id, 'p1');
    expect(snapshot.coalescedAssetIds, ['a', 'b', 'c']);
    expect(snapshot.sourceStatuses, [
      const SourceResolveStatus(
        reference: photos,
        availability: AssetSourceAvailability.available,
        rawCount: 3,
        contributedCount: 3,
      ),
    ]);
  });

  test('SNAP-2 overlapping sources coalesce first appearance', () async {
    final snapshot = await resolvePool(
      definition: pool([photos, all]),
      resolveOne: (ref) async {
        if (ref == photos) {
          return SourceResolveSuccess(['a', 'b', 'c']);
        }
        return SourceResolveSuccess(['b', 'c', 'd']);
      },
    );
    expect(snapshot.coalescedAssetIds, ['a', 'b', 'c', 'd']);
    expect(snapshot.sourceStatuses[0].contributedCount, 3);
    expect(snapshot.sourceStatuses[1].rawCount, 3);
    expect(snapshot.sourceStatuses[1].contributedCount, 1);
    expect(
      snapshot.sourceStatuses[1].availability,
      AssetSourceAvailability.available,
    );
  });

  test('SNAP-3 reverse overlap keeps earlier source order', () async {
    final snapshot = await resolvePool(
      definition: pool([all, photos]),
      resolveOne: (ref) async {
        if (ref == all) {
          return SourceResolveSuccess(['b', 'c', 'd']);
        }
        return SourceResolveSuccess(['a', 'b', 'c']);
      },
    );
    expect(snapshot.coalescedAssetIds, ['b', 'c', 'd', 'a']);
    expect(snapshot.sourceStatuses[1].contributedCount, 1);
  });

  test('SNAP-4 later empty source is non-blocking', () async {
    final snapshot = await resolvePool(
      definition: pool([photos, albumA]),
      resolveOne: (ref) async {
        if (ref == photos) {
          return SourceResolveSuccess(['a']);
        }
        return SourceResolveSuccess(const []);
      },
    );
    expect(snapshot.coalescedAssetIds, ['a']);
    expect(
      snapshot.sourceStatuses[1],
      const SourceResolveStatus(
        reference: albumA,
        availability: AssetSourceAvailability.empty,
        rawCount: 0,
        contributedCount: 0,
      ),
    );
  });

  test('SNAP-5 later unauthorized / unavailable is non-blocking', () async {
    final snapshot = await resolvePool(
      definition: pool([photos, albumA, albumB]),
      resolveOne: (ref) async {
        if (ref == photos) {
          return SourceResolveSuccess(['a', 'b']);
        }
        if (ref == albumA) {
          return SourceResolveFailed(AssetSourceAvailability.unauthorized);
        }
        return SourceResolveFailed(AssetSourceAvailability.unavailable);
      },
    );
    expect(snapshot.coalescedAssetIds, ['a', 'b']);
    expect(
      snapshot.sourceStatuses[1].availability,
      AssetSourceAvailability.unauthorized,
    );
    expect(
      snapshot.sourceStatuses[2].availability,
      AssetSourceAvailability.unavailable,
    );
    expect(snapshot.sourceStatuses[1].rawCount, 0);
    expect(snapshot.sourceStatuses[2].contributedCount, 0);
  });

  test('SNAP-6 all empty / all failed returns empty ids without throwing',
      () async {
    final emptyAll = await resolvePool(
      definition: pool([photos, all]),
      resolveOne: (_) async => SourceResolveSuccess(const []),
    );
    expect(emptyAll.coalescedAssetIds, isEmpty);
    expect(
      emptyAll.sourceStatuses.every(
        (s) => s.availability == AssetSourceAvailability.empty,
      ),
      isTrue,
    );

    final failedAll = await resolvePool(
      definition: pool([albumA, albumB]),
      resolveOne: (_) async =>
          SourceResolveFailed(AssetSourceAvailability.unavailable),
    );
    expect(failedAll.coalescedAssetIds, isEmpty);
    expect(
      failedAll.sourceStatuses.every(
        (s) => s.availability == AssetSourceAvailability.unavailable,
      ),
      isTrue,
    );
  });

  test('SNAP-7 empty SPD yields empty snapshot', () async {
    final snapshot = await resolvePool(
      definition: pool(const []),
      resolveOne: (_) async => fail('resolveOne must not run'),
    );
    expect(snapshot.coalescedAssetIds, isEmpty);
    expect(snapshot.sourceStatuses, isEmpty);
  });

  test('SNAP-8 resolveOne runs sequentially (never overlapping)', () async {
    var inFlight = 0;
    var maxInFlight = 0;
    final order = <SourceReference>[];
    await resolvePool(
      definition: pool([photos, all, albumA]),
      resolveOne: (ref) async {
        inFlight += 1;
        if (inFlight > maxInFlight) {
          maxInFlight = inFlight;
        }
        order.add(ref);
        await Future<void>.delayed(Duration.zero);
        inFlight -= 1;
        return SourceResolveSuccess([ref.id]);
      },
    );
    expect(maxInFlight, 1);
    expect(order, [photos, all, albumA]);
  });

  test('SNAP-9 failed source does not contribute ids', () async {
    final snapshot = await resolvePool(
      definition: pool([albumA]),
      resolveOne: (_) async =>
          SourceResolveFailed(AssetSourceAvailability.unauthorized),
    );
    expect(snapshot.coalescedAssetIds, isEmpty);
    expect(snapshot.sourceStatuses.single.rawCount, 0);
  });

  test('SNAP-10 duplicate album ref resolves twice; second contributes 0',
      () async {
    var calls = 0;
    final snapshot = await resolvePool(
      definition: pool([albumA, albumA]),
      resolveOne: (ref) async {
        calls += 1;
        expect(ref, albumA);
        return SourceResolveSuccess(['x', 'y']);
      },
    );
    expect(calls, 2);
    expect(snapshot.coalescedAssetIds, ['x', 'y']);
    expect(snapshot.sourceStatuses[0].contributedCount, 2);
    expect(snapshot.sourceStatuses[1].contributedCount, 0);
    expect(snapshot.sourceStatuses[1].rawCount, 2);
  });

  test('SNAP-11 snapshot retains coalesced ids and status counts only', () {
    final instance = ResolvedPoolSnapshot(
      id: 'p',
      coalescedAssetIds: const ['a'],
      sourceStatuses: const [
        SourceResolveStatus(
          reference: photos,
          availability: AssetSourceAvailability.available,
          rawCount: 1,
          contributedCount: 1,
        ),
      ],
    );
    expect(instance.coalescedAssetIds, ['a']);
    expect(instance.sourceStatuses.single.rawCount, 1);
    expect(instance.sourceStatuses.single.contributedCount, 1);
  });

  test('unexpected resolveOne error is rethrown (D4=A)', () async {
    await expectLater(
      resolvePool(
        definition: pool([photos]),
        resolveOne: (_) async => throw StateError('channel down'),
      ),
      throwsStateError,
    );
  });

  test('SNAP-12 early unauthorized does not skip later success', () async {
    final snapshot = await resolvePool(
      definition: pool([albumA, photos]),
      resolveOne: (ref) async {
        if (ref == albumA) {
          return SourceResolveFailed(AssetSourceAvailability.unauthorized);
        }
        return SourceResolveSuccess(['m', 'n']);
      },
    );
    expect(snapshot.coalescedAssetIds, ['m', 'n']);
    expect(
      snapshot.sourceStatuses[0].availability,
      AssetSourceAvailability.unauthorized,
    );
    expect(
      snapshot.sourceStatuses[1].availability,
      AssetSourceAvailability.available,
    );
    expect(snapshot.sourceStatuses[1].contributedCount, 2);
  });

  test('SourceResolveFailed rejects available / empty', () {
    expect(
      () => SourceResolveFailed(AssetSourceAvailability.available),
      throwsArgumentError,
    );
    expect(
      () => SourceResolveFailed(AssetSourceAvailability.empty),
      throwsArgumentError,
    );
  });
}
