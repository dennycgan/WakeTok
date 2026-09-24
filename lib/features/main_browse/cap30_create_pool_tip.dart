import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/onboarding/cap30_first_launch_guide_logic.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap30_first_launch_guide_wiring.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 30.4 max tip width — keeps left-of-Create bubble out of Built-in /
/// Saved when possible on phone widths.
const double kCap30CreatePoolTipMaxWidth = 180;

const double _kCap30CreatePoolTipGap = 8;
const double _kCap30CreatePoolTipEdgePad = 8;

/// Cap 30.4 — Create Pool anchored first-launch tip (`<2>`).
///
/// Observes shared orchestrator chrome via epoch only. **Must not** call
/// [syncCap30BrowseReady] — sole sync owner is Cap30VerticalHintGuideHost
/// (see that class hard-requirement comment).
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
  Offset? _tipTopLeft;

  @override
  void initState() {
    super.initState();
    // Observe-only: pick up chrome already active after Vertical Host sync
    // (no syncCap30BrowseReady here).
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

  void _reconcileChrome() {
    final orch = ref.read(cap30FirstLaunchGuideOrchestratorProvider);
    final shouldShow =
        orch.activeChrome == Cap30GuideChromeKind.createPoolTip;
    if (shouldShow && !_visible) {
      setState(() {
        _visible = true;
        _tipTopLeft = null;
      });
      _hideTimer?.cancel();
      _hideTimer = Timer(kCap30GuideStepDuration, () {
        unawaited(_onDisplayEnded());
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureAnchor());
    } else if (!shouldShow && _visible) {
      _hideTimer?.cancel();
      _hideTimer = null;
      setState(() {
        _visible = false;
        _tipTopLeft = null;
      });
    } else if (shouldShow && _visible && _tipTopLeft == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureAnchor());
    }
  }

  void _measureAnchor() {
    if (!mounted || !_visible) {
      return;
    }
    final anchorContext =
        ref.read(cap30CreatePoolAnchorKeyProvider).currentContext;
    final stackBox = context.findRenderObject() as RenderBox?;
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
    // Stack size is the stadium only; Limited helper is Positioned below
    // with clipBehavior none — include helper bottom when present.
    var bottom = anchorTopLeft.dy + anchorBox.size.height;
    void visit(Element element) {
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
      element.visitChildren(visit);
    }

    anchorContext.visitChildElements(visit);

    var left = anchorTopLeft.dx -
        _kCap30CreatePoolTipGap -
        kCap30CreatePoolTipMaxWidth;
    if (left < _kCap30CreatePoolTipEdgePad) {
      left = _kCap30CreatePoolTipEdgePad;
    }
    final top = bottom + _kCap30CreatePoolTipGap;
    final next = Offset(left, top);
    if (_tipTopLeft != next) {
      setState(() => _tipTopLeft = next);
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

    final tipTopLeft = _tipTopLeft;
    if (tipTopLeft == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureAnchor());
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tokens.onMedia,
          height: 1.35,
        );

    return Positioned(
      left: tipTopLeft.dx,
      top: tipTopLeft.dy,
      width: kCap30CreatePoolTipMaxWidth,
      child: IgnorePointer(
        child: Material(
          key: const Key('cap30CreatePoolTip'),
          color: tokens.feedBackground.withValues(
            alpha: kCap19FrostChromeTintOpacity,
          ),
          elevation: 0,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            child: Text(
              l10n.cap30CreatePoolTipMessage,
              key: const Key('cap30CreatePoolTipMessage'),
              style: textStyle,
            ),
          ),
        ),
      ),
    );
  }
}
