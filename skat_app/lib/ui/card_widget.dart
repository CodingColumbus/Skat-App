import 'package:flutter/material.dart';
import '../logic/cards.dart';

const double kCardAspect = 0.7;

/// Gezeichnete Skatkarte (deutsches Bild mit französischen Farbzeichen).
class CardView extends StatelessWidget {
  final SkatCard? card; // null = Rückseite
  final double width;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;
  const CardView({
    super.key,
    this.card,
    this.width = 64,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final h = width / kCardAspect;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, selected ? -14 : 0, 0),
        width: width,
        height: h,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _CardPainter(card, dimmed, selected),
          ),
        ),
      ),
    );
  }
}

class _CardPainter extends CustomPainter {
  final SkatCard? card;
  final bool dimmed, selected;
  _CardPainter(this.card, this.dimmed, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.1));
    canvas.drawRRect(r.shift(const Offset(0, 1.5)), Paint()..color = Colors.black26);
    if (card == null) {
      _back(canvas, size, r);
      return;
    }
    canvas.drawRRect(r, Paint()..color = const Color(0xFFFFFDF5));
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3 : 1.2
        ..color = selected ? const Color(0xFFFFB300) : Colors.black54,
    );
    final c = card!;
    final color = c.suit.isRed ? const Color(0xFFC62828) : const Color(0xFF1A1A1A);
    final w = size.width, h = size.height;
    _text(canvas, c.rank.label, Offset(w * 0.08, h * 0.03), w * 0.30, color, bold: true);
    _text(canvas, c.suit.symbol, Offset(w * 0.08, h * 0.03 + w * 0.30), w * 0.26, color);
    canvas.save();
    canvas.translate(w, h);
    canvas.rotate(3.14159265);
    _text(canvas, c.rank.label, Offset(w * 0.08, h * 0.03), w * 0.30, color, bold: true);
    _text(canvas, c.suit.symbol, Offset(w * 0.08, h * 0.03 + w * 0.30), w * 0.26, color);
    canvas.restore();

    if (c.isJack) {
      _jack(canvas, size, c.suit, color);
    } else {
      _pips(canvas, size, c, color);
    }
    if (dimmed) {
      canvas.drawRRect(r, Paint()..color = Colors.black.withValues(alpha: 0.35));
    }
  }

  void _back(Canvas canvas, Size size, RRect r) {
    canvas.drawRRect(r, Paint()..color = const Color(0xFF1B3A6B));
    final inner = r.deflate(size.width * 0.07);
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFE0C060),
    );
    final p = Paint()
      ..color = const Color(0xFFE0C060).withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRRect(inner);
    for (double i = -size.height; i < size.width + size.height; i += size.width * 0.16) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), p);
      canvas.drawLine(Offset(i + size.height, 0), Offset(i, size.height), p);
    }
    canvas.restore();
  }

  void _text(Canvas canvas, String t, Offset o, double fs, Color color, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          color: color,
          fontSize: fs,
          height: 1.0,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o);
  }

  void _symbol(Canvas canvas, Offset center, double fs, SkatCard c, Color color, {bool flip = false}) {
    final tp = TextPainter(
      text: TextSpan(text: c.suit.symbol, style: TextStyle(color: color, fontSize: fs, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (flip) canvas.rotate(3.14159265);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _pips(Canvas canvas, Size size, SkatCard c, Color color) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final fs = w * 0.30;
    // Positionen (x in Spalten, y als Bruchteil der Höhe)
    final left = w * 0.34, right = w * 0.66;
    List<(double, double, bool)> pos;
    switch (c.rank) {
      case Rank.sieben:
        pos = [(left, .26, false), (right, .26, false), (cx, .38, false), (left, .5, false), (right, .5, false), (left, .74, true), (right, .74, true)];
      case Rank.acht:
        pos = [(left, .26, false), (right, .26, false), (cx, .38, false), (left, .5, false), (right, .5, false), (cx, .62, true), (left, .74, true), (right, .74, true)];
      case Rank.neun:
        pos = [(left, .25, false), (right, .25, false), (left, .42, false), (right, .42, false), (cx, .5, false), (left, .58, true), (right, .58, true), (left, .75, true), (right, .75, true)];
      case Rank.zehn:
        pos = [(left, .24, false), (right, .24, false), (cx, .33, false), (left, .42, false), (right, .42, false), (left, .58, true), (right, .58, true), (cx, .67, true), (left, .76, true), (right, .76, true)];
      default:
        // Bild- und Asskarten: großes Zeichen mittig
        pos = [(cx, .5, false)];
    }
    if (c.rank == Rank.ass) {
      _symbol(canvas, Offset(cx, h * 0.5), w * 0.62, c, color);
      return;
    }
    if (c.rank == Rank.dame || c.rank == Rank.koenig) {
      _symbol(canvas, Offset(cx, h * 0.62), w * 0.30, c, color);
      _crown(canvas, size, c.rank == Rank.koenig, color);
      return;
    }
    for (final (x, y, flip) in pos) {
      _symbol(canvas, Offset(x, h * y), fs, c, color, flip: flip);
    }
  }

  void _crown(Canvas canvas, Size size, bool king, Color color) {
    final w = size.width, h = size.height;
    final base = Paint()..color = const Color(0xFFE8B923);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.black87;
    final path = Path()
      ..moveTo(w * .28, h * .46)
      ..lineTo(w * .28, h * .26)
      ..lineTo(w * .39, h * .35)
      ..lineTo(w * .5, h * .22)
      ..lineTo(w * .61, h * .35)
      ..lineTo(w * .72, h * .26)
      ..lineTo(w * .72, h * .46)
      ..close();
    canvas.drawPath(path, base);
    canvas.drawPath(path, edge);
    if (king) {
      canvas.drawCircle(Offset(w * .5, h * .19), w * .04, base);
    } else {
      canvas.drawCircle(Offset(w * .5, h * .5), w * .0, base);
    }
    // Gesicht-Andeutung
    canvas.drawCircle(Offset(w * .5, h * .53), w * .09, Paint()..color = const Color(0xFFF2C9A0));
  }

  void _jack(Canvas canvas, Size size, Suit s, Color color) {
    final w = size.width, h = size.height;
    final bg = Paint()..color = color.withValues(alpha: 0.10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * .22, h * .2, w * .56, h * .6), Radius.circular(w * .06)),
      bg,
    );
    // Büßchen: Kopf + Hut + Körper
    canvas.drawCircle(Offset(w * .5, h * .38), w * .1, Paint()..color = const Color(0xFFF2C9A0));
    final hat = Path()
      ..moveTo(w * .36, h * .34)
      ..lineTo(w * .5, h * .22)
      ..lineTo(w * .64, h * .34)
      ..close();
    canvas.drawPath(hat, Paint()..color = color);
    final body = Path()
      ..moveTo(w * .34, h * .62)
      ..quadraticBezierTo(w * .5, h * .42, w * .66, h * .62)
      ..close();
    canvas.drawPath(body, Paint()..color = color.withValues(alpha: 0.85));
    _symbol(canvas, Offset(w * .5, h * .70), w * .26, SkatCard(s, Rank.bube), color);
  }

  @override
  bool shouldRepaint(_CardPainter o) => o.card != card || o.dimmed != dimmed || o.selected != selected;
}
