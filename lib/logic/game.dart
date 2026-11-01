import 'dart:math';
import 'package:flutter/foundation.dart';
import 'bot.dart';
import 'cards.dart';
import 'models.dart';
import 'rules.dart';
import 'scoring.dart';
import 'view.dart';

export 'models.dart';

/// Autoritativer Spielzustand für 3 oder 4 Sitze (bei 4 setzt der Geber aus).
/// Alle Aktionen prüfen Sitz, Phase und Regeln und geben `false` zurück, wenn sie ungültig sind.
class SkatGame extends ChangeNotifier {
  SkatGame({
    required List<SeatInfo> seats,
    Random? rng,
    this.botDelay = const Duration(milliseconds: 700),
    this.trickDelay = const Duration(milliseconds: 1400),
  })  : assert(seats.length == 3 || seats.length == 4),
        seats = List.of(seats),
        n = seats.length,
        _rng = rng ?? Random() {
    dealer = _rng.nextInt(n);
    totals = List.filled(n, 0);
    deal();
  }

  final int n;
  final List<SeatInfo> seats;
  final Random _rng;
  Duration botDelay;
  Duration trickDelay;

  late int dealer;
  late List<int> totals;
  int round = 0;

  List<List<SkatCard>> hands = [];
  List<SkatCard> skat = [];
  Phase phase = Phase.bidding;

  // Reizen
  int stage = 0;
  int caller = 0, responder = 0;
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
  List<int> points = [];
  List<int> tricksWon = [];
  List<SkatCard> discarded = [];
  List<SkatCard> lastTrick = [];
  List<int> lastTrickSeats = [];
  int? lastTrickWinner;
  RoundResult? result;
  String message = '';

  bool _disposed = false;
  bool _botScheduled = false;
  int _gen = 0;

  /// Sitzreihenfolge der drei aktiven Spieler: Vorhand, Mittelhand, Hinterhand.
  List<int> get order => [for (var k = 1; k <= 3; k++) (dealer + k) % n];
  int get vorhand => order[0];
  int get mittelhand => order[1];
  int get hinterhand => order[2];

  int nextActive(int seat) {
    final o = order;
    return o[(o.indexOf(seat) + 1) % 3];
  }

  String name(int seat) => seats[seat].name;

  /// Sitz, der gerade etwas tun muss (null, wenn nichts ansteht).
  int? get actingSeat => switch (phase) {
        Phase.bidding => callerToAct ? caller : responder,
        Phase.decide18 || Phase.handDecision || Phase.discard => declarer,
        Phase.playing => turn,
        _ => null,
      };

  int get nextBid {
    for (final v in bidValues()) {
      if (v > bid) return v;
    }
    return bid + 1;
  }

  // ---------- Geben ----------
  void deal() {
    _gen++;
    _botScheduled = false;
    final deck = shuffledDeck(_rng);
    dealer = (dealer + 1) % n;
    hands = List.generate(n, (_) => <SkatCard>[]);
    final o = order;
    for (var i = 0; i < 3; i++) {
      hands[o[i]] = deck.sublist(i * 10, i * 10 + 10)..sort(handCompare);
    }
    skat = deck.sublist(30, 32);
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
    points = List.filled(n, 0);
    tricksWon = List.filled(n, 0);
    discarded = [];
    lastTrick = [];
    lastTrickSeats = [];
    lastTrickWinner = null;
    result = null;
    turn = vorhand;
    phase = Phase.bidding;
    round++;
    message = 'Neue Runde. ${name(mittelhand)} beginnt mit dem Reizen.';
    _changed();
  }

  bool nextRound() {
    if (phase != Phase.roundOver && phase != Phase.allPassed) return false;
    deal();
    return true;
  }

  // ---------- Reizen ----------
  bool bidCall(int seat) {
    if (phase != Phase.bidding || !callerToAct || seat != caller) return false;
    bid = nextBid;
    callerToAct = false;
    message = '${name(caller)} sagt $bid.';
    _changed();
    return true;
  }

