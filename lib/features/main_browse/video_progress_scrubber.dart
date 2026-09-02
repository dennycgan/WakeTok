import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/scrubber_policy.dart';

typedef ScrubPreviewRequest =
    Future<ScrubPreviewFrame?> Function(double positionSeconds);

/// Cap 18.5 short-video-style progress scrubber + preview bubble
/// (ADR-040 D13 supplement). Cap 19.2b: no drag-begin pause callback.
/// Cap 19.2d: live playhead ghost while dragging; optimistic fill on seek
/// release (cancel may still show ~one Host observe tick of catch-up).
/// Cap 19.8: resident timestamp follows live playhead while dragging and
/// freezes at the pre-release second during seek-hold (fill still optimistic).
///
/// Host null / latency gaps show a solid placeholder only — no user-facing
/// unavailable copy (technical failures are not actionable while scrubbing).
class VideoProgressScrubber extends StatefulWidget {
  const VideoProgressScrubber({
    super.key,
    required this.assetIdentifier,
    required this.frozen,
    required this.runtimeEvents,
    this.onScrubBegin,
    required this.onScrubComplete,
    required this.requestPreview,
  });

  final String assetIdentifier;
  final bool frozen;
  final Stream<PlaybackRuntimeEvent> runtimeEvents;

  /// Optional; Cap 19.2b product path no longer needs drag-begin side effects.
  final VoidCallback? onScrubBegin;
  final void Function(double positionSeconds) onScrubComplete;
  final ScrubPreviewRequest requestPreview;

  @override
  State<VideoProgressScrubber> createState() => _VideoProgressScrubberState();
}

class _VideoProgressScrubberState extends State<VideoProgressScrubber> {
  StreamSubscription<PlaybackRuntimeEvent>? _runtimeSub;
  double _positionSeconds = 0;
  double? _durationSeconds;
  bool _dragging = false;
  double _dragRatio = 0;
  Uint8List? _previewBytes;
  double? _previewBucketSeconds;
  double? _lastRequestedBucketSeconds;
  int _lastPreviewRequestMs = 0;
  int _minPreviewThrottleMs = kScrubPreviewInitialThrottleMs;
  int _slowPreviewStreak = 0;
  bool _previewInFlight = false;
  Uint8List? _lastSuccessfulPreviewBytes;
  double? _lastSuccessfulPreviewBucket;
  int? _lastSuccessfulPreviewAtMs;
  int? _scrubBucketDeltaSign;
  bool _scrubPreviewBorrowDisabled = false;
  /// Set when Host JPEG fails the |requested − actual| drift gate.
  bool _driftRejectForbidBorrow = false;
  Offset? _pointerDown;
  double? _dragAnchorLocalX;
  double _dragAnchorRatio = 0;
  double _hitWidth = 0;

  @override
  void initState() {
    super.initState();
    _bindRuntime();
  }

