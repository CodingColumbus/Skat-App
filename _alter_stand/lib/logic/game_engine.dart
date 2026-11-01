import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/cards.dart';
import '../models/game_types.dart';
import '../state/app_state.dart';
import 'bot.dart';
import 'rules.dart';
import 'scoring.dart';

enum Phase {
  idle,
  bidding,
  forehandChoice,
  skatChoice,
  discarding,
  declaring,
  playing,
  roundEnd,
  allPassed,
}

/// Angesagtes Spiel.
class Declaration {
  final GameType type;
  final bool hand;
  final bool ouvert;
  final bool schneiderAnnounced;
  final bool schwarzAnnounced;

  const Declaration({
    required this.type,
    this.hand = false,
    this.ouvert = false,
    this.schneiderAnnounced = false,
    this.schwarzAnnounced = false,
  });

  String get label {
    var s = type.nameDe;
    if (type.isNull) {
      if (ouvert) s += ' Ouvert';
      if (hand) s += ' Hand';
      return s;
    }
    if (hand) s += ' Hand';
    if (schwarzAnnounced) {
      s += ', Schwarz angesagt';
    } else if (schneiderAnnounced) {
      s += ', Schneider angesagt';
    }
    return s;
  }
}

class TrickCard {
  final int player;
  final SkatCard card;

  const TrickCard(this.player, this.card);
}

/// Ergebnis einer gespielten Runde.
class RoundReport {
  final int declarer;
  final Declaration declaration;
  final int declarerPoints;
  final int defenderPoints;
  final int declarerTricks;
  final ScoreResult result;
  final List<int> deltas;
  final List<SkatCard> skat;
  final bool endedEarly;

  const RoundReport({
    required this.declarer,
    required this.declaration,
    required this.declarerPoints,
    required this.defenderPoints,
    required this.declarerTricks,
    required this.result,
    required this.deltas,
    required this.skat,
    required this.endedEarly,
  });
}

class GameEngine extends ChangeNotifier {
  GameEngine({required this.settings, Random? random})
      : _rng = random ?? Random() {
    dealer = _rng.nextInt(3);
  }

  static const int humanIndex = 0;

  final AppSettings settings;
  final Random _rng;
  bool _disposed = false;
  int _token = 0;

  List<String> get names => [settings.playerName, 'Anna', 'Ben'];

  // Karten
  List<List<SkatCard>> hands = _emptyHands();
  List<SkatCard> skat = [];
  List<SkatCard> originalSkat = [];
  List<List<SkatCard>> originalHands = _emptyHands();

  int dealer = 0;
  Phase phase = Phase.idle;

  // Reizen
  int stage = 1;
  int caller = 0;
  int listener = 0;
  int currentBid = 0;
  bool callerToAct = true;
  List<int> maxBids = [0, 0, 0];
  List<String> speech = ['', '', ''];

  // Spiel
  int declarer = -1;
  int bidValue = 0;
  bool skatTaken = false;
  Declaration? declaration;
  String message = '';

  // Stiche
  List<TrickCard> trick = [];
  int turn = 0;
  List<List<SkatCard>> tricksWon = _emptyHands();
  List<int> trickCounts = [0, 0, 0];
  final Set<SkatCard> _finished = {};
  bool trickResolving = false;
  int lastTrickWinner = -1;
  RoundReport? report;

  // Sitzung
  List<int> totals = [0, 0, 0];
  int roundsPlayed = 0;
  List<String> history = [];

  static List<List<SkatCard>> _emptyHands() =>
      List.generate(3, (_) => <SkatCard>[]);

  // --------------------------------------------------------------------
  // Rollen
  // --------------------------------------------------------------------

  int get forehand => (dealer + 1) % 3;
  int get middlehand => (dealer + 2) % 3;
  int get hindhand => dealer;

  String roleLabel(int p) {
    if (p == forehand) return 'Vorhand';
    if (p == middlehand) return 'Mittelhand';
    return 'Hinterhand';
  }

  int get _d => settings.botDelayMs;

