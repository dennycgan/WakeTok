import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/onboarding/cap30_first_launch_guide_logic.dart';
import 'package:waketok/features/main_browse/browse_first_launch_coach_icons.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap30_first_launch_guide_wiring.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 30.3 — centered vertical up/down first-launch coach (`<1>`).
///
/// **Sole Cap 30 browse-ready sync owner (hard requirement, Cap 30.4 /
/// ADR-060).** This Host is the **only** Browse-pane call site for
/// [syncCap30BrowseReady]. It **must** stay mounted for the Browse pane
/// lifetime with **no** gate on [Cap30GuideChromeKind] / `activeChrome`
/// (including when this Host paints [SizedBox.shrink]). Mounting only
/// while `activeChrome == verticalHint` (or any chrome-state gate)
/// silently breaks `<2>` ready sync — disk can stall at step 2 with no
/// error. Same class of risk as the shared orchestrator singleton.
/// Create Pool tip Host must observe epoch / chrome only — never sync.
class Cap30VerticalHintGuideHost extends ConsumerStatefulWidget {
  const Cap30VerticalHintGuideHost({super.key});

  @override
  ConsumerState<Cap30VerticalHintGuideHost> createState() =>
      _Cap30VerticalHintGuideHostState();
}

class _Cap30VerticalHintGuideHostState
    extends ConsumerState<Cap30VerticalHintGuideHost> {
  Timer? _hideTimer;
  int? _indexWhenHintStarted;
  bool _visible = false;
  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_syncReady);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  bool _browseItemReady() {
    final destination = ref.read(mainBrowseDestinationProvider);
    final assetId = ref.read(mainBrowseCurrentAssetIdProvider);
    return destination == MainBrowseDestination.browse &&
        assetId != null &&
        assetId.isNotEmpty;
  }

  Future<void> _syncReady() async {
    if (_syncScheduled) {
      return;
    }
    _syncScheduled = true;
    try {
      final orch = ref.read(cap30FirstLaunchGuideOrchestratorProvider);
      await syncCap30BrowseReady(
        orch: orch,
        bumpEpoch: () =>
            ref.read(cap30FirstLaunchGuideEpochProvider.notifier).bump(),
        ready: _browseItemReady(),
      );
      if (!mounted) {
        return;
      }
      _reconcileChrome();
    } finally {
      _syncScheduled = false;
    }
  }

  void _reconcileChrome() {
    final orch = ref.read(cap30FirstLaunchGuideOrchestratorProvider);
    final shouldShow =
        orch.activeChrome == Cap30GuideChromeKind.verticalHint;
    if (shouldShow && !_visible) {
      _indexWhenHintStarted = ref.read(mainBrowseFeedIndexProvider);
      setState(() => _visible = true);
      _hideTimer?.cancel();
      _hideTimer = Timer(kCap30VerticalHintGuideDuration, () {
        unawaited(_onDisplayEnded());
      });
    } else if (!shouldShow && _visible) {
      _hideTimer?.cancel();
      _hideTimer = null;
      setState(() => _visible = false);
    }
  }

  Future<void> _onDisplayEnded() async {
    final orch = ref.read(cap30FirstLaunchGuideOrchestratorProvider);
    if (orch.activeChrome != Cap30GuideChromeKind.verticalHint) {
      return;
    }
    await orch.notifyStepDisplayEnded();
    ref.read(cap30FirstLaunchGuideEpochProvider.notifier).bump();
    if (mounted) {
      _reconcileChrome();
    }
  }

  Future<void> _onFeedIndexChanged(int next) async {
    final orch = ref.read(cap30FirstLaunchGuideOrchestratorProvider);
    if (orch.activeChrome != Cap30GuideChromeKind.verticalHint) {
      return;
    }
    if (_indexWhenHintStarted != null && next == _indexWhenHintStarted) {
      return;
    }
    _hideTimer?.cancel();
    await orch.notifyVerticalPageChanged();
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
    ref.listen(mainBrowseDestinationProvider, (_, __) {
      Future.microtask(_syncReady);
    });
    ref.listen(mainBrowseCurrentAssetIdProvider, (_, __) {
      Future.microtask(_syncReady);
    });
    ref.listen<int>(mainBrowseFeedIndexProvider, (_, next) {
      Future.microtask(() => _onFeedIndexChanged(next));
    });

    if (!_visible) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: tokens.accent,
          fontWeight: FontWeight.w600,
          shadows: tokens.onMediaLabelShadows,
        );

    return IgnorePointer(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: DecoratedBox(
            key: const Key('cap30VerticalHintGuide'),
            decoration: BoxDecoration(
              color: browseCoachSheetFill(tokens),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrowseFirstLaunchCoachArrowIcon(
                    icon: CupertinoIcons.arrow_up,
                    color: tokens.accent,
                    shadows: tokens.onMediaLabelShadows,
                  ),
                  BrowseFirstLaunchCoachArrowIcon(
                    icon: CupertinoIcons.arrow_down,
                    color: tokens.accent,
                    shadows: tokens.onMediaLabelShadows,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.cap30VerticalHintGuideTitle,
                    key: const Key('cap30VerticalHintGuideTitle'),
                    textAlign: TextAlign.center,
                    style: titleStyle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
