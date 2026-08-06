import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/source/resolved_source.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';

/// Selected built-in source for Main Browse (All / Photos / Videos).
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

/// Bottom destinations for the Main Browse shell.
enum MainBrowseDestination {
  browse,
  clips,
  auto,
  settings,
}

final mainBrowseDestinationProvider =
    NotifierProvider<MainBrowseDestinationNotifier, MainBrowseDestination>(
  MainBrowseDestinationNotifier.new,
);

class MainBrowseDestinationNotifier extends Notifier<MainBrowseDestination> {
  @override
  MainBrowseDestination build() => MainBrowseDestination.browse;

  void select(MainBrowseDestination next) {
    state = next;
  }
}

/// Cap 7.6: session-scoped successful resolve cache (ADR-014 Decision 5).
///
/// "Session" = this [ProviderContainer] / process lifetime (in-memory only).
/// Failures are never stored. Distinct from kickoff Consumption Session.
final mainBrowseResolveCacheProvider =
    NotifierProvider<MainBrowseResolveCache, Map<String, ResolvedSource>>(
  MainBrowseResolveCache.new,
);

class MainBrowseResolveCache extends Notifier<Map<String, ResolvedSource>> {
  @override
  Map<String, ResolvedSource> build() => const {};

  static String keyFor(SourceReference source) =>
      '${source.kind.name}:${source.id}';

  ResolvedSource? get(SourceReference source) => state[keyFor(source)];

  void put(SourceReference source, ResolvedSource resolved) {
    state = {...state, keyFor(source): resolved};
  }
}

/// Resolve the selected built-in source; reuse session cache on revisit.
final mainBrowseFeedQueueProvider =
    FutureProvider<ResolvedSource>((ref) async {
  final source = ref.watch(mainBrowseSelectedSourceProvider);
  final cache = ref.read(mainBrowseResolveCacheProvider.notifier);
  final hit = cache.get(source);
  if (hit != null) {
    return hit;
  }
  final resolved =
      await ref.read(assetSourceRepositoryProvider).resolve(source);
  cache.put(source, resolved);
  return resolved;
});

/// Current PageView index; resets to 0 when the top source changes (Cap 7.5).
final mainBrowseFeedIndexProvider =
    NotifierProvider<MainBrowseFeedIndex, int>(MainBrowseFeedIndex.new);

class MainBrowseFeedIndex extends Notifier<int> {
  @override
  int build() {
    ref.listen<SourceReference>(mainBrowseSelectedSourceProvider, (prev, next) {
      if (prev != next) {
        state = 0;
      }
    });
    return 0;
  }

  void setIndex(int index) {
    if (index == state) {
      return;
    }
    state = index;
  }

  /// Clamp [feedIndex] into the queue, or ignore when empty (restore safety).
  void applyRestoreIndex(int feedIndex, int queueLength) {
    if (queueLength <= 0) {
      return;
    }
    final clamped = feedIndex.clamp(0, queueLength - 1);
    setIndex(clamped);
  }
}
