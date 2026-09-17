import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/library_smoke/asset_share_providers.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap25_share_enable_policy.dart';
import 'package:waketok/features/main_browse/cap25_share_toast.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';
import 'package:waketok/features/main_browse/pv_transition_guard.dart';
import 'package:waketok/features/main_browse/still_in_library_gate.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 25.3 Action Column Share (index 1).
///
/// Slot-family chrome: ADR-051 Decision 7/14 (glyph) + Decision 8 visibility
/// + Decision 14 tap-enable (local L2 / Live motion; iCloud path retained).
/// In-flight latch: ADR-051 Decision 9 via
/// [mainBrowseSharePresentInFlightProvider] (not Cap 24 PopScope).
class Cap25ShareEntryIcon extends ConsumerWidget {
  const Cap25ShareEntryIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settled = ref.watch(mainBrowseVerticalFeedSettledProvider);
    final assetId = ref.watch(mainBrowseCurrentAssetIdProvider);
    final covering =
        assetId != null &&
        assetId.isNotEmpty &&
        ref.watch(pvTransitionGuardProvider).isCovering(assetId);
    // Decision 8 settle/cover axes: hide completely (not Decision 14 dim).
    if (!settled || covering) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final actionable = ref.watch(mainBrowseCurrentAssetActionableProvider);
    final layer2Ready = ref.watch(
      mainBrowseCurrentAssetLayer2DisplayReadyProvider,
    );
    final liveMotion = ref.watch(mainBrowseCurrentLiveMotionMountedProvider);
    final enable = cap25ShareEnablePredicate(
      actionable: actionable,
      verticalFeedSettled: settled,
      transitionCovering: covering,
      layer2DisplayReady: layer2Ready,
      liveMotionMounted: liveMotion,
    );

    return Semantics(
      button: true,
      enabled: enable.tapEnabled,
      label: l10n.cap25ShareEntryIconSemantics,
      child: Opacity(
        opacity: enable.tapEnabled ? 1.0 : kActionColumnEntryIconDisabledOpacity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('cap25ShareEntryIcon'),
            onTap: enable.tapEnabled
                ? () => _onShareTap(context: context, ref: ref, l10n: l10n)
                : null,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: kActionColumnHitSize,
              height: kActionColumnHitSize,
              child: Center(
                child: Icon(
                  // ADR-051 Decision 14: solid turn-up-right (replaces D7
                  // square_arrow_up). Single glyph for enabled and disabled.
                  CupertinoIcons.arrowshape_turn_up_right_fill,
                  // Cap 25 / ADR-051 Decision 7: start at column lock 32;
                  // Profile optical pass may tune (Cap 24 ellipsis uses 36).
                  size: kActionColumnIconSize,
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

Future<void> _onShareTap({
  required BuildContext context,
  required WidgetRef ref,
  required AppLocalizations l10n,
}) async {
  final flight = ref.read(mainBrowseSharePresentInFlightProvider.notifier);
  if (flight.isInFlight) {
    return;
  }
  flight.begin();
  try {
    final allowed = await ensureCurrentAssetStillInLibraryForMutation(
      ref: ref,
      context: context,
    );
    if (!context.mounted || !allowed) {
      return;
    }
    final assetId = ref.read(mainBrowseCurrentAssetIdProvider);
    if (assetId == null || assetId.isEmpty) {
      return;
    }
    try {
      await ref.read(assetShareRepositoryProvider).presentShareSheet(assetId);
    } on PlatformException catch (e) {
      // Host must not emit operationCancelled for sheet dismiss (ADR-051 D4).
      // If it ever does, stay silent like Cap 24 consent cancel — no fail toast.
      if (e.code == AppError.operationCancelled.name) {
        return;
      }
      if (context.mounted) {
        showCap25ShareFailedToast(context, l10n);
      }
    } on Object {
      if (context.mounted) {
        showCap25ShareFailedToast(context, l10n);
      }
    }
  } finally {
    flight.end();
  }
}

/// Positions [Cap25ShareEntryIcon] at action-column index 1 (ADR-051 Q1=B).
class Cap25ShareEntryIconSlot extends StatelessWidget {
  const Cap25ShareEntryIconSlot({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return Positioned(
      right: kMediaChromeTrailingInset,
      bottom: cap25ShareEntryIconBottomInset(tokens),
      child: const Cap25ShareEntryIcon(),
    );
  }
}

/// Bottom inset for Share at action-column index 1.
double cap25ShareEntryIconBottomInset(WakeTokTokens tokens) =>
    actionColumnBottomInsetForIndex(
      1,
      mainBrowseActionColumnLowestBottomInset(tokens),
    );
