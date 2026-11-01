import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:skat_app/logic/cards.dart';
import 'package:skat_app/logic/game.dart';
import 'package:skat_app/logic/rules.dart';
import 'package:skat_app/logic/scoring.dart';
import 'package:skat_app/logic/view.dart';

/// Unabhängige Referenz für die Bedienpflicht (absichtlich getrennt von rules.dart geschrieben).
String _cat(SkatCard c, GameType g) {
  if (g.kind == GameKind.nullGame) return c.suit.name;
  if (c.rank == Rank.bube) return 'T';
  if (g.kind == GameKind.suit && c.suit == g.trump) return 'T';
  return c.suit.name;
}

List<SkatCard> _refLegal(List<SkatCard> hand, List<SkatCard> trick, GameType g) {
  if (trick.isEmpty) return hand;
  final lead = _cat(trick.first, g);
  final same = hand.where((c) => _cat(c, g) == lead).toList();
  return same.isEmpty ? hand : same;
}

const _games = [
  GameType.suit(Suit.karo),
  GameType.suit(Suit.herz),
  GameType.suit(Suit.pik),
  GameType.suit(Suit.kreuz),
  GameType.grand(),
  GameType.nullGame(),
];

List<SeatInfo> _humans(int n) => [for (var i = 0; i < n; i++) SeatInfo('P$i', false)];

/// Spielt eine Runde mit zufälligen (erlaubten) Zügen und prüft dabei die Regeln.
void _playRandomRound(SkatGame g, Random r) {
  var guard = 0;
  while (g.phase != Phase.roundOver && g.phase != Phase.allPassed && guard++ < 1000) {
    final a = g.actingSeat;
    switch (g.phase) {
      case Phase.bidding:
        final pass = r.nextInt(3) == 0;
        if (g.callerToAct) {
          pass ? g.bidPass(a!) : g.bidCall(a!);
        } else {
          pass ? g.bidPass(a!) : g.bidHold(a!);
        }
      case Phase.decide18:
        g.decide18(a!, r.nextBool());
      case Phase.handDecision:
        r.nextBool() ? g.pickUpSkat(a!) : g.playHand(a!, _games[r.nextInt(6)]);
      case Phase.discard:
        expect(g.hands[a!].length, 12);
        g.discardAndPlay(a, g.hands[a].take(2).toList(), _games[r.nextInt(6)]);
      case Phase.playing:
        final seat = a!;
        final hand = List.of(g.hands[seat]);
        final legal = _refLegal(hand, g.trick, g.game!);
        for (final c in hand) {
          if (!legal.contains(c)) {
            final before = g.hands[seat].length;
            expect(g.playCard(seat, c), false, reason: 'Illegale Karte $c wurde akzeptiert');
            expect(g.hands[seat].length, before);
          }
        }
        // Falsche Sitze dürfen nicht spielen
        for (var s = 0; s < g.n; s++) {
          if (s != seat) expect(g.playCard(s, hand.first), false);
        }
        expect(Set.of(g.legalFor(seat)), Set.of(legal), reason: 'legalFor weicht von der Referenz ab');
        expect(g.playCard(seat, legal[r.nextInt(legal.length)]), true);
      case Phase.trickDone:
        g.collectTrick();
      default:
        fail('unerwartete Phase ${g.phase}');
    }
  }
  expect(guard < 1000, true, reason: 'Runde endet nicht');
  if (g.phase == Phase.roundOver) {
    final total = g.points.fold(0, (x, y) => x + y) + pointsOf(g.isHand ? g.skat : g.discarded);
    expect(total, 120);
    expect(g.hands.every((h) => h.isEmpty), true);
    expect(g.result, isNotNull);
  }
}

