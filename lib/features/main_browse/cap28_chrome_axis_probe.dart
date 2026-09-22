import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/features/main_browse/cap25_share_enable_policy.dart';
import 'package:waketok/features/main_browse/cap28_chrome_axis_window.dart';
import 'package:waketok/features/main_browse/cap28_live_probe.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/playback_activation_source.dart';
import 'package:waketok/features/main_browse/pv_transition_guard.dart';

/// Cap 28 settingsResume chrome-axis soak (Profile/Debug).
///
/// Window A: arm on Browse resume latch → log every Riverpod / page-local axis
/// change with `trigger=` + full snapshot → disarm on stable fingerprint +
/// buffer, or hard cap. Does not change product behaviour.
class Cap28ChromeAxisProbe {
  Cap28ChromeAxisProbe._();

  static Cap28ChromeAxisWindow? _window;
  static Timer? _tick;
  static String? _lastLoggedFingerprint;
  static Map<String, Object?> _pageLocal = const {};
  static PlaybackActivationSource _activationSource =
      PlaybackActivationSource.navigation;

  static bool get isArmed => _window?.isArmed ?? false;

  /// Call when Browse becomes active after Settings (resume latch).
  static void armFromResumeLatch({
    required WidgetRef ref,
    required PlaybackActivationSource activationSource,
  }) {
    if (!cap28LiveProbeEnabled) {
      return;
    }
    _activationSource = activationSource;
    _disarmTimersOnly();
    _wasInBuffer = false;
    _pageLocal = const {};
    final window = Cap28ChromeAxisWindow();
    _window = window;
    final snap = snapshot(ref);
    final fp = fingerprintOf(snap);
    window.arm(DateTime.now(), fp);
    _lastLoggedFingerprint = null;
    unawaited(
      Cap28LiveProbe.log('RESUME_WINDOW_ARM', {
        'trigger': 'resumeLatch',
        ...snap,
        'fp': fp,
      }),
    );
    _emitIfNeeded(trigger: 'resumeLatch.baseline', snap: snap, force: true);
    // Widget tests set FLUTTER_TEST — skip periodic Timer (pending-timer
    // invariant). Device/Profile soak still needs the quiet-period tick.
    if (!_runningInFlutterTest) {
      _tick = Timer.periodic(const Duration(milliseconds: 50), (_) {
        _onTick();
      });
    }
  }

  static bool get _runningInFlutterTest {
    // flutter_test sets this env var; Zone declarer covers edge hosts.
    if (Zone.current[#test.declarer] != null) {
      return true;
    }
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  static void setActivationSource(PlaybackActivationSource source) {
    _activationSource = source;
  }

  /// Page-local axes (Meta / loading / surface) — not Riverpod.
  static void notePageLocal({
    required String trigger,
    required Map<String, Object?> fields,
    required WidgetRef ref,
  }) {
    if (!cap28LiveProbeEnabled || !isArmed) {
      return;
    }
    final next = Map<String, Object?>.from(fields);
    if (_mapEquals(_pageLocal, next)) {
      return;
    }
    _pageLocal = next;
    _emitIfNeeded(trigger: trigger, snap: snapshot(ref));
  }

  static bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (final e in a.entries) {
      if (b[e.key] != e.value) {
        return false;
      }
    }
    return true;
  }

  static Map<String, Object?> snapshot(WidgetRef ref) {
    final assetId = ref.read(mainBrowseCurrentAssetIdProvider);
    final covering = assetId != null &&
        assetId.isNotEmpty &&
        ref.read(pvTransitionGuardProvider).isCovering(assetId);
    final actionable = ref.read(mainBrowseCurrentAssetActionableProvider);
    final settled = ref.read(mainBrowseVerticalFeedSettledProvider);
    final coverVisible =
        ref.read(mainBrowseCurrentAssetMediaCoverVisibleProvider);
    final l2Ready =
        ref.read(mainBrowseCurrentAssetLayer2DisplayReadyProvider);
    final liveMotion =
        ref.read(mainBrowseCurrentLiveMotionMountedProvider);
    final share = cap25ShareEnablePredicate(
      actionable: actionable,
      verticalFeedSettled: settled,
      transitionCovering: covering,
      mediaCoverVisible: coverVisible,
      layer2DisplayReady: l2Ready,
      liveMotionMounted: liveMotion,
    );
    final entryOpaque = actionable && coverVisible;
    return {
      'dest': ref.read(mainBrowseDestinationProvider).name,
      'feedIndex': ref.read(mainBrowseFeedIndexProvider),
      'assetId': assetId,
      'activationSource': _activationSource.name,
      'actionable': actionable,
      'settled': settled,
      'covering': covering,
      'coverVisible': coverVisible,
      'l2DisplayReady': l2Ready,
      'liveMotion': liveMotion,
      'shareTap': share.tapEnabled,
      'shareChrome': share.chromeVisible,
      'shareDim': share.dimmed,
      'entryOpaque': entryOpaque,
      'moreOpaque': entryOpaque,
      ..._pageLocal,
    };
  }

  /// Compact fingerprint for stability / bounce metrics (chrome-visible axes).
  static String fingerprintOf(Map<String, Object?> snap) {
    String v(String key) => '${snap[key] ?? '-'}';
    return [
      v('actionable'),
      v('settled'),
      v('covering'),
      v('coverVisible'),
      v('l2DisplayReady'),
      v('liveMotion'),
      v('shareTap'),
      v('entryOpaque'),
      v('metaPaint'),
      v('loading'),
      v('surfaceReady'),
      v('stillCoverReady'),
      v('displayLayer'),
      v('videoSlotMounted'),
      v('posterHold'),
    ].join('|');
  }

  static void onProviderTrigger(String trigger, WidgetRef ref) {
    if (!cap28LiveProbeEnabled || !isArmed) {
      return;
    }
    _emitIfNeeded(trigger: trigger, snap: snapshot(ref));
  }

  static void _emitIfNeeded({
    required String trigger,
    required Map<String, Object?> snap,
    bool force = false,
  }) {
    final window = _window;
    if (window == null || !window.isArmed) {
      return;
    }
    final fp = fingerprintOf(snap);
    final now = DateTime.now();
    if (!force && fp == _lastLoggedFingerprint) {
      // Provider fired but composite chrome fingerprint unchanged — still
      // record trigger so async writers that "fight" without visible change
      // remain visible in the file.
      unawaited(
        Cap28LiveProbe.log('CHROME_AXIS_TOUCH', {
          'trigger': trigger,
          'fp': fp,
          ...snap,
        }),
      );
      window.onEvent(now, fp);
      return;
    }
    if (!window.onEvent(now, fp) && !force) {
      return;
    }
    _lastLoggedFingerprint = fp;
    unawaited(
      Cap28LiveProbe.log('CHROME_AXIS', {
        'trigger': trigger,
        'fp': fp,
        ...snap,
      }),
    );
  }

  static bool _wasInBuffer = false;

  static void _onTick() {
    final window = _window;
    if (window == null || !window.isArmed) {
      _disarmTimersOnly();
      return;
    }
    final beforeBuffer = window.isInBuffer;
    final open = window.tick(DateTime.now());
    if (!beforeBuffer && window.isInBuffer) {
      unawaited(
        Cap28LiveProbe.log('RESUME_WINDOW_STABLE_ENTER', {
          'trigger': 'window.stable',
          ...window.summaryFields(),
          'lastFp': _lastLoggedFingerprint,
        }),
      );
      _wasInBuffer = true;
    }
    if (!open) {
      unawaited(
        Cap28LiveProbe.log('RESUME_WINDOW_DISARM', {
          'trigger': 'window.${window.closeReason}',
          ...window.summaryFields(),
          'lastFp': _lastLoggedFingerprint,
          'sawStableEnter': _wasInBuffer,
        }),
      );
      _wasInBuffer = false;
      _disarmTimersOnly();
    }
  }

  static void forceDisarm({String reason = 'manual'}) {
    final window = _window;
    if (window != null && window.isArmed) {
      unawaited(
        Cap28LiveProbe.log('RESUME_WINDOW_DISARM', {
          'trigger': 'window.$reason',
          ...window.summaryFields(),
          'lastFp': _lastLoggedFingerprint,
        }),
      );
    }
    _window = null;
    _disarmTimersOnly();
  }

  static void _disarmTimersOnly() {
    _tick?.cancel();
    _tick = null;
  }
}

/// Mount under Browse feed: Riverpod axis listeners while the resume window
/// is armed. Zero product UI.
class Cap28ChromeAxisProbeHost extends ConsumerStatefulWidget {
  const Cap28ChromeAxisProbeHost({super.key});

