import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_l2_ready_session.dart';
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

final browseShuffleRandomFactoryProvider = Provider<BrowseShuffleRandomFactory>(
  (ref) => Random.new,
);

/// Cap 14.6 / ADR-025 D8: extra waits after a successful empty Snapshot.
///
/// Production: three delays (four resolve attempts including the first).
/// Tests override to `const []` so empty paths keep a single resolve.
final browseEmptyRetryDelaysProvider = Provider<List<Duration>>(
  (ref) => const [
    Duration(milliseconds: 500),
    Duration(milliseconds: 1000),
    Duration(milliseconds: 2000),
  ],
);

/// Cap 16.4 / ADR-029: current-item Layer 2 must not start until the item
/// has been current for this duration. Initial N = 500 ms. Tests override
/// to [Duration.zero] (same pattern as [browseEmptyRetryDelaysProvider]).
final browseLayer2DwellProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 500),
);

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
  const BrowseSessionView({required this.session, required this.roundEpoch});

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

  /// Cap 14.6: one generation for both [build] and [restartSession] loads.
  int _loadGen = 0;

  Random _random() => ref.read(browseShuffleRandomFactoryProvider)();

  bool _isCurrentLoad(int gen) => gen == _loadGen && ref.mounted;

  @override
  Future<BrowseSessionView> build() async {
    final gen = ++_loadGen;
    final source = ref.watch(mainBrowseSelectedSourceProvider);
    final snapshot = await _snapshotFor(source, gen: gen);
    if (!_isCurrentLoad(gen)) {
      return _parkStaleBuild();
    }
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

  /// Cap 14.4e / ADR-027 strength C: new Consumption Session on the current
  /// source (re-Shuffle), bumping [BrowseSessionView.roundEpoch].
  ///
  /// Prefer this over [Ref.invalidate] of [browseSessionProvider]: invalidate
  /// disposes this notifier and resets [_roundEpoch], so the feed PageView
  /// key (`…-r{epoch}`) may not change. Does **not** clear
  /// [browseSnapshotCacheProvider].
  ///
  /// After [AsyncLoading], unexpected throws become [AsyncError] (not a stuck
  /// spinner). [_loadGen] plus [Ref.mounted] guard writes across the async gap
  /// so a superseded restart cannot overwrite a newer load (Cap 14.6).
  Future<void> restartSession() async {
    ref.read(browseL2ReadySessionProvider.notifier).clear();
    final gen = ++_loadGen;
    final source = ref.read(mainBrowseSelectedSourceProvider);
    state = const AsyncLoading();
    try {
      final snapshot = await _snapshotFor(source, gen: gen);
      if (!_isCurrentLoad(gen)) {
        return;
      }
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
      if (!_isCurrentLoad(gen)) {
        return;
      }
      _roundEpoch += 1;
      state = AsyncData(
        BrowseSessionView(session: session, roundEpoch: _roundEpoch),
      );
    } catch (error, stackTrace) {
      if (!_isCurrentLoad(gen)) {
        return;
      }
      state = AsyncError(error, stackTrace);
    }
  }

  /// Riverpod still applies [build]'s return if this Future completes with
  /// data/error while the build subscription is `running` — and a manual
  /// `state =` in [restartSession] does **not** flip that flag (only a
  /// watched-dependency rebuild or invalidate does). Returning a View or
  /// throwing here would overwrite the newer [restartSession] result with
  /// stale empty/error. Parking until dispose is intentional: onDispose
  /// runs after the subscription is cancelled, so the completion is ignored.
  Future<BrowseSessionView> _parkStaleBuild() {
    final done = Completer<BrowseSessionView>();
    if (!ref.mounted) {
      return done.future;
    }
    ref.onDispose(() {
      if (!done.isCompleted) {
        done.completeError(
          StateError('stale browse session build discarded'),
          StackTrace.empty,
        );
      }
    });
    return done.future;
  }

  Future<ResolvedPoolSnapshot> _snapshotFor(
    SourceReference source, {
    required int gen,
  }) async {
    final cache = ref.read(browseSnapshotCacheProvider.notifier);
    final hit = cache.get(source);
    if (hit != null) {
      return hit;
    }

    Future<ResolvedPoolSnapshot> resolveOnce() {
      final repo = ref.read(assetSourceRepositoryProvider);
      final definition = browsePoolDefinition(source);
      return resolvePool(
        definition: definition,
        resolveOne: (reference) => resolveOneFromRepository(repo, reference),
      );
    }

    var snapshot = await resolveOnce();
    _cacheSuccessfulNonEmpty(cache, source, snapshot);
    if (!_isCurrentLoad(gen) || !_shouldRetryEmpty(snapshot)) {
      return snapshot;
    }

    final delays = ref.read(browseEmptyRetryDelaysProvider);
    for (final delay in delays) {
      await Future<void>.delayed(delay);
      if (!_isCurrentLoad(gen)) {
        return snapshot;
      }
      snapshot = await resolveOnce();
      _cacheSuccessfulNonEmpty(cache, source, snapshot);
      if (!_isCurrentLoad(gen) || !_shouldRetryEmpty(snapshot)) {
        return snapshot;
      }
    }
    return snapshot;
  }

  void _cacheSuccessfulNonEmpty(
    BrowseSnapshotCache cache,
    SourceReference source,
    ResolvedPoolSnapshot snapshot,
  ) {
    // ADR-014 D5: cache successes only. Cap 13.8 / ADR-024: do not cache
    // empty coalesced lists or mapped Failed.
    if (!_hasHardFailure(snapshot) && snapshot.coalescedAssetIds.isNotEmpty) {
      cache.put(source, snapshot);
    }
  }

  bool _hasHardFailure(ResolvedPoolSnapshot snapshot) {
    return snapshot.sourceStatuses.any(
      (s) =>
          s.availability == AssetSourceAvailability.unauthorized ||
          s.availability == AssetSourceAvailability.unavailable,
    );
  }

  /// Successful empty → keep resolve-loading and retry. Hard failure and
  /// non-empty are terminal (ADR-025 D8).
  bool _shouldRetryEmpty(ResolvedPoolSnapshot snapshot) {
    return !_hasHardFailure(snapshot) && snapshot.coalescedAssetIds.isEmpty;
  }
}
