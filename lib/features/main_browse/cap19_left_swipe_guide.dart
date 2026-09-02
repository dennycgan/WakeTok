import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/cap19_left_swipe_providers.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_arbitration.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_session.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// PicTok-class one-shot left-swipe coach mark (Cap 19.6).
const Duration kCap19LeftSwipeGuideDuration = Duration(milliseconds: 2500);

class Cap19LeftSwipeGuideHost extends ConsumerStatefulWidget {
  const Cap19LeftSwipeGuideHost({super.key});

  @override
  ConsumerState<Cap19LeftSwipeGuideHost> createState() =>
      _Cap19LeftSwipeGuideHostState();
}

class _Cap19LeftSwipeGuideHostState extends ConsumerState<Cap19LeftSwipeGuideHost> {
  bool _prefsLoaded = false;
  bool _leftSwipeAddEnabled = true;
  bool _leftSwipeGuideEnabled = true;
  bool _visible = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadPrefs);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = ref.read(cap19LeftSwipePreferencesProvider);
    final addEnabled = await prefs.isLeftSwipeAddEnabled();
    final guideEnabled = await prefs.isLeftSwipeGuideEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _prefsLoaded = true;
      _leftSwipeAddEnabled = addEnabled;
      _leftSwipeGuideEnabled = guideEnabled;
    });
    _maybeShowGuide();
  }

  void _maybeShowGuide() {
    if (!_prefsLoaded || _visible) {
      return;
    }
    final destination = ref.read(mainBrowseDestinationProvider);
    final assetId = ref.read(mainBrowseCurrentAssetIdProvider);
    final browseReady =
        destination == MainBrowseDestination.browse &&
        assetId != null &&
        assetId.isNotEmpty;
    final shouldShow = effectiveLeftSwipeGuideVisible(
      leftSwipeAddEnabled: _leftSwipeAddEnabled,
      leftSwipeGuideEnabled: _leftSwipeGuideEnabled,
      sessionGuideAlreadyShown: Cap19LeftSwipeGuideSession.guideShownThisLaunch,
      browseItemReady: browseReady,
    );
    if (!shouldShow) {
      return;
    }
    Cap19LeftSwipeGuideSession.markGuideShown();
    setState(() => _visible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(kCap19LeftSwipeGuideDuration, () {
      if (mounted) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mainBrowseDestinationProvider, (_, __) => _maybeShowGuide());
    ref.listen(mainBrowseCurrentAssetIdProvider, (_, __) => _maybeShowGuide());

    if (!_visible) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: tokens.onMedia,
          fontWeight: FontWeight.w600,
        );
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: tokens.onMediaMuted,
        );

    return IgnorePointer(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: kCap19ActionsHalfSheetBlurSigma,
                sigmaY: kCap19ActionsHalfSheetBlurSigma,
              ),
              child: DecoratedBox(
                key: const Key('cap19LeftSwipeGuide'),
                decoration: BoxDecoration(
                  color: tokens.feedBackground.withValues(
                    alpha: kCap19ActionsHalfSheetTintOpacity,
                  ),
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
                      Icon(
                        CupertinoIcons.arrow_left,
                        color: tokens.onMedia,
                        size: 28,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.cap19LeftSwipeGuideTitle,
                        key: const Key('cap19LeftSwipeGuideTitle'),
                        textAlign: TextAlign.center,
                        style: titleStyle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.cap19LeftSwipeGuideSubtitle,
                        key: const Key('cap19LeftSwipeGuideSubtitle'),
                        textAlign: TextAlign.center,
                        style: subtitleStyle,
                      ),
                    ],
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
