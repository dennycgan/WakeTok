import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';

/// Swipe-direction arrow for First-launch Browse guidance.
///
/// **Always** paints at [kBrowseFirstLaunchSwipeDirectionArrowSize] — the
/// sole size parameter for this glyph family (`<1>`, `<3>`, future peers).
/// No per-call size override. CupertinoIcons have no bold weight;
/// stroke-under-fill uses [kBrowseFirstLaunchSwipeDirectionArrowStrokeWidth].
class BrowseFirstLaunchCoachArrowIcon extends StatelessWidget {
  const BrowseFirstLaunchCoachArrowIcon({
    super.key,
    required this.icon,
    required this.color,
    this.shadows,
  });

  final IconData icon;
  final Color color;
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final glyph = String.fromCharCode(icon.codePoint);
    final family = icon.fontFamily;
    final package = icon.fontPackage;
    const size = kBrowseFirstLaunchSwipeDirectionArrowSize;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            glyph,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size,
              fontFamily: family,
              package: package,
              height: 1,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = kBrowseFirstLaunchSwipeDirectionArrowStrokeWidth
                ..color = color,
              shadows: shadows,
            ),
          ),
          Icon(
            icon,
            size: size,
            color: color,
          ),
        ],
      ),
    );
  }
}
