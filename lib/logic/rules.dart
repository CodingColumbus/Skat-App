import 'cards.dart';

enum GameKind { suit, grand, nullGame }

class GameType {
  final GameKind kind;
  final Suit? trump;
  const GameType.suit(Suit s)
      : kind = GameKind.suit,
        trump = s;
  const GameType.grand()
      : kind = GameKind.grand,
        trump = null;
  const GameType.nullGame()
      : kind = GameKind.nullGame,
        trump = null;

  bool get isNull => kind == GameKind.nullGame;
  int get baseValue => switch (kind) {
        GameKind.suit => trump!.baseValue,
        GameKind.grand => 24,
        GameKind.nullGame => 23,
      };
  String get label => switch (kind) {
        GameKind.suit => trump!.name,
        GameKind.grand => 'Grand',
        GameKind.nullGame => 'Null',
      };

  @override
  bool operator ==(Object o) => o is GameType && o.kind == kind && o.trump == trump;
  @override
  int get hashCode => Object.hash(kind, trump);
}

/// Ist die Karte in diesem Spiel Trumpf?
bool isTrump(SkatCard c, GameType g) {
  if (g.isNull) return false;
  if (c.isJack) return true;
  return g.kind == GameKind.suit && c.suit == g.trump;
}

/// Reihenfolge innerhalb einer Farbe (höher = stärker).
int _suitStrength(SkatCard c, GameType g) {
  if (g.isNull) {
    const nullOrder = {
      Rank.sieben: 0, Rank.acht: 1, Rank.neun: 2, Rank.zehn: 3,
      Rank.bube: 4, Rank.dame: 5, Rank.koenig: 6, Rank.ass: 7,
    };
    return nullOrder[c.rank]!;
  }
  return c.rank.order; // ohne Buben relevant
}

/// Stärke einer Karte im Stich. Rückgabe -1 wenn die Karte nicht sticht.
int cardStrength(SkatCard c, GameType g, SkatCard lead) {
  if (isTrump(c, g)) {
    if (c.isJack) return 200 + c.suit.index;
    return 100 + c.rank.order;
  }
  if (c.suit == lead.suit && !isTrump(lead, g)) return _suitStrength(c, g);
  return -1;
}

/// Zählt die Farbe, die angespielt wurde ("Trumpf" wenn Trumpfkarte).
bool followsLead(SkatCard c, SkatCard lead, GameType g) {
  final leadTrump = isTrump(lead, g);
  if (leadTrump) return isTrump(c, g);
  return !isTrump(c, g) && c.suit == lead.suit;
}

List<SkatCard> legalMoves(List<SkatCard> hand, List<SkatCard> trick, GameType g) {
  if (trick.isEmpty) return List.of(hand);
  final lead = trick.first;
  final following = hand.where((c) => followsLead(c, lead, g)).toList();
  return following.isEmpty ? List.of(hand) : following;
}

/// Index (im Stich) der stechenden Karte.
int trickWinnerIndex(List<SkatCard> trick, GameType g) {
  final lead = trick.first;
  var best = 0;
  var bestStrength = cardStrength(lead, g, lead);
  for (var i = 1; i < trick.length; i++) {
    final s = cardStrength(trick[i], g, lead);
    if (s > bestStrength) {
      best = i;
      bestStrength = s;
    }
  }
  return best;
}

int pointsOf(Iterable<SkatCard> cards) => cards.fold(0, (a, c) => a + c.points);

/// Spitzen "mit/ohne": Anzahl der aufeinanderfolgenden Buben von Kreuz-Bube an.
/// Rückgabe: (mit?, anzahl). Gilt nur für Farb- und Grandspiele.
(bool, int) spitzen(Iterable<SkatCard> cards, GameType g) {
  final jacks = cards.where((c) => c.isJack).map((c) => c.suit).toSet();
  final hasClubs = jacks.contains(Suit.kreuz);
  final order = [Suit.kreuz, Suit.pik, Suit.herz, Suit.karo];
  var n = 0;
  for (final s in order) {
    if (jacks.contains(s) == hasClubs) {
      n++;
    } else {
      break;
    }
  }
  if (g.kind == GameKind.suit) {
    // Trumpffarbe zählt weiter, wenn alle 4 Buben in einer Hand sind.
    if (n == 4) {
      final tr = g.trump!;
      final ranks = [Rank.ass, Rank.zehn, Rank.koenig, Rank.dame, Rank.neun, Rank.acht, Rank.sieben];
      for (final r in ranks) {
        if (cards.contains(SkatCard(tr, r)) == hasClubs) {
          n++;
        } else {
          break;
        }
      }
    }
  }
  return (hasClubs, n);
}
