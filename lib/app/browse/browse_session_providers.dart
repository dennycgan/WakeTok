import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_chrome_state.dart';
import 'package:waketok/app/browse/browse_l2_ready_session.dart';
import 'package:waketok/app/browse/browse_live_motion_watchdog.dart';
import 'package:waketok/app/browse/process_soft_deleted_asset_ids.dart';
import 'package:waketok/domain/session/consumption_session.dart';
import 'package:waketok/domain/session/derive_default_session_profile.dart';
import 'package:waketok/domain/session/remove_asset_from_session_queue.dart';
import 'package:waketok/domain/session/session_queue.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/resolve_pool.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';
import 'package:waketok/domain/source/saved_pool_record.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/library_smoke/source_resolve_attempt_mapping.dart';

export 'package:waketok/app/browse/browse_chrome_state.dart';

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
/// has been current for this duration. Cap 17.5 production N = 300 ms
/// (was 500 ms; see docs/acceptance/cap17-17.5-notes.md). Tests override
/// to [Duration.zero] (same pattern as [browseEmptyRetryDelaysProvider]).
final browseLayer2DwellProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 300),
);

/// Cap 15.12: short dwell before Layer 2 on device-local first visit (N_local).
/// Production: 80 ms. Tests override to [Duration.zero] where timing is not
/// under test, or to a positive value for leave-before-dwell cases.
final browseLocalFirstVisitDwellProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 80),
);

/// Cap 21 / ADR-044: Browse chrome authority (`activeOrigin` + parked).
///
/// Composition root (ADR-010 / ADR-023 D9). Session wiring watches this —
/// not a parallel feature-owned store.
final browseChromeStateProvider =
    NotifierProvider<BrowseChromeStateNotifier, BrowseChromeState>(
      BrowseChromeStateNotifier.new,
    );

class BrowseChromeStateNotifier extends Notifier<BrowseChromeState> {
  @override
  BrowseChromeState build() {
    return const BrowseChromeState(
      activeOrigin: BrowseOriginBuiltIn(SourceReference.all),
      parkedEphemeralPool: null,
      lastRememberedBuiltIn: SourceReference.all,
      parkedCompositionLabels: null,
    );
  }

  /// Select a built-in tab. Preserves [BrowseChromeState.parkedEphemeralPool].
  void selectBuiltIn(SourceReference next) {
    // Pools is not a SourceReference — callers must not pass it.
    final current = state.activeOrigin;
    if (current is BrowseOriginBuiltIn && current.source == next) {
      return;
    }
    state = BrowseChromeState(
      activeOrigin: BrowseOriginBuiltIn(next),
      parkedEphemeralPool: state.parkedEphemeralPool,
      lastRememberedBuiltIn: next,
      parkedCompositionLabels: state.parkedCompositionLabels,
    );
  }

  /// Cap 26.4b L2: under Limited, leave Saved origin for [lastRememberedBuiltIn].
  ///
  /// Album/smartAlbum resolve under Limited is unauthorized (ADR-021 D3);
  /// staying on Saved would show resolve-failed + Retry.
  void leaveSavedOriginForLimitedAccess() {
    if (state.activeOrigin is! BrowseOriginSavedPool) {
      return;
    }
    selectBuiltIn(state.lastRememberedBuiltIn);
  }

  /// Cap 21.3 D7: resume parked ephemeral as [activeOrigin] (new Session).
  ///
  /// No-op when [parkedEphemeralPool] is null or already the active ephemeral.
  /// Callers that need composition peek must detect the already-active case
  /// before calling this.
  void resumeParkedEphemeral() {
    final parked = state.parkedEphemeralPool;
    if (parked == null) {
      return;
    }
    final current = state.activeOrigin;
    if (current is BrowseOriginEphemeralPool && current.definition == parked) {
      return;
    }
    state = BrowseChromeState(
      activeOrigin: BrowseOriginEphemeralPool(parked),
      parkedEphemeralPool: parked,
      lastRememberedBuiltIn: state.lastRememberedBuiltIn,
      parkedCompositionLabels: state.parkedCompositionLabels,
    );
  }

