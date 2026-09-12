import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap24_more_half_sheet.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/main_browse_trailing_chrome_policy.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';
import 'package:waketok/features/main_browse/pv_transition_guard.dart';
import 'package:waketok/features/main_browse/still_in_library_gate.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 24.3 Action Column `"…"` (index 0). Shares Cap 19 slot-family chrome
/// (ADR-042 D7/D8 + Cap 23); does **not** require Layer 2 ready (ADR-050 D7).
class Cap24MoreEntryIcon extends ConsumerWidget {
  const Cap24MoreEntryIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settled = ref.watch(mainBrowseVerticalFeedSettledProvider);
    final assetId = ref.watch(mainBrowseCurrentAssetIdProvider);
    final covering =
        assetId != null &&
        assetId.isNotEmpty &&
        ref.watch(pvTransitionGuardProvider).isCovering(assetId);
    if (!settled || covering) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final actionable = ref.watch(mainBrowseCurrentAssetActionableProvider);
    final chromeReady = mainBrowseTrailingMutationChromeVisible(
      actionable: actionable,
      verticalFeedSettled: settled,
      transitionCovering: covering,
    );

    return Semantics(
      button: true,
      enabled: chromeReady,
      label: l10n.cap24MoreEntryIconSemantics,
      child: Opacity(
        opacity: actionable ? 1.0 : kCap19EntryIconDisabledOpacity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('cap24MoreEntryIcon'),
            onTap: chromeReady
                ? () async {
                    final allowed =
                        await ensureCurrentAssetStillInLibraryForMutation(
                      ref: ref,
                      context: context,
                    );
                    if (!context.mounted || !allowed) {
                      return;
                    }
                    await showCap24MoreHalfSheet(context);
                  }
                : null,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: kActionColumnHitSize,
              height: kActionColumnHitSize,
              child: Center(
                child: Icon(
                  CupertinoIcons.ellipsis_circle,
                  // Optical match vs Cap 19 rectangle_stack_badge_plus at 32 —
                  // outline circle reads smaller at the shared column size.
                  size: 36,
                  color: tokens.onMedia,
                  shadows: tokens.onMediaLabelShadows,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Positions [Cap24MoreEntryIcon] at action-column index 0.
class Cap24MoreEntryIconSlot extends StatelessWidget {
  const Cap24MoreEntryIconSlot({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return Positioned(
      right: kMediaChromeTrailingInset,
      bottom: mainBrowseActionColumnLowestBottomInset(tokens),
      child: const Cap24MoreEntryIcon(),
    );
  }
}
