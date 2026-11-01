import 'rules.dart';

class ScoreInput {
  final GameType game;
  final bool mit;
  final int spitzen;
  final bool hand;
  final bool ouvert;
  final bool schneiderAnsage;
  final bool schwarzAnsage;
  final bool schneider; // erreicht
  final bool schwarz; // erreicht
  final bool won;
  final int bid;
  const ScoreInput({
    required this.game,
    this.mit = true,
    this.spitzen = 1,
    this.hand = false,
    this.ouvert = false,
    this.schneiderAnsage = false,
    this.schwarzAnsage = false,
    this.schneider = false,
    this.schwarz = false,
    required this.won,
    this.bid = 0,
  });
}

/// Spielwert nach der Skatordnung.
int gameValue(ScoreInput i) {
  final g = i.game;
  if (g.isNull) {
    if (i.ouvert) return i.hand ? 59 : 46;
    return i.hand ? 35 : 23;
  }
  var mult = i.spitzen + 1; // Spiel
  if (i.hand) mult++;
  if (i.schneider || i.schneiderAnsage) mult++;
  if (i.schneiderAnsage) mult++;
  if (i.schwarz || i.schwarzAnsage) mult++;
  if (i.schwarzAnsage) mult++;
  if (i.ouvert) mult++;
  return g.baseValue * mult;
}

/// Punkte für den Alleinspieler (negativ bei Verlust, doppelt).
int scoreFor(ScoreInput i) {
  var v = gameValue(i);
  if (i.bid > 0 && v < i.bid && i.won) {
    // Überreizt: Spiel verloren, Wert = kleinstes Vielfaches des Grundwerts >= Gebot.
    final b = i.game.baseValue;
    v = ((i.bid + b - 1) ~/ b) * b;
    return -2 * v;
  }
  return i.won ? v : -2 * v;
}

/// Gültige Reizwerte aufsteigend.
List<int> bidValues() {
  final s = <int>{};
  for (final b in [9, 10, 11, 12, 23, 24]) {
    for (var m = 2; m <= 18; m++) {
      s.add(b * m);
    }
  }
  s.addAll([35, 46, 59]);
  final l = s.where((v) => v >= 18 && v <= 240).toList()..sort();
  return l;
}
