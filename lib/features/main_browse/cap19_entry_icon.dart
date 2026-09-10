import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/main_browse/cap19_actions_half_sheet.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/main_browse_trailing_chrome_policy.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';
import 'package:waketok/features/main_browse/pv_transition_guard.dart';
import 'package:waketok/features/main_browse/still_in_library_gate.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 19.4 / ADR-040 D15: fixed bottom-trailing entry on Browse media area.
///
/// ADR-042 Decision 7: not-actionable → visible + dim (do not hide).
/// ADR-042 Decision 8: peek / PV covering → fully hidden (same slot family).
class Cap19EntryIcon extends ConsumerWidget {
  const Cap19EntryIcon({super.key, required this.access});

  final PhotosAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settled = ref.watch(mainBrowseVerticalFeedSettledProvider);
    final assetId = ref.watch(mainBrowseCurrentAssetIdProvider);
    final covering =
        assetId != null &&
        assetId.isNotEmpty &&
        ref.watch(pvTransitionGuardProvider).isCovering(assetId);
    // Decision 8 settle/cover axes: hide completely (not Decision 7 dim).
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
      label: l10n.cap19EntryIconSemantics,
      child: Opacity(
        opacity: actionable ? 1.0 : kCap19EntryIconDisabledOpacity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('cap19EntryIcon'),
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
                    await showCap19ActionsHalfSheet(context, access: access);
                  }
                : null,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: kActionColumnHitSize,
              height: kActionColumnHitSize,
              child: Center(
                child: Icon(
                  CupertinoIcons.rectangle_stack_badge_plus,
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

/// Positions [Cap19EntryIcon] on the Browse pane with a shell-fixed bottom
/// inset (see [cap19EntryIconBottomInset] / action-column Reset align).
class Cap19EntryIconSlot extends StatelessWidget {
  const Cap19EntryIconSlot({super.key, required this.access});

  final PhotosAccess access;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return Positioned(
      right: kMediaChromeTrailingInset,
      bottom: cap19EntryIconBottomInset(tokens),
      child: Cap19EntryIcon(access: access),
    );
  }
}
