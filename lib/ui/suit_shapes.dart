import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../logic/cards.dart';

enum CardStyle { french, german }

extension CardStyleX on CardStyle {
  String get label => this == CardStyle.french ? 'Französisches Blatt' : 'Deutsches Blatt';
}

/// Name der Farbe im jeweiligen Blatt.
String suitName(Suit s, CardStyle st) => st == CardStyle.french
    ? s.label
    : const ['Schellen', 'Herz', 'Laub', 'Eichel'][s.index];

/// Beschriftung der Kartenwerte im jeweiligen Blatt.
String rankLabel(Rank r, CardStyle st) {
  if (st == CardStyle.french) return r.label;
  return switch (r) {
    Rank.bube => 'U',
    Rank.dame => 'O',
    Rank.ass => 'A',
    _ => r.label,
  };
}

String rankName(Rank r, CardStyle st) => switch (r) {
      Rank.bube => st == CardStyle.french ? 'Bube' : 'Unter',
      Rank.dame => st == CardStyle.french ? 'Dame' : 'Ober',
      Rank.koenig => 'König',
      Rank.ass => st == CardStyle.french ? 'Ass' : 'Daus',
      Rank.zehn => '10',
      Rank.neun => '9',
      Rank.acht => '8',
      Rank.sieben => '7',
    };

/// Hauptfarbe einer Kartenfarbe (für Index, Rahmen, Figuren).
Color suitColor(Suit s, CardStyle st) {
  if (st == CardStyle.french) {
    return s.isRed ? const Color(0xFFC62828) : const Color(0xFF1C1C22);
  }
  return const [Color(0xFFC77700), Color(0xFFC62828), Color(0xFF2E7D32), Color(0xFF6D4C1F)][s.index];
}

Path _heart() => Path()
  ..moveTo(.5, .92)
  ..cubicTo(.05, .6, .0, .3, .2, .12)
  ..cubicTo(.35, 0, .5, .15, .5, .28)
  ..cubicTo(.5, .15, .65, 0, .8, .12)
  ..cubicTo(1.0, .3, .95, .6, .5, .92)
  ..close();

Path _diamond() => Path()
  ..moveTo(.5, .02)
  ..lineTo(.88, .5)
  ..lineTo(.5, .98)
  ..lineTo(.12, .5)
  ..close();

Path _spade() => Path()
  ..moveTo(.5, .04)
  ..cubicTo(.95, .38, 1.02, .66, .78, .76)
  ..cubicTo(.64, .82, .53, .74, .52, .66)
  ..cubicTo(.54, .80, .58, .90, .68, .98)
  ..lineTo(.32, .98)
  ..cubicTo(.42, .90, .46, .80, .48, .66)
  ..cubicTo(.47, .74, .36, .82, .22, .76)
  ..cubicTo(-.02, .66, .05, .38, .5, .04)
  ..close();

Path _club() => Path()
  ..addOval(Rect.fromCircle(center: const Offset(.5, .27), radius: .21))
  ..addOval(Rect.fromCircle(center: const Offset(.26, .56), radius: .21))
  ..addOval(Rect.fromCircle(center: const Offset(.74, .56), radius: .21))
  ..addOval(Rect.fromCircle(center: const Offset(.5, .5), radius: .13))
  ..moveTo(.5, .55)
  ..lineTo(.64, .98)
  ..lineTo(.36, .98)
  ..close();

Path _scale(Path p, Rect r) {
  final m = Float64List(16);
  m[0] = r.width;
  m[5] = r.height;
  m[10] = 1;
  m[12] = r.left;
  m[13] = r.top;
  m[15] = 1;
  return p.transform(m);
}

