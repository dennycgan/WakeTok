import 'package:waketok/domain/onboarding/cap30_first_launch_guide_logic.dart';
import 'package:waketok/domain/onboarding/cap30_first_launch_guide_preferences.dart';

/// Cap 30.2 — first-launch `<1>`→`<2>` orchestrator (logic only; no Host UI).
///
/// Mid-chain [onBrowseItemReadyChanged] flipping `true`→`false` is **out of
/// scope / accepted risk** for Cap 30.2: no cancel, pause, or step roll-back.
/// See `docs/acceptance/cap30-30.2-notes.md`.
///
/// [chainArmedThisLaunch] is **process memory only** — never persisted
/// (ADR-060 D6). Durable progress is solely [diskStep] via preferences.
class Cap30FirstLaunchGuideOrchestrator {
  Cap30FirstLaunchGuideOrchestrator(this._preferences);

  final Cap30FirstLaunchGuidePreferences _preferences;

  int _diskStep = 0;
  bool _chainArmedThisLaunch = false;
  bool _hydrated = false;
  bool _browseItemReady = false;
  Cap30GuideChromeKind _activeChrome = Cap30GuideChromeKind.none;
  Future<void> _queue = Future<void>.value();

  int get diskStep => _diskStep;

  bool get chainArmedThisLaunch => _chainArmedThisLaunch;

  Cap30GuideChromeKind get activeChrome => _activeChrome;

  bool get browseItemReady => _browseItemReady;

  Future<void> hydrate() {
    return _enqueue(() async {
      _diskStep = await _preferences.getStep();
      _hydrated = true;
      await _maybeBeginStep();
    });
  }

  /// Injected ready signal for tests / future Host. Production Cap 30.2 does
  /// not attach real Browse ready.
  Future<void> onBrowseItemReadyChanged(bool ready) {
    _browseItemReady = ready;
    return _enqueue(_maybeBeginStep);
  }

  /// `<1>` early end when feed PageView actually changes page (Q2).
  Future<void> notifyVerticalPageChanged() {
    if (_activeChrome != Cap30GuideChromeKind.verticalHint) {
      return Future<void>.value();
    }
    return _enqueue(_completeActiveStepAndAdvance);
  }

  /// Timer / display finished for the active chrome (Q1 — 2.5s).
  Future<void> notifyStepDisplayEnded() {
    if (_activeChrome == Cap30GuideChromeKind.none) {
      return Future<void>.value();
    }
    return _enqueue(_completeActiveStepAndAdvance);
  }

  bool get shouldBlockLeftSwipeGuide => shouldBlockLeftSwipeGuideForCap30(
        diskStep: _diskStep,
        chainArmedThisLaunch: _chainArmedThisLaunch,
      );

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.catchError((Object _) {});
    return result;
  }

  Future<void> _maybeBeginStep() async {
    if (!_hydrated || !_browseItemReady) {
      return;
    }
    if (_activeChrome != Cap30GuideChromeKind.none) {
      return;
    }
    if (_diskStep >= kCap30GuideStepComplete) {
      return;
    }
    if (_diskStep == 0 || _diskStep == 1) {
      await _beginVerticalHint();
      return;
    }
    if (_diskStep == 2) {
      await _beginCreatePoolTip();
    }
  }

  Future<void> _beginVerticalHint() async {
    _chainArmedThisLaunch = true;
    _activeChrome = Cap30GuideChromeKind.verticalHint;
    if (_diskStep != 1) {
      await _preferences.setStep(1);
      _diskStep = 1;
    }
  }

  Future<void> _beginCreatePoolTip() async {
    _chainArmedThisLaunch = true;
    _activeChrome = Cap30GuideChromeKind.createPoolTip;
    if (_diskStep != 2) {
      await _preferences.setStep(2);
      _diskStep = 2;
    }
  }

  Future<void> _completeActiveStepAndAdvance() async {
    final current = _activeChrome;
    if (current == Cap30GuideChromeKind.none) {
      return;
    }
    _activeChrome = Cap30GuideChromeKind.none;
    if (current == Cap30GuideChromeKind.verticalHint) {
      await _beginCreatePoolTip();
      return;
    }
    if (current == Cap30GuideChromeKind.createPoolTip) {
      await _preferences.setStep(kCap30GuideStepComplete);
      _diskStep = kCap30GuideStepComplete;
    }
  }
}
