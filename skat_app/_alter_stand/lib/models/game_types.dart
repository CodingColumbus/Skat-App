import 'cards.dart';

enum GameType { clubs, spades, hearts, diamonds, grand, nullGame }

extension GameTypeInfo on GameType {
  bool get isSuit => index <= GameType.diamonds.index;

  bool get isGrand => this == GameType.grand;

  bool get isNull => this == GameType.nullGame;

  /// Trumpffarbe bei Farbspielen (gleiche Reihenfolge wie [Suit]).
  Suit? get trumpSuit => isSuit ? Suit.values[index] : null;

  String get nameDe => switch (this) {
        GameType.clubs => 'Kreuz',
        GameType.spades => 'Pik',
        GameType.hearts => 'Herz',
        GameType.diamonds => 'Karo',
        GameType.grand => 'Grand',
        GameType.nullGame => 'Null',
      };

  /// Grundwert (bei Null: einfacher Nullwert).
  int get baseValue => switch (this) {
        GameType.clubs => 12,
        GameType.spades => 11,
        GameType.hearts => 10,
        GameType.diamonds => 9,
        GameType.grand => 24,
        GameType.nullGame => 23,
      };
}
