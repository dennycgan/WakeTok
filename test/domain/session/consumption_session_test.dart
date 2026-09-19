import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/session/advance_mode.dart';
import 'package:waketok/domain/session/consumption_session.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/domain/session/repeat_policy.dart';
import 'package:waketok/domain/session/session_configuration.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';
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
  // --- SESS ---

  test('SESS-1 start Sequential: coalesced order, index 0', () {
    final snap = _snapshot(id: 's1', ids: const ['a', 'b', 'c']);
    final session = startConsumptionSession(
      snapshot: snap,
      configuration: _newestFirstManualRepeatAll,
    );
    expect(session.queue.orderedAssetIds, ['a', 'b', 'c']);
    expect(session.currentIndex, 0);
    expect(session.currentAssetId, 'a');
    expect(session.playbackPositionMs, isNull);
  });

  test('SESS-2 empty Snapshot: empty queue, index 0', () {
    final session = startConsumptionSession(
      snapshot: _snapshot(id: 'empty', ids: const []),
      configuration: _newestFirstManualRepeatAll,
    );
    expect(session.queue.orderedAssetIds, isEmpty);
    expect(session.currentIndex, 0);
    expect(session.currentAssetId, isNull);
  });

  test('SESS-3 slim surface: no Runtime Presentation / Checkpoint fields', () {
    final session = startConsumptionSession(
      snapshot: _snapshot(id: 'slim', ids: const ['x']),
      configuration: _newestFirstManualRepeatAll,
    );
    // Public fields are only snapshot / queue / currentIndex /
    // playbackPositionMs (+ currentAssetId getter).
    expect(session.snapshot, isNotNull);
    expect(session.queue, isNotNull);
    expect(session.currentIndex, 0);
    expect(session.playbackPositionMs, isNull);
  });

  test('SESS-4 equality is element-wise', () {
    final snap = _snapshot(id: 'eq', ids: const ['a', 'b']);
    final a = startConsumptionSession(
      snapshot: snap,
      configuration: _newestFirstManualRepeatAll,
      playbackPositionMs: 12,
    );
    final b = startConsumptionSession(
      snapshot: snap,
      configuration: _newestFirstManualRepeatAll,
      playbackPositionMs: 12,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);

    final differentPos = startConsumptionSession(
      snapshot: snap,
      configuration: _newestFirstManualRepeatAll,
      playbackPositionMs: 99,
    );
    expect(a, isNot(differentPos));
  });

  // --- STAB ---

  test('STAB-1 start freezes Snapshot ids (unmodifiable copy semantics)', () {
    final snap = _snapshot(id: 'freeze', ids: const ['a', 'b', 'c']);
    final session = startConsumptionSession(
      snapshot: snap,
      configuration: _newestFirstManualRepeatAll,
    );
    expect(session.snapshot.coalescedAssetIds, ['a', 'b', 'c']);
    expect(
      () => session.snapshot.coalescedAssetIds.add('z'),
      throwsUnsupportedError,
    );
    expect(
      () => session.queue.orderedAssetIds.add('z'),
      throwsUnsupportedError,
    );
  });

  test(
    'STAB-2 identical config apply is no-op stable (no library-refresh API)',
    () {
      final snap = _snapshot(id: 'stable', ids: const ['a', 'b', 'c']);
      final session = startConsumptionSession(
        snapshot: snap,
        configuration: _newestFirstManualRepeatAll,
        initialIndex: 1,
        playbackPositionMs: 50,
      );
      final applied = applySessionConfiguration(
        session: session,
        newConfiguration: _newestFirstManualRepeatAll,
      );
      expect(identical(applied, session), isTrue);
      expect(applied.queue.orderedAssetIds, ['a', 'b', 'c']);
      expect(applied.currentIndex, 1);
      expect(applied.playbackPositionMs, 50);
    },
  );

  // --- CONT ---

  test(
    'CONT-1 Sequential→Shuffle remaps mid item (fixed seed; not unconditional 0)',
    () {
      // Sequential [a,b,c,d,e], current 'c' at 2.
      // Random(0) shuffle → [e,c,d,b,a], 'c' at 1.
      final snap = _snapshot(
        id: 'cont1',
        ids: const ['a', 'b', 'c', 'd', 'e'],
      );
      final session = startConsumptionSession(
        snapshot: snap,
        configuration: _newestFirstManualRepeatAll,
        initialIndex: 2,
      );
      expect(session.currentAssetId, 'c');
      expect(session.currentIndex, 2);

      final next = applySessionConfiguration(
        session: session,
        newConfiguration: _shuffleManualRepeatAll,
        random: Random(0),
      );
      expect(next.queue.orderedAssetIds, ['e', 'c', 'd', 'b', 'a']);
      expect(next.currentAssetId, 'c');
      expect(next.currentIndex, 1);
      expect(next.currentIndex, isNot(0));
      expect(identical(next.snapshot, session.snapshot), isTrue);
    },
  );

  test('CONT-2 Shuffle→Sequential remaps to coalesced index', () {
    final snap = _snapshot(
      id: 'cont2',
      ids: const ['a', 'b', 'c', 'd', 'e'],
    );
    final shuffled = startConsumptionSession(
      snapshot: snap,
      configuration: _shuffleManualRepeatAll,
      random: Random(0),
      initialIndex: 1, // 'c' in [e,c,d,b,a]
    );
    expect(shuffled.currentAssetId, 'c');
    expect(shuffled.currentIndex, 1);

    final sequential = applySessionConfiguration(
      session: shuffled,
      newConfiguration: _newestFirstManualRepeatAll,
    );
    expect(sequential.queue.orderedAssetIds, ['a', 'b', 'c', 'd', 'e']);
    expect(sequential.currentAssetId, 'c');
    expect(sequential.currentIndex, 2);
  });

  test(
    'CONT-3 Advance/Repeat-only apply keeps ids and index; updates config',
    () {
      final snap = _snapshot(id: 'cont3', ids: const ['a', 'b', 'c']);
      final session = startConsumptionSession(
        snapshot: snap,
        configuration: _newestFirstManualRepeatAll,
        initialIndex: 1,
      );
      const autoOne = SessionConfiguration(
        orderPolicy: OrderPolicy.newestFirst,
        advanceMode: AdvanceMode.auto,
        repeatPolicy: RepeatPolicy.repeatOne,
      );
      final next = applySessionConfiguration(
        session: session,
        newConfiguration: autoOne,
      );
      expect(next.queue.orderedAssetIds, session.queue.orderedAssetIds);
      expect(next.currentIndex, 1);
      expect(next.currentAssetId, 'b');
      expect(next.queue.configuration, autoOne);
      expect(next.queue.configuration, isNot(_newestFirstManualRepeatAll));
    },
  );

  test('CONT-4 Order rebuild preserves playbackPositionMs', () {
    final snap = _snapshot(id: 'cont4', ids: const ['a', 'b', 'c', 'd', 'e']);
    final session = startConsumptionSession(
      snapshot: snap,
      configuration: _newestFirstManualRepeatAll,
      initialIndex: 2,
      playbackPositionMs: 1234,
    );
    final next = applySessionConfiguration(
      session: session,
      newConfiguration: _shuffleManualRepeatAll,
      random: Random(0),
    );
    expect(next.playbackPositionMs, 1234);
    expect(next.currentAssetId, 'c');
  });

  test('CONT-5 tail asset remaps after Order change', () {
    final snap = _snapshot(id: 'cont5', ids: const ['a', 'b', 'c', 'd', 'e']);
    final session = startConsumptionSession(
      snapshot: snap,
      configuration: _newestFirstManualRepeatAll,
      initialIndex: 4, // 'e'
    );
    expect(session.currentAssetId, 'e');

    final next = applySessionConfiguration(
      session: session,
      newConfiguration: _shuffleManualRepeatAll,
      random: Random(0),
    );
    // Random(0) → [e,c,d,b,a]; 'e' at 0.
    expect(next.queue.orderedAssetIds, ['e', 'c', 'd', 'b', 'a']);
    expect(next.currentAssetId, 'e');
    expect(next.currentIndex, 0);
  });

  // --- ROUND (Cap 13.4 Endless) ---

  test('ROUND-1 next Shuffle round: index 0, first ≠ previous last', () {
    final snap = _snapshot(id: 'round1', ids: const ['a', 'b', 'c', 'd', 'e']);
    final session = startConsumptionSession(
      snapshot: snap,
      configuration: _shuffleManualRepeatAll,
      random: Random(0),
    );
    // Random(0) → [e,c,d,b,a]; last = 'a'.
    expect(session.queue.orderedAssetIds, ['e', 'c', 'd', 'b', 'a']);
    expect(session.queue.orderedAssetIds.last, 'a');

    final next = startNextShuffleRound(
      session: session,
      random: Random(1),
    );
    expect(next.currentIndex, 0);
    expect(next.playbackPositionMs, isNull);
    expect(next.snapshot, same(session.snapshot));
    expect(next.queue.orderedAssetIds.toSet(), snap.coalescedAssetIds.toSet());
    expect(next.queue.orderedAssetIds.first, isNot('a'));
    expect(next.queue.orderedAssetIds, isNot(session.queue.orderedAssetIds));
  });

  test('ROUND-2 stopAtEnd does not advance round', () {
    const stop = SessionConfiguration(
      orderPolicy: OrderPolicy.shuffle,
      advanceMode: AdvanceMode.manual,
      repeatPolicy: RepeatPolicy.stopAtEnd,
    );
    final snap = _snapshot(id: 'round2', ids: const ['a', 'b', 'c']);
    final session = startConsumptionSession(
      snapshot: snap,
      configuration: stop,
      random: Random(0),
    );
    final next = startNextShuffleRound(session: session, random: Random(1));
    expect(identical(next, session), isTrue);
  });

  test('ROUND-3 n≤1 is a no-op', () {
    final snap = _snapshot(id: 'round3', ids: const ['only']);
    final session = startConsumptionSession(
      snapshot: snap,
      configuration: _shuffleManualRepeatAll,
      random: Random(0),
    );
    final next = startNextShuffleRound(session: session, random: Random(1));
    expect(identical(next, session), isTrue);
  });

  test('PREP-1 prepareNextRoundQueue does not mutate session; first ≠ last', () {
    final snap = _snapshot(id: 'prep1', ids: const ['a', 'b', 'c', 'd', 'e']);
    final session = startConsumptionSession(
      snapshot: snap,
      configuration: _shuffleManualRepeatAll,
      random: Random(0),
    );
    final beforeIds = List<String>.from(session.queue.orderedAssetIds);
    final prepared = prepareNextRoundQueue(
      session: session,
      random: Random(1),
    );
    expect(prepared, isNotNull);
    expect(session.queue.orderedAssetIds, beforeIds);
    expect(prepared!.orderedAssetIds.first, isNot(beforeIds.last));
    expect(prepared.snapshotId, snap.id);
  });

  test('COMMIT-1 commitPreparedNextRound keeps prepared order (no reshuffle)', () {
    final snap = _snapshot(id: 'commit1', ids: const ['a', 'b', 'c', 'd', 'e']);
    final session = startConsumptionSession(
      snapshot: snap,
      configuration: _shuffleManualRepeatAll,
      random: Random(0),
    );
    final prepared = prepareNextRoundQueue(
      session: session,
      random: Random(1),
    )!;
    final committed = commitPreparedNextRound(
      session: session,
      prepared: prepared,
    );
    expect(committed.currentIndex, 0);
    expect(committed.playbackPositionMs, isNull);
    expect(committed.queue.orderedAssetIds, prepared.orderedAssetIds);
    expect(committed.queue.orderedAssetIds.first, prepared.orderedAssetIds.first);
  });

  test('COMMIT-2 commitPreparedNextRound landingIndex=1', () {
    final snap = _snapshot(id: 'commit2', ids: const ['a', 'b', 'c', 'd', 'e']);
    final session = startConsumptionSession(
      snapshot: snap,
      configuration: _shuffleManualRepeatAll,
      random: Random(0),
    );
    final prepared = prepareNextRoundQueue(
      session: session,
      random: Random(1),
    )!;
    expect(prepared.orderedAssetIds.length, greaterThanOrEqualTo(2));
    final committed = commitPreparedNextRound(
      session: session,
      prepared: prepared,
      currentIndex: 1,
    );
    expect(committed.currentIndex, 1);
    expect(committed.currentAssetId, prepared.orderedAssetIds[1]);
    expect(committed.queue.orderedAssetIds, prepared.orderedAssetIds);
  });
}
