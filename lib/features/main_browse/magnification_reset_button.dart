import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/browse_magnification.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';
import 'package:waketok/features/main_browse/media_info_overlay.dart';
import 'package:waketok/features/main_browse/presentation_overlay_snapshot.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// D2-A Reset: compact pill (glyph + label) above Overlay; Video-App-B proportions.
class MagnificationResetButton extends ConsumerWidget {
  const MagnificationResetButton({
    super.key,
    required this.overlaySnapshot,
    this.aboveMetaGap = kResetAboveMetaGap,
  });

  final PresentationOverlaySnapshot? overlaySnapshot;

  /// Reset bottom → Overlay row-1 top.
  final double aboveMetaGap;

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
        aboveMetaGap;
    final labelStyle = tokens.labelOnMedia.copyWith(
      shadows: tokens.onMediaLabelShadows,
    );
    final fontSize = labelStyle.fontSize ?? 12;
    final lineBox = fontSize * (labelStyle.height ?? 1.0);
    // Slightly larger than label; Cupertino hairline reads thin at 1×.
    final iconSize = fontSize + 2;
    final radius = BorderRadius.circular(kResetMinHitEdge);

    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          kMediaChromeLeadingInset,
          0,
          kMediaChromeOverlayTrailingInset,
          bottom,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('magnificationResetButton'),
            onTap: () {
              ref.read(browseMagnificationProvider.notifier).forceFit();
            },
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: kResetMinHitEdge,
                minHeight: kResetMinHitEdge,
              ),
              child: IntrinsicWidth(
                child: IntrinsicHeight(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Material(
                      color: tokens.onMediaPillFill,
                      borderRadius: radius,
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kResetPillHorizontalPad,
                          vertical: kResetPillVerticalPad,
                        ),
                        child: Semantics(
                          button: true,
                          label: l10n.mainBrowseMagnificationReset,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: iconSize,
                                height: lineBox,
                                child: Center(
                                  child: _BoldCupertinoIcon(
                                    CupertinoIcons.arrow_clockwise,
                                    size: iconSize,
                                    color: tokens.onMedia,
                                  ),
                                ),
                              ),
                              const SizedBox(width: kResetIconLabelGap),
                              Text(
                                l10n.mainBrowseMagnificationReset,
                                style: labelStyle,
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
          ),
        ),
      ),
    );
  }
}

/// Cupertino glyphs are hairline; stack micro-offsets to read heavier.
class _BoldCupertinoIcon extends StatelessWidget {
  const _BoldCupertinoIcon(
    this.icon, {
    required this.size,
    required this.color,
  });

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const d = 0.35;
    Widget layer(Offset o) => Transform.translate(
      offset: o,
      child: Icon(icon, size: size, color: color),
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        layer(const Offset(-d, 0)),
        layer(const Offset(d, 0)),
        layer(const Offset(0, -d)),
        layer(Offset.zero),
      ],
    );
  }
}
