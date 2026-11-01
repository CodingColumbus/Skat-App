import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'bot.dart';
import 'cards.dart';
import 'rules.dart';
import 'scoring.dart';

enum Phase { bidding, decide18, handDecision, discard, playing, trickDone, roundOver, allPassed }

class RoundResult {
  final int declarer;
  final GameType game;
  final bool won;
  final int declarerPoints;
  final int score;
  final int gameValue;
  final bool schneider, schwarz, hand;
  const RoundResult({
    required this.declarer,
    required this.game,
    required this.won,
    required this.declarerPoints,
    required this.score,
    required this.gameValue,
    required this.schneider,
    required this.schwarz,
    required this.hand,
  });
}

/// Spielzustand für 3 Spieler: Sitz 0 = Mensch, 1 und 2 = Bots.
class SkatGame extends ChangeNotifier {
  SkatGame({Random? rng, this.botDelay = const Duration(milliseconds: 700)})
      : _rng = rng ?? Random() {
    deal();
  }

  final Random _rng;
  final Duration botDelay;
  final List<String> names = ['Du', 'Anna', 'Max'];
  final List<int> totals = [0, 0, 0];

  int dealer = 2;
  List<List<SkatCard>> hands = [[], [], []];
  List<SkatCard> skat = [];
  Phase phase = Phase.bidding;

  // Reizen
  int stage = 0;
  late int caller;
  late int responder;
  int bid = 0;
  bool callerToAct = true;
  int? declarer;
  GameType? game;
  bool isHand = false;
  List<SkatCard> twelve = [];

  // Spiel
  List<SkatCard> trick = [];
  List<int> trickSeats = [];
  int turn = 0;
  List<int> points = [0, 0, 0];
  List<int> tricksWon = [0, 0, 0];
  List<SkatCard> discarded = [];
  int? lastTrickWinner;
  RoundResult? result;
  String message = '';
  bool _disposed = false;
  int _gen = 0;

  int get vorhand => (dealer + 1) % 3;
  int get mittelhand => (dealer + 2) % 3;
  int get hinterhand => dealer;

  List<SkatCard> get myHand => hands[0];
  bool get humanTurn => switch (phase) {
        Phase.bidding => (callerToAct ? caller : responder) == 0,
        Phase.decide18 || Phase.handDecision || Phase.discard => declarer == 0,
        Phase.playing => turn == 0,
        _ => false,
      };

  void deal() {
    _gen++;
    final deck = shuffledDeck(_rng);
    hands = [deck.sublist(0, 10), deck.sublist(10, 20), deck.sublist(20, 30)];
    for (final h in hands) {
      h.sort(handCompare);
    }
    skat = deck.sublist(30, 32);
    dealer = (dealer + 1) % 3;
    stage = 0;
    caller = mittelhand;
    responder = vorhand;
    bid = 0;
    callerToAct = true;
    declarer = null;
    game = null;
    isHand = false;
    twelve = [];
    trick = [];
    trickSeats = [];
    points = [0, 0, 0];
    tricksWon = [0, 0, 0];
    discarded = [];
    lastTrickWinner = null;
    result = null;
    phase = Phase.bidding;
    message = '${names[vorhand]} spielt aus.';
    _changed();
  }

  // ---------- Reizen ----------
  int get nextBid {
    for (final v in bidValues()) {
      if (v > bid) return v;
    }
    return bid + 1;
  }

  /// Aktueller Sprecher beim Reizen.
  int get bidActor => callerToAct ? caller : responder;

  void humanBid() => _bidCall();
  void humanHold() => _bidHold();
  void humanPass() => _bidPass();

  void _bidCall() {
    bid = nextBid;
    callerToAct = false;
    message = '${names[caller]} sagt $bid.';
    _changed();
  }

  void _bidHold() {
    callerToAct = true;
    message = '${names[responder]}: ja.';
    _changed();
  }

  void _bidPass() {
    // Aktueller Sprecher passt.
    final loser = bidActor;
    final winner = callerToAct ? responder : caller;
    message = '${names[loser]} passt.';
    _stageEnd(winner);
  }

  void _stageEnd(int winner) {
    if (stage == 0) {
      stage = 1;
      caller = hinterhand;
      responder = winner;
      callerToAct = true;
      _changed();
      return;
    }
    declarer = winner;
    if (bid == 0) {
      phase = Phase.decide18;
      message = '${names[winner]} muss spielen oder einwerfen.';
    } else {
      _afterBidding();
    }
    _changed();
  }

  void decide18(bool play) {
    if (!play) {
      phase = Phase.allPassed;
      message = 'Alle haben gepasst – neu geben.';
      _changed();
      return;
    }
    bid = 18;
    _afterBidding();
    _changed();
  }

  void _afterBidding() {
    phase = Phase.handDecision;
    message = '${names[declarer!]} spielt (Gebot $bid).';
  }

  // ---------- Skat / Spielwahl ----------
  void pickUpSkat() {
    final d = declarer!;
    hands[d] = [...hands[d], ...skat]..sort(handCompare);
    twelve = List.of(hands[d]);
    isHand = false;
    phase = Phase.discard;
    _changed();
  }

  void playHand(GameType g) {
    isHand = true;
    twelve = List.of(hands[declarer!]);
    _startPlay(g);
  }

  void discardAndPlay(List<SkatCard> two, GameType g) {
    final d = declarer!;
    assert(two.length == 2);
    discarded = List.of(two);
    hands[d] = hands[d].where((c) => !two.contains(c)).toList();
    _startPlay(g);
  }

