import 'package:flutter/material.dart';

import '../../core/models/suit.dart';
import '../theme/app_theme.dart';

/// A suit drawn as vector paths rather than a font glyph, so pips look
/// identical on every platform and at every size. Paths are authored in a
/// 44×50 box (the design language's suit grid).
class SuitGlyph extends StatelessWidget {
  const SuitGlyph({
    super.key,
    required this.suit,
    required this.size,
    required this.color,
  });

  final Suit suit;

  /// Rendered width; height follows the 44:50 grid.
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * _gridH / _gridW),
      painter: _SuitPainter(suit, color),
    );
  }
}

const double _gridW = 44;
const double _gridH = 50;

Path suitPath(Suit suit) => switch (suit) {
  Suit.spades =>
    Path()
      ..moveTo(22, 2)
      ..cubicTo(16, 12, 4, 18, 4, 30)
      ..cubicTo(4, 37, 9, 41, 15, 41)
      ..cubicTo(18, 41, 21, 39, 22, 37)
      ..cubicTo(21, 43, 19, 46, 16, 50)
      ..lineTo(28, 50)
      ..cubicTo(25, 46, 23, 43, 22, 37)
      ..cubicTo(23, 39, 26, 41, 29, 41)
      ..cubicTo(35, 41, 40, 37, 40, 30)
      ..cubicTo(40, 18, 28, 12, 22, 2)
      ..close(),
  Suit.hearts =>
    Path()
      ..moveTo(22, 44)
      ..cubicTo(10, 34, 2, 27, 2, 17)
      ..cubicTo(2, 10, 7, 5, 13, 5)
      ..cubicTo(17, 5, 20, 7, 22, 11)
      ..cubicTo(24, 7, 27, 5, 31, 5)
      ..cubicTo(37, 5, 42, 10, 42, 17)
      ..cubicTo(42, 27, 34, 34, 22, 44)
      ..close(),
  Suit.diamonds =>
    Path()
      ..moveTo(22, 3)
      ..quadraticBezierTo(30, 15, 39, 25)
      ..quadraticBezierTo(30, 35, 22, 47)
      ..quadraticBezierTo(14, 35, 5, 25)
      ..quadraticBezierTo(14, 15, 22, 3)
      ..close(),
  Suit.clubs =>
    Path()
      ..addOval(Rect.fromCircle(center: const Offset(22, 13), radius: 9))
      ..addOval(Rect.fromCircle(center: const Offset(12, 27), radius: 9))
      ..addOval(Rect.fromCircle(center: const Offset(32, 27), radius: 9))
      ..addOval(Rect.fromCircle(center: const Offset(22, 24), radius: 6))
      ..moveTo(22, 26)
      ..cubicTo(21, 36, 19, 42, 15, 48)
      ..lineTo(29, 48)
      ..cubicTo(25, 42, 23, 36, 22, 26)
      ..close(),
};

class _SuitPainter extends CustomPainter {
  const _SuitPainter(this.suit, this.color);

  final Suit suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _gridW, size.height / _gridH);
    // nonZero so the club's overlapping lobes fill solid.
    final path = suitPath(suit)..fillType = PathFillType.nonZero;
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SuitPainter old) =>
      old.suit != suit || old.color != color;
}

/// The app mark: a brass spade inside two fine concentric rings. Used on
/// the home screen and on card backs.
class SpadeMonogram extends StatelessWidget {
  const SpadeMonogram({super.key, required this.size, this.ringWidth = 1});

  final double size;
  final double ringWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MonogramRingsPainter(ringWidth),
        child: Center(
          child: SuitGlyph(
            suit: Suit.spades,
            size: size * 0.4,
            color: AppColors.brass,
          ),
        ),
      ),
    );
  }
}

class _MonogramRingsPainter extends CustomPainter {
  const _MonogramRingsPainter(this.ringWidth);

  final double ringWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - ringWidth;
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..color = AppColors.brass;
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..color = AppColors.brass.withValues(alpha: 0.45);
    canvas.drawCircle(center, radius, outer);
    canvas.drawCircle(center, radius * 0.86, inner);
  }

  @override
  bool shouldRepaint(covariant _MonogramRingsPainter old) =>
      old.ringWidth != ringWidth;
}
