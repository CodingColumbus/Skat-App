import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../logic/cards.dart';
import 'suit_shapes.dart';

const double kCardAspect = 0.68;

class CardView extends StatelessWidget {
  final SkatCard? card; // null = Rückseite
  final double width;
  final CardStyle style;
  final bool selected;
  final bool dimmed;
  final bool highlight;
  final VoidCallback? onTap;
  const CardView({
    super.key,
    this.card,
    this.width = 64,
    this.style = CardStyle.french,
    this.selected = false,
    this.dimmed = false,
    this.highlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final h = width / kCardAspect;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, selected ? -16 : (highlight ? -6 : 0), 0),
        width: width,
        height: h,
        child: RepaintBoundary(
          child: CustomPaint(painter: _CardPainter(card, style, dimmed, selected, highlight)),
        ),
      ),
    );
  }
}

class _CardPainter extends CustomPainter {
  final SkatCard? card;
  final CardStyle style;
  final bool dimmed, selected, highlight;
  _CardPainter(this.card, this.style, this.dimmed, this.selected, this.highlight);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.11));
    canvas.drawRRect(r.shift(Offset(0, w * 0.03)), Paint()..color = Colors.black.withValues(alpha: 0.28));
    if (card == null) {
      _back(canvas, size, r);
      return;
    }
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF3EDDC)],
        ).createShader(Offset.zero & size),
    );
    final c = card!;
    final col = suitColor(c.suit, style);

    // Rangzeichen + kleines Farbzeichen in beiden Ecken
    for (var pass = 0; pass < 2; pass++) {
      canvas.save();
      if (pass == 1) {
        canvas.translate(w, h);
        canvas.rotate(math.pi);
      }
      _label(canvas, rankLabel(c.rank, style), Offset(w * 0.08, h * 0.03), w * 0.27, col);
      drawSuit(canvas, c.suit, style, Rect.fromLTWH(w * 0.075, h * 0.03 + w * 0.29, w * 0.2, w * 0.2));
      canvas.restore();
    }

    final area = Rect.fromLTRB(w * 0.27, h * 0.1, w * 0.8, h * 0.9);
    if (c.rank == Rank.ass) {
      final s = w * 0.5;
      drawSuit(canvas, c.suit, style, Rect.fromCenter(center: area.center, width: s, height: s));
    } else if (c.rank == Rank.bube || c.rank == Rank.dame || c.rank == Rank.koenig) {
      _face(canvas, area, c, col);
    } else {
      _pips(canvas, area, c);
    }

    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF3A3A3A),
    );
    if (selected || highlight) {
      canvas.drawRRect(
        r.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = selected ? const Color(0xFFFFB300) : const Color(0xFF7CE08A),
      );
    }
    if (dimmed) canvas.drawRRect(r, Paint()..color = Colors.black.withValues(alpha: 0.42));
  }

  void _back(Canvas canvas, Size size, RRect r) {
    final w = size.width, h = size.height;
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B2A7A), Color(0xFF16124A)],
        ).createShader(Offset.zero & size),
    );
    final inner = r.deflate(w * 0.07);
    canvas.save();
    canvas.clipRRect(inner);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFE6C766).withValues(alpha: 0.55);
    final step = w * 0.2;
    for (double y = -step; y < h + step; y += step) {
      for (double x = -step; x < w + step; x += step) {
        final cx = x + (((y / step).round()).isOdd ? step / 2 : 0);
        canvas.drawPath(
          Path()
            ..moveTo(cx, y - step / 2)
            ..lineTo(cx + step / 2, y)
            ..lineTo(cx, y + step / 2)
            ..lineTo(cx - step / 2, y)
            ..close(),
          p,
        );
      }
    }
    canvas.restore();
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFFE6C766),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.black54,
    );
    final cp = Offset(w / 2, h / 2);
    canvas.drawCircle(cp, w * 0.17, Paint()..color = const Color(0xFF16124A));
    canvas.drawCircle(cp, w * 0.17, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = const Color(0xFFE6C766));
    drawSuit(canvas, Suit.herz, CardStyle.french, Rect.fromCenter(center: cp, width: w * 0.2, height: w * 0.2));
  }

  void _label(Canvas canvas, String t, Offset o, double fs, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(color: color, fontSize: fs, height: 1.0, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o);
  }

  void _pips(Canvas canvas, Rect area, SkatCard c) {
    // Spalten L/C/R und Zeilen als Anteil der Höhe (0 oben .. 1 unten)
    const l = 0.0, m = 0.5, rr = 1.0;
    final List<(double, double)> p;
    switch (c.rank) {
      case Rank.sieben:
        p = [(l, 0), (rr, 0), (l, .5), (rr, .5), (m, .25), (l, 1), (rr, 1)];
      case Rank.acht:
        p = [(l, 0), (rr, 0), (l, .5), (rr, .5), (m, .25), (m, .75), (l, 1), (rr, 1)];
      case Rank.neun:
        p = [(l, 0), (rr, 0), (l, .333), (rr, .333), (l, .667), (rr, .667), (l, 1), (rr, 1), (m, .5)];
      default:
        p = [(l, 0), (rr, 0), (l, .333), (rr, .333), (l, .667), (rr, .667), (l, 1), (rr, 1), (m, .167), (m, .833)];
    }
    final s = area.width * 0.42;
    final inner = Rect.fromLTRB(area.left + s / 2, area.top + s / 2, area.right - s / 2, area.bottom - s / 2);
    for (final (x, y) in p) {
      final center = Offset(inner.left + inner.width * x, inner.top + inner.height * y);
      final rect = Rect.fromCenter(center: center, width: s, height: s);
      if (y > .5) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(math.pi);
        drawSuit(canvas, c.suit, style, Rect.fromCenter(center: Offset.zero, width: s, height: s));
        canvas.restore();
      } else {
        drawSuit(canvas, c.suit, style, rect);
      }
    }
  }

  // ---------- Bildkarten ----------
  void _face(Canvas canvas, Rect area, SkatCard c, Color accent) {
    final panel = RRect.fromRectAndRadius(area, Radius.circular(area.width * 0.08));
    canvas.drawRRect(panel, Paint()..color = accent.withValues(alpha: 0.10));
    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent.withValues(alpha: 0.7),
    );
    canvas.save();
    canvas.clipRRect(panel);
    final half = Rect.fromLTWH(area.left, area.top, area.width, area.height / 2);
    _figure(canvas, half, c, accent);
    canvas.save();
    canvas.translate(area.center.dx, area.center.dy);
    canvas.rotate(math.pi);
    canvas.translate(-area.center.dx, -area.center.dy);
    _figure(canvas, half, c, accent);
    canvas.restore();
    canvas.restore();
    canvas.drawLine(
      area.centerLeft,
      area.centerRight,
      Paint()
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: 0.6),
    );
    final s = area.width * 0.3;
    final cp = area.center;
    canvas.drawCircle(cp, s * 0.68, Paint()..color = const Color(0xFFFFFDF6));
    canvas.drawCircle(cp, s * 0.68, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = accent);
    drawSuit(canvas, c.suit, style, Rect.fromCenter(center: cp, width: s, height: s));
  }

  void _figure(Canvas canvas, Rect hr, SkatCard c, Color accent) {
    final cx = hr.center.dx;
    final w = hr.width, h = hr.height;
    const skin = Color(0xFFF1C9A0);
    final body = Path()
      ..moveTo(hr.left + w * .08, hr.bottom + 1)
      ..quadraticBezierTo(hr.left + w * .12, hr.top + h * .62, cx, hr.top + h * .60)
      ..quadraticBezierTo(hr.right - w * .12, hr.top + h * .62, hr.right - w * .08, hr.bottom + 1)
      ..close();
    canvas.drawPath(body, Paint()..color = accent.withValues(alpha: 0.9));
    canvas.drawPath(body, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black54);
    // Kragen
    canvas.drawPath(
      Path()
        ..moveTo(cx - w * .12, hr.top + h * .60)
        ..lineTo(cx, hr.top + h * .78)
        ..lineTo(cx + w * .12, hr.top + h * .60)
        ..close(),
      Paint()..color = const Color(0xFFFFF7DC),
    );
    final headC = Offset(cx, hr.top + h * .42);
    final hr0 = w * .17;
    if (c.rank == Rank.dame) {
      // lange Haare
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, headC.dy + hr0 * .5), width: hr0 * 2.9, height: hr0 * 3.2),
          Paint()..color = const Color(0xFF7A4B1E));
    }
    canvas.drawCircle(headC, hr0, Paint()..color = skin);
    canvas.drawCircle(headC, hr0, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black54);
    // Augen
    final eye = Paint()..color = Colors.black87;
    canvas.drawCircle(headC.translate(-hr0 * .38, -hr0 * .1), hr0 * .09, eye);
    canvas.drawCircle(headC.translate(hr0 * .38, -hr0 * .1), hr0 * .09, eye);
    canvas.drawArc(Rect.fromCenter(center: headC.translate(0, hr0 * .35), width: hr0 * .6, height: hr0 * .35), 0.2, 2.7, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black87);
    const gold = Color(0xFFE8B923);
    switch (c.rank) {
      case Rank.koenig:
        canvas.drawPath(
          Path()
            ..moveTo(headC.dx - hr0 * .95, headC.dy + hr0 * .55)
            ..quadraticBezierTo(headC.dx, headC.dy + hr0 * 2.1, headC.dx + hr0 * .95, headC.dy + hr0 * .55)
            ..quadraticBezierTo(headC.dx, headC.dy + hr0 * 1.0, headC.dx - hr0 * .95, headC.dy + hr0 * .55),
          Paint()..color = const Color(0xFFEDEDED),
        );
        final crown = Path()
          ..moveTo(headC.dx - hr0 * 1.05, headC.dy - hr0 * .55)
          ..lineTo(headC.dx - hr0 * 1.1, headC.dy - hr0 * 1.7)
          ..lineTo(headC.dx - hr0 * .5, headC.dy - hr0 * 1.1)
          ..lineTo(headC.dx, headC.dy - hr0 * 1.95)
          ..lineTo(headC.dx + hr0 * .5, headC.dy - hr0 * 1.1)
          ..lineTo(headC.dx + hr0 * 1.1, headC.dy - hr0 * 1.7)
          ..lineTo(headC.dx + hr0 * 1.05, headC.dy - hr0 * .55)
          ..close();
        canvas.drawPath(crown, Paint()..color = gold);
        canvas.drawPath(crown, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black87);
      case Rank.dame:
        final tiara = Path()
          ..moveTo(headC.dx - hr0 * 1.0, headC.dy - hr0 * .3)
          ..quadraticBezierTo(headC.dx, headC.dy - hr0 * 1.9, headC.dx + hr0 * 1.0, headC.dy - hr0 * .3)
          ..close();
        canvas.drawPath(tiara, Paint()..color = accent);
        canvas.drawCircle(headC.translate(0, -hr0 * 1.15), hr0 * .17, Paint()..color = gold);
      default: // Bube / Unter: Barett mit Feder
        final cap = Path()
          ..moveTo(headC.dx - hr0 * 1.15, headC.dy - hr0 * .15)
          ..quadraticBezierTo(headC.dx - hr0 * .2, headC.dy - hr0 * 1.9, headC.dx + hr0 * 1.2, headC.dy - hr0 * .4)
          ..close();
        canvas.drawPath(cap, Paint()..color = accent);
        canvas.drawPath(cap, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black87);
        canvas.drawPath(
          Path()
            ..moveTo(headC.dx + hr0 * .2, headC.dy - hr0 * 1.0)
            ..quadraticBezierTo(headC.dx + hr0 * 1.4, headC.dy - hr0 * 2.0, headC.dx + hr0 * 1.7, headC.dy - hr0 * 1.1),
          Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = gold,
        );
    }
  }

  @override
  bool shouldRepaint(_CardPainter o) =>
      o.card != card || o.style != style || o.dimmed != dimmed || o.selected != selected || o.highlight != highlight;
}