  void _later(int ms, VoidCallback fn) {
    final t = _token;
    Future.delayed(Duration(milliseconds: ms), () {
      if (_disposed || t != _token) return;
      fn();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _token++;
    super.dispose();
  }

  // --------------------------------------------------------------------
  // Runde starten
  // --------------------------------------------------------------------

  void startRound() {
    _token++;
    final deck = buildDeck()..shuffle(_rng);
    hands = [
      for (var p = 0; p < 3; p++)
        sortedHand(deck.sublist(p * 10, p * 10 + 10)),
    ];
    skat = deck.sublist(30, 32);
    originalSkat = List<SkatCard>.of(skat);
    originalHands = [for (final h in hands) List<SkatCard>.of(h)];
    tricksWon = _emptyHands();
    trickCounts = [0, 0, 0];
    trick = [];
    _finished.clear();
    trickResolving = false;
    lastTrickWinner = -1;
    declarer = -1;
    declaration = null;
    skatTaken = false;
    report = null;
    bidValue = 0;
    speech = ['', '', ''];
    message = '';
    maxBids = [
      for (var p = 0; p < 3; p++)
        p == humanIndex ? 0 : Bot.evaluate(hands[p]).maxBid,
    ];
    phase = Phase.bidding;
    stage = 1;
    caller = middlehand;
    listener = forehand;
    currentBid = 0;
    callerToAct = true;
    notifyListeners();
    _bidStep();
  }

  void nextRound() {
    dealer = (dealer + 1) % 3;
    startRound();
  }

  void newSession() {
    totals = [0, 0, 0];
    roundsPlayed = 0;
    history = [];
    nextRound();
  }

  // --------------------------------------------------------------------
  // Reizen
  // --------------------------------------------------------------------

  int get actingBidder => callerToAct ? caller : listener;

  bool get humanMustBid =>
      phase == Phase.bidding && actingBidder == humanIndex;

  int get nextBidValue => nextBid(currentBid);

  void _bidStep() {
    if (phase != Phase.bidding) return;
    final actor = actingBidder;
    if (actor == humanIndex) {
      notifyListeners();
      return;
    }
    notifyListeners();
    _later(_d, () {
      if (phase != Phase.bidding || actingBidder != actor) return;
      if (callerToAct) {
        final next = nextBid(currentBid);
        if (next > 0 && next <= maxBids[actor]) {
          _callerBids(next);
        } else {
          _callerPasses();
        }
      } else {
        if (currentBid <= maxBids[actor]) {
          _listenerAccepts();
        } else {
          _listenerPasses();
        }
      }
    });
  }

  void _callerBids(int v) {
    currentBid = v;
    speech[caller] = '$v';
    speech[listener] = '';
    callerToAct = false;
    notifyListeners();
    _bidStep();
  }

  void _callerPasses() {
    speech[caller] = 'Weg';
    _endStage(listener);
  }

  void _listenerAccepts() {
    speech[listener] = 'Ja';
    callerToAct = true;
    notifyListeners();
    _bidStep();
  }

  void _listenerPasses() {
    speech[listener] = 'Weg';
    _endStage(caller);
  }

  void _endStage(int winner) {
    if (stage == 1) {
      stage = 2;
      caller = hindhand;
      listener = winner;
      callerToAct = true;
      notifyListeners();
      _bidStep();
    } else {
      _biddingFinished(winner);
    }
  }

  void _biddingFinished(int winner) {
    if (currentBid == 0) {
      // Niemand hat gereizt: Vorhand darf das Spiel übernehmen.
      declarer = forehand;
      phase = Phase.forehandChoice;
      message = 'Niemand hat gereizt.';
      notifyListeners();
      if (forehand != humanIndex) {
        _later(_d, () {
          final take = Bot.evaluate(hands[forehand]).margin >= -1.5;
          if (take) {
            currentBid = 18;
            _beginDeclarerPhase();
          } else {
            _allPassed();
          }
        });
      }
      return;
    }
    declarer = winner;
    _beginDeclarerPhase();
  }

  void humanBid() {
    if (!humanMustBid || !callerToAct) return;
    final n = nextBid(currentBid);
    if (n < 0) {
      _callerPasses();
    } else {
      _callerBids(n);
    }
  }

  void humanAccept() {
    if (!humanMustBid || callerToAct) return;
    _listenerAccepts();
  }

  void humanPassBid() {
    if (!humanMustBid) return;
    if (callerToAct) {
      _callerPasses();
    } else {
      _listenerPasses();
    }
  }

  void forehandTakeOver() {
    if (phase != Phase.forehandChoice) return;
    currentBid = 18;
    _beginDeclarerPhase();
  }

  void forehandPass() {
    if (phase != Phase.forehandChoice) return;
    _allPassed();
  }

  void _allPassed() {
    phase = Phase.allPassed;
    message = 'Alle haben gepasst – es wird neu gegeben.';
    notifyListeners();
  }

  // --------------------------------------------------------------------
  // Alleinspieler: Skat, Drücken, Ansage
  // --------------------------------------------------------------------

  void _beginDeclarerPhase() {
    bidValue = currentBid;
    phase = Phase.skatChoice;
    speech = ['', '', ''];
    message = '${names[declarer]} spielt (Reizwert $bidValue)';
    notifyListeners();
    if (declarer != humanIndex) {
      _later(_d + 300, _botSkatChoice);
    }
  }

  void _botSkatChoice() {
    if (phase != Phase.skatChoice) return;
    final hand = hands[declarer];
    final e = Bot.evaluate(hand);
    if (Bot.wantsHand(hand, bidValue)) {
      skatTaken = false;
      _declare(Declaration(type: e.type, hand: true));
      return;
    }
    skatTaken = true;
    hands[declarer] = sortedHand([...hand, ...skat]);
    skat = [];
    message = '${names[declarer]} nimmt den Skat auf';
    notifyListeners();
    _later(_d + 400, () {
      final choice = Bot.chooseAfterSkat(hands[declarer], bidValue);
      hands[declarer] = hands[declarer]
          .where((c) => !choice.discard.contains(c))
          .toList();
      skat = List<SkatCard>.of(choice.discard);
      _declare(Declaration(type: choice.type));
    });
  }

  void humanTakeSkat() {
    if (phase != Phase.skatChoice || declarer != humanIndex) return;
    skatTaken = true;
    hands[humanIndex] = sortedHand([...hands[humanIndex], ...skat]);
    skat = [];
    phase = Phase.discarding;
    notifyListeners();
  }

  void humanPlayHand() {
    if (phase != Phase.skatChoice || declarer != humanIndex) return;
    skatTaken = false;
    phase = Phase.declaring;
    notifyListeners();
  }

  void humanDiscard(List<SkatCard> two) {
    if (phase != Phase.discarding || two.length != 2) return;
    final hand = hands[humanIndex];
    if (!two.every(hand.contains)) return;
    hands[humanIndex] = hand.where((c) => !two.contains(c)).toList();
    skat = List<SkatCard>.of(two);
    phase = Phase.declaring;
    notifyListeners();
  }

  void humanDeclare(Declaration d) {
    if (phase != Phase.declaring || declarer != humanIndex) return;
    _declare(d);
  }

  void _declare(Declaration d) {
    declaration = d;
    for (var p = 0; p < 3; p++) {
      hands[p] = sortedHand(hands[p], d.type);
    }
    phase = Phase.playing;
    trick = [];
    turn = forehand;
    message = '${names[declarer]}: ${d.label}';
    notifyListeners();
    _playStep();
  }

  // --------------------------------------------------------------------
  // Stichspiel
  // --------------------------------------------------------------------

  List<SkatCard> get trickCards => [for (final t in trick) t.card];

  List<SkatCard> get legalCards {
    if (phase != Phase.playing || turn != humanIndex || trickResolving) {
      return const [];
    }
    return legalMoves(hands[humanIndex], trickCards, declaration!.type);
  }

  void _playStep() {
    if (phase != Phase.playing || trickResolving) return;
    if (turn == humanIndex) {
      notifyListeners();
      return;
    }
    final p = turn;
    notifyListeners();
    _later(_d, () => _botPlay(p));
  }

  void _botPlay(int p) {
    if (phase != Phase.playing || turn != p || trickResolving) return;
    final d = declaration!;
    final view = PlayView(
      type: d.type,
      me: p,
      declarer: declarer,
      hand: hands[p],
      trick: trickCards,
      trickPlayers: [for (final t in trick) t.player],
      seen: <SkatCard>{..._finished, ...trickCards},
      declarerOpenHand: (d.ouvert && p != declarer) ? hands[declarer] : null,
    );
    _playCard(p, Bot.chooseCard(view));
  }

  void humanPlay(SkatCard card) {
    if (!legalCards.contains(card)) return;
    _playCard(humanIndex, card);
  }

  void _playCard(int p, SkatCard card) {
    hands[p] = hands[p].where((c) => c != card).toList();
    trick = [...trick, TrickCard(p, card)];
    if (trick.length == 3) {
      trickResolving = true;
      final idx = trickWinnerIndex(trickCards, declaration!.type);
      lastTrickWinner = trick[idx].player;
      notifyListeners();
      _later(_d + 600, _collectTrick);
    } else {
      turn = (p + 1) % 3;
      notifyListeners();
      _playStep();
    }
  }

  void _collectTrick() {
    final w = lastTrickWinner;
    final cards = trickCards;
    tricksWon[w].addAll(cards);
    trickCounts[w]++;
    _finished.addAll(cards);
    trick = [];
    trickResolving = false;
    turn = w;
    final d = declaration!;
    final nullLost = d.type.isNull && w == declarer;
    if (nullLost || hands.every((h) => h.isEmpty)) {
      _endRound(nullLost);
    } else {
      notifyListeners();
      _playStep();
    }
  }

  // --------------------------------------------------------------------
  // Rundenende
  // --------------------------------------------------------------------

  void _endRound(bool endedEarly) {
    final d = declaration!;
    final tricks = trickCounts[declarer];
    final declPts = totalPoints(tricksWon[declarer]) + totalPoints(skat);

    bool won;
    var schneider = false;
    var schwarz = false;
    if (d.type.isNull) {
      won = tricks == 0;
    } else {
      won = declPts >= 61 &&
          (!d.schneiderAnnounced || declPts >= 90) &&
          (!d.schwarzAnnounced || tricks == 10);
      schneider = declPts >= 90 || declPts <= 30;
      schwarz = tricks == 10 || tricks == 0;
    }

    final original12 = [...originalHands[declarer], ...originalSkat];
    final sp = countSpitzen(original12, d.type);
    final result = evaluateGame(ScoreInput(
      type: d.type,
      withJacks: sp.withJacks,
      spitzen: max(1, sp.count),
      hand: d.hand,
      ouvert: d.ouvert,
      schneiderAnnounced: d.schneiderAnnounced,
      schwarzAnnounced: d.schwarzAnnounced,
      schneider: schneider,
      schwarz: schwarz,
      won: won,
      bid: bidValue,
    ));

    final deltas = pointsForRound(
      system: settings.playSystem,
      playerCount: 3,
      declarer: declarer,
      dealer: -1,
      result: result,
    );
    for (var p = 0; p < 3; p++) {
      totals[p] += deltas[p];
    }
    roundsPlayed++;
    history.add('${names[declarer]}: ${result.gameLabel} – '
        '${result.won ? 'gewonnen' : 'verloren'}');

    report = RoundReport(
      declarer: declarer,
      declaration: d,
      declarerPoints: declPts,
      defenderPoints: 120 - declPts,
      declarerTricks: tricks,
      result: result,
      deltas: deltas,
      skat: List<SkatCard>.of(skat),
      endedEarly: endedEarly,
    );
    phase = Phase.roundEnd;
    notifyListeners();
  }
}
