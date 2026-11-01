import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/suit_shapes.dart';

const tableColors = <(String, Color)>[
  ('Spielgrün', Color(0xFF1B6B3A)),
  ('Königsblau', Color(0xFF1F4E8C)),
  ('Burgund', Color(0xFF7A1F2B)),
  ('Anthrazit', Color(0xFF30343B)),
  ('Holz', Color(0xFF7B5530)),
];

class Settings extends ChangeNotifier {
  String playerName = 'Spieler';
  CardStyle cardStyle = CardStyle.french;
  ThemeMode themeMode = ThemeMode.system;
  int tableColor = 0;
  int botSpeed = 1; // 0 schnell, 1 normal, 2 langsam
  double cardScale = 1.0;
  bool showLegalHint = true;
  bool doubleTapToPlay = false;
  bool showAugen = true;
  bool haptics = true;
  bool showOpponentTricks = true;

  Duration get botDelay => const [Duration(milliseconds: 350), Duration(milliseconds: 750), Duration(milliseconds: 1300)][botSpeed];
  Duration get trickDelay => const [Duration(milliseconds: 800), Duration(milliseconds: 1400), Duration(milliseconds: 2200)][botSpeed];
  Color get table => tableColors[tableColor].$2;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      playerName = p.getString('s_name') ?? playerName;
      cardStyle = CardStyle.values[(p.getInt('s_deck') ?? 0).clamp(0, 1)];
      themeMode = ThemeMode.values[(p.getInt('s_theme') ?? 0).clamp(0, 2)];
      tableColor = (p.getInt('s_table') ?? 0).clamp(0, tableColors.length - 1);
      botSpeed = (p.getInt('s_speed') ?? 1).clamp(0, 2);
      cardScale = (p.getDouble('s_scale') ?? 1.0).clamp(0.8, 1.25);
      showLegalHint = p.getBool('s_hint') ?? true;
      doubleTapToPlay = p.getBool('s_dtap') ?? false;
      showAugen = p.getBool('s_augen') ?? true;
      haptics = p.getBool('s_haptic') ?? true;
      showOpponentTricks = p.getBool('s_tricks') ?? true;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('s_name', playerName);
      await p.setInt('s_deck', cardStyle.index);
      await p.setInt('s_theme', themeMode.index);
      await p.setInt('s_table', tableColor);
      await p.setInt('s_speed', botSpeed);
      await p.setDouble('s_scale', cardScale);
      await p.setBool('s_hint', showLegalHint);
      await p.setBool('s_dtap', doubleTapToPlay);
      await p.setBool('s_augen', showAugen);
      await p.setBool('s_haptic', haptics);
      await p.setBool('s_tricks', showOpponentTricks);
    } catch (_) {}
  }

  void update(VoidCallback f) {
    f();
    notifyListeners();
    _save();
  }
}

class SettingsScope extends InheritedNotifier<Settings> {
  const SettingsScope({super.key, required Settings settings, required super.child}) : super(notifier: settings);
  static Settings of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}
