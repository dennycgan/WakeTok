import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_chrome_state.dart';
import 'package:waketok/app/browse/browse_l2_ready_session.dart';
import 'package:waketok/app/browse/browse_live_motion_watchdog.dart';
import 'package:waketok/app/browse/browse_order_preference.dart';
import 'package:waketok/app/browse/browse_origin_session_delta.dart';
import 'package:waketok/app/browse/browse_sticky_feed_data_source_id.dart';
import 'package:waketok/app/browse/process_soft_deleted_asset_ids.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/session/all_rank_order.dart';
import 'package:waketok/domain/session/build_session_queue.dart';
import 'package:waketok/domain/session/consumption_session.dart';
import 'package:waketok/domain/session/derive_default_session_profile.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/domain/session/remove_asset_from_session_queue.dart';
import 'package:waketok/domain/session/repeat_policy.dart';
import 'package:waketok/domain/session/session_configuration.dart';
import 'package:waketok/features/main_browse/cap27_l1_stall_probe.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/resolve_pool.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';
import 'package:waketok/domain/source/saved_pool_record.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/library_smoke/source_resolve_attempt_mapping.dart';

export 'package:waketok/app/browse/browse_chrome_state.dart';
export 'package:waketok/app/browse/browse_order_preference.dart';
export 'package:waketok/app/browse/browse_origin_session_delta.dart';
export 'package:waketok/app/browse/browse_sticky_feed_data_source_id.dart';

/// Creates Shuffle entropy (ADR-023 D5).
///
/// A **factory** (not a cached [Random]) so each Session / round gets a fresh
/// instance. Tests override to `() => Random(seed)`.
typedef BrowseShuffleRandomFactory = Random Function();

final browseShuffleRandomFactoryProvider = Provider<BrowseShuffleRandomFactory>(
  (ref) => Random.new,
);

/// Cap 27 / ADR-056 D10: injectable All-rank map builder (tests override).
typedef BrowseAllRankMapFactory = Map<String, int> Function(List<String> allIds);

final browseAllRankMapFactoryProvider = Provider<BrowseAllRankMapFactory>(
  (ref) => buildAllRankMap,
);

/// Memoized ranks for the cached All Snapshot (same lifetime as that entry).
///
/// `null` when All is missing or empty. Watching [browseSnapshotCacheProvider]
/// drops ranks when All is invalidated (ADR-048 / ADR-056 D10).
final browseAllRankMapProvider = Provider<Map<String, int>?>((ref) {
  final cache = ref.watch(browseSnapshotCacheProvider);
  final snap = cache[BrowseSnapshotCache.keyFor(SourceReference.all)];
  if (snap == null || snap.coalescedAssetIds.isEmpty) {
    return null;
  }
  return ref.watch(browseAllRankMapFactoryProvider)(snap.coalescedAssetIds);
});

/// Cap 27 / ADR-056 D9: at most one in-flight All resolve (prefetch + ranks).
Future<ResolvedPoolSnapshot?>? _allResolveInFlight;

/// Fire-and-forget All Snapshot after Photos authorization settles.
///
/// Put only when successful non-empty (ADR-024). No prefetch-only retry
/// loop. Does not restart Session. Watch from Main Browse shell.
final browseAllPrefetchBinderProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<PhotosAccess>>(
    photosAuthorizationProvider,
    (previous, next) {
      final access = next.asData?.value;
      if (access == PhotosAccess.full || access == PhotosAccess.limited) {
        unawaited(ensureBrowseAllSnapshotCached(ref));
      }
    },
    fireImmediately: true,
  );
});

/// Shared All resolve for prefetch and multi-source rank waits (ADR-056 D9).
Future<ResolvedPoolSnapshot?> ensureBrowseAllSnapshotCached(Ref ref) {
  final key = BrowseSnapshotCache.keyFor(SourceReference.all);
  final hit = ref.read(browseSnapshotCacheProvider)[key];
  if (hit != null && hit.coalescedAssetIds.isNotEmpty) {
    return Future<ResolvedPoolSnapshot?>.value(hit);
  }

  final inFlight = _allResolveInFlight;
  if (inFlight != null) {
    return inFlight;
  }

  final future = _resolveAllOnce(ref);
  _allResolveInFlight = future;
  return future.whenComplete(() {
    if (identical(_allResolveInFlight, future)) {
      _allResolveInFlight = null;
    }
  });
}

Future<ResolvedPoolSnapshot?> _resolveAllOnce(Ref ref) async {
  final definition = browsePoolDefinition(SourceReference.all);
  final repo = ref.read(assetSourceRepositoryProvider);
  try {
    final snapshot = await resolvePool(
      definition: definition,
      resolveOne: (reference) => resolveOneFromRepository(repo, reference),
    );
    if (snapshot.coalescedAssetIds.isNotEmpty) {
      ref
          .read(browseSnapshotCacheProvider.notifier)
          .put(SourceReference.all, snapshot);
    }
    return snapshot;
  } catch (_) {
    // Prefetch must not surface Host/test resolve failures (ADR-056 D9).
    return null;
  }
}

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

