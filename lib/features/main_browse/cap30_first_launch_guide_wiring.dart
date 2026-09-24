import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/cap30_first_launch_guide_providers.dart';
import 'package:waketok/features/main_browse/cap30_first_launch_guide_orchestrator.dart';

/// **Shared orchestrator instance (hard requirement, Cap 30.3 / ADR-060).**
///
/// For the entire app [ProviderScope] / process lifetime, the Cap 30 `<1>`
/// Host and the Cap 19 left-swipe tip D6 check **must** read this **same**
/// [Cap30FirstLaunchGuideOrchestrator] instance (constructed once from
/// composition-root prefs). `chainArmedThisLaunch` is process memory on
/// that object only — separate instances break D6.
final cap30FirstLaunchGuideOrchestratorProvider =
    Provider<Cap30FirstLaunchGuideOrchestrator>((ref) {
  final prefs = ref.watch(cap30FirstLaunchGuidePreferencesProvider);
  return Cap30FirstLaunchGuideOrchestrator(prefs);
});

/// Cap 30.4 — [GlobalKey] for Create Pool column → `<2>` tip anchor.
///
/// One key per [ProviderScope]. Tip Host must **not** call
/// [syncCap30BrowseReady].
final cap30CreatePoolAnchorKeyProvider = Provider<GlobalKey>((ref) {
  return GlobalKey(debugLabel: 'cap30CreatePoolAnchor');
});

class Cap30FirstLaunchGuideEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Bumped after orchestrator mutations so `<1>` / `<2>` Hosts and Cap 19
/// guide rebuild.
final cap30FirstLaunchGuideEpochProvider =
    NotifierProvider<Cap30FirstLaunchGuideEpochNotifier, int>(
  Cap30FirstLaunchGuideEpochNotifier.new,
);

/// Hydrate + apply browse-ready on the shared orchestrator.
/// Bumps [bumpEpoch] only when orchestrator visible state changes.
Future<void> syncCap30BrowseReady({
  required Cap30FirstLaunchGuideOrchestrator orch,
  required void Function() bumpEpoch,
  required bool ready,
}) async {
  if (await orch.applyBrowseReady(ready)) {
    bumpEpoch();
  }
}
