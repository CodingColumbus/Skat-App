import 'dart:math';

/// Farben in Skat-Reihenfolge (Kreuz > Pik > Herz > Karo).
enum Suit { karo, herz, pik, kreuz }

/// Reihenfolge im Farbspiel (Ass hoch, 10 über König).
enum Rank { sieben, acht, neun, dame, koenig, zehn, ass, bube }

extension SuitX on Suit {
  String get symbol => const ['♦', '♥', '♠', '♣'][index];
  String get label => const ['Karo', 'Herz', 'Pik', 'Kreuz'][index];
  bool get isRed => this == Suit.karo || this == Suit.herz;
  /// Grundwert für die Spielwertberechnung.
  int get baseValue => const [9, 10, 11, 12][index];
}

extension RankX on Rank {
  String get label => const ['7', '8', '9', 'D', 'K', '10', 'A', 'B'][index];
  int get points => const [0, 0, 0, 3, 4, 10, 11, 2][index];
  /// Rang im Farb-/Nullspiel-freien Vergleich (Bube separat behandelt).
  int get order => const [0, 1, 2, 3, 4, 5, 6, 7][index];
}

class SkatCard {
  final Suit suit;
  final Rank rank;
  const SkatCard(this.suit, this.rank);

  bool get isJack => rank == Rank.bube;
  int get points => rank.points;

  @override
  bool operator ==(Object o) => o is SkatCard && o.suit == suit && o.rank == rank;
  @override
  int get hashCode => suit.index * 8 + rank.index;
  @override
  String toString() => '${suit.symbol}${rank.label}';
}

List<SkatCard> fullDeck() => [
      for (final s in Suit.values)
        for (final r in Rank.values) SkatCard(s, r)
    ];

List<SkatCard> shuffledDeck([Random? rng]) => fullDeck()..shuffle(rng ?? Random());

/// Sortierung für die Hand: Buben zuerst, dann nach Farbe und Rang.
int handCompare(SkatCard a, SkatCard b) {
  if (a.isJack != b.isJack) return a.isJack ? -1 : 1;
  if (a.isJack) return b.suit.index - a.suit.index;
  if (a.suit != b.suit) return b.suit.index - a.suit.index;
  return b.rank.order - a.rank.order;
}
