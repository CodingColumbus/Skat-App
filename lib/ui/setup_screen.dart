import 'package:flutter/material.dart';
import '../logic/game.dart';
import '../net/controller.dart';
import '../state/settings.dart';
import 'game_screen.dart';

const _botPool = ['Anna', 'Max', 'Lena'];

/// Auswahl: wie viele Menschen spielen an diesem Handy (Rest Bots).
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int humans = 1;
  List<TextEditingController>? _names;

  List<TextEditingController> get names => _names ??= [
        TextEditingController(text: SettingsScope.of(context).playerName),
        for (var i = 2; i <= 4; i++) TextEditingController(text: 'Spieler $i'),
      ];

  @override
  void dispose() {
    for (final c in _names ?? <TextEditingController>[]) {
      c.dispose();
    }
    super.dispose();
  }

  int get seats => humans < 3 ? 3 : humans;

  void _start() {
    final s = SettingsScope.of(context);
    final list = <SeatInfo>[];
    for (var i = 0; i < humans; i++) {
      final t = names[i].text.trim();
      list.add(SeatInfo(t.isEmpty ? 'Spieler ${i + 1}' : t, false));
    }
    var b = 0;
    while (list.length < 3) {
      list.add(SeatInfo(_botPool[b++], true));
    }
    final g = SkatGame(seats: list, botDelay: s.botDelay, trickDelay: s.trickDelay);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(controller: LocalController(g))));
  }

  @override
  Widget build(BuildContext context) {
    final bots = seats - humans;
    return Scaffold(
      appBar: AppBar(title: const Text('Spiel starten')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Wie viele Menschen spielen an diesem Handy?', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('1'), icon: Icon(Icons.person)),
            ButtonSegment(value: 2, label: Text('2'), icon: Icon(Icons.people)),
            ButtonSegment(value: 3, label: Text('3'), icon: Icon(Icons.groups)),
            ButtonSegment(value: 4, label: Text('4'), icon: Icon(Icons.groups_2)),
          ],
          selected: {humans},
          onSelectionChanged: (v) => setState(() => humans = v.first),
        ),
        const SizedBox(height: 8),
        Text(
          humans == 4
              ? '4 Spieler: Der Geber setzt jeweils eine Runde aus.'
              : bots == 0
                  ? '3 Spieler, keine Bots.'
                  : '$humans Mensch${humans > 1 ? 'en' : ''} + $bots Bot${bots > 1 ? 's' : ''}.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (humans > 1)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Das Handy wird weitergegeben, sobald jemand anderes dran ist. Die Hand bleibt bis dahin verdeckt.'),
          ),
        const SizedBox(height: 16),
        for (var i = 0; i < humans; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: names[i],
              maxLength: 14,
              decoration: InputDecoration(labelText: 'Name Spieler ${i + 1}', border: const OutlineInputBorder(), counterText: ''),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow), label: const Text('Los geht\'s')),
      ]),
    );
  }
}
