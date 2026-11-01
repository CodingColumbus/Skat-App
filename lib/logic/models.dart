import 'cards.dart';
import 'rules.dart';

enum Phase { bidding, decide18, handDecision, discard, playing, trickDone, roundOver, allPassed }

class SeatInfo {
  String name;
  bool isBot;
  SeatInfo(this.name, this.isBot);
}

int cardToInt(SkatCard c) => c.suit.index * 8 + c.rank.index;
SkatCard cardFromInt(int v) => SkatCard(Suit.values[v ~/ 8], Rank.values[v % 8]);
List<int> cardsToJson(Iterable<SkatCard> l) => [for (final c in l) cardToInt(c)];
List<SkatCard> cardsFromJson(dynamic l) => [for (final v in (l as List)) cardFromInt(v as int)];

Map<String, dynamic> gameTypeToJson(GameType g) => {'k': g.kind.index, 't': g.trump?.index ?? -1};
GameType gameTypeFromJson(Map<String, dynamic> j) {
  final k = GameKind.values[j['k'] as int];
  return switch (k) {
    GameKind.suit => GameType.suit(Suit.values[j['t'] as int]),
    GameKind.grand => const GameType.grand(),
    GameKind.nullGame => const GameType.nullGame(),
  };
}

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

  Map<String, dynamic> toJson() => {
        'd': declarer,
        'g': gameTypeToJson(game),
        'w': won,
        'p': declarerPoints,
        's': score,
        'v': gameValue,
        'sn': schneider,
        'sw': schwarz,
        'h': hand,
      };

  factory RoundResult.fromJson(Map<String, dynamic> j) => RoundResult(
        declarer: j['d'] as int,
        game: gameTypeFromJson(j['g'] as Map<String, dynamic>),
        won: j['w'] as bool,
        declarerPoints: j['p'] as int,
        score: j['s'] as int,
        gameValue: j['v'] as int,
        schneider: j['sn'] as bool,
        schwarz: j['sw'] as bool,
        hand: j['h'] as bool,
      );
}