  void _startPlay(GameType g) {
    game = g;
    for (final h in hands) {
      h.sort(handCompare);
    }
    phase = Phase.playing;
    turn = vorhand;
    trick = [];
    trickSeats = [];
    message = '${names[declarer!]} spielt ${g.label}${isHand ? ' Hand' : ''}.';
    _changed();
  }

  // ---------- Stichspiel ----------
  List<SkatCard> legalForHuman() => phase == Phase.playing && turn == 0
      ? legalMoves(hands[0], trick, game!)
      : const [];

  void playCard(SkatCard c) {
    if (phase != Phase.playing) return;
    final seat = turn;
    assert(hands[seat].contains(c));
    hands[seat].remove(c);
    trick.add(c);
    trickSeats.add(seat);
    if (trick.length == 3) {
      final w = trickSeats[trickWinnerIndex(trick, game!)];
      lastTrickWinner = w;
      points[w] += pointsOf(trick);
      tricksWon[w]++;
      phase = Phase.trickDone;
      message = '${names[w]} sticht.';
      turn = w;
    } else {
      turn = (seat + 1) % 3;
    }
    _changed();
  }

  /// Stich abräumen und weiterspielen bzw. Runde beenden.
  void collectTrick() {
    if (phase != Phase.trickDone) return;
    trick = [];
    trickSeats = [];
    if (hands.every((h) => h.isEmpty)) {
      _finishRound();
    } else {
      phase = Phase.playing;
    }
    _changed();
  }

  void _finishRound() {
    final d = declarer!;
    final g = game!;
    final dPoints = points[d] + (isHand ? pointsOf(skat) : pointsOf(discarded));
    final dTricks = tricksWon[d];
    bool won;
    bool schneider = false, schwarz = false;
    if (g.isNull) {
      won = dTricks == 0;
    } else {
      won = dPoints >= 61;
      schneider = won ? dPoints >= 90 : dPoints <= 30;
      schwarz = won ? dTricks == 10 : dTricks == 0;
    }
    final (_, n) = g.isNull ? (true, 0) : spitzen(twelve, g);
    final input = ScoreInput(
      game: g,
      spitzen: n,
      hand: isHand,
      schneider: schneider,
      schwarz: schwarz,
      won: won,
      bid: bid,
    );
    final score = scoreFor(input);
    totals[d] += score;
    result = RoundResult(
      declarer: d,
      game: g,
      won: score > 0,
      declarerPoints: dPoints,
      score: score,
      gameValue: gameValue(input),
      schneider: schneider,
      schwarz: schwarz,
      hand: isHand,
    );
    phase = Phase.roundOver;
    message = score > 0 ? '${names[d]} gewinnt!' : '${names[d]} verliert.';
  }

  // ---------- Bots ----------
  void _changed() {
    if (_disposed) return;
    notifyListeners();
    _scheduleBot();
  }

  bool get _botToAct {
    switch (phase) {
      case Phase.bidding:
        return bidActor != 0;
      case Phase.decide18:
      case Phase.handDecision:
      case Phase.discard:
        return declarer != 0;
      case Phase.playing:
        return turn != 0;
      case Phase.trickDone:
        return true; // automatisch abräumen
      default:
        return false;
    }
  }

  void _scheduleBot() {
    if (!_botToAct) return;
    final gen = _gen;
    final delay = phase == Phase.trickDone
        ? (botDelay == Duration.zero ? Duration.zero : const Duration(milliseconds: 1100))
        : botDelay;
    Future.delayed(delay, () {
      if (_disposed || gen != _gen) return;
      _botStep();
    });
  }

  void _botStep() {
    switch (phase) {
      case Phase.bidding:
        _botBid();
      case Phase.decide18:
        decide18(bestGame(hands[declarer!]) != null || _rng.nextBool());
      case Phase.handDecision:
        final d = declarer!;
        final choice = bestGame(hands[d]);
        // Hand spielen bei sehr starker Hand
        if (choice != null && choice.value >= bid && choice.value >= 48 && !choice.game.isNull) {
          playHand(choice.game);
        } else {
          pickUpSkat();
        }
      case Phase.discard:
        final d = declarer!;
        final choice = bestGame(hands[d]) ?? GameChoice(_fallbackGame(hands[d]), 0);
        final two = chooseDiscard(hands[d], choice.game);
        // Spiel mit 10 Karten erneut bewerten
        final remaining = hands[d].where((c) => !two.contains(c)).toList();
        final g = bestGame(remaining)?.game ?? choice.game;
        discardAndPlay(two, g);
      case Phase.playing:
        final seat = turn;
        final c = botPlay(
          hand: hands[seat],
          trick: trick,
          seatsInTrick: trickSeats,
          seat: seat,
          declarer: declarer!,
          game: game!,
        );
        playCard(c);
      case Phase.trickDone:
        collectTrick();
      default:
        break;
    }
  }

  GameType _fallbackGame(List<SkatCard> h) {
    // Häufigste Farbe als Trumpf
    final counts = {for (final s in Suit.values) s: h.where((c) => c.suit == s && !c.isJack).length};
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return GameType.suit(best);
  }

  void _botBid() {
    final actor = bidActor;
    final limit = maxBid(hands[actor]);
    if (callerToAct) {
      if (nextBid <= limit) {
        _bidCall();
      } else {
        _bidPass();
      }
    } else {
      if (bid <= limit) {
        _bidHold();
      } else {
        _bidPass();
      }
    }
  }

  void newRound() => deal();

  void resetTotals() {
    for (var i = 0; i < 3; i++) {
      totals[i] = 0;
    }
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
