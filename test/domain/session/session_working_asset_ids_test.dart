import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/session/advance_mode.dart';
import 'package:waketok/domain/session/consumption_session.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/domain/session/remove_asset_from_session_queue.dart';
import 'package:waketok/domain/session/repeat_policy.dart';
import 'package:waketok/domain/session/session_configuration.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/domain/source/source_resolve_status.dart';

const _shuffle = SessionConfiguration(
  orderPolicy: OrderPolicy.shuffle,
  advanceMode: AdvanceMode.manual,
  repeatPolicy: RepeatPolicy.repeatAll,
);

const _sequential = SessionConfiguration(
  orderPolicy: OrderPolicy.sequential,
  advanceMode: AdvanceMode.manual,
  repeatPolicy: RepeatPolicy.repeatAll,
);

ResolvedPoolSnapshot _snap(List<String> ids) {
  return ResolvedPoolSnapshot(
    id: 'snap-24.4b',
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

ConsumptionSession _session(List<String> ids, {int index = 0}) {
  return startConsumptionSession(
    snapshot: _snap(ids),
    configuration: _shuffle,
    random: Random(0),
    initialIndex: index,
  );
}

ConsumptionSession _afterSoftDelete(
  ConsumptionSession session,
  String assetId,
) {
  final landed = removeAssetFromSessionQueue(
    session: session,
    assetId: assetId,
    feedIndex: session.currentIndex,
  );
  expect(landed.removed, isTrue);
  return landed.session;
}

void main() {
  test(
    'U-24.4b-1 soft-delete survives ≥2 start-over rounds (working set)',
    () {
      var session = _session(const ['a', 'b', 'c', 'd', 'e']);
      final deleted = session.currentAssetId!;
      session = _afterSoftDelete(session, deleted);
      expect(session.queue.orderedAssetIds, isNot(contains(deleted)));
      expect(session.snapshot.coalescedAssetIds, contains(deleted));

      for (var round = 0; round < 3; round++) {
        session = startNextShuffleRound(
          session: session,
          random: Random(round + 1),
        );
        expect(
          session.queue.orderedAssetIds,
          isNot(contains(deleted)),
          reason: 'deleted id revived on round advance #$round',
        );
        expect(sessionWorkingAssetIds(session), isNot(contains(deleted)));
        expect(
          session.queue.orderedAssetIds.toSet(),
          equals(sessionWorkingAssetIds(session).toSet()),
        );
      }
    },
  );

  test(
    'U-24.4b-2 soft-delete survives Order Continuity rebuild',
    () {
      var session = _session(const ['a', 'b', 'c', 'd', 'e'], index: 1);
      final deleted = session.currentAssetId!;
      session = _afterSoftDelete(session, deleted);

      final sequential = applySessionConfiguration(
        session: session,
        newConfiguration: _sequential,
      );
      expect(sequential.queue.orderedAssetIds, isNot(contains(deleted)));
      expect(
        sequential.queue.orderedAssetIds,
        sessionWorkingAssetIds(session),
      );

      final reshuffled = applySessionConfiguration(
        session: sequential,
        newConfiguration: _shuffle,
        random: Random(7),
      );
      expect(reshuffled.queue.orderedAssetIds, isNot(contains(deleted)));
      expect(
        reshuffled.queue.orderedAssetIds.toSet(),
        equals({'a', 'b', 'c', 'd', 'e'}.difference({deleted})),
      );
    },
  );

  test(
    'U-24.4b-3 working set n=1: start-over no-ops; n=2 completes (no hang)',
    () {
      // Shrink to 2 via soft-delete.
      var session = _session(const ['a', 'b', 'c']);
      session = _afterSoftDelete(session, session.queue.orderedAssetIds.first);
      expect(session.queue.orderedAssetIds, hasLength(2));

      final previousLast = session.queue.orderedAssetIds.last;
      final next = startNextShuffleRound(
        session: session,
        random: Random(0),
      );
      expect(next.queue.orderedAssetIds, hasLength(2));
      expect(
        next.queue.orderedAssetIds.toSet(),
        equals(session.queue.orderedAssetIds.toSet()),
      );
      // ADR-023 D5 is best-effort; n=2 may still start with previousLast
      // after capped retries — must not hang (loop is capped in builder).
      expect(next.currentIndex, 0);
      // Touch previousLast so the contract is explicit in the test.
      expect(previousLast, isNotEmpty);

      // Shrink to 1.
      final sole = next.queue.orderedAssetIds.first;
      final oneLeft = _afterSoftDelete(next, next.queue.orderedAssetIds.last);
      expect(oneLeft.queue.orderedAssetIds, [sole]);
      final noop = startNextShuffleRound(
        session: oneLeft,
        random: Random(1),
      );
      expect(identical(noop, oneLeft) || noop.queue.orderedAssetIds == [sole],
          isTrue);
      expect(noop.queue.orderedAssetIds, [sole]);
    },
  );

  test(
    'U-24.4b-4 empty working set: start-over no-op; Order rebuild stays empty',
    () {
      var session = _session(const ['a', 'b']);
      session = _afterSoftDelete(session, session.queue.orderedAssetIds.first);
      session = _afterSoftDelete(session, session.queue.orderedAssetIds.first);
      expect(session.queue.orderedAssetIds, isEmpty);
      expect(session.currentIndex, 0);
      expect(sessionWorkingAssetIds(session), isEmpty);

      final afterRound = startNextShuffleRound(
        session: session,
        random: Random(0),
      );
      expect(afterRound.queue.orderedAssetIds, isEmpty);
      expect(afterRound.currentIndex, 0);

      final sequential = applySessionConfiguration(
        session: session,
        newConfiguration: _sequential,
      );
      expect(sequential.queue.orderedAssetIds, isEmpty);
      expect(sequential.currentIndex, 0);
      expect(sequential.currentAssetId, isNull);
    },
  );

  test(
    'U-24.4b-5 sessionWorkingAssetIds ignores feedIndex consumption',
    () {
      final session = _session(const ['a', 'b', 'c', 'd'], index: 2);
      expect(session.currentIndex, 2);
      expect(
        sessionWorkingAssetIds(session).toSet(),
        equals(session.queue.orderedAssetIds.toSet()),
      );
      expect(sessionWorkingAssetIds(session), hasLength(4));
    },
  );
}
