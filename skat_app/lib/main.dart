import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/game_screen.dart';
import 'ui/scorer_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SkatApp());
}

class SkatApp extends StatelessWidget {
  const SkatApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF14532D), useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF14532D), brightness: Brightness.dark, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String title, String sub, Widget page) => Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Icon(icon, size: 44),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(sub),
                  ]),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('♠ ♥ ♣ ♦', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text('Skat', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 32),
            tile(Icons.style, 'Spielen', 'Skat gegen zwei Bots', const GameScreen()),
            const SizedBox(height: 12),
            tile(Icons.edit_note, 'Punkte notieren', 'Mit Namen, Auto-Wertung und manueller Eingabe', const ScorerScreen()),
          ]),
        ),
      ),
    );
  }
}
