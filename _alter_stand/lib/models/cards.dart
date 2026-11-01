/// Kartenmodell für Skat (32 Karten).
///
/// Reihenfolge der Farben entspricht der Skat-Rangfolge der Buben:
/// Kreuz > Pik > Herz > Karo.
enum Suit { clubs, spades, hearts, diamonds }

enum Rank { seven, eight, nine, ten, jack, queen, king, ace }

extension SuitInfo on Suit {
  String get nameDe => switch (this) {
        Suit.clubs => 'Kreuz',
        Suit.spades => 'Pik',
        Suit.hearts => 'Herz',
        Suit.diamonds => 'Karo',
      };

  String get symbol => switch (this) {
        Suit.clubs => '♣',
        Suit.spades => '♠',
        Suit.hearts => '♥',
        Suit.diamonds => '♦',
      };

  /// Grundwert des Farbspiels.
  int get baseValue => switch (this) {
        Suit.clubs => 12,
        Suit.spades => 11,
        Suit.hearts => 10,
        Suit.diamonds => 9,
      };

  bool get isRed => this == Suit.hearts || this == Suit.diamonds;
}

extension RankInfo on Rank {
  String get label => switch (this) {
        Rank.seven => '7',
        Rank.eight => '8',
        Rank.nine => '9',
        Rank.ten => '10',
        Rank.jack => 'B',
        Rank.queen => 'D',
        Rank.king => 'K',
        Rank.ace => 'A',
      };

  /// Augenwert.
  int get points => switch (this) {
        Rank.seven => 0,
        Rank.eight => 0,
        Rank.nine => 0,
        Rank.ten => 10,
        Rank.jack => 2,
        Rank.queen => 3,
        Rank.king => 4,
        Rank.ace => 11,
      };

  /// Rangfolge innerhalb einer Farbe bei Farb- und Grandspielen
  /// (A, 10, K, D, 9, 8, 7). Der Bube ist dort immer Trumpf.
  int get normalOrder => switch (this) {
        Rank.ace => 7,
        Rank.ten => 6,
        Rank.king => 5,
        Rank.queen => 4,
        Rank.nine => 3,
        Rank.eight => 2,
        Rank.seven => 1,
        Rank.jack => 0,
      };

  /// Rangfolge beim Nullspiel (A, K, D, B, 10, 9, 8, 7).
  int get nullOrder => switch (this) {
        Rank.ace => 8,
        Rank.king => 7,
        Rank.queen => 6,
        Rank.jack => 5,
        Rank.ten => 4,
        Rank.nine => 3,
        Rank.eight => 2,
        Rank.seven => 1,
      };
}

class SkatCard {
  final Suit suit;
  final Rank rank;

  const SkatCard(this.suit, this.rank);

  int get code => suit.index * 8 + rank.index;

  int get points => rank.points;

  bool get isJack => rank == Rank.jack;

  @override
  bool operator ==(Object other) => other is SkatCard && other.code == code;

  @override
  int get hashCode => code;

  @override
  String toString() => '${suit.symbol}${rank.label}';
}

List<SkatCard> buildDeck() => [
      for (final s in Suit.values)
        for (final r in Rank.values) SkatCard(s, r),
    ];

int totalPoints(Iterable<SkatCard> cards) =>
    cards.fold<int>(0, (sum, c) => sum + c.points);
