import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/browse_magnification.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/media_info_overlay.dart';
import 'package:waketok/features/main_browse/presentation_overlay_snapshot.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Gap between Reset chrome and the top of [MediaInfoOverlay] (ADR-043 D2-A).
const double kCap20ResetAboveOverlayGap = 8;

/// Touch target edge for the welded Reset control.
const double kCap20ResetHitSize = 40;

/// D2-A Reset: independent bottom-left [Align] above Overlay (ADR-043).
class MagnificationResetButton extends ConsumerWidget {
  const MagnificationResetButton({
    super.key,
    required this.overlaySnapshot,
  });

  final PresentationOverlaySnapshot? overlaySnapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final magnified = ref.watch(browseStillMagnifiedProvider);
    if (!magnified) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final bottom =
        mainBrowseMediaOverlayBottomInset(tokens) +
        MediaInfoOverlay.columnHeightFor(overlaySnapshot) +
        kCap20ResetAboveOverlayGap;

    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          MediaInfoOverlay.trailingInset,
          bottom,
        ),
        child: Material(
          color: tokens.feedBackground.withValues(alpha: 0.55),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('magnificationResetButton'),
            onTap: () {
              ref.read(browseMagnificationProvider.notifier).forceFit();
            },
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: kCap20ResetHitSize,
              height: kCap20ResetHitSize,
              child: Semantics(
                button: true,
                label: l10n.mainBrowseMagnificationReset,
                child: Icon(
                  Icons.fullscreen_exit,
                  color: tokens.onMedia,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
