import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/session/advance_mode.dart';
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

const _sequentialManualRepeatAll = SessionConfiguration(
  orderPolicy: OrderPolicy.sequential,
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
  test('SQ-1 Sequential non-empty Snapshot preserves coalesced order', () {
    final snap = _snapshot(id: 'pool-a', ids: const ['c', 'a', 'b']);
    final queue = buildSessionQueue(
      snapshot: snap,
      configuration: _sequentialManualRepeatAll,
    );

    expect(queue.snapshotId, 'pool-a');
    expect(queue.configuration, _sequentialManualRepeatAll);
    expect(queue.orderedAssetIds, ['c', 'a', 'b']);
    expect(queue.orderedAssetIds.length, snap.coalescedAssetIds.length);
    for (var i = 0; i < queue.orderedAssetIds.length; i++) {
      expect(queue.orderedAssetIds[i], snap.coalescedAssetIds[i]);
    }
  });

  test('SQ-2 Sequential empty Snapshot → empty Queue', () {
    final snap = _snapshot(id: 'pool-empty', ids: const []);
    final queue = buildSessionQueue(
      snapshot: snap,
      configuration: _sequentialManualRepeatAll,
    );
    expect(queue.snapshotId, 'pool-empty');
    expect(queue.orderedAssetIds, isEmpty);
  });

  test('SQ-3 orderedAssetIds is unmodifiable', () {
    final queue = buildSessionQueue(
      snapshot: _snapshot(id: 'pool-imm', ids: const ['x']),
      configuration: _sequentialManualRepeatAll,
    );
    expect(
      () => queue.orderedAssetIds.add('y'),
      throwsUnsupportedError,
    );
  });

  test('SQ-4 OrderPolicy.shuffle → documented UnsupportedError (ADR-022 D6)',
      () {
    const shuffleConfig = SessionConfiguration(
      orderPolicy: OrderPolicy.shuffle,
      advanceMode: AdvanceMode.manual,
      repeatPolicy: RepeatPolicy.repeatAll,
    );
    final snap = _snapshot(id: 'pool-shuf', ids: const ['a', 'b']);

    expect(
      () => buildSessionQueue(snapshot: snap, configuration: shuffleConfig),
      throwsA(
        isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          allOf(contains('Cap 13'), contains('ADR-022')),
        ),
      ),
    );
  });

  test('SQ-5 Advance/Repeat changes do not alter Sequential id list', () {
    final snap = _snapshot(id: 'pool-axes', ids: const ['1', '2', '3']);
    const autoStop = SessionConfiguration(
      orderPolicy: OrderPolicy.sequential,
      advanceMode: AdvanceMode.auto,
      repeatPolicy: RepeatPolicy.stopAtEnd,
    );
    const autoOne = SessionConfiguration(
      orderPolicy: OrderPolicy.sequential,
      advanceMode: AdvanceMode.auto,
      repeatPolicy: RepeatPolicy.repeatOne,
    );

    final q1 = buildSessionQueue(
      snapshot: snap,
      configuration: _sequentialManualRepeatAll,
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
    const config = _sequentialManualRepeatAll;
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

  test(
    'SQ-7 Mixed deriveDefaultSessionProfile fed to buildSessionQueue refuses',
    () {
      final def = SourcePoolDefinition(
        id: 'pool-mixed-derive',
        persistencePolicy: PersistencePolicy.ephemeral,
        orderedSourceReferences: const [SourceReference.all],
      );
      final snap = _snapshot(
        id: def.id,
        ids: const ['m1', 'm2'],
      );
      final derived = deriveDefaultSessionProfile(
        definition: def,
        snapshot: snap,
      );
      expect(derived.orderPolicy, OrderPolicy.shuffle);

      // Combination gate — do not replace with separate derive / shuffle tests.
      expect(
        () => buildSessionQueue(snapshot: snap, configuration: derived),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            allOf(contains('Cap 13'), contains('ADR-022')),
          ),
        ),
      );
    },
  );
}