  /// Whether [activeOrigin] is the parked ephemeral Definition (chip peek path).
  bool get isParkedEphemeralActive {
    final parked = state.parkedEphemeralPool;
    final current = state.activeOrigin;
    return parked != null &&
        current is BrowseOriginEphemeralPool &&
        current.definition == parked;
  }

  /// Cap 21.4 / ADR-044 D6.1: Start Browsing — replace parked and activate.
  ///
  /// [compositionLabels] must match [definition.orderedSourceReferences]
  /// length when non-null (Cap 21.5 peek name freeze).
  void startEphemeralPool(
    SourcePoolDefinition definition, {
    List<String>? compositionLabels,
  }) {
    if (compositionLabels != null &&
        compositionLabels.length != definition.orderedSourceReferences.length) {
      throw ArgumentError.value(
        compositionLabels.length,
        'compositionLabels.length',
        'must match orderedSourceReferences '
            '(${definition.orderedSourceReferences.length})',
      );
    }
    state = BrowseChromeState(
      activeOrigin: BrowseOriginEphemeralPool(definition),
      parkedEphemeralPool: definition,
      lastRememberedBuiltIn: state.lastRememberedBuiltIn,
      parkedCompositionLabels: compositionLabels == null
          ? null
          : List<String>.unmodifiable(compositionLabels),
    );
  }

  /// Cap 22.3 / ADR-046 D3–D4: activate a Saved preset and clear park.
  void startSavedPool(SavedPoolRecord record) {
    final definition = record.toDefinition();
    state = BrowseChromeState(
      activeOrigin: BrowseOriginSavedPool(
        poolId: record.id,
        definition: definition,
      ),
      parkedEphemeralPool: null,
      lastRememberedBuiltIn: state.lastRememberedBuiltIn,
      parkedCompositionLabels: null,
    );
  }

  /// Cap 22.4 / ADR-046 D7: open from Saved menu — keep park.
  ///
  /// No-op when [record] is already the active Saved origin (caller peeks).
  void openSavedPool(SavedPoolRecord record) {
    final current = state.activeOrigin;
    if (current is BrowseOriginSavedPool && current.poolId == record.id) {
      return;
    }
    state = BrowseChromeState(
      activeOrigin: BrowseOriginSavedPool(
        poolId: record.id,
        definition: record.toDefinition(),
      ),
      parkedEphemeralPool: state.parkedEphemeralPool,
      lastRememberedBuiltIn: state.lastRememberedBuiltIn,
      parkedCompositionLabels: state.parkedCompositionLabels,
    );
  }

  /// Refresh the active Saved recipe snapshot after Rename (same [poolId]).
  void replaceActiveSavedPool(SavedPoolRecord record) {
    final current = state.activeOrigin;
    if (current is! BrowseOriginSavedPool || current.poolId != record.id) {
      return;
    }
    state = BrowseChromeState(
      activeOrigin: BrowseOriginSavedPool(
        poolId: record.id,
        definition: record.toDefinition(),
      ),
      parkedEphemeralPool: state.parkedEphemeralPool,
      lastRememberedBuiltIn: state.lastRememberedBuiltIn,
      parkedCompositionLabels: state.parkedCompositionLabels,
    );
  }

  /// Test injection: set parked without changing [activeOrigin].
  @visibleForTesting
  void debugSetParkedEphemeralPool(SourcePoolDefinition? parked) {
    state = state.copyWithParked(parked);
  }

  /// Test injection: same as [startEphemeralPool] (kept for Cap 21.3 tests).
  @visibleForTesting
  void debugActivateEphemeralPool(
    SourcePoolDefinition definition, {
    List<String>? compositionLabels,
  }) {
    startEphemeralPool(definition, compositionLabels: compositionLabels);
  }
}

