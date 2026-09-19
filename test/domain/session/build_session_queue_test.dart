import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/session/advance_mode.dart';
import 'package:waketok/domain/session/all_rank_order.dart';
import 'package:waketok/domain/session/build_session_queue.dart';
import 'package:waketok/domain/session/derive_default_session_profile.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/domain/session/repeat_policy.dart';
import 'package:waketok/domain/session/session_configuration.dart';
import 'package:waketok/domain/session/session_queue.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/domain/source/source_resolve_status.dart';

const _newestFirstManualRepeatAll = SessionConfiguration(
  orderPolicy: OrderPolicy.newestFirst,
  advanceMode: AdvanceMode.manual,
  repeatPolicy: RepeatPolicy.repeatAll,
);

const _shuffleManualRepeatAll = SessionConfiguration(
  orderPolicy: OrderPolicy.shuffle,
  advanceMode: AdvanceMode.manual,
  repeatPolicy: RepeatPolicy.repeatAll,
);

ResolvedPoolSnapshot _snapshot({
  required String id,
  required List<String> ids,
}) {
  return ResolvedPoolSnapshot(
    id: id,
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

void main() {
  test('SQ-1 newestFirst non-empty Snapshot preserves coalesced order', () {
    final snap = _snapshot(id: 'pool-a', ids: const ['c', 'a', 'b']);
    final queue = buildSessionQueue(
      snapshot: snap,
      configuration: _newestFirstManualRepeatAll,
    );

    expect(queue.snapshotId, 'pool-a');
    expect(queue.configuration, _newestFirstManualRepeatAll);
    expect(queue.orderedAssetIds, ['c', 'a', 'b']);
    expect(queue.orderedAssetIds.length, snap.coalescedAssetIds.length);
    for (var i = 0; i < queue.orderedAssetIds.length; i++) {
      expect(queue.orderedAssetIds[i], snap.coalescedAssetIds[i]);
    }
  });

  test('SQ-2 newestFirst empty Snapshot → empty Queue', () {
    final snap = _snapshot(id: 'pool-empty', ids: const []);
    final queue = buildSessionQueue(
      snapshot: snap,
      configuration: _newestFirstManualRepeatAll,
    );
    expect(queue.snapshotId, 'pool-empty');
    expect(queue.orderedAssetIds, isEmpty);
  });

  test('SQ-3 orderedAssetIds is unmodifiable', () {
    final queue = buildSessionQueue(
      snapshot: _snapshot(id: 'pool-imm', ids: const ['x']),
      configuration: _newestFirstManualRepeatAll,
    );
    expect(
      () => queue.orderedAssetIds.add('y'),
      throwsUnsupportedError,
    );
  });

  test('SQ-5 Advance/Repeat changes do not alter newestFirst id list', () {
    final snap = _snapshot(id: 'pool-axes', ids: const ['1', '2', '3']);
    const autoStop = SessionConfiguration(
      orderPolicy: OrderPolicy.newestFirst,
      advanceMode: AdvanceMode.auto,
      repeatPolicy: RepeatPolicy.stopAtEnd,
    );
    const autoOne = SessionConfiguration(
      orderPolicy: OrderPolicy.newestFirst,
      advanceMode: AdvanceMode.auto,
      repeatPolicy: RepeatPolicy.repeatOne,
    );

    final q1 = buildSessionQueue(
      snapshot: snap,
      configuration: _newestFirstManualRepeatAll,
    );
    final q2 = buildSessionQueue(snapshot: snap, configuration: autoStop);
    final q3 = buildSessionQueue(snapshot: snap, configuration: autoOne);

    expect(q1.orderedAssetIds, ['1', '2', '3']);
    expect(q2.orderedAssetIds, q1.orderedAssetIds);
    expect(q3.orderedAssetIds, q1.orderedAssetIds);
    expect(q2.configuration, autoStop);
    expect(q3.configuration, autoOne);
  });

  test('SQ-6 SessionQueue equality uses element-wise orderedAssetIds', () {
    const config = _newestFirstManualRepeatAll;
    final a = SessionQueue(
      snapshotId: 'same',
      configuration: config,
      orderedAssetIds: const ['x', 'y'],
    );
    final b = SessionQueue(
      snapshotId: 'same',
      configuration: config,
      orderedAssetIds: const ['x', 'y'],
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);

    final differentIds = SessionQueue(
      snapshotId: 'same',
      configuration: config,
      orderedAssetIds: const ['y', 'x'],
    );
    expect(a, isNot(differentIds));

    final differentSnap = SessionQueue(
      snapshotId: 'other',
      configuration: config,
      orderedAssetIds: const ['x', 'y'],
    );
    expect(a, isNot(differentSnap));
  });

  // --- Cap 13.2 Endless Shuffle (ADR-023 D5) ---

  test(
    'SHUF-1 Shuffle n≥3 fixed seed: exact golden order (permutation + reorder)',
    () {
      // Random(0) Fisher–Yates on [x,y,z] → [z,y,x] (proves shuffle, not
      // identity; identity would also be "a permutation").
      final snap = _snapshot(id: 'pool-shuf1', ids: const ['x', 'y', 'z']);
      final queue = buildSessionQueue(
        snapshot: snap,
        configuration: _shuffleManualRepeatAll,
        random: Random(0),
      );

      expect(queue.orderedAssetIds, ['z', 'y', 'x']);
      expect(
        queue.orderedAssetIds.toSet(),
        snap.coalescedAssetIds.toSet(),
      );
      expect(queue.orderedAssetIds.length, 3);
      expect(queue.orderedAssetIds, isNot(snap.coalescedAssetIds));
    },
  );

  test('SHUF-2 Shuffle empty Snapshot → empty Queue', () {
    final queue = buildSessionQueue(
      snapshot: _snapshot(id: 'pool-shuf-empty', ids: const []),
      configuration: _shuffleManualRepeatAll,
      random: Random(0),
    );
    expect(queue.orderedAssetIds, isEmpty);
  });

  test(
    'SHUF-3 Shuffle n=1 returns sole id; previousRoundLastId does not loop',
    () {
      final snap = _snapshot(id: 'pool-one', ids: const ['only']);
      final queue = buildSessionQueue(
        snapshot: snap,
        configuration: _shuffleManualRepeatAll,
        random: Random(0),
        previousRoundLastId: 'only',
      );
      expect(queue.orderedAssetIds, ['only']);
    },
  );

  test('SHUF-4 Shuffle fixed seed is deterministic (golden)', () {
    final snap = _snapshot(
      id: 'pool-det',
      ids: const ['a', 'b', 'c', 'd', 'e'],
    );
    final q1 = buildSessionQueue(
      snapshot: snap,
      configuration: _shuffleManualRepeatAll,
      random: Random(42),
    );
    final q2 = buildSessionQueue(
      snapshot: snap,
      configuration: _shuffleManualRepeatAll,
      random: Random(42),
    );
    expect(q1.orderedAssetIds, ['d', 'b', 'a', 'e', 'c']);
    expect(q2.orderedAssetIds, q1.orderedAssetIds);
  });

  test('SHUF-5 Advance/Repeat do not alter Shuffle id list (same seed)', () {
    final snap = _snapshot(id: 'pool-axes-s', ids: const ['a', 'b', 'c', 'd']);
    const autoStop = SessionConfiguration(
      orderPolicy: OrderPolicy.shuffle,
      advanceMode: AdvanceMode.auto,
      repeatPolicy: RepeatPolicy.stopAtEnd,
    );
    const autoOne = SessionConfiguration(
      orderPolicy: OrderPolicy.shuffle,
      advanceMode: AdvanceMode.auto,
      repeatPolicy: RepeatPolicy.repeatOne,
    );

    final q1 = buildSessionQueue(
      snapshot: snap,
      configuration: _shuffleManualRepeatAll,
      random: Random(7),
    );
    final q2 = buildSessionQueue(
      snapshot: snap,
      configuration: autoStop,
      random: Random(7),
    );
    final q3 = buildSessionQueue(
      snapshot: snap,
      configuration: autoOne,
      random: Random(7),
    );

    expect(q2.orderedAssetIds, q1.orderedAssetIds);
    expect(q3.orderedAssetIds, q1.orderedAssetIds);
    expect(q2.configuration, autoStop);
    expect(q3.configuration, autoOne);
  });

  test(
    'SHUF-6 previousRoundLastId: retry after first FY would collide',
    () {
      // Same Random(2): without avoid → first round starts with 'c';
      // with previousRoundLastId='c' → builder retries and returns the
      // next round order (public-API premise, not a private FY probe).
      const previousLast = 'c';
      final snap = _snapshot(
        id: 'pool-avoid',
        ids: const ['a', 'b', 'c', 'd', 'e'],
      );

      final without = buildSessionQueue(
        snapshot: snap,
        configuration: _shuffleManualRepeatAll,
        random: Random(2),
      );
      expect(without.orderedAssetIds, ['c', 'a', 'e', 'b', 'd']);

      final withAvoid = buildSessionQueue(
        snapshot: snap,
        configuration: _shuffleManualRepeatAll,
        random: Random(2),
        previousRoundLastId: previousLast,
      );
      expect(withAvoid.orderedAssetIds.first, isNot(previousLast));
      expect(withAvoid.orderedAssetIds, ['a', 'b', 'd', 'c', 'e']);
      expect(
        withAvoid.orderedAssetIds.toSet(),
        snap.coalescedAssetIds.toSet(),
      );
    },
  );

  test(
    'SHUF-7 Mixed deriveDefaultSessionProfile fed to buildSessionQueue succeeds',
    () {
      final def = SourcePoolDefinition(
        id: 'pool-mixed-derive',
        persistencePolicy: PersistencePolicy.ephemeral,
        orderedSourceReferences: const [SourceReference.all],
      );
      final snap = _snapshot(
        id: def.id,
        ids: const ['m1', 'm2', 'm3'],
      );
      final derived = deriveDefaultSessionProfile(
        definition: def,
        snapshot: snap,
      );
      expect(derived.orderPolicy, OrderPolicy.shuffle);

      final queue = buildSessionQueue(
        snapshot: snap,
        configuration: derived,
        random: Random(0),
      );
      expect(queue.configuration.orderPolicy, OrderPolicy.shuffle);
      expect(queue.orderedAssetIds.length, 3);
      expect(queue.orderedAssetIds.toSet(), {'m1', 'm2', 'm3'});
    },
  );

  // --- Cap 27.3 / ADR-056 newestFirst / oldestFirst / All-rank ---

  const oldestFirstManualRepeatAll = SessionConfiguration(
    orderPolicy: OrderPolicy.oldestFirst,
    advanceMode: AdvanceMode.manual,
    repeatPolicy: RepeatPolicy.repeatAll,
  );

  test('SQ-7 single-source oldestFirst is reverse of coalesced', () {
    final snap = _snapshot(id: 'pool-old', ids: const ['c', 'a', 'b']);
    final newest = buildSessionQueue(
      snapshot: snap,
      configuration: _newestFirstManualRepeatAll,
    );
    final oldest = buildSessionQueue(
      snapshot: snap,
      configuration: oldestFirstManualRepeatAll,
    );
    expect(newest.orderedAssetIds, ['c', 'a', 'b']);
    expect(oldest.orderedAssetIds, ['b', 'a', 'c']);
    expect(
      oldest.orderedAssetIds,
      newest.orderedAssetIds.reversed.toList(),
    );
  });

  test('SQ-8 multi-source newestFirst sorts by All rank; oldest reverses', () {
    // All (newest→oldest): a, b, c, d. Working is subset out of All order.
    final ranks = buildAllRankMap(const ['a', 'b', 'c', 'd']);
    final snap = _snapshot(id: 'pool-ms', ids: const ['c', 'a', 'd']);
    final newest = buildSessionQueue(
      snapshot: snap,
      configuration: _newestFirstManualRepeatAll,
      allRanks: ranks,
    );
    final oldest = buildSessionQueue(
      snapshot: snap,
      configuration: oldestFirstManualRepeatAll,
      allRanks: ranks,
    );
    expect(newest.orderedAssetIds, ['a', 'c', 'd']);
    expect(oldest.orderedAssetIds, ['d', 'c', 'a']);
    expect(
      oldest.orderedAssetIds,
      newest.orderedAssetIds.reversed.toList(),
    );
  });

  test('SQ-9 unknown rank ids sort by id and append after known (defensive)', () {
    final ranks = buildAllRankMap(const ['a', 'b']);
    final snap = _snapshot(id: 'pool-unk', ids: const ['z', 'a', 'm', 'b']);
    final newest = buildSessionQueue(
      snapshot: snap,
      configuration: _newestFirstManualRepeatAll,
      allRanks: ranks,
    );
    expect(newest.orderedAssetIds, ['a', 'b', 'm', 'z']);
  });
}
