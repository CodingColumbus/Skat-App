import 'cards.dart';
import 'rules.dart';
import 'scoring.dart';

/// Ergebnis der Handbewertung eines Bots.
class GameChoice {
  final GameType game;
  final int value; // geschätzter Reizwert
  const GameChoice(this.game, this.value);
}

int _jacks(List<SkatCard> h) => h.where((c) => c.isJack).length;

int _trumpCount(List<SkatCard> h, GameType g) => h.where((c) => isTrump(c, g)).length;

int _aces(List<SkatCard> h, {Suit? except}) =>
    h.where((c) => c.rank == Rank.ass && c.suit != except).length;

/// Bestes Spiel für eine Hand (10 oder 12 Karten). null = nichts spielbar.
GameChoice? bestGame(List<SkatCard> hand) {
  GameChoice? best;
  void consider(GameType g, int value) {
    if (best == null || value > best!.value) best = GameChoice(g, value);
  }

  final j = _jacks(hand);
  // Farbspiele
  for (final s in Suit.values) {
    final g = GameType.suit(s);
    final t = _trumpCount(hand, g);
    final a = _aces(hand, except: s);
    final ok = (j >= 2 && t >= 5) || (j >= 3 && t >= 4) || (j >= 1 && t >= 6) ||
        (j >= 2 && t >= 4 && a >= 2);
    if (!ok) continue;
    final (_, n) = spitzen(hand, g);
    consider(g, s.baseValue * (n + 1));
  }
  // Grand
  const grand = GameType.grand();
  if (j >= 3 || (j == 2 && _aces(hand) >= 3 && hand.any((c) => c.suit == Suit.kreuz && c.isJack))) {
    final (_, n) = spitzen(hand, grand);
    consider(grand, 24 * (n + 1));
  }
  // Null
  final high = hand.where((c) => c.rank == Rank.ass || c.rank == Rank.koenig || c.rank == Rank.zehn).length;
  if (j == 0 && high <= 2 && _aces(hand) == 0 && best == null) {
    consider(const GameType.nullGame(), 23);
  }
  return best;
}

/// Höchstes Gebot, bis zu dem ein Bot mitgeht (0 = nie).
int maxBid(List<SkatCard> hand) => bestGame(hand)?.value ?? 0;

/// Wählt zwei Karten zum Drücken aus 12 Karten.
List<SkatCard> chooseDiscard(List<SkatCard> twelve, GameType g) {
  final cards = List.of(twelve);
  if (g.isNull) {
    cards.sort((a, b) => cardOrderNull(b) - cardOrderNull(a));
    return cards.take(2).toList();
  }
  // Nicht-Trumpf-Karten, möglichst Singles/Kurzfarben mit hohen Augen, Asse behalten.
  final cands = cards.where((c) => !isTrump(c, g) && c.rank != Rank.ass).toList();
  int suitLen(Suit s) => cards.where((c) => c.suit == s && !isTrump(c, g)).length;
  cands.sort((a, b) {
    final la = suitLen(a.suit), lb = suitLen(b.suit);
    // Kürzere Farben zuerst, dann mehr Augen
    if (la != lb) return la - lb;
    return b.points - a.points;
  });
  final out = cands.take(2).toList();
  if (out.length < 2) {
    final rest = cards.where((c) => !out.contains(c)).toList()
      ..sort((a, b) => a.points - b.points);
    out.addAll(rest.take(2 - out.length));
  }
  return out;
}

int cardOrderNull(SkatCard c) {
  const o = {
    Rank.sieben: 0, Rank.acht: 1, Rank.neun: 2, Rank.zehn: 3,
    Rank.bube: 4, Rank.dame: 5, Rank.koenig: 6, Rank.ass: 7,
  };
  return o[c.rank]!;
}

/// Kartenwahl eines Bots.
/// [trick]: bisher gespielte Karten (in Spielreihenfolge),
/// [seatsInTrick]: Sitze dazu, [declarer]: Sitz des Alleinspielers.
SkatCard botPlay({
  required List<SkatCard> hand,
  required List<SkatCard> trick,
  required List<int> seatsInTrick,
  required int seat,
  required int declarer,
  required GameType game,
}) {
  final legal = legalMoves(hand, trick, game);
  if (legal.length == 1) return legal.first;
  final amDeclarer = seat == declarer;

  if (game.isNull) return _nullPlay(legal, trick, game, amDeclarer);

  int cost(SkatCard c) => (isTrump(c, game) ? 100 : 0) + c.points + c.rank.order;

  if (trick.isEmpty) {
    // Ausspielen
    final trumps = legal.where((c) => isTrump(c, game)).toList()
      ..sort((a, b) => cardStrength(b, game, b) - cardStrength(a, game, a));
    if (amDeclarer) {
      if (trumps.length >= 3) return trumps.first;
      final aces = legal.where((c) => c.rank == Rank.ass && !isTrump(c, game)).toList();
      if (aces.isNotEmpty) return aces.first;
      if (trumps.isNotEmpty) return trumps.first;
    } else {
      final aces = legal.where((c) => c.rank == Rank.ass && !isTrump(c, game)).toList();
      if (aces.isNotEmpty) return aces.first;
    }
    final sorted = List.of(legal)..sort((a, b) => cost(a) - cost(b));
    return sorted.first;
  }

  // Zugeben
  final lead = trick.first;
  final wi = trickWinnerIndex(trick, game);
  final winnerSeat = seatsInTrick[wi];
  final winning = trick[wi];
  final last = trick.length == 2;
  final winners = legal.where((c) => cardStrength(c, game, lead) > cardStrength(winning, game, lead)).toList()
    ..sort((a, b) => cost(a) - cost(b));
  final partnerWinning = !amDeclarer && winnerSeat != declarer;

  if (partnerWinning) {
    // Schmieren, wenn der Stich sicher ist (ich bin letzter) – sonst niedrig.
    if (last) {
      final s = List.of(legal)..sort((a, b) => b.points - a.points);
      return s.first;
    }
    final s = List.of(legal)..sort((a, b) => cost(a) - cost(b));
    return s.first;
  }
  if (winners.isNotEmpty) {
    // Billigsten gewinnenden Stich nehmen; Punktelastige bevorzugen wenn viel im Stich liegt.
    return winners.first;
  }
  final s = List.of(legal)..sort((a, b) => cost(a) - cost(b));
  return s.first;
}

SkatCard _nullPlay(List<SkatCard> legal, List<SkatCard> trick, GameType g, bool declarer) {
  final sorted = List.of(legal)..sort((a, b) => cardOrderNull(a) - cardOrderNull(b));
  if (trick.isEmpty) return sorted.first;
  final lead = trick.first;
  final wi = trickWinnerIndex(trick, g);
  final winning = trick[wi];
  final under = sorted.where((c) => cardStrength(c, g, lead) < cardStrength(winning, g, lead)).toList();
  if (declarer) {
    // Möglichst drunter bleiben (höchste Karte darunter), sonst niedrigste.
    if (under.isNotEmpty) return under.last;
    return sorted.first;
  }
  return sorted.first;
}

/// Wie viel Spielwert hat das ausgewählte Spiel mit diesen Karten (für Anzeige).
int estimateValue(List<SkatCard> cards, GameType g, {bool hand = false}) {
  if (g.isNull) return gameValue(ScoreInput(game: g, hand: hand, won: true));
  final (_, n) = spitzen(cards, g);
  return gameValue(ScoreInput(game: g, spitzen: n, hand: hand, won: true));
}
