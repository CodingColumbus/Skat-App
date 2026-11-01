import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/cards.dart';

const double kCardAspect = 1.45;

Color suitColor(Suit s, bool fourColor) {
  if (fourColor) {
    return switch (s) {
      Suit.clubs => const Color(0xFF2E7D32),
      Suit.spades => const Color(0xFF1B1B1B),
      Suit.hearts => const Color(0xFFC62828),
      Suit.diamonds => const Color(0xFF1565C0),
    };
  }
  return s.isRed ? const Color(0xFFC62828) : const Color(0xFF1B1B1B);
}

/// Zeichnet das Symbol einer Kartenfarbe mittig bei [c] in der Größe [s].
void drawSuitShape(Canvas canvas, Suit suit, Offset c, double s, Color color) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  switch (suit) {
    case Suit.diamonds:
      final diamond = Path()
        ..moveTo(c.dx, c.dy - s * 0.5)
        ..lineTo(c.dx + s * 0.36, c.dy)
        ..lineTo(c.dx, c.dy + s * 0.5)
        ..lineTo(c.dx - s * 0.36, c.dy)
        ..close();
      canvas.drawPath(diamond, paint);
    case Suit.hearts:
      final hr = s * 0.265;
      canvas.drawCircle(Offset(c.dx - s * 0.235, c.dy - s * 0.17), hr, paint);
      canvas.drawCircle(Offset(c.dx + s * 0.235, c.dy - s * 0.17), hr, paint);
      final heartTip = Path()
        ..moveTo(c.dx - s * 0.495, c.dy - s * 0.1)
        ..lineTo(c.dx + s * 0.495, c.dy - s * 0.1)
        ..lineTo(c.dx, c.dy + s * 0.5)
        ..close();
      canvas.drawPath(heartTip, paint);
    case Suit.spades:
      final sr = s * 0.265;
      canvas.drawCircle(Offset(c.dx - s * 0.235, c.dy + s * 0.08), sr, paint);
      canvas.drawCircle(Offset(c.dx + s * 0.235, c.dy + s * 0.08), sr, paint);
      final spadeBody = Path()
        ..moveTo(c.dx, c.dy - s * 0.5)
        ..lineTo(c.dx + s * 0.495, c.dy + s * 0.04)
        ..lineTo(c.dx - s * 0.495, c.dy + s * 0.04)
        ..close();
      canvas.drawPath(spadeBody, paint);
      final spadeStem = Path()
        ..moveTo(c.dx - s * 0.07, c.dy + s * 0.2)
        ..lineTo(c.dx + s * 0.07, c.dy + s * 0.2)
        ..lineTo(c.dx + s * 0.2, c.dy + s * 0.5)
        ..lineTo(c.dx - s * 0.2, c.dy + s * 0.5)
        ..close();
      canvas.drawPath(spadeStem, paint);
    case Suit.clubs:
      final cr = s * 0.22;
      canvas.drawCircle(Offset(c.dx, c.dy - s * 0.26), cr, paint);
      canvas.drawCircle(Offset(c.dx - s * 0.26, c.dy + s * 0.08), cr, paint);
      canvas.drawCircle(Offset(c.dx + s * 0.26, c.dy + s * 0.08), cr, paint);
      canvas.drawCircle(Offset(c.dx, c.dy - s * 0.02), s * 0.14, paint);
      final clubStem = Path()
        ..moveTo(c.dx - s * 0.07, c.dy + s * 0.1)
        ..lineTo(c.dx + s * 0.07, c.dy + s * 0.1)
        ..lineTo(c.dx + s * 0.19, c.dy + s * 0.5)
        ..lineTo(c.dx - s * 0.19, c.dy + s * 0.5)
        ..close();
      canvas.drawPath(clubStem, paint);
  }
}

/// Kleines Kartenfarben-Symbol als Widget.
class SuitIcon extends StatelessWidget {
  const SuitIcon(this.suit, {super.key, this.size = 20, this.color});

  final Suit suit;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? suitColor(suit, false);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SuitIconPainter(suit, c)),
    );
  }
}

class _SuitIconPainter extends CustomPainter {
  _SuitIconPainter(this.suit, this.color);

  final Suit suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    drawSuitShape(
        canvas, suit, Offset(size.width / 2, size.height / 2), size.width * 0.9, color);
  }

  @override
  bool shouldRepaint(covariant _SuitIconPainter old) =>
      old.suit != suit || old.color != color;
}

/// Eine Spielkarte (Vorderseite oder Rückseite, wenn [card] null ist).
class PlayingCardView extends StatelessWidget {
  const PlayingCardView({
    super.key,
    this.card,
    required this.width,
    this.dimmed = false,
    this.fourColor = false,
  });

