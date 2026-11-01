import 'cards.dart';
import 'models.dart';
import 'rules.dart';

/// Was ein einzelner Spieler vom Spiel sehen darf. Wird auch übers Netzwerk gesendet.
class GameView {
  final int n;
  final List<String> names;
  final List<bool> isBot;
  final int mySeat;
  final int dealer;
  final Phase phase;
  final int? actingSeat;
  final bool callerToAct;
  final int caller, responder, bid, nextBid;
  final int? declarer;
  final GameType? game;
  final bool isHand;
  final List<SkatCard> myHand;
  final List<int> handSizes;
  final List<SkatCard> legal;
  final List<SkatCard> trick;
  final List<int> trickSeats;
  final int turn;
  final List<int> tricksWon;
  final List<int> totals;
  final String message;
  final RoundResult? result;
  final List<SkatCard> lastTrick;
  final List<int> lastTrickSeats;
  final int? lastTrickWinner;
  final List<SkatCard> revealedSkat;
  final int myAugen;
  final int round;

  const GameView({
    required this.n,
    required this.names,
    required this.isBot,
    required this.mySeat,
    required this.dealer,
    required this.phase,
    required this.actingSeat,
    required this.callerToAct,
    required this.caller,
    required this.responder,
    required this.bid,
    required this.nextBid,
    required this.declarer,
    required this.game,
    required this.isHand,
    required this.myHand,
    required this.handSizes,
    required this.legal,
    required this.trick,
    required this.trickSeats,
    required this.turn,
    required this.tricksWon,
    required this.totals,
    required this.message,
    required this.result,
    required this.lastTrick,
    required this.lastTrickSeats,
    required this.lastTrickWinner,
    required this.revealedSkat,
    required this.myAugen,
    required this.round,
  });

  bool get myTurnToAct => actingSeat == mySeat;

  Map<String, dynamic> toJson() => {
        'n': n,
        'names': names,
        'bots': isBot,
        'me': mySeat,
        'dealer': dealer,
        'phase': phase.index,
        'act': actingSeat,
        'cta': callerToAct,
        'caller': caller,
        'resp': responder,
        'bid': bid,
        'nb': nextBid,
        'decl': declarer,
        'game': game == null ? null : gameTypeToJson(game!),
        'hand': isHand,
        'mh': cardsToJson(myHand),
        'hs': handSizes,
        'legal': cardsToJson(legal),
        'trick': cardsToJson(trick),
        'ts': trickSeats,
        'turn': turn,
        'tw': tricksWon,
        'tot': totals,
        'msg': message,
        'res': result?.toJson(),
        'lt': cardsToJson(lastTrick),
        'lts': lastTrickSeats,
        'ltw': lastTrickWinner,
        'rs': cardsToJson(revealedSkat),
        'aug': myAugen,
        'round': round,
      };

  factory GameView.fromJson(Map<String, dynamic> j) => GameView(
        n: j['n'] as int,
        names: (j['names'] as List).cast<String>(),
        isBot: (j['bots'] as List).cast<bool>(),
        mySeat: j['me'] as int,
        dealer: j['dealer'] as int,
        phase: Phase.values[j['phase'] as int],
        actingSeat: j['act'] as int?,
        callerToAct: j['cta'] as bool,
        caller: j['caller'] as int,
        responder: j['resp'] as int,
        bid: j['bid'] as int,
        nextBid: j['nb'] as int,
        declarer: j['decl'] as int?,
        game: j['game'] == null ? null : gameTypeFromJson(j['game'] as Map<String, dynamic>),
        isHand: j['hand'] as bool,
        myHand: cardsFromJson(j['mh']),
        handSizes: (j['hs'] as List).cast<int>(),
        legal: cardsFromJson(j['legal']),
        trick: cardsFromJson(j['trick']),
        trickSeats: (j['ts'] as List).cast<int>(),
        turn: j['turn'] as int,
        tricksWon: (j['tw'] as List).cast<int>(),
        totals: (j['tot'] as List).cast<int>(),
        message: j['msg'] as String,
        result: j['res'] == null ? null : RoundResult.fromJson(j['res'] as Map<String, dynamic>),
        lastTrick: cardsFromJson(j['lt']),
        lastTrickSeats: (j['lts'] as List).cast<int>(),
        lastTrickWinner: j['ltw'] as int?,
        revealedSkat: cardsFromJson(j['rs']),
        myAugen: j['aug'] as int,
        round: j['round'] as int,
      );
}