/// Zeichnet ein Farbzeichen in [r]. Französisch: einfarbig; Deutsch: bunte Symbole.
void drawSuit(Canvas canvas, Suit s, CardStyle st, Rect r) {
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = (r.width * 0.045).clamp(0.8, 3.0)
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFF222222);
  if (st == CardStyle.french) {
    final p = switch (s) {
      Suit.karo => _diamond(),
      Suit.herz => _heart(),
      Suit.pik => _spade(),
      Suit.kreuz => _club(),
    };
    canvas.drawPath(_scale(p, r), Paint()..color = suitColor(s, st));
    return;
  }
  switch (s) {
    case Suit.herz:
      final p = _scale(_heart(), r);
      canvas.drawPath(p, Paint()..color = const Color(0xFFD32F2F));
      canvas.drawPath(p, stroke);
      canvas.drawOval(Rect.fromLTWH(r.left + r.width * .22, r.top + r.height * .2, r.width * .16, r.height * .12),
          Paint()..color = Colors.white.withValues(alpha: .55));
    case Suit.karo: // Schellen
      final bell = Path()
        ..moveTo(.12, .78)
        ..cubicTo(.12, .05, .88, .05, .88, .78)
        ..close();
      final b = _scale(bell, r);
      canvas.drawPath(b, Paint()..color = const Color(0xFFF2B01E));
      canvas.drawPath(b, stroke);
      final lip = RRect.fromRectAndRadius(
          Rect.fromLTWH(r.left + r.width * .08, r.top + r.height * .74, r.width * .84, r.height * .1), Radius.circular(r.width * .05));
      canvas.drawRRect(lip, Paint()..color = const Color(0xFFD08A00));
      canvas.drawRRect(lip, stroke);
      canvas.drawCircle(Offset(r.left + r.width * .5, r.top + r.height * .91), r.width * .07, Paint()..color = const Color(0xFF6D4C1F));
      canvas.drawCircle(Offset(r.left + r.width * .5, r.top + r.height * .18), r.width * .05, Paint()..color = const Color(0xFF6D4C1F));
    case Suit.pik: // Laub
      final leaf = Path()
        ..moveTo(.5, .02)
        ..cubicTo(1.08, .2, .98, .72, .5, .9)
        ..cubicTo(.02, .72, -.08, .2, .5, .02)
        ..close();
      final l = _scale(leaf, r);
      canvas.drawPath(l, Paint()..color = const Color(0xFF43A047));
      canvas.drawPath(l, stroke);
      final vein = Path()
        ..moveTo(.5, .12)
        ..lineTo(.5, .98);
      canvas.drawPath(_scale(vein, r), stroke);
      canvas.drawLine(Offset(r.left + r.width * .5, r.top + r.height * .45), Offset(r.left + r.width * .75, r.top + r.height * .3), stroke);
      canvas.drawLine(Offset(r.left + r.width * .5, r.top + r.height * .6), Offset(r.left + r.width * .25, r.top + r.height * .45), stroke);
    case Suit.kreuz: // Eichel
      final nut = Rect.fromLTWH(r.left + r.width * .2, r.top + r.height * .3, r.width * .6, r.height * .68);
      canvas.drawOval(nut, Paint()..color = const Color(0xFFD9B04A));
      canvas.drawOval(nut, stroke);
      final cap = Rect.fromLTWH(r.left + r.width * .12, r.top + r.height * .14, r.width * .76, r.height * .36);
      canvas.drawOval(cap, Paint()..color = const Color(0xFF6D4C1F));
      canvas.drawOval(cap, stroke);
      canvas.drawLine(Offset(r.left + r.width * .5, r.top + r.height * .02), Offset(r.left + r.width * .5, r.top + r.height * .16), stroke..strokeWidth = stroke.strokeWidth * 1.6);
  }
}

/// Kleines Farbzeichen als Widget (z. B. für Auswahl-Chips).
class SuitIcon extends StatelessWidget {
  final Suit suit;
  final CardStyle style;
  final double size;
  const SuitIcon(this.suit, this.style, {super.key, this.size = 18});
  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _SuitIconPainter(suit, style)));
}

class _SuitIconPainter extends CustomPainter {
  final Suit suit;
  final CardStyle style;
  _SuitIconPainter(this.suit, this.style);
  @override
  void paint(Canvas canvas, Size size) => drawSuit(canvas, suit, style, Offset.zero & size);
  @override
  bool shouldRepaint(_SuitIconPainter o) => o.suit != suit || o.style != style;
}