/// Cap 27 / ADR-057 Decision 5: effective feed id (sticky ?? origin-derived).
///
/// Kept separate from [browseOriginSessionDeltaProvider] (Decision 3).
final browseEffectiveFeedDataSourceIdProvider = Provider<String>((ref) {
  final sticky = ref.watch(browseStickyFeedDataSourceIdProvider);
  if (sticky != null) {
    return sticky;
  }
  return ref.watch(browseChromeStateProvider).feedDataSourceId;
});

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

  /// ADR-057 D3+D5: real Session boundary — shared signal + clear sticky id.
  ///
  /// Call **before** writing [state] on every Origin path except Temp-peek
  /// promote ([BrowseSessionNotifier.promoteCurrentSessionToSavedPool]).
  void _noteRealSessionBoundary() {
    ref
        .read(browseOriginSessionDeltaProvider.notifier)
        .markRealSessionBoundary();
    ref.read(browseStickyFeedDataSourceIdProvider.notifier).clear();
  }

  /// Select a built-in tab. Preserves [BrowseChromeState.parkedEphemeralPool].
  void selectBuiltIn(SourceReference next) {
    // Pools is not a SourceReference — callers must not pass it.
    final current = state.activeOrigin;
    if (current is BrowseOriginBuiltIn && current.source == next) {
      return;
    }
    _noteRealSessionBoundary();
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
    _noteRealSessionBoundary();
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
    _noteRealSessionBoundary();
    state = BrowseChromeState(
      activeOrigin: BrowseOriginEphemeralPool(definition),
      parkedEphemeralPool: definition,
      lastRememberedBuiltIn: state.lastRememberedBuiltIn,
      parkedCompositionLabels: compositionLabels == null
          ? null
          : List<String>.unmodifiable(compositionLabels),
    );
  }

  /// Cap 22 / ADR-047 D3: Build Save & browse — new Session (not promote).
  void startSavedPool(SavedPoolRecord record) {
    final definition = record.toDefinition();
    _noteRealSessionBoundary();
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

  /// Cap 22.4 / ADR-046 D7: open from Saved menu — keep park; always new Session.
  ///
  /// No-op when [record] is already the active Saved origin (caller peeks).
  /// Must **not** call [BrowseSessionNotifier.promoteCurrentSessionToSavedPool]
  /// even when the recipe matches the current sources.
  void openSavedPool(SavedPoolRecord record) {
    final current = state.activeOrigin;
    if (current is BrowseOriginSavedPool && current.poolId == record.id) {
      return;
    }
    _noteRealSessionBoundary();
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

  /// Chrome-only write for Temp-peek promote (ADR-057). Does **not** mark a
  /// real Session boundary or clear sticky feed id.
  void applyPromoteToSavedPool(SavedPoolRecord record) {
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

  /// Refresh the active Saved recipe snapshot after Rename (same [poolId]).
  void replaceActiveSavedPool(SavedPoolRecord record) {
    final current = state.activeOrigin;
    if (current is! BrowseOriginSavedPool || current.poolId != record.id) {
      return;
    }
    // Same poolId — Origin equality unchanged; not a Session boundary.
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
/// Origin changes are handled **imperatively** (ADR-057): [build] registers a
/// `listen` on [BrowseChromeState.activeOrigin] and reads
/// [browseOriginSessionDeltaProvider]. Identity-preserving promote → no-op
/// (Session [AsyncData] is left untouched — avoids `watch`-driven
/// `isReloading` / PageView teardown). Real Session boundary →
/// [restartSession]. First mount still loads once via [build] (no `watch`
/// required). [advanceToNextRound] reshuffles in-place for Endless Repeat
/// All (Cap 22.5 scheme A).
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
    // Imperative Origin dispatch (ADR-057): do **not** `watch` Origin —
    // a watch rebuild always enters AsyncLoading/isReloading and can tear
    // down PageView even when Decision 1 keeps the Session.
    ref.listen<BrowseOrigin>(
      browseChromeStateProvider.select((s) => s.activeOrigin),
      (previous, next) {
        if (previous == null || previous == next) {
          return;
        }
        // ADR-057 D3: shared signal only — no private promote heuristic.
        if (ref
            .read(browseOriginSessionDeltaProvider)
            .isIdentityPreservingPromote) {
          return;
        }
        unawaited(restartSession());
      },
    );

    final gen = ++_loadGen;
    final chrome = ref.read(browseChromeStateProvider);
    final definition = _definitionFor(chrome);
    final snapshot = await _snapshotFor(definition, gen: gen);
    if (!_isCurrentLoad(gen)) {
      return _parkStaleBuild();
    }
    final forSession = _snapshotForNewSession(snapshot);
    final configuration = _configurationFor(
      definition: definition,
      snapshot: forSession,
    );
    final ranks = await _ranksForOrder(
      definition: definition,
      order: configuration.orderPolicy,
      gen: gen,
    );
    if (!_isCurrentLoad(gen)) {
      return _parkStaleBuild();
    }
    final session = startConsumptionSession(
      snapshot: forSession,
      configuration: configuration,
      random: _random(),
      allRanks: ranks,
    );
    _roundEpoch += 1;
    return BrowseSessionView(session: session, roundEpoch: _roundEpoch);
  }

  /// Cap 27 / ADR-057 D1: sole keep-Session path (Temp peek Save this pool).
  ///
  /// Decision 5 sticky hold and Decision 3 promote mark are applied as
  /// **separate** steps (not one conflated if). Chrome write uses
  /// [BrowseChromeStateNotifier.applyPromoteToSavedPool] only. Session
  /// [state] is intentionally **not** rewritten — the Origin `listen`
  /// no-ops on the shared promote signal, so [AsyncData] stays put.
  void promoteCurrentSessionToSavedPool(SavedPoolRecord record) {
    final chrome = ref.read(browseChromeStateProvider);
    if (chrome.activeOrigin is! BrowseOriginEphemeralPool) {
      throw StateError(
        'promoteCurrentSessionToSavedPool requires active ephemeral Origin',
      );
    }
    if (state.asData?.value == null) {
      throw StateError(
        'promoteCurrentSessionToSavedPool requires a loaded Session',
      );
    }

    // Decision 5 — independent sticky hold (before Origin write).
    final sticky = ref.read(browseStickyFeedDataSourceIdProvider);
    if (sticky == null) {
      ref
          .read(browseStickyFeedDataSourceIdProvider.notifier)
          .hold(chrome.feedDataSourceId);
    }

    // Decision 3 — shared signal before Origin write.
    ref
        .read(browseOriginSessionDeltaProvider.notifier)
        .markIdentityPreservingPromote();

    ref.read(browseChromeStateProvider.notifier).applyPromoteToSavedPool(record);
  }

  /// Cap 24.4c: filter process soft-deletes for Session start only — never
  /// mutates [browseSnapshotCacheProvider].
  ResolvedPoolSnapshot _snapshotForNewSession(ResolvedPoolSnapshot snapshot) {
    return snapshotExcludingProcessSoftDeletes(
      snapshot: snapshot,
      excluded: ref.read(processSoftDeletedAssetIdsProvider),
    );
  }

  /// Cap 27.4 / ADR-055 + ADR-056 D7: confirm order preference.
  ///
  /// Compares against **effective** policy (`preference ?? shuffle`). Same
  /// value → no-op (does not write preference). Changed value → write
  /// preference, rebuild Queue from [sessionWorkingAssetIds] at index 0,
  /// bump [roundEpoch]. Does **not** call [restartSession]: keeps L2-ready
  /// session cache, live-motion watchdog skip ids, sticky feed id, and does
  /// not mark a real Origin Session boundary. Does **not** use
  /// [applySessionConfiguration] Continuity remap.
  ///
  /// Returns `true` when preference/queue were updated; `false` on no-op.
  Future<bool> applyConfirmedOrderPreference(OrderPolicy confirmed) async {
    final preference = ref.read(browseOrderPreferenceProvider);
    final effective = preference ?? OrderPolicy.shuffle;
    if (confirmed == effective) {
      return false;
    }

    ref.read(browseOrderPreferenceProvider.notifier).setPreference(confirmed);

    final current = state.asData?.value;
    if (current == null) {
      // Preference remembered for the next Session that has items (ADR-055 D5).
      return true;
    }

    final session = current.session;
    final oldConfig = session.queue.configuration;
    final newConfig = SessionConfiguration(
      orderPolicy: confirmed,
      advanceMode: oldConfig.advanceMode,
      repeatPolicy: oldConfig.repeatPolicy,
    );

    final chrome = ref.read(browseChromeStateProvider);
    final definition = _definitionFor(chrome);
    // Light path: do not bump [_loadGen] / enter AsyncLoading. Abort rebuild
    // if a real [restartSession] superseded us while ranks were loading.
    final loadGenAtStart = _loadGen;
    final ranks = await _ranksForOrder(
      definition: definition,
      order: confirmed,
      gen: loadGenAtStart,
    );
    if (!ref.mounted || _loadGen != loadGenAtStart) {
      return true;
    }
    final latest = state.asData?.value;
    if (latest == null) {
      return true;
    }

    final newQueue = buildSessionQueue(
      snapshot: latest.session.snapshot,
      configuration: newConfig,
      random: _random(),
      workingAssetIds: sessionWorkingAssetIds(latest.session),
      allRanks: ranks,
    );
    _roundEpoch += 1;
    state = AsyncData(
      BrowseSessionView(
        session: ConsumptionSession(
          snapshot: latest.session.snapshot,
          queue: newQueue,
          currentIndex: 0,
          playbackPositionMs: null,
        ),
        roundEpoch: _roundEpoch,
      ),
    );
    return true;
  }

  /// Endless round advance (ADR-056 D8): shuffle reshuffles; newest/oldest
  /// return to index 0 on the same ordered list. Bumps [roundEpoch].
  void advanceToNextRound() {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    final session = current.session;
    final config = session.queue.configuration;
    if (config.repeatPolicy != RepeatPolicy.repeatAll) {
      return;
    }
    if (session.queue.orderedAssetIds.length <= 1) {
      return;
    }

    final beforeEpoch = current.roundEpoch;
    final headBefore = session.queue.orderedAssetIds.isEmpty
        ? null
        : session.queue.orderedAssetIds.first;
    unawaited(
      Cap27L1StallProbe.log('ADVANCE_TO_NEXT_ROUND_BEGIN', {
        'roundEpoch': beforeEpoch,
        'orderPolicy': config.orderPolicy.name,
        'queueLen': session.queue.orderedAssetIds.length,
        'headId': headBefore,
        'currentIndex': session.currentIndex,
      }),
    );

    if (config.orderPolicy == OrderPolicy.shuffle) {
      final next = startNextShuffleRound(
        session: session,
        random: _random(),
      );
      if (identical(next, session)) {
        return;
      }
      _roundEpoch += 1;
      state = AsyncData(
        BrowseSessionView(session: next, roundEpoch: _roundEpoch),
      );
      unawaited(
        Cap27L1StallProbe.log('ADVANCE_TO_NEXT_ROUND_END', {
          'roundEpoch': _roundEpoch,
          'orderPolicy': config.orderPolicy.name,
          'headId': next.queue.orderedAssetIds.isEmpty
              ? null
              : next.queue.orderedAssetIds.first,
          'path': 'shuffle',
        }),
      );
      return;
    }

    // newestFirst / oldestFirst: same list, land at 0.
    _roundEpoch += 1;
    state = AsyncData(
      BrowseSessionView(
        session: ConsumptionSession(
          snapshot: session.snapshot,
          queue: session.queue,
          currentIndex: 0,
          playbackPositionMs: null,
        ),
        roundEpoch: _roundEpoch,
      ),
    );
    unawaited(
      Cap27L1StallProbe.log('ADVANCE_TO_NEXT_ROUND_END', {
        'roundEpoch': _roundEpoch,
        'orderPolicy': config.orderPolicy.name,
        'headId': headBefore,
        'path': 'same_list_to_0',
      }),
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
    // Real Session boundary on the same Origin (ADR-027 / ADR-057 D5 clear).
    ref
        .read(browseOriginSessionDeltaProvider.notifier)
        .markRealSessionBoundary();
    ref.read(browseStickyFeedDataSourceIdProvider.notifier).clear();
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
      final configuration = _configurationFor(
        definition: definition,
        snapshot: forSession,
      );
      final ranks = await _ranksForOrder(
        definition: definition,
        order: configuration.orderPolicy,
        gen: gen,
      );
      if (!_isCurrentLoad(gen)) {
        return;
      }
      final session = startConsumptionSession(
        snapshot: forSession,
        configuration: configuration,
        random: _random(),
        allRanks: ranks,
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

  SessionConfiguration _configurationFor({
    required SourcePoolDefinition definition,
    required ResolvedPoolSnapshot snapshot,
  }) {
    final derived = deriveDefaultSessionProfile(
      definition: definition,
      snapshot: snapshot,
    );
    final preference = ref.read(browseOrderPreferenceProvider);
    if (preference == null) {
      return derived;
    }
    return SessionConfiguration(
      orderPolicy: preference,
      advanceMode: derived.advanceMode,
      repeatPolicy: derived.repeatPolicy,
    );
  }

  /// All-rank map for multi-source newest/oldest; null for shuffle / single
  /// source / when All is missing (Session falls back to coalesced order).
  Future<Map<String, int>?> _ranksForOrder({
    required SourcePoolDefinition definition,
    required OrderPolicy order,
    required int gen,
  }) async {
    if (order == OrderPolicy.shuffle) {
      return null;
    }
    if (definition.orderedSourceReferences.length <= 1) {
      return null;
    }
    await ensureBrowseAllSnapshotCached(ref);
    if (!_isCurrentLoad(gen)) {
      return null;
    }
    return ref.read(browseAllRankMapProvider);
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
