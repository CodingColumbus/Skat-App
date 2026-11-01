import 'package:flutter/foundation.dart';
import '../logic/cards.dart';
import '../logic/game.dart';
import '../logic/models.dart';
import '../logic/rules.dart';
import '../logic/view.dart';

/// Wendet eine Aktion (vom lokalen Spieler oder über das Netzwerk) auf die Engine an.
bool applyAction(SkatGame g, int seat, Map<String, dynamic> a) {
  try {
    switch (a['a']) {
      case 'bidCall':
        return g.bidCall(seat);
      case 'bidHold':
        return g.bidHold(seat);
      case 'bidPass':
        return g.bidPass(seat);
      case 'decide18':
        return g.decide18(seat, a['play'] as bool);
      case 'pickUp':
        return g.pickUpSkat(seat);
      case 'playHand':
        return g.playHand(seat, gameTypeFromJson(a['g'] as Map<String, dynamic>));
      case 'discard':
        return g.discardAndPlay(seat, cardsFromJson(a['c']), gameTypeFromJson(a['g'] as Map<String, dynamic>));
      case 'play':
        return g.playCard(seat, cardFromInt(a['c'] as int));
      case 'next':
        return g.nextRound();
    }
  } catch (_) {}
  return false;
}

/// Schnittstelle, über die die Oberfläche das Spiel bedient – lokal, als Host oder als Client.
abstract class GameController extends ChangeNotifier {
  GameView? get view;
  /// Pass-and-Play: Sitz, an den das Gerät übergeben werden soll (Hand bleibt bis dahin verdeckt).
  int? get handoffSeat => null;
  void confirmHandoff() {}
  bool get isOnline => false;
  bool get canResetTotals => true;
  String? get status => null;

  void send(Map<String, dynamic> action);

  void bidCall() => send({'a': 'bidCall'});
  void bidHold() => send({'a': 'bidHold'});
  void bidPass() => send({'a': 'bidPass'});
  void decide18(bool play) => send({'a': 'decide18', 'play': play});
  void pickUp() => send({'a': 'pickUp'});
  void playHand(GameType g) => send({'a': 'playHand', 'g': gameTypeToJson(g)});
  void discard(List<SkatCard> two, GameType g) =>
      send({'a': 'discard', 'c': cardsToJson(two), 'g': gameTypeToJson(g)});
  void playCard(SkatCard c) => send({'a': 'play', 'c': cardToInt(c)});
  void nextRound() => send({'a': 'next'});
  void resetTotals() {}
}

/// Ein Gerät, eine oder mehrere Personen (Pass-and-Play), Rest Bots.
class LocalController extends GameController {
  LocalController(this.game, {this.fixedSeat}) {
    final humans = this.humans;
    viewSeat = fixedSeat ?? (humans.isEmpty ? 0 : humans.first);
    game.addListener(_onGame);
    _onGame();
  }

  final SkatGame game;
  final int? fixedSeat;
  late int viewSeat;
  int? _handoff;

  List<int> get humans => [for (var i = 0; i < game.n; i++) if (!game.seats[i].isBot) i];

  @override
  int? get handoffSeat => _handoff;

  @override
  GameView get view => game.viewFor(viewSeat);

  void _onGame() {
    final a = game.actingSeat;
    if (fixedSeat == null && humans.length > 1 && a != null && !game.seats[a].isBot && a != viewSeat) {
      _handoff = a;
    }
    notifyListeners();
  }

  @override
  void confirmHandoff() {
    if (_handoff == null) return;
    viewSeat = _handoff!;
    _handoff = null;
    notifyListeners();
  }

  @override
  void send(Map<String, dynamic> action) {
    if (_handoff != null) return;
    applyAction(game, viewSeat, action);
  }

  @override
  void resetTotals() => game.resetTotals();

  @override
  void dispose() {
    game.removeListener(_onGame);
    game.dispose();
    super.dispose();
  }
}