  final SkatCard? card;
  final double width;
  final bool dimmed;
  final bool fourColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: width * kCardAspect,
        child: CustomPaint(
          painter: CardPainter(card: card, dimmed: dimmed, fourColor: fourColor),
        ),
      ),
    );
  }
}

class CardPainter extends CustomPainter {
  CardPainter({
    required this.card,
    required this.dimmed,
    required this.fourColor,
  });

  final SkatCard? card;
  final bool dimmed;
  final bool fourColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(w * 0.09));
    canvas.drawShadow(Path()..addRRect(rrect), Colors.black, 2.5, true);
    final c = card;
    if (c == null) {
      _paintBack(canvas, size, rrect);
    } else {
      _paintFace(canvas, size, rrect, c);
    }
    if (dimmed) {
      canvas.drawRRect(rrect, Paint()..color = const Color(0x88000000));
    }
  }

  void _paintBack(Canvas canvas, Size size, RRect rrect) {
    final w = size.width;
    final h = size.height;
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFFFFFFFF));
    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.06, w * 0.06, w - w * 0.12, h - w * 0.12),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(inner, Paint()..color = const Color(0xFF1E3A8A));
    canvas.save();
    canvas.clipRRect(inner);
    final line = Paint()
      ..color = const Color(0x44FFFFFF)
      ..strokeWidth = 1.0;
    final step = w * 0.16;
    for (double d = -h; d < w + h; d += step) {
      canvas.drawLine(Offset(d, 0), Offset(d + h, h), line);
      canvas.drawLine(Offset(d + h, 0), Offset(d, h), line);
    }
    canvas.restore();
    final emblem = Path()
      ..moveTo(w / 2, h * 0.36)
      ..lineTo(w * 0.72, h / 2)
      ..lineTo(w / 2, h * 0.64)
      ..lineTo(w * 0.28, h / 2)
      ..close();
    canvas.drawPath(emblem, Paint()..color = const Color(0xFF1E3A8A));
    canvas.drawPath(
        emblem,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.02
          ..color = const Color(0xFFFFFFFF));
    canvas.drawRRect(
        inner,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.014
          ..color = const Color(0xFFFFFFFF));
    canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF9E9E9E));
  }

  void _paintFace(Canvas canvas, Size size, RRect rrect, SkatCard c) {
    final w = size.width;
    final h = size.height;
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFFFDFBF4));
    canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF9E9E9E));
    final color = suitColor(c.suit, fourColor);

    _corner(canvas, size, c, color);
    canvas.save();
    canvas.translate(w, h);
    canvas.rotate(math.pi);
    _corner(canvas, size, c, color);
    canvas.restore();

    final area = Rect.fromLTRB(w * 0.27, h * 0.13, w * 0.73, h * 0.87);

    switch (c.rank) {
      case Rank.ace:
        drawSuitShape(canvas, c.suit, area.center, w * 0.5, color);
      case Rank.jack:
      case Rank.queen:
      case Rank.king:
        _paintFaceCard(canvas, size, area, c, color);
      case Rank.seven:
      case Rank.eight:
      case Rank.nine:
      case Rank.ten:
        _paintPips(canvas, size, area, c, color);
    }
  }

  void _corner(Canvas canvas, Size size, SkatCard c, Color color) {
    final w = size.width;
    final h = size.height;
    final label = c.rank.label;
    final fontSize = label.length > 1 ? w * 0.21 : w * 0.26;
    _drawText(canvas, label, Offset(w * 0.15, h * 0.085), fontSize, color);
    drawSuitShape(canvas, c.suit, Offset(w * 0.15, h * 0.085 + w * 0.23),
        w * 0.17, color);
  }

  void _paintPips(
      Canvas canvas, Size size, Rect area, SkatCard c, Color color) {
    final w = size.width;
    final pipSize = w * 0.2;
    final List<Offset> pos;
    switch (c.rank) {
      case Rank.seven:
        pos = const [
          Offset(0.25, 0.12),
          Offset(0.75, 0.12),
          Offset(0.25, 0.5),
          Offset(0.75, 0.5),
          Offset(0.25, 0.88),
          Offset(0.75, 0.88),
          Offset(0.5, 0.31),
        ];
      case Rank.eight:
        pos = const [
          Offset(0.25, 0.12),
          Offset(0.75, 0.12),
          Offset(0.25, 0.5),
          Offset(0.75, 0.5),
          Offset(0.25, 0.88),
          Offset(0.75, 0.88),
          Offset(0.5, 0.31),
          Offset(0.5, 0.69),
        ];
      case Rank.nine:
        pos = const [
          Offset(0.25, 0.12),
          Offset(0.75, 0.12),
          Offset(0.25, 0.37),
          Offset(0.75, 0.37),
          Offset(0.25, 0.63),
          Offset(0.75, 0.63),
          Offset(0.25, 0.88),
          Offset(0.75, 0.88),
          Offset(0.5, 0.5),
        ];
      default:
        pos = const [
          Offset(0.25, 0.12),
          Offset(0.75, 0.12),
          Offset(0.25, 0.37),
          Offset(0.75, 0.37),
          Offset(0.25, 0.63),
          Offset(0.75, 0.63),
          Offset(0.25, 0.88),
          Offset(0.75, 0.88),
          Offset(0.5, 0.245),
          Offset(0.5, 0.755),
        ];
    }
    for (final n in pos) {
      final center = Offset(
        area.left + n.dx * area.width,
        area.top + n.dy * area.height,
      );
      if (n.dy > 0.5) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(math.pi);
        canvas.translate(-center.dx, -center.dy);
        drawSuitShape(canvas, c.suit, center, pipSize, color);
        canvas.restore();
      } else {
        drawSuitShape(canvas, c.suit, center, pipSize, color);
      }
    }
  }

  void _paintFaceCard(
      Canvas canvas, Size size, Rect area, SkatCard c, Color color) {
    final w = size.width;
    final frame = RRect.fromRectAndRadius(area, Radius.circular(w * 0.04));
    canvas.drawRRect(frame, Paint()..color = color.withAlpha(22));
    canvas.drawRRect(
        frame,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.018
          ..color = color);
    canvas.drawLine(
      Offset(area.left, area.center.dy),
      Offset(area.right, area.center.dy),
      Paint()
        ..strokeWidth = w * 0.012
        ..color = color.withAlpha(120),
    );

    void half() {
      final cx = area.center.dx;
      final top = area.top;
      final emblem = Offset(cx, top + w * 0.14);
      switch (c.rank) {
        case Rank.king:
          _crown(canvas, emblem, w * 0.26, color, pearls: false);
        case Rank.queen:
          _crown(canvas, emblem, w * 0.26, color, pearls: true);
        default:
          _cap(canvas, emblem, w * 0.26, color);
      }
      _drawText(canvas, c.rank.label, Offset(cx, top + w * 0.31), w * 0.27, color);
      drawSuitShape(canvas, c.suit, Offset(cx, top + w * 0.45), w * 0.14, color);
    }

    half();
    canvas.save();
    canvas.translate(area.center.dx, area.center.dy);
    canvas.rotate(math.pi);
    canvas.translate(-area.center.dx, -area.center.dy);
    half();
    canvas.restore();
  }

  void _crown(Canvas canvas, Offset c, double s, Color color,
      {required bool pearls}) {
    final paint = Paint()..color = color;
    final p = Path()
      ..moveTo(c.dx - s * 0.5, c.dy + s * 0.3)
      ..lineTo(c.dx - s * 0.5, c.dy - s * 0.15)
      ..lineTo(c.dx - s * 0.25, c.dy + s * 0.05)
      ..lineTo(c.dx, c.dy - s * 0.3)
      ..lineTo(c.dx + s * 0.25, c.dy + s * 0.05)
      ..lineTo(c.dx + s * 0.5, c.dy - s * 0.15)
      ..lineTo(c.dx + s * 0.5, c.dy + s * 0.3)
      ..close();
    canvas.drawPath(p, paint);
    if (pearls) {
      canvas.drawCircle(Offset(c.dx - s * 0.5, c.dy - s * 0.18), s * 0.07, paint);
      canvas.drawCircle(Offset(c.dx, c.dy - s * 0.34), s * 0.07, paint);
      canvas.drawCircle(Offset(c.dx + s * 0.5, c.dy - s * 0.18), s * 0.07, paint);
    }
  }

  void _cap(Canvas canvas, Offset c, double s, Color color) {
    final paint = Paint()..color = color;
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(c.dx, c.dy + s * 0.15), width: s * 0.9, height: s * 0.8),
      math.pi,
      math.pi,
      true,
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - s * 0.55, c.dy + s * 0.13, s * 1.1, s * 0.16),
        Radius.circular(s * 0.06),
      ),
      paint,
    );
    final feather = Path()
      ..moveTo(c.dx + s * 0.15, c.dy - s * 0.15)
      ..quadraticBezierTo(
          c.dx + s * 0.5, c.dy - s * 0.5, c.dx + s * 0.62, c.dy - s * 0.1);
    canvas.drawPath(
      feather,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.08
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  void _drawText(
      Canvas canvas, String text, Offset center, double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CardPainter old) =>
      old.card != card || old.dimmed != dimmed || old.fourColor != fourColor;
}
