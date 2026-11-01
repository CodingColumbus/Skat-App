import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/scoring.dart';

/// Einstellungen der App (werden dauerhaft gespeichert).
class AppSettings extends ChangeNotifier {
  String playerName = 'Du';
  bool fourColorDeck = false;
  int botDelayMs = 700;
  bool singleTapPlay = false;
  ScoringSystem playSystem = ScoringSystem.seegerFabian;

  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      playerName = p.getString('playerName') ?? 'Du';
      fourColorDeck = p.getBool('fourColorDeck') ?? false;
      botDelayMs = p.getInt('botDelayMs') ?? 700;
      singleTapPlay = p.getBool('singleTapPlay') ?? false;
      final sys = p.getInt('playSystem') ?? 0;
      playSystem = ScoringSystem
          .values[sys.clamp(0, ScoringSystem.values.length - 1).toInt()];
    } catch (_) {
      // Standardwerte verwenden.
    }
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setString('playerName', playerName);
    p.setBool('fourColorDeck', fourColorDeck);
    p.setInt('botDelayMs', botDelayMs);
    p.setBool('singleTapPlay', singleTapPlay);
    p.setInt('playSystem', playSystem.index);
  }

  void setPlayerName(String v) {
    final name = v.trim();
    playerName = name.isEmpty ? 'Du' : name;
    _save();
    notifyListeners();
  }

  void setFourColor(bool v) {
    fourColorDeck = v;
    _save();
    notifyListeners();
  }

  void setBotDelay(int ms) {
    botDelayMs = ms;
    _save();
    notifyListeners();
  }

  void setSingleTap(bool v) {
    singleTapPlay = v;
    _save();
    notifyListeners();
  }

  void setPlaySystem(ScoringSystem s) {
    playSystem = s;
    _save();
    notifyListeners();
  }
}

/// Eine Zeile in der Punkteliste.
class RoundEntry {
  final List<int> deltas;
  final bool manual;
  final int? declarer;
  final bool? won;
  final String label;
  final String note;

  const RoundEntry({
    required this.deltas,
    required this.manual,
    this.declarer,
    this.won,
    this.label = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'deltas': deltas,
        'manual': manual,
        'declarer': declarer,
        'won': won,
        'label': label,
        'note': note,
      };

  factory RoundEntry.fromJson(Map<String, dynamic> j) => RoundEntry(
        deltas: (j['deltas'] as List).map((e) => (e as num).toInt()).toList(),
        manual: j['manual'] as bool? ?? false,
        declarer: (j['declarer'] as num?)?.toInt(),
        won: j['won'] as bool?,
        label: j['label'] as String? ?? '',
        note: j['note'] as String? ?? '',
      );
}

/// Eine Punkteliste (ein Skatabend).
class ScoreList {
  final String id;
  String title;
  final List<String> names;
  ScoringSystem system;
  final int firstDealer;
  final DateTime created;
  final List<RoundEntry> rounds;

  ScoreList({
    required this.id,
    required this.title,
    required this.names,
    required this.system,
    required this.firstDealer,
    required this.created,
    List<RoundEntry>? rounds,
  }) : rounds = rounds ?? [];

  int get playerCount => names.length;

  /// Geber der Runde mit dem Index [roundIndex].
  int dealerForRound(int roundIndex) =>
      (firstDealer + roundIndex) % playerCount;

  List<int> get totals {
    final t = List<int>.filled(playerCount, 0);
    for (final r in rounds) {
      for (var p = 0; p < playerCount && p < r.deltas.length; p++) {
        t[p] += r.deltas[p];
      }
    }
    return t;
  }

  int winsOf(int p) =>
      rounds.where((r) => r.declarer == p && r.won == true).length;

  int lossesOf(int p) =>
      rounds.where((r) => r.declarer == p && r.won == false).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'names': names,
        'system': system.index,
        'firstDealer': firstDealer,
        'created': created.toIso8601String(),
        'rounds': rounds.map((r) => r.toJson()).toList(),
      };

  factory ScoreList.fromJson(Map<String, dynamic> j) {
    final sys = (j['system'] as num?)?.toInt() ?? 0;
    return ScoreList(
      id: j['id'] as String,
      title: j['title'] as String? ?? 'Skatliste',
      names: (j['names'] as List).map((e) => e as String).toList(),
      system: ScoringSystem
          .values[sys.clamp(0, ScoringSystem.values.length - 1).toInt()],
      firstDealer: (j['firstDealer'] as num?)?.toInt() ?? 0,
      created: DateTime.tryParse(j['created'] as String? ?? '') ?? DateTime.now(),
      rounds: (j['rounds'] as List? ?? [])
          .map((e) => RoundEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Speichert alle Punktelisten.
class ListRepository extends ChangeNotifier {
  final List<ScoreList> lists = [];
  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      final raw = p.getString('score_lists');
      if (raw == null) return;
      final data = jsonDecode(raw) as List;
      lists
        ..clear()
        ..addAll(data.map((e) => ScoreList.fromJson(e as Map<String, dynamic>)));
    } catch (_) {
      // Beschädigte Daten ignorieren.
    }
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setString(
        'score_lists', jsonEncode(lists.map((l) => l.toJson()).toList()));
  }

  void add(ScoreList l) {
    lists.insert(0, l);
    _save();
    notifyListeners();
  }

  void remove(String id) {
    lists.removeWhere((l) => l.id == id);
    _save();
    notifyListeners();
  }

  /// Nach jeder Änderung an einer Liste aufrufen.
  void changed() {
    _save();
    notifyListeners();
  }
}

final AppSettings settings = AppSettings();
final ListRepository listRepo = ListRepository();