  @override
  void didUpdateWidget(VideoProgressScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runtimeEvents != widget.runtimeEvents ||
        oldWidget.assetIdentifier != widget.assetIdentifier) {
      _bindRuntime();
    }
    if (widget.frozen && _dragging) {
      _endDrag(commitSeek: false);
    }
  }

  @override
  void dispose() {
    unawaited(_runtimeSub?.cancel());
    super.dispose();
  }

  void _bindRuntime() {
    unawaited(_runtimeSub?.cancel());
    _runtimeSub = widget.runtimeEvents.listen((event) {
      if (event.currentItemIdentifier != widget.assetIdentifier) {
        return;
      }
      // Cap 19.2d: keep updating while dragging so the ghost fill tracks the
      // real playhead. Drag ratio / label / preview keys stay on finger paths.
      // After seek release, hold the optimistic landing until observe catches
      // up (or the hold window expires) so stale ticks cannot flash the bar.
      setState(() {
        _durationSeconds = event.durationSeconds ?? _durationSeconds;
        final incoming = event.playbackPositionSeconds;
        final hold = _seekHoldSeconds;
        if (hold != null) {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final expired =
              _seekHoldUntilMs != null && nowMs >= _seekHoldUntilMs!;
          final settled = scrubberShouldAcceptRuntimeAfterSeekHold(
            incomingSeconds: incoming,
            seekHoldSeconds: hold,
          );
          if (expired || settled) {
            _seekHoldSeconds = null;
            _seekHoldUntilMs = null;
            _residentHoldSeconds = null;
            _positionSeconds = incoming;
          }
          // else: keep optimistic _positionSeconds
        } else {
          _positionSeconds = incoming;
        }
      });
    });
  }

  double? get _effectiveDuration =>
      _durationSeconds != null && _durationSeconds! > 0
      ? _durationSeconds
      : null;

  double get _displayRatio {
    if (_dragging) {
      return _dragRatio.clamp(0.0, 1.0);
    }
    final ratio = scrubberFillRatio(
      positionSeconds: _positionSeconds,
      durationSeconds: _effectiveDuration,
    );
    return ratio ?? 0;
  }

  /// Live playhead ratio for Cap 19.2d ghost (independent of drag fill).
  double get _livePlayheadRatio {
    return scrubberFillRatio(
          positionSeconds: _positionSeconds,
          durationSeconds: _effectiveDuration,
        ) ??
        0;
  }

  double get _displaySeconds {
    final duration = _effectiveDuration;
    if (duration != null && duration > 0) {
      return (_displayRatio * duration).clamp(0, duration);
    }
    return _positionSeconds;
  }

  /// Rounded whole-second label during drag; matches [scrubberSeekSeconds].
  double get _labelSeconds {
    final duration = _effectiveDuration;
    if (_dragging && duration != null && duration > 0) {
      return scrubberSeekSeconds(
        ratio: _dragRatio,
        durationSeconds: duration,
      ).toDouble();
    }
    return _dragging ? _displaySeconds : _positionSeconds;
  }

  bool _dragCommitted = false;
  /// After scrub seek release, ignore Host observe until it nears this second
  /// (stale playhead ticks would otherwise flash the pre-seek fill).
  double? _seekHoldSeconds;
  int? _seekHoldUntilMs;
  /// Cap 19.8: last confirmed live second before optimistic seek landing —
  /// resident label stays on this until seek-hold settles.
  double? _residentHoldSeconds;

  void _onHorizontalDragStart(DragStartDetails details) {
    if (widget.frozen) {
      return;
    }
    _dragCommitted = false;
    final anchorRatio = scrubberFillRatio(
          positionSeconds: _positionSeconds,
          durationSeconds: _effectiveDuration,
        ) ??
        0;
    setState(() {
      _dragging = true;
      _seekHoldSeconds = null;
      _seekHoldUntilMs = null;
      _residentHoldSeconds = null;
      _dragAnchorLocalX = details.localPosition.dx;
      _dragAnchorRatio = anchorRatio;
      _dragRatio = anchorRatio;
      _resetPreviewSession();
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_dragging || widget.frozen) {
      return;
    }
    if (!_dragCommitted) {
      _dragCommitted = true;
      widget.onScrubBegin?.call();
    }
    final previousRequest = _previewRequestKeyForRatio(_dragRatio);
    final nextRatio = _dragRatioFromDrag(details.localPosition.dx);
    final nextRequest = _previewRequestKeyForRatio(nextRatio);
    // Direction sign only on mid-path whole-second keys (skip end-cap ε).
    if (scrubPreviewIsWholeSecondKey(previousRequest) &&
        scrubPreviewIsWholeSecondKey(nextRequest) &&
        nextRequest != previousRequest) {
      final delta = nextRequest - previousRequest;
      final sign = delta > 0 ? 1 : -1;
      if (_scrubBucketDeltaSign != null && sign != _scrubBucketDeltaSign) {
        _scrubPreviewBorrowDisabled = true;
      }
      _scrubBucketDeltaSign = sign;
    }
    final requestChanged =
        _previewBucketSeconds != null && _previewBucketSeconds != nextRequest;
    setState(() {
      _dragRatio = nextRatio;
      if (requestChanged) {
        _clearCurrentPreviewFrame();
      }
    });
    if (_dragCommitted) {
      _maybeRequestPreview(force: false);
    }
  }

  double _secondsForRatio(double ratio) {
    final duration = _effectiveDuration;
    if (duration != null && duration > 0) {
      return (ratio.clamp(0.0, 1.0) * duration).clamp(0, duration);
    }
    return _positionSeconds;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_dragging) {
      return;
    }
    _endDrag(commitSeek: true);
  }

  void _onHorizontalDragCancel() {
    if (!_dragging) {
      return;
    }
    _endDrag(commitSeek: false);
  }

  void _endDrag({required bool commitSeek}) {
    final duration = _effectiveDuration;
    final seconds = duration != null && duration > 0
        ? scrubberSeekSeconds(ratio: _dragRatio, durationSeconds: duration)
            .toDouble()
        : _positionSeconds;
    final shouldSeek = commitSeek && _dragCommitted;
    setState(() {
      // Cap 19.2d: optimistic playhead + seek-hold before clearing drag so
      // (1) the first non-drag frame paints the landing and (2) stale Host
      // observe ticks (still at the old playhead until seek applies) cannot
      // flash the fill back. Cancel / uncommitted end does not hold — fill
      // follows latest live; residual ~one Host tick (~250ms) is accepted.
      if (shouldSeek) {
        // Cap 19.8: snapshot live playhead for resident label before fill
        // optimism — label must not jump to the seek target until settled.
        _residentHoldSeconds = _positionSeconds;
        _positionSeconds = seconds;
        _seekHoldSeconds = seconds;
        _seekHoldUntilMs =
            DateTime.now().millisecondsSinceEpoch + 1200;
      }
      _dragging = false;
      _dragCommitted = false;
      _dragAnchorLocalX = null;
      _previewBytes = null;
      _previewBucketSeconds = null;
      _previewInFlight = false;
      _lastSuccessfulPreviewBytes = null;
      _lastSuccessfulPreviewBucket = null;
      _lastSuccessfulPreviewAtMs = null;
      _scrubBucketDeltaSign = null;
      _scrubPreviewBorrowDisabled = false;
      _driftRejectForbidBorrow = false;
    });
    if (shouldSeek) {
      widget.onScrubComplete(seconds);
    }
  }

  void _resetPreviewSession() {
    _previewBytes = null;
    _previewBucketSeconds = null;
    _lastSuccessfulPreviewBytes = null;
    _lastSuccessfulPreviewBucket = null;
    _lastSuccessfulPreviewAtMs = null;
    _scrubBucketDeltaSign = null;
    _scrubPreviewBorrowDisabled = false;
    _driftRejectForbidBorrow = false;
  }

  void _clearCurrentPreviewFrame() {
    _previewBytes = null;
    _previewBucketSeconds = null;
  }

  void _recordSuccessfulPreview({
    required Uint8List bytes,
    required double bucketSeconds,
    required int capturedAtMs,
  }) {
    _previewBytes = bytes;
    _lastSuccessfulPreviewBytes = bytes;
    _lastSuccessfulPreviewBucket = bucketSeconds;
    _lastSuccessfulPreviewAtMs = capturedAtMs;
  }

  Uint8List? _bubbleDisplayBytes(int nowMs) {
    final duration = _effectiveDuration;
    final requestKey = _previewRequestKey();
    final endCap = duration != null &&
        duration > 0 &&
        scrubPreviewIsEndCap(
          displaySeconds: _displaySeconds,
          durationSeconds: duration,
        );
    return scrubPreviewDisplayBytes(
      currentBucketBytes: _previewBytes,
      borrowSourceBytes: _lastSuccessfulPreviewBytes,
      currentBucketSeconds: requestKey,
      borrowSourceBucketSeconds: _lastSuccessfulPreviewBucket,
      nowMs: nowMs,
      borrowSourceCapturedAtMs: _lastSuccessfulPreviewAtMs,
      scrubDirectionReversed: _scrubPreviewBorrowDisabled,
      forbidBorrow: endCap || _driftRejectForbidBorrow,
    );
  }

  double _dragRatioFromDrag(double currentLocalX) {
    final anchorX = _dragAnchorLocalX;
    if (anchorX == null || _hitWidth <= 0) {
      return _dragRatio;
    }
    return scrubberDragRatio(
      anchorRatio: _dragAnchorRatio,
      anchorLocalX: anchorX,
      currentLocalX: currentLocalX,
      hitWidth: _hitWidth,
    );
  }

  double _previewRequestKeyForRatio(double ratio) {
    final duration = _effectiveDuration;
    if (duration != null && duration > 0) {
      return scrubPreviewRequestSeconds(
        displaySeconds: _secondsForRatio(ratio),
        durationSeconds: duration,
      );
    }
    return scrubPreviewFallbackSeconds(_secondsForRatio(ratio));
  }

  double _previewRequestKey() {
    final duration = _effectiveDuration;
    if (duration != null && duration > 0) {
      return scrubPreviewRequestSeconds(
        displaySeconds: _displaySeconds,
        durationSeconds: duration,
      );
    }
    return scrubPreviewFallbackSeconds(_displaySeconds);
  }

  void _maybeRequestPreview({required bool force}) {
    final requestKey = _previewRequestKey();
    if (_previewInFlight) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!force &&
        !scrubPreviewShouldRequest(
          nowMs: nowMs,
          lastRequestStartedMs: _lastPreviewRequestMs,
          minRequestIntervalMs: _minPreviewThrottleMs,
          bucketSeconds: requestKey,
          lastRequestedBucketSeconds: _lastRequestedBucketSeconds,
          hasOutstandingRequest: _previewInFlight,
        )) {
      return;
    }
    _lastPreviewRequestMs = nowMs;
    _lastRequestedBucketSeconds = requestKey;
    final previousKey = _previewBucketSeconds;
    setState(() {
      _previewInFlight = true;
      _previewBucketSeconds = requestKey;
      if (previousKey != requestKey) {
        _previewBytes = null;
        _driftRejectForbidBorrow = false;
      }
    });
    debugPrint(
      'WT18.5 dart request key=$requestKey inFlight=$_previewInFlight',
    );
    unawaited(
      widget.requestPreview(requestKey).then((frame) {
        if (!mounted || !_dragging) {
          return;
        }
        final currentKey = _previewRequestKey();
        debugPrint(
          'WT18.5 dart response reqKey=$requestKey currentKey=$currentKey '
          'bytes=${frame?.jpegBytes.length ?? 0} '
          'actual=${frame?.actualSeconds}',
        );
        if (currentKey != requestKey) {
          setState(() {
            _previewInFlight = false;
          });
          _maybeRequestPreview(force: false);
          return;
        }
        setState(() {
          _previewInFlight = false;
          if (frame == null) {
            // Ordinary Host nil — §2.1 borrow still allowed.
            _previewBytes = null;
            _driftRejectForbidBorrow = false;
            _slowPreviewStreak++;
            _minPreviewThrottleMs = scrubPreviewNextThrottleMs(
              currentMs: _minPreviewThrottleMs,
              slowOutstandingStreak: _slowPreviewStreak,
            );
          } else if (!scrubPreviewActualAcceptable(
            requestedSeconds: requestKey,
            actualSeconds: frame.actualSeconds,
          )) {
            debugPrint(
              'WT18.5 dart driftReject req=$requestKey '
              'actual=${frame.actualSeconds}',
            );
            _previewBytes = null;
            _driftRejectForbidBorrow = true;
            _slowPreviewStreak++;
            _minPreviewThrottleMs = scrubPreviewNextThrottleMs(
              currentMs: _minPreviewThrottleMs,
              slowOutstandingStreak: _slowPreviewStreak,
            );
          } else {
            _driftRejectForbidBorrow = false;
            _slowPreviewStreak = 0;
            _minPreviewThrottleMs = kScrubPreviewInitialThrottleMs;
            _recordSuccessfulPreview(
              bytes: frame.jpegBytes,
              bucketSeconds: requestKey,
              capturedAtMs: DateTime.now().millisecondsSinceEpoch,
            );
          }
        });
      }),
    );
  }

  bool _isTapNoOp(PointerUpEvent event) {
    final start = _pointerDown;
    _pointerDown = null;
    if (start == null) {
      return false;
    }
    return (event.localPosition - start).distance <= kTouchSlop;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final trackHeight = kScrubProgressTrackHeight;
    final trackRadius = trackHeight / 2;
    final timestampLabel = scrubberTimestampLabel(
      frozen: widget.frozen,
      positionSeconds: _positionSeconds,
      durationSeconds: _effectiveDuration,
      residentHoldSeconds:
          _seekHoldSeconds != null ? _residentHoldSeconds : null,
    );
    final residentChromeVisible = scrubberResidentChromeVisible(
      frozen: widget.frozen,
      durationSeconds: _effectiveDuration,
    );
    final timestampStyle = tokens.labelOnMedia.copyWith(
      shadows: tokens.onMediaLabelShadows,
    );
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: kMainBrowseScrubberReserveHeight,
      child: RawGestureDetector(
        key: const Key('mainBrowseVideoScrubber'),
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          HorizontalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                HorizontalDragGestureRecognizer
              >(
                HorizontalDragGestureRecognizer.new,
                (HorizontalDragGestureRecognizer instance) {
                  instance.onStart = widget.frozen ? null : _onHorizontalDragStart;
                  instance.onUpdate =
                      widget.frozen ? null : _onHorizontalDragUpdate;
                  instance.onEnd = widget.frozen ? null : _onHorizontalDragEnd;
                  instance.onCancel =
                      widget.frozen ? null : _onHorizontalDragCancel;
                },
              ),
        },
        child: Listener(
          onPointerDown: (event) {
            _pointerDown = event.localPosition;
          },
          onPointerUp: (event) {
            if (_isTapNoOp(event)) {
              // ADR-040: pure band tap is no-op (no seek, no play/pause).
            }
          },
          onPointerCancel: (_) {
            _pointerDown = null;
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              _hitWidth = constraints.maxWidth;
              final thumbX = scrubberLocalXFromRatio(
                ratio: _displayRatio,
                hitWidth: constraints.maxWidth,
              );
              final nowMs = DateTime.now().millisecondsSinceEpoch;
              final displayBytes = _bubbleDisplayBytes(nowMs);
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  if (_dragging)
                    Positioned(
                      left: (thumbX - 72).clamp(8.0, constraints.maxWidth - 152),
                      bottom: kMainBrowseScrubberReserveHeight - 8,
                      child: _ScrubPreviewBubble(
                        bytes: displayBytes,
                        timestamp: formatScrubTimestamp(
                          _labelSeconds,
                          durationSeconds: _effectiveDuration!,
                        ),
                        placeholderFill: tokens.scrubPreviewPlaceholderFill,
                        labelStyle: timestampStyle,
                        borderColor: tokens.onMedia,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: kScrubberTrackHorizontalPadding,
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IgnorePointer(
                            ignoring: !residentChromeVisible,
                            child: Opacity(
                              opacity: residentChromeVisible ? 1 : 0,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom:
                                          kMainBrowseScrubberTimestampAboveTrackGap,
                                    ),
                                    child: timestampLabel != null
                                        ? Text(
                                            timestampLabel,
                                            key: const Key(
                                              'mainBrowseScrubberTimestamp',
                                            ),
                                            style: timestampStyle,
                                          )
                                        : SizedBox(
                                            height:
                                                mainBrowseScrubberTimestampLineHeight(
                                              tokens,
                                            ),
                                          ),
                                  ),
                                  SizedBox(
                                    height: trackHeight,
                                    child: Stack(
                                      alignment: Alignment.centerLeft,
                                      children: [
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: tokens.scrubProgressTrack,
                                            borderRadius: BorderRadius.circular(
                                              trackRadius,
                                            ),
                                          ),
                                          child: const SizedBox.expand(),
                                        ),
                                        if (scrubberLiveGhostVisible(
                                              dragging: _dragging,
                                            ) &&
                                            _livePlayheadRatio > 0)
                                          FractionallySizedBox(
                                            key: const Key(
                                              'mainBrowseScrubberLiveGhost',
                                            ),
                                            widthFactor: _livePlayheadRatio,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color:
                                                    tokens.scrubProgressLiveGhost,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  trackRadius,
                                                ),
                                              ),
                                              child: SizedBox(height: trackHeight),
                                            ),
                                          ),
                                        if (_displayRatio > 0)
                                          FractionallySizedBox(
                                            key: const Key(
                                              'mainBrowseScrubberPrimaryFill',
                                            ),
                                            widthFactor: _displayRatio,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: tokens.scrubProgressPlayed,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  trackRadius,
                                                ),
                                              ),
                                              child: SizedBox(height: trackHeight),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ScrubPreviewBubble extends StatelessWidget {
  const _ScrubPreviewBubble({
    required this.bytes,
    required this.timestamp,
    required this.placeholderFill,
    required this.labelStyle,
    required this.borderColor,
  });

  final Uint8List? bytes;
  final String timestamp;
  final Color placeholderFill;
  final TextStyle labelStyle;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          width: 144,
          height: 192,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Always opaque so Image.memory decode gaps do not flash video.
              ColoredBox(color: placeholderFill),
              if (bytes != null)
                Image.memory(
                  bytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Text(timestamp, style: labelStyle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
