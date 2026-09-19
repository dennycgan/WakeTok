import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_session_providers.dart'
    show
        BrowseOrigin,
        browseChromeStateProvider,
        browseOriginSessionDeltaProvider;
import 'package:waketok/domain/playback/playback_models.dart';

/// Cap 15.10: proof that Layer 2 completed for an asset in the current Browse
/// Session. Survives leave-current; cleared on Session end (leave Browse / tab).
enum FeedL2ReadyKind {
  /// Full still [DisplayAsset] ready to show without L1→L2.
  stillFull,

  /// Video L2 succeeded; [cover] is poster for on-screen cover during prepare.
  video,
}

/// Session-scoped L2-ready entry (handles only — not a disk cache).
class FeedL2ReadyEntry {
  const FeedL2ReadyEntry({
    required this.assetIdentifier,
    required this.kind,
    this.cover,
  });

  final String assetIdentifier;
  final FeedL2ReadyKind kind;

  /// Still: full L2 file. Video: poster shown until surface ready.
  final DisplayAsset? cover;
}

/// Per Browse Session map: `localIdentifier → L2-ready proof`.
///
/// Mint on L2 **success** only. Never mint from in-flight / cancelled L2.
/// Token survives leave-current after success; [clear] on Session end.
class BrowseL2ReadySession extends Notifier<Map<String, FeedL2ReadyEntry>> {
  @override
  Map<String, FeedL2ReadyEntry> build() {
    ref.listen<BrowseOrigin>(
      browseChromeStateProvider.select((s) => s.activeOrigin),
      (previous, next) {
        if (previous == null || previous == next) {
          return;
        }
        // ADR-057 D3: shared signal only — no private promote heuristic.
        if (ref.read(browseOriginSessionDeltaProvider).isIdentityPreservingPromote) {
          return;
        }
        state = const {};
      },
    );
    return const {};
  }

  void record(FeedL2ReadyEntry entry) {
    state = {...state, entry.assetIdentifier: entry};
  }

  /// Map lookup only — no disk I/O.
  ///
  /// Called from [MediaFeedPageState.didUpdateWidget]. Must not [existsSync]
  /// (blocks the UI isolate) and must not write [state] (Riverpod).
  FeedL2ReadyEntry? lookup(String assetIdentifier) => state[assetIdentifier];

  /// Cap 15.13 / 15.14: cover-path check for become-current routing.
  ///
  /// Yields one event-loop turn so [didUpdateWidget] / [build] can finish,
  /// then uses [File.existsSync] (await [File.exists] hangs under FakeAsync /
  /// testWidgets). Do not call this from widget lifecycle methods.
  Future<FeedL2ReadyEntry?> lookupIfCoverOnDisk(String assetIdentifier) async {
    final entry = state[assetIdentifier];
    if (entry == null) {
      return null;
    }
    final path = entry.cover?.localFilePath;
    if (path == null) {
      return entry;
    }
    await Future<void>.value();
    if (!_pathExists(path)) {
      final current = state[assetIdentifier];
      if (current?.cover?.localFilePath == path) {
        evict(assetIdentifier);
      }
      return null;
    }
    return state[assetIdentifier];
  }

  void evict(String assetIdentifier) {
    if (!state.containsKey(assetIdentifier)) {
      return;
    }
    final next = Map<String, FeedL2ReadyEntry>.from(state);
    next.remove(assetIdentifier);
    state = next;
  }

  /// Cap 15.13: resume batch — sync path checks with yields between batches
  /// (must not await dart:io under FakeAsync / testWidgets).
  Future<void> evictEntriesWithMissingPathsAsync() async {
    if (state.isEmpty) {
      return;
    }
    const batchSize = 8;
    final stale = <String>[];
    var checked = 0;
    for (final entry in state.entries) {
      final path = entry.value.cover?.localFilePath;
      if (path != null && !_pathExists(path)) {
        stale.add(entry.key);
      }
      checked++;
      if (checked % batchSize == 0) {
        await Future<void>.value();
      }
    }
    if (stale.isEmpty) {
      return;
    }
    final next = Map<String, FeedL2ReadyEntry>.from(state);
    for (final id in stale) {
      next.remove(id);
    }
    state = next;
  }

  void clear() {
    state = const {};
  }

  bool _pathExists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }
}

final browseL2ReadySessionProvider =
    NotifierProvider<BrowseL2ReadySession, Map<String, FeedL2ReadyEntry>>(
      BrowseL2ReadySession.new,
    );