void main() {
  test('Deck hat 32 Karten, 120 Augen', () {
    final d = fullDeck();
    expect(d.length, 32);
    expect(pointsOf(d), 120);
  });

  test('Buben sind Trumpf, Kreuz-Bube sticht Pik-Bube', () {
    const g = GameType.suit(Suit.herz);
    final trick = [
      const SkatCard(Suit.herz, Rank.ass),
      const SkatCard(Suit.pik, Rank.bube),
      const SkatCard(Suit.kreuz, Rank.bube),
    ];
    expect(trickWinnerIndex(trick, g), 2);
  });

  test('Bedienpflicht: Bube ist keine Farbkarte', () {
    const g = GameType.suit(Suit.karo);
    final hand = [const SkatCard(Suit.pik, Rank.bube), const SkatCard(Suit.pik, Rank.ass), const SkatCard(Suit.herz, Rank.sieben)];
    final legal = legalMoves(hand, [const SkatCard(Suit.pik, Rank.zehn)], g);
    expect(legal, [const SkatCard(Suit.pik, Rank.ass)]);
  });

  test('Trumpf angespielt: nur Trumpf (auch Buben) erlaubt', () {
    const g = GameType.suit(Suit.herz);
    final hand = [const SkatCard(Suit.pik, Rank.bube), const SkatCard(Suit.herz, Rank.sieben), const SkatCard(Suit.pik, Rank.ass)];
    final legal = legalMoves(hand, [const SkatCard(Suit.herz, Rank.ass)], g);
    expect(Set.of(legal), {const SkatCard(Suit.pik, Rank.bube), const SkatCard(Suit.herz, Rank.sieben)});
  });

  test('Null: 10 liegt zwischen 9 und Bube', () {
    const g = GameType.nullGame();
    final trick = [const SkatCard(Suit.herz, Rank.neun), const SkatCard(Suit.herz, Rank.zehn)];
    expect(trickWinnerIndex(trick, g), 1);
  });

  test('Spitzen: mit 2 Spiel 3', () {
    const g = GameType.suit(Suit.kreuz);
    final cards = [const SkatCard(Suit.kreuz, Rank.bube), const SkatCard(Suit.pik, Rank.bube), const SkatCard(Suit.karo, Rank.bube)];
    final (mit, n) = spitzen(cards, g);
    expect(mit, true);
    expect(n, 2);
  });

  test('Wertung: Kreuz mit 1 gewonnen = 24, verloren = -48', () {
    const g = GameType.suit(Suit.kreuz);
    expect(scoreFor(const ScoreInput(game: g, spitzen: 1, won: true)), 24);
    expect(scoreFor(const ScoreInput(game: g, spitzen: 1, won: false)), -48);
  });

  test('Wertung: Null Hand 35, Grand mit 2 Hand 96', () {
    expect(gameValue(const ScoreInput(game: GameType.nullGame(), hand: true, won: true)), 35);
    expect(gameValue(const ScoreInput(game: GameType.grand(), spitzen: 2, hand: true, won: true)), 96);
  });

  test('Überreizt: Gebot 30 bei Karo mit 1 -> verloren', () {
    const g = GameType.suit(Suit.karo);
    expect(scoreFor(const ScoreInput(game: g, spitzen: 1, won: true, bid: 30)), -72);
  });

  test('Engine lehnt illegale Züge ab (500 Zufallsrunden, 3 und 4 Sitze)', () {
    final r = Random(42);
    for (final n in [3, 4]) {
      final g = SkatGame(seats: _humans(n), rng: Random(7));
      var finished = 0;
      for (var i = 0; i < 250; i++) {
        _playRandomRound(g, r);
        if (g.phase == Phase.roundOver) finished++;
        expect(g.nextRound(), true);
      }
      expect(finished > 50, true);
      g.dispose();
    }
  });

  test('4 Sitze: Geber setzt aus und bekommt keine Karten', () {
    final g = SkatGame(seats: _humans(4), rng: Random(1));
    for (var i = 0; i < 8; i++) {
      expect(g.hands[g.dealer], isEmpty);
      expect(g.order.contains(g.dealer), false);
      expect(g.order.length, 3);
      g.nextRound();
    }
    g.dispose();
  });

  test('Ansicht überträgt sich verlustfrei als JSON und verbirgt fremde Karten', () {
    final g = SkatGame(seats: _humans(3), rng: Random(3));
    final v = g.viewFor(1);
    final back = GameView.fromJson(v.toJson());
    expect(back.myHand, g.hands[1]);
    expect(back.handSizes, [10, 10, 10]);
    expect(back.names, v.names);
    expect(back.phase, v.phase);
    // Sitz 1 darf Sitz 0s Karten nicht in seiner Ansicht haben.
    expect(v.myHand.any(g.hands[0].contains), false);
    expect(v.toJson()['mh'], cardsToJson(g.hands[1]));
    g.dispose();
  });

  for (final n in [3, 4]) {
    test('Bots spielen ganze Runden ohne zu hängen ($n Sitze)', () async {
      final seats = [for (var i = 0; i < n; i++) SeatInfo('B$i', true)];
      final g = SkatGame(seats: seats, botDelay: Duration.zero, trickDelay: Duration.zero, rng: Random(n));
      var rounds = 0;
      final deadline = DateTime.now().add(const Duration(seconds: 25));
      while (rounds < 6 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        if (g.phase == Phase.roundOver || g.phase == Phase.allPassed) {
          if (g.phase == Phase.roundOver) rounds++;
          g.nextRound();
        }
      }
      expect(rounds >= 3, true, reason: 'Bots haben nur $rounds Runden geschafft');
      g.dispose();
    });
  }
}