  @override
  ConsumerState<Cap28ChromeAxisProbeHost> createState() =>
      _Cap28ChromeAxisProbeHostState();
}

class _Cap28ChromeAxisProbeHostState
    extends ConsumerState<Cap28ChromeAxisProbeHost> {
  @override
  Widget build(BuildContext context) {
    if (!cap28LiveProbeEnabled) {
      return const SizedBox.shrink();
    }
    ref.listen<bool>(mainBrowseCurrentAssetActionableProvider, (prev, next) {
      if (prev == next) {
        return;
      }
      Cap28ChromeAxisProbe.onProviderTrigger('provider.actionable', ref);
    });
    ref.listen<bool>(mainBrowseVerticalFeedSettledProvider, (prev, next) {
      if (prev == next) {
        return;
      }
      Cap28ChromeAxisProbe.onProviderTrigger('provider.settled', ref);
    });
    ref.listen<bool>(mainBrowseCurrentAssetMediaCoverVisibleProvider,
        (prev, next) {
      if (prev == next) {
        return;
      }
      Cap28ChromeAxisProbe.onProviderTrigger('provider.coverVisible', ref);
    });
    ref.listen<bool>(mainBrowseCurrentAssetLayer2DisplayReadyProvider,
        (prev, next) {
      if (prev == next) {
        return;
      }
      Cap28ChromeAxisProbe.onProviderTrigger('provider.l2DisplayReady', ref);
    });
    ref.listen<bool>(mainBrowseCurrentLiveMotionMountedProvider, (prev, next) {
      if (prev == next) {
        return;
      }
      Cap28ChromeAxisProbe.onProviderTrigger('provider.liveMotion', ref);
    });
    ref.listen<bool>(mainBrowseCurrentAssetHostUnavailableProvider,
        (prev, next) {
      if (prev == next) {
        return;
      }
      Cap28ChromeAxisProbe.onProviderTrigger('provider.hostUnavailable', ref);
    });
    ref.listen<MainBrowseDestination>(mainBrowseDestinationProvider,
        (prev, next) {
      if (prev == next) {
        return;
      }
      Cap28ChromeAxisProbe.onProviderTrigger('provider.dest', ref);
    });
    ref.listen<PvTransitionGuardState>(pvTransitionGuardProvider, (prev, next) {
      if (prev == next) {
        return;
      }
      Cap28ChromeAxisProbe.onProviderTrigger('provider.pvGuard', ref);
    });
    return const SizedBox.shrink();
  }
}
