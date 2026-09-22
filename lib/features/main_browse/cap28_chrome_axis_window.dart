/// Cap 28 chrome-axis probe window (Profile/Debug soak).
///
/// Pure timing state machine — no Flutter/Riverpod. Arms on settingsResume,
/// keeps logging through [stableFor] of unchanged fingerprint, then
/// [bufferAfterStable], and always respects [hardCap] from arm.
class Cap28ChromeAxisWindow {
  Cap28ChromeAxisWindow({
    this.stableFor = const Duration(milliseconds: 500),
    this.bufferAfterStable = const Duration(milliseconds: 750),
    this.hardCap = const Duration(seconds: 3),
    this.crossFrameGap = const Duration(milliseconds: 8),
  });

  final Duration stableFor;
  final Duration bufferAfterStable;
  final Duration hardCap;

  /// Gaps ≥ this between fingerprint changes count as cross-frame.
  final Duration crossFrameGap;

  DateTime? _armedAt;
  String? _lastFingerprint;
  DateTime? _lastChangeAt;
  DateTime? _stableSince;
  bool _inBuffer = false;
  bool _closed = false;
  String? _closeReason;

  final List<String> _orderedCrossFrameFingerprints = <String>[];
  int _bounceCount = 0;
  int _eventCount = 0;
  int _sameFrameBurstCount = 0;

  bool get isArmed => _armedAt != null && !_closed;
  bool get isClosed => _closed;
  bool get isInBuffer => _inBuffer;
  String? get closeReason => _closeReason;
  int get eventCount => _eventCount;
  int get bounceCount => _bounceCount;
  int get sameFrameBurstCount => _sameFrameBurstCount;
  List<String> get orderedCrossFrameFingerprints =>
      List<String>.unmodifiable(_orderedCrossFrameFingerprints);
  int get crossFrameFingerprintCount => _orderedCrossFrameFingerprints.length;

  void arm(DateTime now, String fingerprint) {
    _armedAt = now;
    _lastFingerprint = fingerprint;
    _lastChangeAt = now;
    _stableSince = now;
    _inBuffer = false;
    _closed = false;
    _closeReason = null;
    _orderedCrossFrameFingerprints
      ..clear()
      ..add(fingerprint);
    _bounceCount = 0;
    _eventCount = 0;
    _sameFrameBurstCount = 0;
  }

  /// Record an axis event. Returns whether the window is still open for logging.
  bool onEvent(DateTime now, String fingerprint) {
    if (_armedAt == null || _closed) {
      return false;
    }
    _eventCount++;
    if (fingerprint == _lastFingerprint) {
      return !_closed;
    }

    final gap = _lastChangeAt == null
        ? Duration.zero
        : now.difference(_lastChangeAt!);
    final prev = _lastFingerprint;
    _lastFingerprint = fingerprint;
    _lastChangeAt = now;
    _stableSince = now;

    if (gap >= crossFrameGap) {
      _orderedCrossFrameFingerprints.add(fingerprint);
      _noteBounceIfAny();
    } else if (prev != null) {
      // Same-frame burst: fold into the current frame's painted fingerprint.
      _sameFrameBurstCount++;
      if (_orderedCrossFrameFingerprints.isEmpty) {
        _orderedCrossFrameFingerprints.add(fingerprint);
      } else {
        _orderedCrossFrameFingerprints[
            _orderedCrossFrameFingerprints.length - 1] = fingerprint;
      }
    }

    // Change during buffer keeps logging; stability clock restarts.
    if (_inBuffer) {
      _inBuffer = false;
    }
    return true;
  }

  /// Timer tick — may enter buffer or close. Returns whether still open.
  bool tick(DateTime now) {
    if (_armedAt == null || _closed) {
      return false;
    }
    final sinceArm = now.difference(_armedAt!);
    if (sinceArm >= hardCap) {
      _close('hardCap');
      return false;
    }
    final sinceStable = _stableSince == null
        ? Duration.zero
        : now.difference(_stableSince!);
    if (!_inBuffer) {
      if (sinceStable >= stableFor) {
        _inBuffer = true;
        // Buffer clock starts at the moment stability was reached.
        _stableSince = now;
      }
      return true;
    }
    if (sinceStable >= bufferAfterStable) {
      _close('stable+buf');
      return false;
    }
    return true;
  }

  Map<String, Object?> summaryFields() {
    return {
      'closeReason': _closeReason,
      'eventCount': _eventCount,
      'crossFrameFpCount': crossFrameFingerprintCount,
      'bounceCount': _bounceCount,
      'sameFrameBurstCount': _sameFrameBurstCount,
      'crossFrameFps': _orderedCrossFrameFingerprints.join('>'),
    };
  }

  void _noteBounceIfAny() {
    if (_orderedCrossFrameFingerprints.length < 3) {
      return;
    }
    final n = _orderedCrossFrameFingerprints.length;
    final a = _orderedCrossFrameFingerprints[n - 3];
    final b = _orderedCrossFrameFingerprints[n - 2];
    final c = _orderedCrossFrameFingerprints[n - 1];
    if (a == c && a != b) {
      _bounceCount++;
    }
  }

  void _close(String reason) {
    _closed = true;
    _closeReason = reason;
  }
}
