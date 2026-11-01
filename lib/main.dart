import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'state/settings.dart';
import 'ui/online_screens.dart';
import 'ui/rules_screen.dart';
import 'ui/scorer_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/setup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SkatApp());
}

class SkatApp extends StatefulWidget {
  const SkatApp({super.key});
  @override
  State<SkatApp> createState() => _SkatAppState();
}

class _SkatAppState extends State<SkatApp> {
  final settings = Settings();

  @override
  void initState() {
    super.initState();
    settings.load();
  }

  ThemeData _theme(Brightness b) {
    final base = ColorScheme.fromSeed(seedColor: const Color(0xFF1B6B3A), brightness: b);
    return ThemeData(
      colorScheme: base,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: true),
      cardTheme: CardThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => SettingsScope(
        settings: settings,
        child: MaterialApp(
          title: 'Skat',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          home: const HomeScreen(),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget tile(IconData icon, String title, String sub, Widget page, {bool primary = false}) => Card(
          clipBehavior: Clip.antiAlias,
          color: primary ? cs.primaryContainer : null,
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(children: [
                Icon(icon, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(sub, style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          children: [
            Center(child: Text('SKAT', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 6))),
            const SizedBox(height: 4),
            Center(child: Text('Spielen · Notieren · Mitspielen', style: Theme.of(context).textTheme.bodyMedium)),
            const SizedBox(height: 28),
            tile(Icons.style, 'Spielen', '1 bis 4 Spieler an einem Handy, Rest Bots', const SetupScreen(), primary: true),
            const SizedBox(height: 10),
            tile(Icons.wifi_tethering, 'Mehrspieler (WLAN)', 'Mit Freunden auf mehreren Handys, Android + iPhone', const OnlineMenuScreen()),
            const SizedBox(height: 10),
            tile(Icons.edit_note, 'Punkte notieren', 'Mit Namen, Auto-Wertung und manueller Eingabe', const ScorerScreen()),
            const SizedBox(height: 10),
            tile(Icons.menu_book, 'Regeln', 'Kurz erklärt', const RulesScreen()),
            const SizedBox(height: 10),
            tile(Icons.settings, 'Einstellungen', 'Kartenblatt, Design, Tempo, Hilfen', const SettingsScreen()),
          ],
        ),
      ),
    );
  }
}
