import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/scrubber_policy.dart';

typedef ScrubPreviewRequest = Future<Uint8List?> Function(double positionSeconds);

/// Cap 18.5 TikTok-style progress scrubber + preview bubble (ADR-040 D13 supplement).
///
/// Host null / latency gaps show a solid placeholder only — no user-facing
/// unavailable copy (technical failures are not actionable while scrubbing).
class VideoProgressScrubber extends StatefulWidget {
  const VideoProgressScrubber({
    super.key,
    required this.assetIdentifier,
    required this.frozen,
    required this.runtimeEvents,
    required this.onScrubBegin,
    required this.onScrubComplete,
    required this.requestPreview,
  });

  final String assetIdentifier;
  final bool frozen;
  final Stream<PlaybackRuntimeEvent> runtimeEvents;
  final VoidCallback onScrubBegin;
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
  Offset? _pointerDown;
  double? _dragAnchorLocalX;
  double _dragAnchorRatio = 0;

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
      if (_dragging) {
        return;
      }
      setState(() {
        _positionSeconds = event.playbackPositionSeconds;
        _durationSeconds = event.durationSeconds ?? _durationSeconds;
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

  double get _displaySeconds {
    final duration = _effectiveDuration;
    if (duration != null && duration > 0) {
      return (_displayRatio * duration).clamp(0, duration);
    }
    return _positionSeconds;
  }

  bool _dragCommitted = false;

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
      widget.onScrubBegin();
    }
    final previousBucket = scrubPreviewBucketSeconds(
      _secondsForRatio(_dragRatio),
    );
    final nextRatio = _dragRatioFromDrag(details.localPosition.dx);
    final nextBucket = scrubPreviewBucketSeconds(
      _secondsForRatio(nextRatio),
    );
    if (nextBucket != previousBucket) {
      final delta = nextBucket - previousBucket;
      if (delta != 0) {
        final sign = delta > 0 ? 1 : -1;
        if (_scrubBucketDeltaSign != null && sign != _scrubBucketDeltaSign) {
          _scrubPreviewBorrowDisabled = true;
        }
        _scrubBucketDeltaSign = sign;
      }
    }
    final bucketChanged =
        _previewBucketSeconds != null && _previewBucketSeconds != nextBucket;
    setState(() {
      _dragRatio = nextRatio;
      if (bucketChanged) {
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
        ? (_dragRatio.clamp(0.0, 1.0) * duration)
        : _positionSeconds;
    final shouldSeek = commitSeek && _dragCommitted;
    setState(() {
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
    final currentBucket = scrubPreviewBucketSeconds(_displaySeconds);
    return scrubPreviewDisplayBytes(
      currentBucketBytes: _previewBytes,
      borrowSourceBytes: _lastSuccessfulPreviewBytes,
      currentBucketSeconds: currentBucket,
      borrowSourceBucketSeconds: _lastSuccessfulPreviewBucket,
      nowMs: nowMs,
      borrowSourceCapturedAtMs: _lastSuccessfulPreviewAtMs,
      scrubDirectionReversed: _scrubPreviewBorrowDisabled,
    );
  }

  double _trackWidth() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return 0;
    }
    return box.size.width;
  }

  double _dragRatioFromDrag(double currentLocalX) {
    final anchorX = _dragAnchorLocalX;
    if (anchorX == null) {
      return _dragRatio;
    }
    return scrubberDragRatio(
      anchorRatio: _dragAnchorRatio,
      anchorLocalX: anchorX,
      currentLocalX: currentLocalX,
      trackWidth: _trackWidth(),
    );
  }

  void _maybeRequestPreview({required bool force}) {
    final bucket = scrubPreviewBucketSeconds(_displaySeconds);
    if (_previewInFlight) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!force &&
        !scrubPreviewShouldRequest(
          nowMs: nowMs,
          lastRequestStartedMs: _lastPreviewRequestMs,
          minRequestIntervalMs: _minPreviewThrottleMs,
          bucketSeconds: bucket,
          lastRequestedBucketSeconds: _lastRequestedBucketSeconds,
          hasOutstandingRequest: _previewInFlight,
        )) {
      return;
    }
    _lastPreviewRequestMs = nowMs;
    _lastRequestedBucketSeconds = bucket;
    final previousBucket = _previewBucketSeconds;
    setState(() {
      _previewInFlight = true;
      _previewBucketSeconds = bucket;
      if (previousBucket != bucket) {
        _previewBytes = null;
      }
    });
    debugPrint('WT18.5 dart request bucket=$bucket inFlight=$_previewInFlight');
    unawaited(
      widget.requestPreview(bucket).then((bytes) {
        if (!mounted || !_dragging) {
          return;
        }
        final currentBucket = scrubPreviewBucketSeconds(_displaySeconds);
        debugPrint(
          'WT18.5 dart response reqBucket=$bucket currentBucket=$currentBucket '
          'bytes=${bytes?.length ?? 0}',
        );
        if (currentBucket != bucket) {
          setState(() {
            _previewInFlight = false;
          });
          _maybeRequestPreview(force: false);
          return;
        }
        setState(() {
          _previewInFlight = false;
          if (bytes == null) {
            _previewBytes = null;
            _slowPreviewStreak++;
            _minPreviewThrottleMs = scrubPreviewNextThrottleMs(
              currentMs: _minPreviewThrottleMs,
              slowOutstandingStreak: _slowPreviewStreak,
            );
          } else {
            _slowPreviewStreak = 0;
            _minPreviewThrottleMs = kScrubPreviewInitialThrottleMs;
            _recordSuccessfulPreview(
              bytes: bytes,
              bucketSeconds: bucket,
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
              final thumbX = _displayRatio * constraints.maxWidth;
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
                          _displaySeconds,
                          durationSeconds: _effectiveDuration,
                        ),
                        placeholderFill: tokens.scrubPreviewPlaceholderFill,
                        labelStyle: tokens.labelOnMedia.copyWith(
                          shadows: tokens.onMediaLabelShadows,
                        ),
                        borderColor: tokens.onMedia,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_dragging)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                formatScrubTimestamp(
                                  _displaySeconds,
                                  durationSeconds: _effectiveDuration,
                                ),
                                style: tokens.labelOnMedia.copyWith(
                                  shadows: tokens.onMediaLabelShadows,
                                ),
                              ),
                            ),
                          SizedBox(
                            height: 3,
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: tokens.scrubProgressTrack,
                                    borderRadius: BorderRadius.circular(1.5),
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                                if (!widget.frozen && _displayRatio > 0)
                                  FractionallySizedBox(
                                    widthFactor: _displayRatio,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: tokens.scrubProgressPlayed,
                                        borderRadius: BorderRadius.circular(1.5),
                                      ),
                                      child: const SizedBox(height: 3),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
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
