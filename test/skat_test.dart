import 'package:flutter_test/flutter_test.dart';
import 'package:skat_app/logic/cards.dart';
import 'package:skat_app/logic/rules.dart';
import 'package:skat_app/logic/scoring.dart';
import 'package:skat_app/logic/game.dart';

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

  test('Bedienpflicht: Bube ist kein Farbkarte', () {
    const g = GameType.suit(Suit.karo);
    final hand = [const SkatCard(Suit.pik, Rank.bube), const SkatCard(Suit.pik, Rank.ass), const SkatCard(Suit.herz, Rank.sieben)];
    final legal = legalMoves(hand, [const SkatCard(Suit.pik, Rank.zehn)], g);
    expect(legal, [const SkatCard(Suit.pik, Rank.ass)]);
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

  test('Wertung: Null Hand 35, Grand mit 2 Hand 24*4', () {
    expect(gameValue(const ScoreInput(game: GameType.nullGame(), hand: true, won: true)), 35);
    expect(gameValue(const ScoreInput(game: GameType.grand(), spitzen: 2, hand: true, won: true)), 96);
  });

  test('Überreizt: Gebot 30 bei Karo mit 1 (18) -> verloren', () {
    const g = GameType.suit(Suit.karo);
    expect(scoreFor(const ScoreInput(game: g, spitzen: 1, won: true, bid: 30)), -72);
  });

  test('Ganze Runde mit Bots läuft durch', () async {
    final game = SkatGame(botDelay: Duration.zero);
    // Mensch spielt automatisch mit: wähle legale Karten.
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (game.phase != Phase.roundOver &&
        game.phase != Phase.allPassed &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
      if (game.humanTurn) {
        switch (game.phase) {
          case Phase.bidding:
            game.humanPass();
          case Phase.decide18:
            game.decide18(true);
          case Phase.handDecision:
            game.pickUpSkat();
          case Phase.discard:
            game.discardAndPlay(game.myHand.take(2).toList(), const GameType.suit(Suit.kreuz));
          case Phase.playing:
            game.playCard(game.legalForHuman().first);
          default:
        }
      }
    }
    expect(game.phase == Phase.roundOver || game.phase == Phase.allPassed, true);
    if (game.phase == Phase.roundOver) {
      expect(game.result, isNotNull);
    }
    game.dispose();
  });
}
