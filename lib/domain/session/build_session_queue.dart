import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/domain/session/session_configuration.dart';
import 'package:waketok/domain/session/session_queue.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';

/// Builds a finite [SessionQueue] from a Snapshot + Configuration (ADR-022).
///
/// Cap 12 implements [OrderPolicy.sequential] only:
/// `orderedAssetIds == snapshot.coalescedAssetIds` (no re-sort; no
/// segmentIndex Queue-layer step — D4/D5). [OrderPolicy.shuffle] is a
/// documented domain refusal (D6) — Cap 13 Endless Shuffle.
///
/// Advance Mode and Repeat Policy are stored on the queue but do not change
/// the id list (Glossary §11: Queue stays finite).
///
/// **Derive ≠ apply (domain):** feeding
/// `deriveDefaultSessionProfile(...)` (Cap 12 always Mixed → Shuffle) into
/// this builder refuses today (ADR-022 Consequence).
SessionQueue buildSessionQueue({
  required ResolvedPoolSnapshot snapshot,
  required SessionConfiguration configuration,
}) {
  switch (configuration.orderPolicy) {
    case OrderPolicy.sequential:
      return SessionQueue(
        snapshotId: snapshot.id,
        configuration: configuration,
        orderedAssetIds: snapshot.coalescedAssetIds,
      );
    case OrderPolicy.shuffle:
      throw UnsupportedError(
        'OrderPolicy.shuffle Session Queue construction is Cap 13 '
        '(Endless Shuffle); Cap 12 Sequential only (ADR-022 D6).',
      );
  }
}
