import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_session_providers.dart'
    show
        BrowseOrigin,
        browseChromeStateProvider,
        browseOriginSessionDeltaProvider;

/// Cap 25 / ADR-051 Decision 14 + Cap 26.4b / ADR-052 Decision 4:
/// Live motion ended watchdog.
///
/// Armed when Host `startPlayback` is issued (`_liveStartIssued`), **not**
/// at PV mount / sync `requestLivePhoto` return. Budget covers:
/// - full motion content ≈ 3s (Live capture ~1.5s before/after key)
/// - device/scheduling slack ≈ 3s
/// Prepare / iCloud download / surface bind latency are **outside** this
/// window (must not create a session auto-play skip).
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
