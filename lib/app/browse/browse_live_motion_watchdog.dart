import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_session_providers.dart'
    show BrowseOrigin, browseChromeStateProvider;

/// Cap 25 / ADR-051 Decision 14: Live motion ended watchdog.
///
/// Armed at `live_mounted_true` (request succeeded, PV mount). Covers:
/// - full motion content ≈ 3s (Live capture ~1.5s before/after key)
/// - surface create + bind + startPlayback ≈ 2s
/// - device/scheduling slack ≈ 1s
const Duration kLiveMotionEndedWatchdog = Duration(seconds: 6);

/// Session-scoped asset ids that hit the Live ended watchdog once.
///
/// Next `_prepareLiveMotion` for these ids skips Host Live (stay still) for
/// the rest of this Consumption Session. Cleared on Session end / Origin
/// change — never persisted across process death.
class BrowseLiveMotionWatchdogSkipIds
    extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.listen<BrowseOrigin>(
      browseChromeStateProvider.select((s) => s.activeOrigin),
      (previous, next) {
        if (previous != null && previous != next) {
          state = const {};
        }
      },
    );
    return const {};
  }

  bool contains(String assetId) => state.contains(assetId);

  void add(String assetId) {
    if (assetId.isEmpty || state.contains(assetId)) {
      return;
    }
    state = {...state, assetId};
  }

  void clear() {
    if (state.isEmpty) {
      return;
    }
    state = const {};
  }
}

final browseLiveMotionWatchdogSkipIdsProvider =
    NotifierProvider<BrowseLiveMotionWatchdogSkipIds, Set<String>>(
      BrowseLiveMotionWatchdogSkipIds.new,
    );
