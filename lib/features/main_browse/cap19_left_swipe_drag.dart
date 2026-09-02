import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_arbitration.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Max tracked left drag as a fraction of viewport width.
const double kCap19LeftSwipeMaxDragFraction = 0.38;

/// Release animation when append threshold is met.
const Duration kCap19LeftSwipeCompleteDuration = Duration(milliseconds: 180);

/// Snap-back when release is below threshold.
const Duration kCap19LeftSwipeCancelDuration = Duration(milliseconds: 200);

/// Drop-target chip opacity at drag start (before threshold).
const double kCap19LeftSwipeChipMinOpacity = 0.3;

/// Drop-target chip scale at drag start.
const double kCap19LeftSwipeChipMinScale = 0.85;

/// Drop-target chip scale when armed (past commit threshold).
const double kCap19LeftSwipeChipArmedScale = 1.05;

/// Leading inset for the fixed drop-target chip (left edge).
const double kCap19LeftSwipeChipLeadingInset = 16;

class Cap19LeftSwipeDragState {
  const Cap19LeftSwipeDragState({this.offsetX = 0});

  final double offsetX;

  bool get isActive => offsetX < 0;
}

class Cap19LeftSwipeDragNotifier extends Notifier<Cap19LeftSwipeDragState> {
  @override
  Cap19LeftSwipeDragState build() => const Cap19LeftSwipeDragState();

  void updateOffset(double offsetX) {
    state = Cap19LeftSwipeDragState(offsetX: offsetX);
  }

  void reset() {
    state = const Cap19LeftSwipeDragState();
  }
}

final cap19LeftSwipeDragProvider =
    NotifierProvider<Cap19LeftSwipeDragNotifier, Cap19LeftSwipeDragState>(
      Cap19LeftSwipeDragNotifier.new,
    );

double cap19LeftSwipeClampedOffset({
  required double dx,
  required double viewportWidth,
}) {
  if (dx >= 0) {
    return 0;
  }
  final maxDrag = -viewportWidth * kCap19LeftSwipeMaxDragFraction;
  return dx.clamp(maxDrag, 0);
}

/// Progress toward append threshold (0..1+).
double cap19LeftSwipeDragProgress(double offsetX) {
  if (offsetX >= 0) {
    return 0;
  }
  return -offsetX / kCap19LeftSwipeDistanceThreshold;
}

bool cap19LeftSwipeDragIsArmed(double offsetX) {
  return cap19LeftSwipeDragProgress(offsetX) >= 1.0;
}

/// Chip opacity: faint at drag start → solid near threshold.
double cap19LeftSwipeChipOpacity(double progress) {
  final t = progress.clamp(0.0, 1.0);
  return kCap19LeftSwipeChipMinOpacity +
      (1.0 - kCap19LeftSwipeChipMinOpacity) * t;
}

/// Chip scale: small at drag start → full size → slight overshoot when armed.
double cap19LeftSwipeChipScale(double progress) {
  if (progress >= 1.0) {
    return kCap19LeftSwipeChipArmedScale;
  }
  return kCap19LeftSwipeChipMinScale +
      (1.0 - kCap19LeftSwipeChipMinScale) * progress.clamp(0.0, 1.0);
}

/// Whether pointer motion should enter left-swipe drag tracking.
bool cap19LeftSwipeDragShouldCommit(Offset delta) {
  return delta.dx < -kCap19LeftSwipeEarlyMotionThreshold &&
      delta.dx.abs() > delta.dy.abs();
}

/// Fixed drop-target chip — opacity/scale follow drag progress (no width strip).
class Cap19LeftSwipeAlbumReveal extends ConsumerWidget {
  const Cap19LeftSwipeAlbumReveal({super.key, required this.isCurrent});

  final bool isCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isCurrent) {
      return const SizedBox.shrink();
    }
    final offsetX = ref.watch(
      cap19LeftSwipeDragProvider.select((drag) => drag.offsetX),
    );
    if (offsetX >= 0) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final progress = cap19LeftSwipeDragProgress(offsetX);
    final armed = cap19LeftSwipeDragIsArmed(offsetX);
    final opacity = cap19LeftSwipeChipOpacity(progress);
    final scale = cap19LeftSwipeChipScale(progress);
    final hintStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: armed ? tokens.onMedia : tokens.onMediaMuted,
          fontWeight: armed ? FontWeight.w600 : FontWeight.w500,
          height: 1.2,
        );

    return Positioned(
      top: 0,
      bottom: 0,
      left: kCap19LeftSwipeChipLeadingInset,
      child: RepaintBoundary(
        child: IgnorePointer(
          child: Center(
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: DecoratedBox(
                  key: const Key('cap19LeftSwipeAlbumReveal'),
                  decoration: BoxDecoration(
                    color: tokens.feedBackground.withValues(
                      alpha: armed ? 0.78 : 0.62,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: armed
                        ? Border.all(color: tokens.brandGold, width: 1.5)
                        : Border.all(
                            color: tokens.onMediaMuted.withValues(alpha: 0.45),
                          ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          armed
                              ? CupertinoIcons.folder_fill
                              : CupertinoIcons.folder,
                          color: armed ? tokens.brandGold : tokens.onMedia,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 148),
                          child: Text(
                            l10n.cap19LeftSwipeDragHint,
                            key: const Key('cap19LeftSwipeDragHint'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: hintStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