/// Built-in projection for Main Browse tabs (All / Photos / Videos).
///
/// Cap 21.2: [build] derives from [browseChromeStateProvider] (owner B);
/// [select] writes chrome only. Not session authority — that is
/// [browseChromeStateProvider].activeOrigin.
final mainBrowseSelectedSourceProvider =
    NotifierProvider<MainBrowseSelectedSource, SourceReference>(
      MainBrowseSelectedSource.new,
    );

class MainBrowseSelectedSource extends Notifier<SourceReference> {
  @override
  SourceReference build() {
    return ref.watch(browseChromeStateProvider).projectedBuiltIn;
  }

  void select(SourceReference next) {
    ref.read(browseChromeStateProvider.notifier).selectBuiltIn(next);
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

  /// Ordered Reference fingerprint (ADR-044 D6.2). Duplicates participate.
  static String keyForRefs(List<SourceReference> ordered) {
    if (ordered.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    for (var i = 0; i < ordered.length; i++) {
      if (i > 0) {
        buffer.write('|');
      }
      final ref = ordered[i];
      buffer
        ..write(ref.kind.name)
        ..write(':')
        ..write(ref.id);
    }
    return buffer.toString();
  }

  /// Single-source key — compatible with Cap 13 callers / tests.
  static String keyFor(SourceReference source) => keyForRefs([source]);

  ResolvedPoolSnapshot? get(SourceReference source) => getForRefs([source]);

  ResolvedPoolSnapshot? getForRefs(List<SourceReference> ordered) =>
      state[keyForRefs(ordered)];

  void put(SourceReference source, ResolvedPoolSnapshot snapshot) {
    putForRefs([source], snapshot);
  }

  void putForRefs(
    List<SourceReference> ordered,
    ResolvedPoolSnapshot snapshot,
  ) {
    state = {...state, keyForRefs(ordered): snapshot};
  }

  void clear() => state = const {};

  /// ADR-048: drop entries whose fingerprint includes [albumId] as an album
  /// ref. Exact segment match (`album:<id>`); does not clear unrelated keys.
  void invalidateEntriesContainingAlbum(String albumId) {
    if (albumId.isEmpty || state.isEmpty) {
      return;
    }
    final needle = 'album:$albumId';
    final next = <String, ResolvedPoolSnapshot>{};
    var removed = false;
    for (final entry in state.entries) {
      final keep = !entry.key.split('|').contains(needle);
      if (keep) {
        next[entry.key] = entry.value;
      } else {
        removed = true;
      }
    }
    if (removed) {
      state = next;
    }
  }
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
/// Watches [browseChromeStateProvider].activeOrigin (ADR-044 D6.1). Each
/// distinct Origin (including built-in revisit) starts a **new** Session on
/// the cached Snapshot (D8). [advanceToNextRound] reshuffles in-place for
/// Endless Repeat All (Cap 22.5 scheme A: placeholder settle / overscroll).
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

  SourcePoolDefinition _definitionFor(BrowseChromeState chrome) {
    return chrome.activeDefinition(forBuiltIn: browsePoolDefinition);
  }

  @override
  Future<BrowseSessionView> build() async {
    final gen = ++_loadGen;
    // Watch Origin only — parked-only updates must not rebuild Session.
    ref.watch(browseChromeStateProvider.select((s) => s.activeOrigin));
    final chrome = ref.read(browseChromeStateProvider);
    final definition = _definitionFor(chrome);
    final snapshot = await _snapshotFor(definition, gen: gen);
    if (!_isCurrentLoad(gen)) {
      return _parkStaleBuild();
    }
    final forSession = _snapshotForNewSession(snapshot);
    final configuration = deriveDefaultSessionProfile(
      definition: definition,
      snapshot: forSession,
    );
    final session = startConsumptionSession(
      snapshot: forSession,
      configuration: configuration,
      random: _random(),
    );
    _roundEpoch += 1;
    return BrowseSessionView(session: session, roundEpoch: _roundEpoch);
  }

  /// Cap 24.4c: filter process soft-deletes for Session start only — never
  /// mutates [browseSnapshotCacheProvider].
  ResolvedPoolSnapshot _snapshotForNewSession(ResolvedPoolSnapshot snapshot) {
    return snapshotExcludingProcessSoftDeletes(
      snapshot: snapshot,
      excluded: ref.read(processSoftDeletedAssetIdsProvider),
    );
  }

  /// Endless Shuffle: reshuffle immediately on the same Snapshot and bump
  /// [BrowseSessionView.roundEpoch] (PageView remount). Cap 22.5 scheme A
  /// calls this after placeholder ScrollEnd settle or true overscroll.
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

  /// Cap 24.4 / ADR-050 D4: remove [assetId] from the in-memory Queue and
  /// return the landing feed index. Does **not** bump [roundEpoch], reshuffle,
  /// or touch [browseSnapshotCacheProvider].
  ///
  /// Returns `null` when no session data is loaded.
  int? removeAssetAndLand({
    required String assetId,
    required int feedIndex,
  }) {
    final current = state.asData?.value;
    if (current == null) {
      return null;
    }
    final result = removeAssetFromSessionQueue(
      session: current.session,
      assetId: assetId,
      feedIndex: feedIndex,
    );
    if (!result.removed) {
      return feedIndex;
    }
    // Cap 24.4c: process-lifetime exclusion for later Session starts.
    ref.read(processSoftDeletedAssetIdsProvider.notifier).add(assetId);
    state = AsyncData(
      BrowseSessionView(
        session: result.session,
        roundEpoch: current.roundEpoch,
      ),
    );
    return result.feedIndex;
  }

  /// Cap 14.4e / ADR-027 strength C: new Consumption Session on the current
  /// Origin (re-Shuffle), bumping [BrowseSessionView.roundEpoch].
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
    ref.read(browseLiveMotionWatchdogSkipIdsProvider.notifier).clear();
    final gen = ++_loadGen;
    final chrome = ref.read(browseChromeStateProvider);
    final definition = _definitionFor(chrome);
    state = const AsyncLoading();
    try {
      final snapshot = await _snapshotFor(definition, gen: gen);
      if (!_isCurrentLoad(gen)) {
        return;
      }
      final forSession = _snapshotForNewSession(snapshot);
      final configuration = deriveDefaultSessionProfile(
        definition: definition,
        snapshot: forSession,
      );
      final session = startConsumptionSession(
        snapshot: forSession,
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
    SourcePoolDefinition definition, {
    required int gen,
  }) async {
    final cache = ref.read(browseSnapshotCacheProvider.notifier);
    final refs = definition.orderedSourceReferences;
    final hit = cache.getForRefs(refs);
    if (hit != null) {
      return hit;
    }

    Future<ResolvedPoolSnapshot> resolveOnce() {
      final repo = ref.read(assetSourceRepositoryProvider);
      return resolvePool(
        definition: definition,
        resolveOne: (reference) => resolveOneFromRepository(repo, reference),
      );
    }

    var snapshot = await resolveOnce();
    _cacheSuccessfulNonEmpty(cache, refs, snapshot);
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
      _cacheSuccessfulNonEmpty(cache, refs, snapshot);
      if (!_isCurrentLoad(gen) || !_shouldRetryEmpty(snapshot)) {
        return snapshot;
      }
    }
    return snapshot;
  }

  void _cacheSuccessfulNonEmpty(
    BrowseSnapshotCache cache,
    List<SourceReference> orderedRefs,
    ResolvedPoolSnapshot snapshot,
  ) {
    // Cap 21.5 / ADR-024: never cache empty coalesced lists. Non-empty may
    // cache even when some sources hard-failed (partial pool still playable).
    // Do **not** gate this on [_hasHardFailure] — that predicate stays only
    // for ADR-025 D8 empty auto-retry via [_shouldRetryEmpty].
    if (snapshot.coalescedAssetIds.isNotEmpty) {
      cache.putForRefs(orderedRefs, snapshot);
    }
  }

  /// True when any source mapped to unauthorized / unavailable.
  ///
  /// Used only by [_shouldRetryEmpty] (ADR-025 D8). Cap 21.5 partial-cache
  /// must not rewrite this predicate.
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
