import 'package:waketok/features/main_browse/main_browse_trailing_chrome_policy.dart';

/// Cap 25 / ADR-051 Decision 14: Share tap-enable axes beyond Decision 8
/// chrome visibility.
///
/// [chromeVisible] is Decision 8 (`actionable ∧ settled ∧ ¬covering`).
/// [tapEnabled] requires current-item Layer-2 display ready and no Live
/// motion mounted — same rule for local decode and iCloud download.
/// Peek / covering hide is owned by the entry icon (shrink), not this dim axis.
class Cap25ShareEnable {
  const Cap25ShareEnable({
    required this.chromeVisible,
    required this.tapEnabled,
  });

  final bool chromeVisible;
  final bool tapEnabled;

  /// Icon shown (settled ∧ ¬covering) but not tappable → Decision 14 dim.
  bool get dimmed => !tapEnabled;
}

/// Pure Decision 14 predicate (no Riverpod).
Cap25ShareEnable cap25ShareEnablePredicate({
  required bool actionable,
  required bool verticalFeedSettled,
  required bool transitionCovering,
  required bool layer2DisplayReady,
  required bool liveMotionMounted,
}) {
  final chromeVisible = mainBrowseTrailingMutationChromeVisible(
    actionable: actionable,
    verticalFeedSettled: verticalFeedSettled,
    transitionCovering: transitionCovering,
  );
  if (!chromeVisible) {
    return const Cap25ShareEnable(chromeVisible: false, tapEnabled: false);
  }

  final tapEnabled = layer2DisplayReady && !liveMotionMounted;
  return Cap25ShareEnable(chromeVisible: true, tapEnabled: tapEnabled);
}
