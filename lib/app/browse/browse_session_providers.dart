import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/session/consumption_session.dart';
import 'package:waketok/domain/session/derive_default_session_profile.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/resolve_pool.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/library_smoke/source_resolve_attempt_mapping.dart';

/// Creates Shuffle entropy (ADR-023 D5).
///
/// A **factory** (not a cached [Random]) so each Session / round gets a fresh
/// instance. Tests override to `() => Random(seed)`.
typedef BrowseShuffleRandomFactory = Random Function();

final browseShuffleRandomFactoryProvider =
    Provider<BrowseShuffleRandomFactory>((ref) => Random.new);

/// Selected built-in source for Main Browse (All / Photos / Videos).
///
/// Lives at the composition root so session wiring can watch it without a
/// circular `features` ↔ `app` import (Cap 13.4 / ADR-023 D9).
final mainBrowseSelectedSourceProvider =
    NotifierProvider<MainBrowseSelectedSource, SourceReference>(
  MainBrowseSelectedSource.new,
);

class MainBrowseSelectedSource extends Notifier<SourceReference> {
  @override
  SourceReference build() => SourceReference.all;

  void select(SourceReference next) {
    if (next.kind == state.kind && next.id == state.id) {
      return;
    }
    // Pools is not a SourceReference — callers must not pass it.
    state = next;
  }
}

/// Process-lifetime successful Snapshot cache (ADR-014 D5 semantics; Cap 13.4
/// caches [ResolvedPoolSnapshot], not Host resolve order as feed order).
final browseSnapshotCacheProvider =
    NotifierProvider<BrowseSnapshotCache, Map<String, ResolvedPoolSnapshot>>(
  BrowseSnapshotCache.new,
);

class BrowseSnapshotCache extends Notifier<Map<String, ResolvedPoolSnapshot>> {
  @override
  Map<String, ResolvedPoolSnapshot> build() => const {};

  static String keyFor(SourceReference source) =>
      '${source.kind.name}:${source.id}';

  ResolvedPoolSnapshot? get(SourceReference source) => state[keyFor(source)];

  void put(SourceReference source, ResolvedPoolSnapshot snapshot) {
    state = {...state, keyFor(source): snapshot};
  }

  void clear() => state = const {};
}

/// Ephemeral single-source SPD id for a Browse tab (not a Saved Pool).
String browsePoolDefinitionId(SourceReference source) =>
    'browse-${source.kind.name}-${source.id}';

SourcePoolDefinition browsePoolDefinition(SourceReference source) {
  return SourcePoolDefinition(
    id: browsePoolDefinitionId(source),
    persistencePolicy: PersistencePolicy.ephemeral,
    orderedSourceReferences: [source],
  );
}

/// In-memory Browse feed session + round epoch (Cap 13.4).
class BrowseSessionView {
  const BrowseSessionView({
    required this.session,
    required this.roundEpoch,
  });

  final ConsumptionSession session;
  final int roundEpoch;

  List<String> get orderedAssetIds => session.queue.orderedAssetIds;
}

/// Main Browse Consumption Session: Snapshot cache + Shuffle Queue (ADR-023).
///
/// Watches [mainBrowseSelectedSourceProvider]. Each distinct source selection
/// (including revisit after another tab) starts a **new** Session on the
/// cached Snapshot (D8). [advanceToNextRound] reshuffles in-place for Endless.
final browseSessionProvider =
    AsyncNotifierProvider<BrowseSessionNotifier, BrowseSessionView>(
  BrowseSessionNotifier.new,
);

class BrowseSessionNotifier extends AsyncNotifier<BrowseSessionView> {
  int _roundEpoch = 0;

  Random _random() => ref.read(browseShuffleRandomFactoryProvider)();

  @override
  Future<BrowseSessionView> build() async {
    final source = ref.watch(mainBrowseSelectedSourceProvider);
    final snapshot = await _snapshotFor(source);
    final definition = browsePoolDefinition(source);
    final configuration = deriveDefaultSessionProfile(
      definition: definition,
      snapshot: snapshot,
    );
    final session = startConsumptionSession(
      snapshot: snapshot,
      configuration: configuration,
      random: _random(),
    );
    _roundEpoch += 1;
    return BrowseSessionView(session: session, roundEpoch: _roundEpoch);
  }

  /// Endless Shuffle: next round on the same Snapshot (Repeat All).
  void advanceToNextRound() {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    final next = startNextShuffleRound(
      session: current.session,
      random: _random(),
    );
    if (identical(next, current.session)) {
      return;
    }
    _roundEpoch += 1;
    state = AsyncData(
      BrowseSessionView(session: next, roundEpoch: _roundEpoch),
    );
  }

  Future<ResolvedPoolSnapshot> _snapshotFor(SourceReference source) async {
    final cache = ref.read(browseSnapshotCacheProvider.notifier);
    final hit = cache.get(source);
    if (hit != null) {
      return hit;
    }
    final repo = ref.read(assetSourceRepositoryProvider);
    final definition = browsePoolDefinition(source);
    final snapshot = await resolvePool(
      definition: definition,
      resolveOne: (reference) => resolveOneFromRepository(repo, reference),
    );
    // ADR-014 D5: cache successes only. Cap 13.8 narrows that: do not cache
    // empty coalesced lists (Limited first-launch race) or mapped Failed.
    final hasHardFailure = snapshot.sourceStatuses.any(
      (s) =>
          s.availability == AssetSourceAvailability.unauthorized ||
          s.availability == AssetSourceAvailability.unavailable,
    );
    if (!hasHardFailure && snapshot.coalescedAssetIds.isNotEmpty) {
      cache.put(source, snapshot);
    }
    return snapshot;
  }
}
