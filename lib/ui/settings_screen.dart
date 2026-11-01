import 'package:flutter/material.dart';
import '../logic/cards.dart';
import '../state/settings.dart';
import 'card_widget.dart';
import 'suit_shapes.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    Widget section(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(children: [
        section('Spieler'),
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('Dein Name'),
          subtitle: Text(s.playerName),
          onTap: () async {
            final c = TextEditingController(text: s.playerName);
            final r = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Dein Name'),
                content: TextField(controller: c, maxLength: 14, autofocus: true),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('OK')),
                ],
              ),
            );
            if (r != null && r.isNotEmpty) s.update(() => s.playerName = r);
          },
        ),
        section('Karten'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<CardStyle>(
            segments: const [
              ButtonSegment(value: CardStyle.french, label: Text('Französisch')),
              ButtonSegment(value: CardStyle.german, label: Text('Deutsch')),
            ],
            selected: {s.cardStyle},
            onSelectionChanged: (v) => s.update(() => s.cardStyle = v.first),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110 * s.cardScale,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final c in const [
                SkatCard(Suit.kreuz, Rank.bube),
                SkatCard(Suit.herz, Rank.ass),
                SkatCard(Suit.pik, Rank.koenig),
                SkatCard(Suit.karo, Rank.dame),
                SkatCard(Suit.herz, Rank.zehn),
              ])
                Padding(padding: const EdgeInsets.only(right: 8), child: CardView(card: c, width: 64 * s.cardScale, style: s.cardStyle)),
              Padding(padding: const EdgeInsets.only(right: 8), child: CardView(width: 64 * s.cardScale, style: s.cardStyle)),
            ],
          ),
        ),
        ListTile(
          title: const Text('Kartengröße'),
          subtitle: Slider(
            min: 0.8,
            max: 1.25,
            divisions: 9,
            value: s.cardScale,
            onChanged: (v) => s.update(() => s.cardScale = v),
          ),
        ),
        SwitchListTile(
          title: const Text('Spielbare Karten hervorheben'),
          subtitle: const Text('Nicht erlaubte Karten werden abgedunkelt'),
          value: s.showLegalHint,
          onChanged: (v) => s.update(() => s.showLegalHint = v),
        ),
        SwitchListTile(
          title: const Text('Karte per Doppeltipp spielen'),
          subtitle: const Text('Verhindert versehentliches Ausspielen'),
          value: s.doubleTapToPlay,
          onChanged: (v) => s.update(() => s.doubleTapToPlay = v),
        ),
        section('Aussehen'),
        ListTile(
          title: const Text('Farbschema'),
          subtitle: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto)),
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode)),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode)),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => s.update(() => s.themeMode = v.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(spacing: 10, runSpacing: 8, children: [
            for (var i = 0; i < tableColors.length; i++)
              ChoiceChip(
                avatar: CircleAvatar(backgroundColor: tableColors[i].$2),
                label: Text(tableColors[i].$1),
                selected: s.tableColor == i,
                onSelected: (_) => s.update(() => s.tableColor = i),
              ),
          ]),
        ),
        section('Spielablauf'),
        ListTile(
          title: const Text('Bot-Geschwindigkeit'),
          subtitle: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('Schnell')),
              ButtonSegment(value: 1, label: Text('Normal')),
              ButtonSegment(value: 2, label: Text('Langsam')),
            ],
            selected: {s.botSpeed},
            onSelectionChanged: (v) => s.update(() => s.botSpeed = v.first),
          ),
        ),
        SwitchListTile(
          title: const Text('Augenzähler anzeigen'),
          subtitle: const Text('Zeigt die Augen deiner Partei in dieser Runde'),
          value: s.showAugen,
          onChanged: (v) => s.update(() => s.showAugen = v),
        ),
        SwitchListTile(
          title: const Text('Stichzähler bei Gegnern'),
          value: s.showOpponentTricks,
          onChanged: (v) => s.update(() => s.showOpponentTricks = v),
        ),
        SwitchListTile(
          title: const Text('Vibration'),
          value: s.haptics,
          onChanged: (v) => s.update(() => s.haptics = v),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}
