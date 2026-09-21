import 'package:flutter/material.dart';
import 'package:waketok/features/main_browse/bottom_tab_layout.dart';

/// Monochrome Browse nav glyph — §11.4.5 single large card + peek (Browse B).
///
/// Large **vertical** front card; small peek peeks **upper-left** (brand-aligned;
/// candidate B mirrored). Outlined: front occludes peek in the overlap (no
/// crossed strokes). **No** doom-scroll arrows. Color from caller.
class BrowseCardStackIcon extends StatelessWidget {
  const BrowseCardStackIcon({
    super.key,
    required this.color,
    required this.filled,
    this.size = kBottomTabIconSize,
  });

  final Color color;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BrowseCardStackPainter(color: color, filled: filled),
      ),
    );
  }
}

class _BrowseCardStackPainter extends CustomPainter {
  const _BrowseCardStackPainter({
    required this.color,
    required this.filled,
  });

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    const design = 24.0;
    canvas.save();
    canvas.scale(size.width / design, size.height / design);

    RRect card(double l, double t, double w, double h, double r) {
      return RRect.fromRectAndRadius(
        Rect.fromLTWH(l, t, w, h),
        Radius.circular(r),
      );
    }

    // Browse B: peek UL + larger vertical front; same aspect ratio.
    // Peek top-edge width fixed; height = width × (frontH / frontW).
    const frontW = 14.5;
    const frontH = 17.5;
    const peekW = 10.5;
    final peekH = peekW * (frontH / frontW); // ≈ 12.67
    final peek = card(2.5, 2.0, peekW, peekH, 2.2);
    final front = card(5.5, 4.5, frontW, frontH, 2.8);

    if (filled) {
      canvas.drawRRect(
        peek,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: 0.45),
      );
      canvas.drawRRect(
        front,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color,
      );
    } else {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = kBottomTabBrowseOutlinedStroke
        ..color = color
        ..strokeJoin = StrokeJoin.round;

      // Occlusion: draw peek only outside the front interior so overlap
      // strokes do not cross through the large card.
      canvas.save();
      final outsideFront = Path()
        ..addRect(const Rect.fromLTWH(0, 0, design, design))
        ..addRRect(front)
        ..fillType = PathFillType.evenOdd;
      canvas.clipPath(outsideFront);
      canvas.drawRRect(peek, stroke);
      canvas.restore();

      canvas.drawRRect(front, stroke);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BrowseCardStackPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.filled != filled;
  }
}

/// Order Action swap glyph — same motif as [Icons.swap_vert], weight toward
/// Settings; still thinner than Browse outlined ([kBottomTabActionSwapStroke]).
class OrderSwapIcon extends StatelessWidget {
  const OrderSwapIcon({
    super.key,
    required this.color,
    this.size = kBottomTabIconSize,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OrderSwapPainter(color: color),
      ),
    );
  }
}

class _OrderSwapPainter extends CustomPainter {
  const _OrderSwapPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const design = 24.0;
    canvas.save();
    canvas.scale(size.width / design, size.height / design);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kBottomTabActionSwapStroke
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = design / 2;
    final halfGap = kBottomTabActionSwapShaftGap / 2;
    final leftX = cx - halfGap;
    final rightX = cx + halfGap;
    const top = 4.5;
    const bottom = 19.5;
    const head = 3.4;

    // Left shaft down + arrowhead at bottom; right shaft up + arrowhead at top.
    final left = Path()
      ..moveTo(leftX, top)
      ..lineTo(leftX, bottom)
      ..moveTo(leftX, bottom)
      ..lineTo(leftX - head, bottom - head)
      ..moveTo(leftX, bottom)
      ..lineTo(leftX + head, bottom - head);
    final right = Path()
      ..moveTo(rightX, bottom)
      ..lineTo(rightX, top)
      ..moveTo(rightX, top)
      ..lineTo(rightX - head, top + head)
      ..moveTo(rightX, top)
      ..lineTo(rightX + head, top + head);
    canvas.drawPath(left, paint);
    canvas.drawPath(right, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrderSwapPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
