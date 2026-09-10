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

const _sequential = SessionConfiguration(
  orderPolicy: OrderPolicy.sequential,
  advanceMode: AdvanceMode.manual,
  repeatPolicy: RepeatPolicy.repeatAll,
);

ResolvedPoolSnapshot _snap(List<String> ids) {
  return ResolvedPoolSnapshot(
    id: 'snap',
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
    configuration: _sequential,
    initialIndex: index,
  );
}

void main() {
  test('U-24.4-1 mid-list remove at playhead keeps feedIndex; next rises', () {
    final session = _session(const ['a', 'b', 'c'], index: 1);
    final result = removeAssetFromSessionQueue(
      session: session,
      assetId: 'b',
      feedIndex: 1,
    );
    expect(result.removed, isTrue);
    expect(result.session.queue.orderedAssetIds, ['a', 'c']);
    expect(result.feedIndex, 1);
    expect(result.session.currentAssetId, 'c');
    expect(result.session.snapshot.coalescedAssetIds, ['a', 'b', 'c']);
  });

  test('U-24.4-2 remove last item lands on newLength-1 (not 0)', () {
    final session = _session(const ['a', 'b', 'c'], index: 2);
    final result = removeAssetFromSessionQueue(
      session: session,
      assetId: 'c',
      feedIndex: 2,
    );
    expect(result.removed, isTrue);
    expect(result.session.queue.orderedAssetIds, ['a', 'b']);
    expect(result.feedIndex, 1);
    expect(result.session.currentAssetId, 'b');
  });

  test('U-24.4-3 sole item → empty queue; feedIndex 0', () {
    final session = _session(const ['only'], index: 0);
    final result = removeAssetFromSessionQueue(
      session: session,
      assetId: 'only',
      feedIndex: 0,
    );
    expect(result.removed, isTrue);
    expect(result.session.queue.orderedAssetIds, isEmpty);
    expect(result.feedIndex, 0);
    expect(result.session.currentAssetId, isNull);
  });

  test('U-24.4-4 id not in queue → no-op', () {
    final session = _session(const ['a', 'b'], index: 0);
    final result = removeAssetFromSessionQueue(
      session: session,
      assetId: 'missing',
      feedIndex: 0,
    );
    expect(result.removed, isFalse);
    expect(result.session, same(session));
    expect(result.feedIndex, 0);
  });
}
