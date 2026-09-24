import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/onboarding/cap30_first_launch_guide_logic.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap30_first_launch_guide_wiring.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 30.4 — ceiling only for long copy wrap. Actual tip width is intrinsic
/// under [ConstrainedBox]; narrow screens also clamp via
/// `create.right - edgePad` (not a fixed left-shift of this constant).
const double kCap30CreatePoolTipMaxWidth = 180;

const double _kCap30CreatePoolTipGap = 8;
const double _kCap30CreatePoolTipEdgePad = 8;

/// Inward caret — larger than the early Cap 30.4 probe so the tip reads
/// under Create on device. Vertex aims at Create stadium horizontal center.
const double kCap30CreatePoolTipArrowHeight = 14;
const double kCap30CreatePoolTipArrowHalfWidth = 11;

/// Cap 30.4 — Create Pool anchored first-launch tip (`<2>`).
///
/// Placement: **below** Create column (stadium + Limited helper), **right
/// edge pinned to Create**, width intrinsic with adaptive max. Upward
/// arrow sits **inside** the bubble top edge and aims at Create stadium
/// center (same Full / Limited). Observes shared orchestrator chrome via
/// epoch only. **Must not** call [syncCap30BrowseReady] — sole sync owner
/// is Cap30VerticalHintGuideHost (see that class hard-requirement comment).
class Cap30CreatePoolTipHost extends ConsumerStatefulWidget {
  const Cap30CreatePoolTipHost({super.key});

  @override
  ConsumerState<Cap30CreatePoolTipHost> createState() =>
      _Cap30CreatePoolTipHostState();
}

class _Cap30CreatePoolTipHostState
    extends ConsumerState<Cap30CreatePoolTipHost> {
  Timer? _hideTimer;
  bool _visible = false;

  /// Distance from BrowsePane stack top to tip top.
  double? _tipTop;

  /// [Positioned.right] — pins tip's right edge to Create's right edge.
  double? _tipRight;

  /// Adaptive max width: min(ceiling, create.right - edgePad).
  double? _tipMaxWidth;

  /// Create stadium center X in BrowsePane stack coordinates (arrow aim).
  double? _createCenterStackX;

  double? _stackWidth;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        _reconcileChrome();
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _clearPlacement() {
    _tipTop = null;
    _tipRight = null;
    _tipMaxWidth = null;
    _createCenterStackX = null;
    _stackWidth = null;
  }

  void _reconcileChrome() {
    final orch = ref.read(cap30FirstLaunchGuideOrchestratorProvider);
    final shouldShow =
        orch.activeChrome == Cap30GuideChromeKind.createPoolTip;
    if (shouldShow && !_visible) {
      setState(() {
        _visible = true;
        _clearPlacement();
      });
      _hideTimer?.cancel();
      _hideTimer = Timer(kCap30CreatePoolTipDuration, () {
        unawaited(_onDisplayEnded());
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureAnchor());
    } else if (!shouldShow && _visible) {
      _hideTimer?.cancel();
      _hideTimer = null;
      setState(() {
        _visible = false;
        _clearPlacement();
      });
    } else if (shouldShow && _visible && _tipTop == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureAnchor());
    }
  }

  void _measureAnchor() {
    if (!mounted || !_visible) {
      return;
    }
    final anchorContext =
        ref.read(cap30CreatePoolAnchorKeyProvider).currentContext;
    final stackBox = context.findAncestorRenderObjectOfType<RenderStack>();
    if (anchorContext == null || stackBox == null || !stackBox.hasSize) {
      return;
    }
    final anchorBox = anchorContext.findRenderObject() as RenderBox?;
    if (anchorBox == null || !anchorBox.hasSize) {
      return;
    }
    final anchorTopLeft = anchorBox.localToGlobal(
      Offset.zero,
      ancestor: stackBox,
    );

    // Horizontal aim: InkWell stadium (`mainBrowseCreatePool`), not the
    // KeyedSubtree alone — keeps the caret on the capsule midline.
    RenderBox? stadiumBox;
    void visitStadium(Element element) {
      if (element.widget.key == const Key('mainBrowseCreatePool')) {
        final box = element.renderObject as RenderBox?;
        if (box != null && box.hasSize) {
          stadiumBox = box;
        }
      }
      element.visitChildren(visitStadium);
    }

    anchorContext.visitChildElements(visitStadium);
    final aimBox = stadiumBox ?? anchorBox;
    final aimTopLeft = aimBox.localToGlobal(
      Offset.zero,
      ancestor: stackBox,
    );
    final createCenterX = aimTopLeft.dx + aimBox.size.width / 2;
    final createRight = aimTopLeft.dx + aimBox.size.width;

    // Vertical: below stadium + Limited helper when present.
    var bottom = aimTopLeft.dy + aimBox.size.height;
    void visitHelper(Element element) {
      if (element.widget.key ==
          const Key('mainBrowseCreatePoolRequiresFullAccess')) {
        final helperBox = element.renderObject as RenderBox?;
        if (helperBox != null && helperBox.hasSize) {
          final helperTopLeft = helperBox.localToGlobal(
            Offset.zero,
            ancestor: stackBox,
          );
          final helperBottom = helperTopLeft.dy + helperBox.size.height;
          if (helperBottom > bottom) {
            bottom = helperBottom;
          }
        }
      }
      element.visitChildren(visitHelper);
    }

    anchorContext.visitChildElements(visitHelper);

    final tipRight = stackBox.size.width - createRight;
    final tipMaxWidth = math.min(
      kCap30CreatePoolTipMaxWidth,
      math.max(0.0, createRight - _kCap30CreatePoolTipEdgePad),
    );
    final tipTop = bottom + _kCap30CreatePoolTipGap;
    final stackWidth = stackBox.size.width;

    if (_tipTop != tipTop ||
        _tipRight != tipRight ||
        _tipMaxWidth != tipMaxWidth ||
        _createCenterStackX != createCenterX ||
        _stackWidth != stackWidth) {
      setState(() {
        _tipTop = tipTop;
        _tipRight = tipRight;
        _tipMaxWidth = tipMaxWidth;
        _createCenterStackX = createCenterX;
        _stackWidth = stackWidth;
      });
    }
  }

  Future<void> _onDisplayEnded() async {
    final orch = ref.read(cap30FirstLaunchGuideOrchestratorProvider);
    if (orch.activeChrome != Cap30GuideChromeKind.createPoolTip) {
      return;
    }
    await orch.notifyStepDisplayEnded();
    ref.read(cap30FirstLaunchGuideEpochProvider.notifier).bump();
    if (mounted) {
      _reconcileChrome();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(cap30FirstLaunchGuideEpochProvider);
    ref.listen(cap30FirstLaunchGuideEpochProvider, (_, __) {
      _reconcileChrome();
    });

    if (!_visible) {
      return const SizedBox.shrink();
    }

    final tipTop = _tipTop;
    final tipRight = _tipRight;
    final tipMaxWidth = _tipMaxWidth;
    final createCenterStackX = _createCenterStackX;
    final stackWidth = _stackWidth;
    if (tipTop == null ||
        tipRight == null ||
        tipMaxWidth == null ||
        createCenterStackX == null ||
        stackWidth == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureAnchor());
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: tokens.accent,
          height: 1.35,
          shadows: tokens.onMediaLabelShadows,
        );

    return Positioned(
      top: tipTop,
      right: tipRight,
      child: IgnorePointer(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tipMaxWidth),
          child: _CreatePoolTipBubble(
            message: l10n.cap30CreatePoolTipMessage,
            textStyle: textStyle,
            surfaceColor: browseCoachSheetFill(tokens),
            accent: tokens.accent,
            createCenterStackX: createCenterStackX,
            stackWidth: stackWidth,
            tipRight: tipRight,
          ),
        ),
      ),
    );
  }
}

