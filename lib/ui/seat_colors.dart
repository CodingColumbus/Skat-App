import 'package:flutter/material.dart';

/// Persönliche Farbe pro Sitz – auf allen Geräten gleich.
const seatColors = <Color>[
  Color(0xFF4FC3F7), // hellblau
  Color(0xFFFFB74D), // orange
  Color(0xFFF06292), // pink
  Color(0xFFBA68C8), // lila
];

Color seatColor(int seat) => seatColors[seat % seatColors.length];

/// Kleiner Namens-Chip in der Spielerfarbe.
class SeatTag extends StatelessWidget {
  final String name;
  final int seat;
  final bool small;
  const SeatTag(this.name, this.seat, {super.key, this.small = false});
  @override
  Widget build(BuildContext context) {
    final c = seatColor(seat);
    return Container(
      constraints: BoxConstraints(maxWidth: small ? 76 : 110),
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: 1.5),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(10)),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.black87, fontSize: small ? 10 : 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