  bool bidHold(int seat) {
    if (phase != Phase.bidding || callerToAct || seat != responder) return false;
    callerToAct = true;
    message = '${name(responder)} hält.';
    _changed();
    return true;
  }

  bool bidPass(int seat) {
    if (phase != Phase.bidding || seat != actingSeat) return false;
    final loser = seat;
    final winner = callerToAct ? responder : caller;
    message = '${name(loser)} passt.';
    _stageEnd(winner);
    return true;
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
      message = '${name(winner)} muss spielen oder einwerfen.';
    } else {
      phase = Phase.handDecision;
      message = '${name(winner)} spielt (Gebot $bid).';
    }
    _changed();
  }

  bool decide18(int seat, bool play) {
    if (phase != Phase.decide18 || seat != declarer) return false;
    if (!play) {
      phase = Phase.allPassed;
      message = 'Alle haben gepasst – neu geben.';
    } else {
      bid = 18;
      phase = Phase.handDecision;
      message = '${name(seat)} spielt (Gebot 18).';
    }
    _changed();
    return true;
  }

  // ---------- Skat / Spielwahl ----------
  bool pickUpSkat(int seat) {
    if (phase != Phase.handDecision || seat != declarer) return false;
    hands[seat] = [...hands[seat], ...skat]..sort(handCompare);
    twelve = List.of(hands[seat]);
    isHand = false;
    phase = Phase.discard;
    message = '${name(seat)} nimmt den Skat auf.';
    _changed();
    return true;
  }

  bool playHand(int seat, GameType g) {
    if (phase != Phase.handDecision || seat != declarer) return false;
    isHand = true;
    twelve = List.of(hands[seat]);
    _startPlay(g);
    return true;
  }

  bool discardAndPlay(int seat, List<SkatCard> two, GameType g) {
    if (phase != Phase.discard || seat != declarer) return false;
    if (two.length != 2 || two[0] == two[1]) return false;
    if (!two.every(hands[seat].contains)) return false;
    discarded = List.of(two);
    hands[seat] = hands[seat].where((c) => !two.contains(c)).toList();
    _startPlay(g);
    return true;
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
    message = '${name(declarer!)} spielt ${g.label}${isHand ? ' Hand' : ''}.';
    _changed();
  }

  // ---------- Stichspiel ----------
  List<SkatCard> legalFor(int seat) =>
      phase == Phase.playing && seat == turn ? legalMoves(hands[seat], trick, game!) : const [];

  bool playCard(int seat, SkatCard c) {
    if (phase != Phase.playing || seat != turn) return false;
    if (!hands[seat].contains(c)) return false;
    if (!legalMoves(hands[seat], trick, game!).contains(c)) return false;
    hands[seat].remove(c);
    trick.add(c);
    trickSeats.add(seat);
    if (trick.length == 3) {
      final w = trickSeats[trickWinnerIndex(trick, game!)];
      lastTrick = List.of(trick);
      lastTrickSeats = List.of(trickSeats);
      lastTrickWinner = w;
      points[w] += pointsOf(trick);
      tricksWon[w]++;
      phase = Phase.trickDone;
      message = '${name(w)} sticht.';
      turn = w;
    } else {
      turn = nextActive(seat);
    }
    _changed();
    return true;
  }

  void collectTrick() {
    if (phase != Phase.trickDone) return;
    trick = [];
    trickSeats = [];
    if (order.every((s) => hands[s].isEmpty)) {
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
    var schneider = false, schwarz = false;
    if (g.isNull) {
      won = dTricks == 0;
    } else {
      won = dPoints >= 61;
      schneider = won ? dPoints >= 90 : dPoints <= 30;
      schwarz = won ? dTricks == 10 : dTricks == 0;
    }
    final (_, sp) = g.isNull ? (true, 0) : spitzen(twelve, g);
    final input = ScoreInput(
      game: g,
      spitzen: sp,
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
    message = score > 0 ? '${name(d)} gewinnt!' : '${name(d)} verliert.';
  }

  // ---------- Ansicht ----------
  GameView viewFor(int seat) {
    final d = declarer;
    var augen = 0;
    if (d != null && game != null) {
      if (seat == d) {
        augen = points[d] + (isHand ? 0 : pointsOf(discarded));
      } else {
        for (final s in order) {
          if (s != d) augen += points[s];
        }
      }
    }
    final over = phase == Phase.roundOver;
    return GameView(
      n: n,
      names: [for (final s in seats) s.name],
      isBot: [for (final s in seats) s.isBot],
      mySeat: seat,
      dealer: dealer,
      phase: phase,
      actingSeat: actingSeat,
      callerToAct: callerToAct,
      caller: caller,
      responder: responder,
      bid: bid,
      nextBid: nextBid,
      declarer: declarer,
      game: game,
      isHand: isHand,
      myHand: List.of(hands[seat]),
      handSizes: [for (final h in hands) h.length],
      legal: legalFor(seat),
      trick: List.of(trick),
      trickSeats: List.of(trickSeats),
      turn: turn,
      tricksWon: List.of(tricksWon),
      totals: List.of(totals),
      message: message,
      result: result,
      lastTrick: List.of(lastTrick),
      lastTrickSeats: List.of(lastTrickSeats),
      lastTrickWinner: lastTrickWinner,
      revealedSkat: over ? (isHand ? List.of(skat) : List.of(discarded)) : const [],
      myAugen: augen,
      round: round,
    );
  }

  // ---------- Bots ----------
  void _changed() {
    if (_disposed) return;
    notifyListeners();
    _scheduleBot();
  }

  bool get _botToAct {
    if (phase == Phase.trickDone) return true;
    final a = actingSeat;
    return a != null && seats[a].isBot;
  }

  void _scheduleBot() {
    if (_botScheduled || !_botToAct) return;
    _botScheduled = true;
    final gen = _gen;
    final delay = phase == Phase.trickDone ? trickDelay : botDelay;
    Future.delayed(delay, () {
      _botScheduled = false;
      if (_disposed || gen != _gen) return;
      _botStep();
      // Falls der Schritt nichts geändert hat, nicht endlos neu planen.
    });
  }

  void _botStep() {
    if (phase == Phase.trickDone) {
      collectTrick();
      return;
    }
    final a = actingSeat;
    if (a == null || !seats[a].isBot) return;
    switch (phase) {
      case Phase.bidding:
        final limit = maxBid(hands[a]);
        if (callerToAct) {
          nextBid <= limit ? bidCall(a) : bidPass(a);
        } else {
          bid <= limit ? bidHold(a) : bidPass(a);
        }
      case Phase.decide18:
        decide18(a, bestGame(hands[a]) != null || _rng.nextBool());
      case Phase.handDecision:
        final choice = bestGame(hands[a]);
        if (choice != null && choice.value >= bid && choice.value >= 48 && !choice.game.isNull) {
          playHand(a, choice.game);
        } else {
          pickUpSkat(a);
        }
      case Phase.discard:
        final choice = bestGame(hands[a]) ?? GameChoice(_fallbackGame(hands[a]), 0);
        final two = chooseDiscard(hands[a], choice.game);
        final remaining = hands[a].where((c) => !two.contains(c)).toList();
        final g = bestGame(remaining)?.game ?? choice.game;
        discardAndPlay(a, two, g);
      case Phase.playing:
        final c = botPlay(
          hand: hands[a],
          trick: trick,
          seatsInTrick: trickSeats,
          seat: a,
          declarer: declarer!,
          game: game!,
        );
        playCard(a, c);
      default:
        break;
    }
  }

  GameType _fallbackGame(List<SkatCard> h) {
    final counts = {for (final s in Suit.values) s: h.where((c) => c.suit == s && !c.isJack).length};
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return GameType.suit(best);
  }

  /// Ein Mensch ist weg (Verbindung verloren): Bot übernimmt den Sitz.
  void replaceWithBot(int seat) {
    seats[seat].isBot = true;
    seats[seat].name = '${seats[seat].name} (Bot)';
    _changed();
  }

  void resetTotals() {
    totals = List.filled(n, 0);
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