/// Sheet bubble with inward upward caret aimed at Create stadium center.
///
/// Arrow X is derived from the **laid-out** tip width (not maxWidth alone),
/// so a short intrinsic tip still aims at Create center on narrow screens.
class _CreatePoolTipBubble extends StatefulWidget {
  const _CreatePoolTipBubble({
    required this.message,
    required this.textStyle,
    required this.surfaceColor,
    required this.accent,
    required this.createCenterStackX,
    required this.stackWidth,
    required this.tipRight,
  });

  final String message;
  final TextStyle? textStyle;
  final Color surfaceColor;
  final Color accent;
  final double createCenterStackX;
  final double stackWidth;
  final double tipRight;

  @override
  State<_CreatePoolTipBubble> createState() => _CreatePoolTipBubbleState();
}

class _CreatePoolTipBubbleState extends State<_CreatePoolTipBubble> {
  final GlobalKey _columnKey = GlobalKey();
  double? _laidTipWidth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureWidth());
  }

  @override
  void didUpdateWidget(covariant _CreatePoolTipBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureWidth());
  }

  void _captureWidth() {
    if (!mounted) {
      return;
    }
    final box = _columnKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    if (_laidTipWidth != box.size.width) {
      setState(() => _laidTipWidth = box.size.width);
    }
  }

  @override
  Widget build(BuildContext context) {
    final laid = _laidTipWidth;
    double? arrowX;
    if (laid != null && laid > 0) {
      final tipLeft = widget.stackWidth - widget.tipRight - laid;
      final pad = kCap30CreatePoolTipArrowHalfWidth + 2;
      // Prefer exact stadium center; clamp only when the tip is too narrow
      // to host the caret without clipping (should be rare under Create).
      arrowX = (widget.createCenterStackX - tipLeft)
          .clamp(pad, math.max(pad, laid - pad))
          .toDouble();
    }

    return Material(
      key: const Key('cap30CreatePoolTip'),
      color: widget.surfaceColor,
      elevation: 0,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicWidth(
        child: Column(
          key: _columnKey,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: kCap30CreatePoolTipArrowHeight,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  if (arrowX != null)
                    Positioned(
                      left: arrowX - kCap30CreatePoolTipArrowHalfWidth,
                      top: 0,
                      width: kCap30CreatePoolTipArrowHalfWidth * 2,
                      height: kCap30CreatePoolTipArrowHeight,
                      child: CustomPaint(
                        key: const Key('cap30CreatePoolTipArrow'),
                        painter: _UpCaretPainter(color: widget.accent),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
              child: Text(
                widget.message,
                key: const Key('cap30CreatePoolTipMessage'),
                style: widget.textStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Upward caret drawn inside its bounds; tip at top-center.
class _UpCaretPainter extends CustomPainter {
  _UpCaretPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final path = Path()
      ..moveTo(x, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _UpCaretPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
